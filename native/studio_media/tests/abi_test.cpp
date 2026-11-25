#include "studio_media.h"
#include <atomic>
#include <chrono>
#include <condition_variable>
#include <filesystem>
#include <iostream>
#include <mutex>
#include <nlohmann/json.hpp>
#include <stdexcept>
#include <thread>
using J = nlohmann::json;
void require(bool b) {
  if (!b)
    throw std::runtime_error("assertion failed");
}
J response(char *s) {
  require(s);
  J j;
  try {
    j = J::parse(s);
  } catch (...) {
    sm_string_free(s);
    throw;
  }
  sm_string_free(s);
  return j;
}
size_t fds() {
  return std::distance(std::filesystem::directory_iterator("/proc/self/fd"),
                       std::filesystem::directory_iterator());
}
int main(int argc, char **argv) {
  try {
    require(argc == 2);
    std::string test = argv[1];
    require(sm_abi_version() == 1);
    const auto before = fds();
    if (test == "handles") {
      require(sm_create(nullptr) == 0);
      require(sm_create("") == 0);
      for (int i = 0; i < 100; i++) {
        auto a = sm_create("studio"), b = sm_create("image");
        require(a && b && a != b);
        require(response(sm_probe(a, "image", "/not/read"))["code"] ==
                "NAMESPACE_MISMATCH");
        require(sm_close(a, "image") == -1);
        require(sm_cancel(b, "studio") == -1);
        require(sm_cancel(a, "studio") == 0);
        require(sm_close(a, "studio") == 0);
        require(sm_close(a, "studio") == -1);
        require(response(sm_probe(a, "studio", "/not/read"))["code"] ==
                "INVALID_HANDLE");
        require(sm_close(b, "image") == 0);
      }
    } else if (test == "errors") {
      auto h = sm_create("test");
      for (auto path : {"https://example.invalid/media.mp4", "file:/etc/passwd",
                        "relative.mp4"})
        require(response(sm_probe(h, "test", path))["code"] ==
                "LOCAL_FILE_REQUIRED");
      require(!response(sm_export(h, "test", "not json"))["ok"].get<bool>());
      require(response(sm_export(h, "test", "{}"))["code"] == "RECIPE_FIELDS");
      require(
          response(sm_export(h, "test", "{\"width\":1,\"width\":2}"))["code"] ==
          "RECIPE_DUPLICATE_KEY");
      std::string deep(66, '[');
      deep += "0";
      deep += std::string(66, ']');
      require(response(sm_export(h, "test", deep.c_str()))["code"] ==
              "RECIPE_DEPTH_LIMIT");
      require(sm_close(h, "test") == 0);
    } else if (test == "cancel") {
      auto root =
          std::filesystem::temp_directory_path() /
          ("studio-cancel-" +
           std::to_string(
               std::chrono::steady_clock::now().time_since_epoch().count()));
      std::filesystem::create_directory(root);
      for (int i = 0; i < 10; i++) {
        auto h = sm_create("cancel");
        std::atomic<bool> done = false;
        J result;
        J recipe = {
            {"outputPath", (root / (std::to_string(i) + ".pending")).string()},
            {"width", 720},
            {"height", 1280},
            {"fps", {{"n", 30}, {"d", 1}}},
            {"frameCount", 120000},
            {"segments", J::array()}};
        std::thread work([&] {
          result = response(sm_export(h, "cancel", recipe.dump().c_str()));
          done = true;
        });
        std::mutex m;
        std::condition_variable cv;
        std::unique_lock lock(m);
        const auto limit =
            std::chrono::steady_clock::now() + std::chrono::seconds(10);
        while (!done && std::chrono::steady_clock::now() < limit) {
          sm_cancel(h, "cancel");
          cv.wait_for(lock, std::chrono::milliseconds(1));
        }
        if (!done)
          sm_close(h, "cancel");
        work.join();
        require(result["code"] == "CANCELED");
        require(sm_close(h, "cancel") == 0);
      }
      std::filesystem::remove_all(root);
    } else
      throw std::runtime_error("unknown test");
    require(fds() == before);
    std::cout << test << ": PASS; fd delta=0\n";
    return 0;
  } catch (const std::exception &e) {
    std::cerr << e.what() << "\n";
    return 1;
  }
}
