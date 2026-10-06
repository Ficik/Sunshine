/**
 * @file tests/unit/test_clipboard.cpp
 * @brief Test bounded clipboard data and X11 selection ownership.
 */
#include "src/clipboard.h"

#include <gtest/gtest.h>

TEST(Clipboard, RejectsOversizedAndNulText) {
  EXPECT_THROW(clipboard::transfer(true, std::string(clipboard::MAX_BYTES + 1, 'x')), std::runtime_error);
  EXPECT_THROW(clipboard::transfer(true, std::string("a\0b", 3)), std::runtime_error);
}

#ifdef SUNSHINE_BUILD_X11
TEST(Clipboard, X11UnicodeEmptyAndIncrementalTransfer) {
  // Opt in only on the isolated Xvfb test display, never the user's clipboard.
  if (!std::getenv("SUNSHINE_CLIPBOARD_TEST")) {
    GTEST_SKIP() << "Set SUNSHINE_CLIPBOARD_TEST=1 with an isolated X11 DISPLAY";
  }
  EXPECT_THROW(clipboard::transfer(false), clipboard::no_text);
  // Match proc_t::running()'s catch-all reaper while clipboard helpers exit.
  std::jthread reaper([](std::stop_token stop) {
    while (!stop.stop_requested()) {
      {
        std::lock_guard lock {clipboard::child_reaper_mutex()};
        while (waitpid(-1, nullptr, WNOHANG) > 0) {}
      }
      std::this_thread::sleep_for(std::chrono::milliseconds(1));
    }
  });
  for (const auto &text : {std::string("Příliš žluťoučký 🦎\nline two\t&<>"), std::string(), std::string(clipboard::MAX_BYTES, 'x')}) {
    clipboard::transfer(true, text);
    EXPECT_EQ(clipboard::transfer(false), text);
  }
}

#endif
