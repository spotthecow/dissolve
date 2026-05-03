const std = @import("std");
const Io = std.Io;

const dissolve = @import("dissolve");
const window = dissolve.window;

pub fn main(init: std.process.Init) !void {
    const io = init.io;

    window.init();
    const w = try window.create(1280, 720, "hello zig");
    defer window.destroy(w);

    while (!window.shouldClose(w)) {
        window.pumpEvents();
        try io.sleep(.fromMilliseconds(16), .awake);
    }
}
