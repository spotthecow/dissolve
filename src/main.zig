const std = @import("std");
const window = @import("window.zig");
const instance_mod = @import("render/instance.zig");

pub fn main(init: std.process.Init) !void {
    const io = init.io;

    window.init();

    var instance = try instance_mod.create("dissolve");
    defer instance.deinit();
    std.debug.print("Vulkan instance created\n", .{});

    const w = try window.create(1280, 720, "hello zig");
    defer window.destroy(w);

    while (!window.shouldClose(w)) {
        window.pumpEvents();
        try io.sleep(.fromMilliseconds(16), .awake);
    }
}
