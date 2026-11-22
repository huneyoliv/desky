#include "flutter_window.h"

#include <dwmapi.h>
#include <flutter/standard_method_codec.h>

#include <optional>

#include "flutter/generated_plugin_registrant.h"

namespace {

// A window the user would expect to receive focus once Desky steps back.
bool IsActivationCandidate(HWND candidate, HWND self) {
  if (candidate == self || !IsWindowVisible(candidate) || IsIconic(candidate)) {
    return false;
  }
  if (GetWindow(candidate, GW_OWNER) != nullptr) return false;
  const LONG_PTR ex_style = GetWindowLongPtr(candidate, GWL_EXSTYLE);
  if (ex_style & (WS_EX_TOOLWINDOW | WS_EX_NOACTIVATE)) return false;
  BOOL cloaked = FALSE;
  if (SUCCEEDED(DwmGetWindowAttribute(candidate, DWMWA_CLOAKED, &cloaked,
                                      sizeof(cloaked))) &&
      cloaked) {
    return false;
  }
  return true;
}

}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  window_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(), "dev.desky/window",
          &flutter::StandardMethodCodec::GetInstance());
  window_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
                 result) {
        if (call.method_name() == "setOverlayMode") {
          const auto* enabled = std::get_if<bool>(call.arguments());
          overlay_mode_ = enabled != nullptr && *enabled;
          result->Success();
        } else if (call.method_name() == "sendToBack") {
          SendToBack(GetHandle());
          result->Success();
        } else {
          result->NotImplemented();
        }
      });

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::SendToBack(HWND hwnd) {
  if (hwnd == nullptr) return;
  // Find who should get focus before we move, while z-order is still intact.
  HWND next = GetWindow(hwnd, GW_HWNDNEXT);
  while (next != nullptr && !IsActivationCandidate(next, hwnd)) {
    next = GetWindow(next, GW_HWNDNEXT);
  }
  if (IsIconic(hwnd)) ShowWindow(hwnd, SW_RESTORE);
  // HWND_BOTTOM also drops "always on top" (mini player), which is wanted:
  // otherwise the window could not go behind anything.
  SetWindowPos(hwnd, HWND_BOTTOM, 0, 0, 0, 0,
               SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE);
  if (next != nullptr) {
    SetForegroundWindow(next);
  }
}

void FlutterWindow::OnDestroy() {
  window_channel_ = nullptr;
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // OBS overlay mode: a minimized window is not drawn, so OBS loses it.
  // Taskbar clicks, Win+Down and the system menu all arrive as SC_MINIMIZE;
  // turn them into "send to back" so the window keeps rendering.
  if (overlay_mode_ && message == WM_SYSCOMMAND &&
      (wparam & 0xFFF0) == SC_MINIMIZE) {
    SendToBack(hwnd);
    return 0;
  }

  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
