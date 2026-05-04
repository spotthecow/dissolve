const builtin = @import("builtin");

const backend = switch (builtin.os.tag) {
    .macos => @import("platform/macos/backend.zig"),
    else => @compileError("dissolve: unsupported OS '" ++ @tagName(builtin.os.tag) ++ "'"),
};

pub const init = backend.init;
pub const pumpEvents = backend.pumpEvents;

pub const Window = struct {
    handle: *backend.Window,

    pub fn create(width: u32, height: u32, title: [:0]const u8) !Window {
        return .{ .handle = try backend.create(width, height, title) };
    }

    pub fn destroy(self: Window) void {
        backend.destroy(self.handle);
    }

    pub fn shouldClose(self: Window) bool {
        return backend.shouldClose(self.handle);
    }

    pub fn getMetalLayer(self: Window) error{NoMetalLayer}!*anyopaque {
        return try backend.getMetalLayer(self.handle);
    }
};
