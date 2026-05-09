const std = @import("std");
const gpu = @import("gpu.zig");
const window = @import("window.zig");

const testing = std.testing;
const Window = window.Window;

const vk = @import("vulkan");

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const gpa = init.gpa;

    window.init();

    var instance = try gpu.instance.create();
    defer instance.deinit();

    const w = try Window.create(1280, 720, "dissolve");
    defer w.destroy();

    var surface = try gpu.surface.create(&instance, w);
    defer surface.deinit();

    var device = try gpu.device.createForSurfaceAlloc(surface, gpa);
    defer device.deinit();

    while (!w.shouldClose()) {
        window.pumpEvents();
        try io.sleep(.fromMilliseconds(16), .awake);
    }
}

test {
    testing.refAllDecls(@This());
}
