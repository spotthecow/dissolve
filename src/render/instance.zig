const std = @import("std");
const vk = @import("vulkan");
const builtin = @import("builtin");

pub const Instance = struct {
    handle: vk.Instance,
    wrapper: vk.InstanceWrapper,

    pub fn deinit(self: *Instance) void {
        self.wrapper.destroyInstance(self.handle, null);
        self.* = undefined;
    }
};

extern "c" fn vkGetInstanceProcAddr(instance: vk.Instance, name: [*:0]const u8) vk.PfnVoidFunction;

const required_extensions: []const [*:0]const u8 = ext: {
    var exts: []const [*:0]const u8 = &.{
        "VK_KHR_surface",
    };
    if (builtin.os.tag == .macos) {
        exts = exts ++ &[_][*:0]const u8{
            "VK_EXT_metal_surface",
        };
    }
    break :ext exts;
};

pub fn create(app_name: [:0]const u8) !Instance {
    const vkb = vk.BaseWrapper.load(vkGetInstanceProcAddr);

    const app_info: vk.ApplicationInfo = .{
        .p_application_name = app_name.ptr,
        .application_version = 0,
        .p_engine_name = "dissolve",
        .engine_version = 0,
        .api_version = @bitCast(vk.API_VERSION_1_3),
    };

    const handle = try vkb.createInstance(&.{
        .flags = .{},
        .p_application_info = &app_info,
        .enabled_layer_count = 0,
        .pp_enabled_layer_names = null,
        .enabled_extension_count = @intCast(required_extensions.len),
        .pp_enabled_extension_names = required_extensions.ptr,
    }, null);

    const wrapper = vk.InstanceWrapper.load(handle, vkGetInstanceProcAddr);

    return .{
        .handle = handle,
        .wrapper = wrapper,
    };
}
