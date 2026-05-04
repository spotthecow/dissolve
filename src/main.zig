const std = @import("std");
const render = @import("render.zig");
const window = @import("window.zig");

const Window = window.Window;

pub fn main(init: std.process.Init) !void {
    const io = init.io;

    window.init();

    var instance = try render.createInstance("dissolve");
    defer instance.deinit();
    std.debug.print("Vulkan instance created\n", .{});

    const w = try Window.create(1280, 720, "dissolve");
    defer w.destroy();

    var surface = try render.createSurface(&instance, w);
    defer surface.deinit();
    std.debug.print("Vulkan surface created\n", .{});

    while (!w.shouldClose()) {
        window.pumpEvents();
        try io.sleep(.fromMilliseconds(16), .awake);
    }
}
