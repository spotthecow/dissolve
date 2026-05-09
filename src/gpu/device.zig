const vk = @import("vulkan");
const Instance = @import("instance.zig").Instance;
const Surface = @import("surface.zig").Surface;
const std = @import("std");

pub const Device = struct {
    handle: vk.Device,
    phy: vk.PhysicalDevice,
    wrapper: vk.DeviceWrapper,

    pub fn deinit(self: *Device) void {
        self.wrapper.destroyDevice(self.handle, null);
        self.* = undefined;
    }
};

pub fn createForSurfaceAlloc(surface: Surface, allocator: std.mem.Allocator) !Device {
    const instance = surface.instance;
    const vki = &instance.wrapper;

    const phys = try vki.enumeratePhysicalDevicesAlloc(instance.handle, allocator);
    defer allocator.free(phys);
    if (phys.len == 0) return error.NoPhysicalDevice;
    const phy = phys[0];

    const queue_family_props = try vki.getPhysicalDeviceQueueFamilyPropertiesAlloc(
        phy,
        allocator,
    );
    defer allocator.free(queue_family_props);

    const queue_family_idx: u32 = for (queue_family_props, 0..) |prop, i| {
        if (prop.queue_flags.graphics_bit) {
            const supported = try vki.getPhysicalDeviceSurfaceSupportKHR(
                phy,
                @intCast(i),
                surface.handle,
            );
            if (supported == .true) {
                break @intCast(i);
            }
        }
    } else return error.NoQueueFamily;

    const queue_create_info = vk.DeviceQueueCreateInfo{
        .p_queue_priorities = &[_]f32{1.0},
        .queue_count = 1,
        .queue_family_index = queue_family_idx,
    };

    const exts: []const [*:0]const u8 = &.{vk.extensions.khr_swapchain.name};
    const vk_13_features = vk.PhysicalDeviceVulkan13Features{
        .dynamic_rendering = .true,
        .synchronization_2 = .true,
    };

    const create_info = vk.DeviceCreateInfo{
        .p_next = &vk_13_features,
        .queue_create_info_count = 1,
        .p_queue_create_infos = @ptrCast(&queue_create_info),
        .enabled_extension_count = exts.len,
        .pp_enabled_extension_names = exts.ptr,
    };
    const device = try vki.createDevice(phy, &create_info, null);

    const vkd = vk.DeviceWrapper.load(device, vki.dispatch.vkGetDeviceProcAddr.?);

    return Device{
        .handle = device,
        .phy = phy,
        .wrapper = vkd,
    };
}
