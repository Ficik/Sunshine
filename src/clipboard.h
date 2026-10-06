/**
 * @file src/clipboard.h
 * @brief Bounded UTF-8 clipboard access for the X11 desktop.
 */
#pragma once

#include <mutex>
#include <stdexcept>
#include <string>
#include <string_view>

#ifdef SUNSHINE_BUILD_X11
  #include <chrono>
  #include <cstdio>
  #include <fcntl.h>
  #include <poll.h>
  #include <spawn.h>
  #include <sys/wait.h>
  #include <thread>
  #include <unistd.h>

extern char **environ;
#endif

namespace clipboard {
  constexpr size_t MAX_BYTES = 1024 * 1024;  ///< Maximum UTF-8 clipboard payload.

  /**
   * @brief Serialize clipboard child ownership with Sunshine's catch-all child reaper.
   * @return Mutex held until a clipboard helper's exit status has been collected.
   */
  inline std::mutex &child_reaper_mutex() {
    static std::mutex mutex;
    return mutex;
  }

  /** @brief The current X11 selection has no UTF-8 text target. */
  class no_text: public std::runtime_error {
  public:
    using std::runtime_error::runtime_error;
  };

  /**
   * @brief Read or replace CLIPBOARD using xclip, which handles X11 INCR transfers.
   * @param write Whether to replace the selection.
   * @param text UTF-8 text to put on the clipboard.
   * @return Current text on reads; empty on writes.
   * @throws std::runtime_error On unavailable clipboard, oversized data or timeout.
   */
  inline std::string transfer(bool write, std::string_view text = {}) {
    if (text.size() > MAX_BYTES || text.find('\0') != std::string_view::npos) {
      throw std::runtime_error("Clipboard text is too large or contains NUL");
    }
#ifdef SUNSHINE_BUILD_X11
    std::lock_guard lock {child_reaper_mutex()};
    // No shell, command-line text, or named temporary files. xclip owns the
    // selection after its parent exits, so an acknowledged write is pasteable.
    FILE *input = std::tmpfile();
    if (!input) {
      throw std::runtime_error("Cannot create clipboard input");
    }
    if (std::fwrite(text.data(), 1, text.size(), input) != text.size()) {
      std::fclose(input);
      throw std::runtime_error("Cannot write clipboard input");
    }
    std::rewind(input);
    int output[2];
    if (pipe2(output, O_CLOEXEC) != 0) {
      std::fclose(input);
      throw std::runtime_error("Cannot create clipboard output");
    }
    posix_spawn_file_actions_t actions;
    posix_spawn_file_actions_init(&actions);
    posix_spawn_file_actions_adddup2(&actions, fileno(input), STDIN_FILENO);
    if (write) {
      posix_spawn_file_actions_addopen(&actions, STDOUT_FILENO, "/dev/null", O_WRONLY, 0);
    } else {
      posix_spawn_file_actions_adddup2(&actions, output[1], STDOUT_FILENO);
    }
    posix_spawn_file_actions_addopen(&actions, STDERR_FILENO, "/dev/null", O_WRONLY, 0);
    posix_spawn_file_actions_addclose(&actions, output[0]);
    posix_spawn_file_actions_addclose(&actions, output[1]);
    posix_spawn_file_actions_addclose(&actions, fileno(input));
    const char *args[] = {"/usr/bin/xclip", "-selection", "clipboard", "-target", "UTF8_STRING", write ? "-in" : "-out", nullptr};
    pid_t pid;
    int error = posix_spawn(&pid, args[0], &actions, nullptr, const_cast<char **>(args), environ);
    posix_spawn_file_actions_destroy(&actions);
    std::fclose(input);
    close(output[1]);
    if (error) {
      close(output[0]);
      throw std::runtime_error("Cannot start xclip; install xclip and set DISPLAY");
    }
    fcntl(output[0], F_SETFL, O_NONBLOCK);
    auto deadline = std::chrono::steady_clock::now() + std::chrono::seconds(2);
    std::string result;
    int status = 0;
    bool finished = false;
    bool eof = write;
    while (std::chrono::steady_clock::now() < deadline) {
      char buffer[16384];
      ssize_t count;
      while (!eof && (count = read(output[0], buffer, sizeof(buffer))) > 0) {
        result.append(buffer, count);
        if (result.size() > MAX_BYTES) {
          break;
        }
      }
      if (!eof && count == 0) {
        eof = true;
      }
      if (result.size() > MAX_BYTES) {
        break;
      }
      if (!finished) {
        finished = waitpid(pid, &status, WNOHANG) == pid;
      }
      if (finished && eof) {
        break;
      }
      std::this_thread::sleep_for(std::chrono::milliseconds(5));
    }
    close(output[0]);
    if (!finished) {
      kill(pid, SIGKILL);
      while (waitpid(pid, &status, 0) < 0 && errno == EINTR) {}
    }
    if (!write && finished && eof && WIFEXITED(status) && WEXITSTATUS(status) == 1) {
      throw no_text("No text clipboard is available");
    }
    if (!finished || !eof || result.size() > MAX_BYTES || !WIFEXITED(status) || WEXITSTATUS(status) != 0) {
      throw std::runtime_error("X11 clipboard unavailable, too large, or timed out");
    }
    return result;
#else
    throw std::runtime_error("Clipboard requires an X11 build");
#endif
  }
}  // namespace clipboard
