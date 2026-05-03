pub const Window = opaque {};

extern "c" fn platform_init() void;
extern "c" fn platform_window_create(width: c_int, height: c_int, title: [*:0]const u8) ?*Window;
extern "c" fn platform_window_destroy(window: *Window) void;
extern "c" fn platform_window_should_close(window: *Window) bool;
extern "c" fn platform_pump_events() void;

pub fn init() void {
    platform_init();
}

pub fn create(width: u32, height: u32, title: [:0]const u8) !*Window {
    const window = platform_window_create(@intCast(width), @intCast(height), title.ptr);
    return window orelse error.WindowCreateFailed;
}

pub fn destroy(window: *Window) void {
    platform_window_destroy(window);
}

pub fn shouldClose(window: *Window) bool {
    return platform_window_should_close(window);
}

pub fn pumpEvents() void {
    platform_pump_events();
}
