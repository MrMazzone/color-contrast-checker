// Linux implementation of desktop_eyedropper.
//
// The Dart side first asks the XDG desktop portal (GNOME/KDE, Wayland and
// X11) to pick a color. This native code provides:
//   * setWindowVisible — hide/show the app window around a pick.
//   * pickColor        — an X11 fallback: capture the root window, show a
//                        full-screen override-redirect overlay with a
//                        magnifier loupe, and return the clicked pixel.

#include "include/desktop_eyedropper/desktop_eyedropper_plugin.h"

#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>
#ifdef GDK_WINDOWING_X11
#include <gdk/gdkx.h>
#endif

#include <algorithm>
#include <cmath>
#include <cstring>

#define DESKTOP_EYEDROPPER_PLUGIN(obj)                                     \
  (G_TYPE_CHECK_INSTANCE_CAST((obj), desktop_eyedropper_plugin_get_type(), \
                              DesktopEyedropperPlugin))

namespace {

constexpr int kCells = 15;      // Pixels shown across the loupe (odd).
constexpr int kCellSize = 9;    // Logical size of each magnified pixel.
constexpr int kLoupeSize = kCells * kCellSize;
constexpr int kLabelHeight = 44;
constexpr int kOffset = 22;     // Loupe distance from the pointer.

struct PickSession;

}  // namespace

struct _DesktopEyedropperPlugin {
  GObject parent_instance;
  FlPluginRegistrar* registrar;
  PickSession* session;
};

G_DEFINE_TYPE(DesktopEyedropperPlugin, desktop_eyedropper_plugin,
              g_object_get_type())

namespace {

struct PickSession {
  DesktopEyedropperPlugin* plugin = nullptr;
  FlMethodCall* call = nullptr;
  GtkWidget* window = nullptr;
  GdkPixbuf* shot = nullptr;
  GdkSeat* seat = nullptr;
  int width = 0;     // Root window size in logical pixels.
  int height = 0;
  double scale = 1;  // Screenshot pixels per logical pixel.
  double x = 0;      // Pointer position in logical pixels.
  double y = 0;
  GdkRectangle last_loupe = {0, 0, 0, 0};
  bool finished = false;
};

// Reads the screenshot pixel under logical position (lx, ly) offset by
// (dx, dy) screenshot pixels. Returns false when out of bounds.
bool PixelAt(const PickSession* s, double lx, double ly, int dx, int dy,
             guint8* r, guint8* g, guint8* b) {
  const int px = static_cast<int>(std::floor(lx * s->scale)) + dx;
  const int py = static_cast<int>(std::floor(ly * s->scale)) + dy;
  const int w = gdk_pixbuf_get_width(s->shot);
  const int h = gdk_pixbuf_get_height(s->shot);
  if (px < 0 || py < 0 || px >= w || py >= h) return false;
  const int n = gdk_pixbuf_get_n_channels(s->shot);
  const int stride = gdk_pixbuf_get_rowstride(s->shot);
  const guint8* p = gdk_pixbuf_read_pixels(s->shot) + py * stride + px * n;
  *r = p[0];
  *g = p[1];
  *b = p[2];
  return true;
}

GdkRectangle LoupeRect(const PickSession* s) {
  const int total_h = kLoupeSize + kLabelHeight;
  int lx = static_cast<int>(s->x) + kOffset;
  int ly = static_cast<int>(s->y) + kOffset;
  if (lx + kLoupeSize > s->width) lx = static_cast<int>(s->x) - kOffset - kLoupeSize;
  if (ly + total_h > s->height) ly = static_cast<int>(s->y) - kOffset - total_h;
  return GdkRectangle{std::max(0, lx), std::max(0, ly), kLoupeSize, total_h};
}

void InvalidateLoupe(PickSession* s) {
  GdkRectangle next = LoupeRect(s);
  // Pad by a few pixels to cover strokes drawn on the edges.
  auto queue = [s](const GdkRectangle& r) {
    if (r.width == 0) return;
    gtk_widget_queue_draw_area(s->window, r.x - 4, r.y - 4, r.width + 8,
                               r.height + 8);
  };
  queue(s->last_loupe);
  queue(next);
  s->last_loupe = next;
}

gboolean OnDraw(GtkWidget* widget, cairo_t* cr, gpointer data) {
  auto* s = static_cast<PickSession*>(data);

  // Frozen screenshot.
  cairo_save(cr);
  cairo_scale(cr, 1.0 / s->scale, 1.0 / s->scale);
  gdk_cairo_set_source_pixbuf(cr, s->shot, 0, 0);
  cairo_pattern_set_filter(cairo_get_source(cr), CAIRO_FILTER_NEAREST);
  cairo_paint(cr);
  cairo_restore(cr);

  const GdkRectangle rect = LoupeRect(s);
  const int half = kCells / 2;

  // Magnified pixels.
  for (int j = -half; j <= half; j++) {
    for (int i = -half; i <= half; i++) {
      guint8 r = 128, g = 128, b = 128;
      PixelAt(s, s->x, s->y, i, j, &r, &g, &b);
      cairo_set_source_rgb(cr, r / 255.0, g / 255.0, b / 255.0);
      cairo_rectangle(cr, rect.x + (i + half) * kCellSize,
                      rect.y + (j + half) * kCellSize, kCellSize, kCellSize);
      cairo_fill(cr);
    }
  }

  // Center pixel highlight: dark outline with a light inner outline so it is
  // visible on any color.
  const double cx = rect.x + half * kCellSize;
  const double cy = rect.y + half * kCellSize;
  cairo_set_line_width(cr, 2);
  cairo_set_source_rgb(cr, 0, 0, 0);
  cairo_rectangle(cr, cx - 1, cy - 1, kCellSize + 2, kCellSize + 2);
  cairo_stroke(cr);
  cairo_set_line_width(cr, 1);
  cairo_set_source_rgb(cr, 1, 1, 1);
  cairo_rectangle(cr, cx + 0.5, cy + 0.5, kCellSize - 1, kCellSize - 1);
  cairo_stroke(cr);

  // Loupe border.
  cairo_set_line_width(cr, 2);
  cairo_set_source_rgb(cr, 0.08, 0.08, 0.12);
  cairo_rectangle(cr, rect.x, rect.y, kLoupeSize, kLoupeSize);
  cairo_stroke(cr);

  // Label with swatch, hex value and hint.
  guint8 r = 0, g = 0, b = 0;
  PixelAt(s, s->x, s->y, 0, 0, &r, &g, &b);
  const double label_y = rect.y + kLoupeSize;
  cairo_set_source_rgba(cr, 0.08, 0.08, 0.12, 0.94);
  cairo_rectangle(cr, rect.x - 1, label_y, kLoupeSize + 2, kLabelHeight);
  cairo_fill(cr);

  cairo_set_source_rgb(cr, r / 255.0, g / 255.0, b / 255.0);
  cairo_rectangle(cr, rect.x + 8, label_y + 8, 18, 18);
  cairo_fill_preserve(cr);
  cairo_set_source_rgb(cr, 1, 1, 1);
  cairo_set_line_width(cr, 1);
  cairo_stroke(cr);

  char hex[8];
  g_snprintf(hex, sizeof(hex), "#%02X%02X%02X", r, g, b);
  cairo_select_font_face(cr, "Sans", CAIRO_FONT_SLANT_NORMAL,
                         CAIRO_FONT_WEIGHT_BOLD);
  cairo_set_font_size(cr, 14);
  cairo_move_to(cr, rect.x + 34, label_y + 22);
  cairo_show_text(cr, hex);

  cairo_select_font_face(cr, "Sans", CAIRO_FONT_SLANT_NORMAL,
                         CAIRO_FONT_WEIGHT_NORMAL);
  cairo_set_font_size(cr, 10);
  cairo_set_source_rgba(cr, 1, 1, 1, 0.8);
  cairo_move_to(cr, rect.x + 8, label_y + 39);
  cairo_show_text(cr, "Click to pick \xC2\xB7 Esc to cancel");
  return TRUE;
}

void Finish(PickSession* s, bool picked) {
  if (s->finished) return;
  s->finished = true;

  if (s->seat != nullptr) gdk_seat_ungrab(s->seat);

  g_autoptr(FlValue) value = nullptr;
  if (picked) {
    guint8 r = 0, g = 0, b = 0;
    if (PixelAt(s, s->x, s->y, 0, 0, &r, &g, &b)) {
      value = fl_value_new_int((r << 16) | (g << 8) | b);
    }
  }
  if (value == nullptr) value = fl_value_new_null();
  fl_method_call_respond_success(s->call, value, nullptr);

  gtk_widget_destroy(s->window);
  g_object_unref(s->shot);
  g_object_unref(s->call);
  s->plugin->session = nullptr;
  delete s;
}

void MovePointer(PickSession* s, double dx, double dy) {
  s->x = std::clamp(s->x + dx, 0.0, static_cast<double>(s->width - 1));
  s->y = std::clamp(s->y + dy, 0.0, static_cast<double>(s->height - 1));
  if (s->seat != nullptr) {
    GdkDevice* pointer = gdk_seat_get_pointer(s->seat);
    if (pointer != nullptr) {
      gdk_device_warp(pointer, gtk_widget_get_screen(s->window),
                      static_cast<int>(std::lround(s->x)),
                      static_cast<int>(std::lround(s->y)));
    }
  }
  InvalidateLoupe(s);
}

gboolean OnMotion(GtkWidget* widget, GdkEventMotion* event, gpointer data) {
  auto* s = static_cast<PickSession*>(data);
  s->x = event->x;
  s->y = event->y;
  InvalidateLoupe(s);
  return TRUE;
}

gboolean OnButton(GtkWidget* widget, GdkEventButton* event, gpointer data) {
  auto* s = static_cast<PickSession*>(data);
  if (event->type != GDK_BUTTON_PRESS) return TRUE;
  s->x = event->x;
  s->y = event->y;
  if (event->button == 1) {
    Finish(s, true);
  } else if (event->button == 3) {
    Finish(s, false);
  }
  return TRUE;
}

gboolean OnKey(GtkWidget* widget, GdkEventKey* event, gpointer data) {
  auto* s = static_cast<PickSession*>(data);
  const double step = (event->state & GDK_SHIFT_MASK) ? 10 : 1;
  switch (event->keyval) {
    case GDK_KEY_Escape:
      Finish(s, false);
      break;
    case GDK_KEY_Return:
    case GDK_KEY_KP_Enter:
    case GDK_KEY_space:
      Finish(s, true);
      break;
    case GDK_KEY_Left:
      MovePointer(s, -step, 0);
      break;
    case GDK_KEY_Right:
      MovePointer(s, step, 0);
      break;
    case GDK_KEY_Up:
      MovePointer(s, 0, -step);
      break;
    case GDK_KEY_Down:
      MovePointer(s, 0, step);
      break;
    default:
      break;
  }
  return TRUE;
}

gboolean OnMap(GtkWidget* widget, GdkEvent* event, gpointer data) {
  auto* s = static_cast<PickSession*>(data);
  GdkWindow* gdk_window = gtk_widget_get_window(widget);
  GdkDisplay* display = gtk_widget_get_display(widget);
  g_autoptr(GdkCursor) cursor =
      gdk_cursor_new_for_display(display, GDK_CROSSHAIR);
  s->seat = gdk_display_get_default_seat(display);
  gdk_seat_grab(s->seat, gdk_window, GDK_SEAT_CAPABILITY_ALL, TRUE, cursor,
                nullptr, nullptr, nullptr);
  return FALSE;
}

GtkWindow* GetToplevel(DesktopEyedropperPlugin* self) {
  FlView* view = fl_plugin_registrar_get_view(self->registrar);
  if (view == nullptr) return nullptr;
  GtkWidget* toplevel = gtk_widget_get_toplevel(GTK_WIDGET(view));
  return GTK_IS_WINDOW(toplevel) ? GTK_WINDOW(toplevel) : nullptr;
}

FlMethodResponse* SetWindowVisible(DesktopEyedropperPlugin* self,
                                   FlValue* args) {
  gboolean visible = TRUE;
  if (args != nullptr && fl_value_get_type(args) == FL_VALUE_TYPE_MAP) {
    FlValue* v = fl_value_lookup_string(args, "visible");
    if (v != nullptr && fl_value_get_type(v) == FL_VALUE_TYPE_BOOL) {
      visible = fl_value_get_bool(v);
    }
  }
  GtkWindow* window = GetToplevel(self);
  if (window != nullptr) {
    if (visible) {
      gtk_widget_show(GTK_WIDGET(window));
      gtk_window_present(window);
    } else {
      gtk_widget_hide(GTK_WIDGET(window));
    }
  }
  return FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
}

FlMethodResponse* ErrorResponse(const char* code, const char* message) {
  return FL_METHOD_RESPONSE(
      fl_method_error_response_new(code, message, nullptr));
}

// Starts an X11 pick. Responds asynchronously when the user clicks or
// cancels; returns an immediate error response otherwise.
FlMethodResponse* StartPick(DesktopEyedropperPlugin* self,
                            FlMethodCall* method_call) {
  if (self->session != nullptr) {
    return ErrorResponse("busy", "A color pick is already running.");
  }

  GdkDisplay* display = gdk_display_get_default();
#ifdef GDK_WINDOWING_X11
  const bool is_x11 = display != nullptr && GDK_IS_X11_DISPLAY(display);
#else
  const bool is_x11 = false;
#endif
  if (!is_x11) {
    return ErrorResponse(
        "unsupported",
        "This desktop does not provide a screen color picker. Install "
        "xdg-desktop-portal with a GNOME or KDE backend to enable it.");
  }

  GdkWindow* root = gdk_get_default_root_window();
  const int width = gdk_window_get_width(root);
  const int height = gdk_window_get_height(root);
  GdkPixbuf* shot = gdk_pixbuf_get_from_window(root, 0, 0, width, height);
  if (shot == nullptr) {
    return ErrorResponse("capture_failed", "Could not capture the screen.");
  }

  auto* s = new PickSession();
  s->plugin = self;
  s->call = FL_METHOD_CALL(g_object_ref(method_call));
  s->shot = shot;
  s->width = width;
  s->height = height;
  s->scale = static_cast<double>(gdk_pixbuf_get_width(shot)) / width;
  self->session = s;

  GdkSeat* seat = gdk_display_get_default_seat(display);
  GdkDevice* pointer = seat != nullptr ? gdk_seat_get_pointer(seat) : nullptr;
  if (pointer != nullptr) {
    gdk_device_get_position_double(pointer, nullptr, &s->x, &s->y);
  }

  s->window = gtk_window_new(GTK_WINDOW_POPUP);
  gtk_window_move(GTK_WINDOW(s->window), 0, 0);
  gtk_widget_set_size_request(s->window, width, height);
  gtk_widget_set_app_paintable(s->window, TRUE);
  gtk_widget_add_events(s->window, GDK_POINTER_MOTION_MASK |
                                       GDK_BUTTON_PRESS_MASK |
                                       GDK_KEY_PRESS_MASK);
  g_signal_connect(s->window, "draw", G_CALLBACK(OnDraw), s);
  g_signal_connect(s->window, "motion-notify-event", G_CALLBACK(OnMotion), s);
  g_signal_connect(s->window, "button-press-event", G_CALLBACK(OnButton), s);
  g_signal_connect(s->window, "key-press-event", G_CALLBACK(OnKey), s);
  g_signal_connect(s->window, "map-event", G_CALLBACK(OnMap), s);
  gtk_widget_show_all(s->window);
  return nullptr;
}

}  // namespace

static void desktop_eyedropper_plugin_handle_method_call(
    DesktopEyedropperPlugin* self, FlMethodCall* method_call) {
  const gchar* method = fl_method_call_get_name(method_call);
  g_autoptr(FlMethodResponse) response = nullptr;

  if (strcmp(method, "pickColor") == 0) {
    response = StartPick(self, method_call);
    if (response == nullptr) return;  // Responds when the pick finishes.
  } else if (strcmp(method, "setWindowVisible") == 0) {
    response = SetWindowVisible(self, fl_method_call_get_args(method_call));
  } else {
    response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  }
  fl_method_call_respond(method_call, response, nullptr);
}

static void desktop_eyedropper_plugin_dispose(GObject* object) {
  G_OBJECT_CLASS(desktop_eyedropper_plugin_parent_class)->dispose(object);
}

static void desktop_eyedropper_plugin_class_init(
    DesktopEyedropperPluginClass* klass) {
  G_OBJECT_CLASS(klass)->dispose = desktop_eyedropper_plugin_dispose;
}

static void desktop_eyedropper_plugin_init(DesktopEyedropperPlugin* self) {
  self->registrar = nullptr;
  self->session = nullptr;
}

static void method_call_cb(FlMethodChannel* channel, FlMethodCall* method_call,
                           gpointer user_data) {
  DesktopEyedropperPlugin* plugin = DESKTOP_EYEDROPPER_PLUGIN(user_data);
  desktop_eyedropper_plugin_handle_method_call(plugin, method_call);
}

void desktop_eyedropper_plugin_register_with_registrar(
    FlPluginRegistrar* registrar) {
  DesktopEyedropperPlugin* plugin = DESKTOP_EYEDROPPER_PLUGIN(
      g_object_new(desktop_eyedropper_plugin_get_type(), nullptr));
  plugin->registrar = registrar;

  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  g_autoptr(FlMethodChannel) channel =
      fl_method_channel_new(fl_plugin_registrar_get_messenger(registrar),
                            "desktop_eyedropper", FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(
      channel, method_call_cb, g_object_ref(plugin), g_object_unref);

  g_object_unref(plugin);
}
