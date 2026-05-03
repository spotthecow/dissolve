const builtin = @import("builtin");

const backend = switch (builtin.os.tag) {
    .macos => @import("platform/macos/backend.zig"),
    else => @compileError("dissolve: unsupported OS '" ++ @tagName(builtin.os.tag) ++ "'"),
};

pub const Window = backend.Window;
pub const init = backend.init;
pub const create = backend.create;
pub const destroy = backend.destroy;
pub const shouldClose = backend.shouldClose;
pub const pumpEvents = backend.pumpEvents;
