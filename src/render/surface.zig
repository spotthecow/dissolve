const vk = @import("vulkan");
const std = @import("std");
const builtin = @import("builtin");

const Instance = @import("../render.zig").instance.Instance;
const Window = @import("../window.zig").Window;

pub const Surface = struct {
    handle: vk.SurfaceKHR,
    instance: *const Instance,

    pub fn deinit(self: *Surface) void {
        self.instance.wrapper.destroySurfaceKHR(self.instance.handle, self.handle, null);
        self.* = undefined;
    }
};

pub fn create(instance: *const Instance, w: Window) !Surface {
    switch (builtin.os.tag) {
        .macos => {
            const mtl_layer = try w.getMetalLayer();
            const create_info = vk.MetalSurfaceCreateInfoEXT{ .p_layer = @ptrCast(mtl_layer) };
            const handle = try instance.wrapper.createMetalSurfaceEXT(
                instance.handle,
                &create_info,
                null,
            );
            return Surface{ .handle = handle, .instance = instance };
        },
        else => @compileError("dissolve: unsupported OS '" ++ @tagName(builtin.os.tag) ++ "'"),
    }
}
