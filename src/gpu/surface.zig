const vk = @import("vulkan");
const Instance = @import("instance.zig").Instance;
const Window = @import("../window.zig").Window;

pub const Surface = struct {
    handle: vk.SurfaceKHR,
    instance: *Instance,

    pub fn deinit(self: *Surface) void {
        self.instance.wrapper.destroySurfaceKHR(self.instance.handle, self.handle, null);
        self.* = undefined;
    }
};

pub fn create(instance: *Instance, window: Window) !Surface {
    const vki = &instance.wrapper;

    const mtl_layer = try window.getMetalLayer();
    const create_info = vk.MetalSurfaceCreateInfoEXT{
        .p_layer = @ptrCast(mtl_layer),
    };
    const handle = try vki.createMetalSurfaceEXT(instance.handle, &create_info, null);

    return Surface{ .handle = handle, .instance = instance };
}
