// Windows implementation of desktop_eyedropper.
//
// A pick works like this:
//   1. Optionally hide the app window (with DWM transitions disabled so it
//      vanishes instantly) and wait for DWM to compose a frame without it.
//   2. Capture the whole virtual desktop (all monitors) into a DIB section.
//   3. Show a topmost, borderless overlay covering the virtual desktop that
//      paints the frozen capture plus a magnifier loupe at the cursor.
//   4. Left click / Enter / Space picks, Esc / right click cancels, arrow
//      keys nudge the cursor (Shift = 10px).
//   5. Restore the app window and return 0xRRGGBB (or null).
//
// The Flutter runner is per-monitor DPI aware (v2), so all coordinates here
// are physical pixels. The loupe is scaled by the DPI of the monitor under
// the cursor.

#include "desktop_eyedropper_plugin.h"

// clang-format off
#include <windows.h>
#include <windowsx.h>
#include <dwmapi.h>
#include <shellscalingapi.h>
// clang-format on

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <algorithm>
#include <cmath>
#include <cstdint>
#include <memory>
#include <string>

namespace desktop_eyedropper {

namespace {

constexpr wchar_t kOverlayClassName[] = L"DesktopEyedropperOverlay";
constexpr int kCells = 15;  // Pixels shown across the loupe (odd).

using FlutterResult = std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>;

}  // namespace

// One eyedropper pick. Owns the overlay window and the screen capture, and
// deletes itself when the overlay is destroyed.
class PickSession {
 public:
  PickSession(DesktopEyedropperPlugin* plugin, HWND app_window,
              bool hide_window, FlutterResult result)
      : plugin_(plugin),
        app_window_(app_window),
        hide_window_(hide_window),
        result_(std::move(result)) {}

  // Returns false (and responds with an error) if the pick could not start.
  bool Start() {
    if (hide_window_ && app_window_ != nullptr) HideAppWindow();

    if (!Capture()) {
      RestoreAppWindow();
      result_->Error("capture_failed", "Could not capture the screen.");
      return false;
    }
    if (!CreateOverlay()) {
      RestoreAppWindow();
      result_->Error("overlay_failed", "Could not create the picker overlay.");
      return false;
    }
    return true;
  }

  ~PickSession() {
    if (bitmap_ != nullptr) DeleteObject(bitmap_);
    if (memory_dc_ != nullptr) DeleteDC(memory_dc_);
    if (label_font_ != nullptr) DeleteObject(label_font_);
    if (hint_font_ != nullptr) DeleteObject(hint_font_);
  }

 private:
  void HideAppWindow() {
    BOOL disable = TRUE;
    DwmSetWindowAttribute(app_window_, DWMWA_TRANSITIONS_FORCEDISABLED,
                          &disable, sizeof(disable));
    ShowWindow(app_window_, SW_HIDE);
    app_hidden_ = true;
    // Wait for DWM to present a frame without our window.
    DwmFlush();
    Sleep(40);
    DwmFlush();
  }

  void RestoreAppWindow() {
    if (!app_hidden_) return;
    app_hidden_ = false;
    ShowWindow(app_window_, SW_SHOW);
    SetForegroundWindow(app_window_);
    BOOL disable = FALSE;
    DwmSetWindowAttribute(app_window_, DWMWA_TRANSITIONS_FORCEDISABLED,
                          &disable, sizeof(disable));
  }

  bool Capture() {
    origin_x_ = GetSystemMetrics(SM_XVIRTUALSCREEN);
    origin_y_ = GetSystemMetrics(SM_YVIRTUALSCREEN);
    width_ = GetSystemMetrics(SM_CXVIRTUALSCREEN);
    height_ = GetSystemMetrics(SM_CYVIRTUALSCREEN);
    if (width_ <= 0 || height_ <= 0) return false;

    HDC screen = GetDC(nullptr);
    if (screen == nullptr) return false;
    memory_dc_ = CreateCompatibleDC(screen);

    BITMAPINFO info = {};
    info.bmiHeader.biSize = sizeof(BITMAPINFOHEADER);
    info.bmiHeader.biWidth = width_;
    info.bmiHeader.biHeight = -height_;  // Top-down rows.
    info.bmiHeader.biPlanes = 1;
    info.bmiHeader.biBitCount = 32;
    info.bmiHeader.biCompression = BI_RGB;
    void* bits = nullptr;
    bitmap_ = CreateDIBSection(screen, &info, DIB_RGB_COLORS, &bits, nullptr, 0);
    if (bitmap_ == nullptr || memory_dc_ == nullptr) {
      ReleaseDC(nullptr, screen);
      return false;
    }
    pixels_ = static_cast<const uint32_t*>(bits);
    SelectObject(memory_dc_, bitmap_);
    const BOOL ok = BitBlt(memory_dc_, 0, 0, width_, height_, screen, origin_x_,
                           origin_y_, SRCCOPY | CAPTUREBLT);
    ReleaseDC(nullptr, screen);
    GdiFlush();
    return ok != FALSE;
  }

  static void EnsureClassRegistered() {
    static bool registered = false;
    if (registered) return;
    WNDCLASSEXW wc = {};
    wc.cbSize = sizeof(wc);
    wc.lpfnWndProc = &PickSession::WndProc;
    wc.hInstance = GetModuleHandle(nullptr);
    wc.hCursor = LoadCursor(nullptr, IDC_CROSS);
    wc.lpszClassName = kOverlayClassName;
    RegisterClassExW(&wc);
    registered = true;
  }

  bool CreateOverlay() {
    EnsureClassRegistered();
    POINT cursor;
    GetCursorPos(&cursor);
    cursor_x_ = cursor.x - origin_x_;
    cursor_y_ = cursor.y - origin_y_;

    overlay_ = CreateWindowExW(WS_EX_TOPMOST | WS_EX_TOOLWINDOW,
                               kOverlayClassName, L"Pick a color", WS_POPUP,
                               origin_x_, origin_y_, width_, height_, nullptr,
                               nullptr, GetModuleHandle(nullptr), this);
    if (overlay_ == nullptr) return false;
    ShowWindow(overlay_, SW_SHOW);
    SetForegroundWindow(overlay_);
    SetFocus(overlay_);
    SetCursor(LoadCursor(nullptr, IDC_CROSS));
    return true;
  }

  static LRESULT CALLBACK WndProc(HWND hwnd, UINT message, WPARAM wparam,
                                  LPARAM lparam) {
    if (message == WM_NCCREATE) {
      auto* create = reinterpret_cast<CREATESTRUCT*>(lparam);
      SetWindowLongPtr(hwnd, GWLP_USERDATA,
                       reinterpret_cast<LONG_PTR>(create->lpCreateParams));
    }
    auto* self =
        reinterpret_cast<PickSession*>(GetWindowLongPtr(hwnd, GWLP_USERDATA));
    if (self == nullptr) return DefWindowProc(hwnd, message, wparam, lparam);

    switch (message) {
      case WM_ERASEBKGND:
        return 1;
      case WM_PAINT:
        self->Paint(hwnd);
        return 0;
      case WM_SETCURSOR:
        SetCursor(LoadCursor(nullptr, IDC_CROSS));
        return TRUE;
      case WM_MOUSEMOVE:
        self->MoveTo(GET_X_LPARAM(lparam), GET_Y_LPARAM(lparam));
        return 0;
      case WM_LBUTTONDOWN:
        self->MoveTo(GET_X_LPARAM(lparam), GET_Y_LPARAM(lparam));
        self->Finish(true);
        return 0;
      case WM_RBUTTONDOWN:
        self->Finish(false);
        return 0;
      case WM_KEYDOWN:
        self->OnKey(static_cast<UINT>(wparam));
        return 0;
      case WM_CLOSE:
        self->Finish(false);
        return 0;
      case WM_NCDESTROY: {
        SetWindowLongPtr(hwnd, GWLP_USERDATA, 0);
        self->overlay_ = nullptr;
        self->Complete();
        delete self;
        return 0;
      }
      default:
        break;
    }
    return DefWindowProc(hwnd, message, wparam, lparam);
  }

  void OnKey(UINT key) {
    const int step = (GetKeyState(VK_SHIFT) & 0x8000) ? 10 : 1;
    switch (key) {
      case VK_ESCAPE:
        Finish(false);
        break;
      case VK_RETURN:
      case VK_SPACE:
        Finish(true);
        break;
      case VK_LEFT:
        Nudge(-step, 0);
        break;
      case VK_RIGHT:
        Nudge(step, 0);
        break;
      case VK_UP:
        Nudge(0, -step);
        break;
      case VK_DOWN:
        Nudge(0, step);
        break;
      default:
        break;
    }
  }

  void Nudge(int dx, int dy) {
    const int x = std::clamp(cursor_x_ + dx, 0, width_ - 1);
    const int y = std::clamp(cursor_y_ + dy, 0, height_ - 1);
    SetCursorPos(x + origin_x_, y + origin_y_);
    MoveTo(x, y);
  }

  void MoveTo(int x, int y) {
    cursor_x_ = std::clamp(x, 0, width_ - 1);
    cursor_y_ = std::clamp(y, 0, height_ - 1);
    RECT next = LoupeRect();
    InvalidateRect(overlay_, &last_loupe_, FALSE);
    InvalidateRect(overlay_, &next, FALSE);
    last_loupe_ = next;
  }

  // Reads the captured pixel at (x, y) in overlay coordinates.
  bool PixelAt(int x, int y, COLORREF* color) const {
    if (x < 0 || y < 0 || x >= width_ || y >= height_) return false;
    const uint32_t p = pixels_[static_cast<size_t>(y) * width_ + x];
    *color = RGB((p >> 16) & 0xFF, (p >> 8) & 0xFF, p & 0xFF);
    return true;
  }

  double ScaleAtCursor() const {
    POINT pt = {cursor_x_ + origin_x_, cursor_y_ + origin_y_};
    HMONITOR monitor = MonitorFromPoint(pt, MONITOR_DEFAULTTONEAREST);
    UINT dpi_x = 96, dpi_y = 96;
    if (FAILED(GetDpiForMonitor(monitor, MDT_EFFECTIVE_DPI, &dpi_x, &dpi_y))) {
      dpi_x = 96;
    }
    return dpi_x / 96.0;
  }

  struct Metrics {
    int cell;
    int loupe;
    int label_height;
  };

  Metrics GetMetrics() const {
    const double scale = ScaleAtCursor();
    Metrics m;
    m.cell = std::max(6, static_cast<int>(std::lround(9 * scale)));
    m.loupe = m.cell * kCells;
    m.label_height = static_cast<int>(std::lround(46 * scale));
    return m;
  }

  // Loupe + label rectangle in overlay coordinates, kept on the monitor
  // under the cursor.
  RECT LoupeRect() const {
    const Metrics m = GetMetrics();
    const int offset = m.cell * 2 + 4;
    const int total_height = m.loupe + m.label_height;

    POINT pt = {cursor_x_ + origin_x_, cursor_y_ + origin_y_};
    MONITORINFO info = {sizeof(info)};
    GetMonitorInfo(MonitorFromPoint(pt, MONITOR_DEFAULTTONEAREST), &info);
    const RECT mon = {info.rcMonitor.left - origin_x_,
                      info.rcMonitor.top - origin_y_,
                      info.rcMonitor.right - origin_x_,
                      info.rcMonitor.bottom - origin_y_};

    int left = cursor_x_ + offset;
    int top = cursor_y_ + offset;
    if (left + m.loupe > mon.right) left = cursor_x_ - offset - m.loupe;
    if (top + total_height > mon.bottom) top = cursor_y_ - offset - total_height;
    left = std::max<int>(left, mon.left);
    top = std::max<int>(top, mon.top);
    // Pad for border strokes.
    return RECT{left - 3, top - 3, left + m.loupe + 3, top + total_height + 3};
  }

  void EnsureFonts(int label_height) {
    if (label_font_ != nullptr && font_height_ == label_height) return;
    if (label_font_ != nullptr) DeleteObject(label_font_);
    if (hint_font_ != nullptr) DeleteObject(hint_font_);
    font_height_ = label_height;
    label_font_ = CreateFontW(-(label_height * 36 / 100), 0, 0, 0, FW_SEMIBOLD,
                              FALSE, FALSE, FALSE, DEFAULT_CHARSET,
                              OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS,
                              CLEARTYPE_QUALITY, DEFAULT_PITCH, L"Segoe UI");
    hint_font_ = CreateFontW(-(label_height * 24 / 100), 0, 0, 0, FW_NORMAL,
                             FALSE, FALSE, FALSE, DEFAULT_CHARSET,
                             OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS,
                             CLEARTYPE_QUALITY, DEFAULT_PITCH, L"Segoe UI");
  }

  void FillSolid(HDC dc, const RECT& rect, COLORREF color) {
    HBRUSH brush = CreateSolidBrush(color);
    FillRect(dc, &rect, brush);
    DeleteObject(brush);
  }

  void FrameSolid(HDC dc, RECT rect, COLORREF color, int thickness) {
    for (int i = 0; i < thickness; i++) {
      HBRUSH brush = CreateSolidBrush(color);
      FrameRect(dc, &rect, brush);
      DeleteObject(brush);
      InflateRect(&rect, -1, -1);
    }
  }

  void DrawLoupe(HDC dc) {
    const Metrics m = GetMetrics();
    const RECT bounds = LoupeRect();
    const int left = bounds.left + 3;
    const int top = bounds.top + 3;
    const int half = kCells / 2;

    // Magnified pixels.
    for (int j = -half; j <= half; j++) {
      for (int i = -half; i <= half; i++) {
        COLORREF color = RGB(128, 128, 128);
        PixelAt(cursor_x_ + i, cursor_y_ + j, &color);
        const RECT cell = {left + (i + half) * m.cell, top + (j + half) * m.cell,
                           left + (i + half + 1) * m.cell,
                           top + (j + half + 1) * m.cell};
        FillSolid(dc, cell, color);
      }
    }

    // Center pixel: black outline with white inner outline.
    RECT center = {left + half * m.cell, top + half * m.cell,
                   left + (half + 1) * m.cell, top + (half + 1) * m.cell};
    RECT outer = center;
    InflateRect(&outer, 2, 2);
    FrameSolid(dc, outer, RGB(0, 0, 0), 2);
    FrameSolid(dc, center, RGB(255, 255, 255), 1);

    // Loupe border.
    RECT frame = {left - 2, top - 2, left + m.loupe + 2, top + m.loupe + 2};
    FrameSolid(dc, frame, RGB(20, 20, 30), 2);

    // Label.
    COLORREF picked = RGB(0, 0, 0);
    PixelAt(cursor_x_, cursor_y_, &picked);
    const RECT label = {left - 2, top + m.loupe, left + m.loupe + 2,
                        top + m.loupe + m.label_height};
    FillSolid(dc, label, RGB(20, 20, 30));

    const int pad = m.label_height / 6;
    const int swatch = m.label_height * 40 / 100;
    RECT swatch_rect = {label.left + pad + 2, label.top + pad,
                        label.left + pad + 2 + swatch, label.top + pad + swatch};
    FillSolid(dc, swatch_rect, picked);
    FrameSolid(dc, swatch_rect, RGB(255, 255, 255), 1);

    EnsureFonts(m.label_height);
    SetBkMode(dc, TRANSPARENT);
    SetTextColor(dc, RGB(255, 255, 255));

    wchar_t hex[8];
    swprintf_s(hex, L"#%02X%02X%02X", GetRValue(picked), GetGValue(picked),
               GetBValue(picked));
    HGDIOBJ old_font = SelectObject(dc, label_font_);
    RECT hex_rect = {swatch_rect.right + pad, label.top + pad - 2,
                     label.right - pad, swatch_rect.bottom + 2};
    DrawTextW(dc, hex, -1, &hex_rect, DT_LEFT | DT_VCENTER | DT_SINGLELINE);

    SelectObject(dc, hint_font_);
    SetTextColor(dc, RGB(205, 205, 215));
    RECT hint_rect = {label.left + pad + 2, swatch_rect.bottom + pad / 2,
                      label.right - pad, label.bottom - pad / 2};
    DrawTextW(dc, L"Click to pick \x00B7 Esc to cancel", -1, &hint_rect,
              DT_LEFT | DT_VCENTER | DT_SINGLELINE | DT_END_ELLIPSIS);
    SelectObject(dc, old_font);
  }

  void Paint(HWND hwnd) {
    PAINTSTRUCT ps;
    HDC hdc = BeginPaint(hwnd, &ps);
    const RECT& r = ps.rcPaint;
    const int w = r.right - r.left;
    const int h = r.bottom - r.top;
    if (w > 0 && h > 0) {
      // Double-buffer the dirty region to avoid flicker.
      HDC buffer = CreateCompatibleDC(hdc);
      HBITMAP buffer_bitmap = CreateCompatibleBitmap(hdc, w, h);
      HGDIOBJ old_bitmap = SelectObject(buffer, buffer_bitmap);
      SetViewportOrgEx(buffer, -r.left, -r.top, nullptr);

      BitBlt(buffer, r.left, r.top, w, h, memory_dc_, r.left, r.top, SRCCOPY);
      DrawLoupe(buffer);

      SetViewportOrgEx(buffer, 0, 0, nullptr);
      BitBlt(hdc, r.left, r.top, w, h, buffer, 0, 0, SRCCOPY);
      SelectObject(buffer, old_bitmap);
      DeleteObject(buffer_bitmap);
      DeleteDC(buffer);
    }
    EndPaint(hwnd, &ps);
  }

  void Finish(bool picked) {
    if (finished_) return;
    finished_ = true;
    picked_ = picked;
    if (picked) {
      COLORREF color = RGB(0, 0, 0);
      has_color_ = PixelAt(cursor_x_, cursor_y_, &color);
      color_ = color;
    }
    // Completion happens in WM_NCDESTROY.
    DestroyWindow(overlay_);
  }

  void Complete() {
    RestoreAppWindow();
    if (!finished_) {
      // Destroyed externally.
      picked_ = false;
    }
    if (picked_ && has_color_) {
      const int64_t rgb = (static_cast<int64_t>(GetRValue(color_)) << 16) |
                          (static_cast<int64_t>(GetGValue(color_)) << 8) |
                          GetBValue(color_);
      result_->Success(flutter::EncodableValue(rgb));
    } else {
      result_->Success();
    }
    plugin_->OnSessionFinished();
  }

  DesktopEyedropperPlugin* plugin_;
  HWND app_window_;
  bool hide_window_;
  bool app_hidden_ = false;
  FlutterResult result_;

  HWND overlay_ = nullptr;
  HDC memory_dc_ = nullptr;
  HBITMAP bitmap_ = nullptr;
  const uint32_t* pixels_ = nullptr;
  int origin_x_ = 0;
  int origin_y_ = 0;
  int width_ = 0;
  int height_ = 0;
  int cursor_x_ = 0;
  int cursor_y_ = 0;
  RECT last_loupe_ = {0, 0, 0, 0};

  HFONT label_font_ = nullptr;
  HFONT hint_font_ = nullptr;
  int font_height_ = 0;

  bool finished_ = false;
  bool picked_ = false;
  bool has_color_ = false;
  COLORREF color_ = 0;
};

// static
void DesktopEyedropperPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows* registrar) {
  auto channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          registrar->messenger(), "desktop_eyedropper",
          &flutter::StandardMethodCodec::GetInstance());

  auto plugin = std::make_unique<DesktopEyedropperPlugin>(registrar);

  channel->SetMethodCallHandler(
      [plugin_pointer = plugin.get()](const auto& call, auto result) {
        plugin_pointer->HandleMethodCall(call, std::move(result));
      });

  registrar->AddPlugin(std::move(plugin));
}

DesktopEyedropperPlugin::DesktopEyedropperPlugin(
    flutter::PluginRegistrarWindows* registrar)
    : registrar_(registrar) {}

DesktopEyedropperPlugin::~DesktopEyedropperPlugin() = default;

void DesktopEyedropperPlugin::OnSessionFinished() { session_ = nullptr; }

HWND DesktopEyedropperPlugin::GetTopLevelWindow() const {
  if (registrar_ == nullptr || registrar_->GetView() == nullptr) return nullptr;
  HWND view = registrar_->GetView()->GetNativeWindow();
  return view != nullptr ? GetAncestor(view, GA_ROOT) : nullptr;
}

void DesktopEyedropperPlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  const std::string& method = method_call.method_name();

  if (method == "pickColor") {
    if (session_ != nullptr) {
      result->Error("busy", "A color pick is already running.");
      return;
    }
    bool hide_window = true;
    if (const auto* args =
            std::get_if<flutter::EncodableMap>(method_call.arguments())) {
      auto it = args->find(flutter::EncodableValue("hideWindow"));
      if (it != args->end()) {
        if (const auto* value = std::get_if<bool>(&it->second)) {
          hide_window = *value;
        }
      }
    }
    auto* session = new PickSession(this, GetTopLevelWindow(), hide_window,
                                    std::move(result));
    session_ = session;
    if (!session->Start()) {
      // Start() already responded with an error.
      session_ = nullptr;
      delete session;
    }
    return;
  }

  if (method == "setWindowVisible") {
    // Window hiding is handled inside pickColor on Windows.
    result->Success();
    return;
  }

  result->NotImplemented();
}

}  // namespace desktop_eyedropper
