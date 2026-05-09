const vk = @import("vulkan");
const builtin = @import("builtin");
const expect = @import("std").testing.expect;

extern "c" fn vkGetInstanceProcAddr(instance: vk.Instance, name: [*:0]const u8) vk.PfnVoidFunction;

pub const Instance = struct {
    handle: vk.Instance,
    wrapper: vk.InstanceWrapper,

    pub fn deinit(self: *Instance) void {
        self.wrapper.destroyInstance(self.handle, null);
        self.* = undefined;
    }
};

const extensions = blk: {
    var exts: []const [*:0]const u8 = &.{vk.extensions.khr_surface.name};

    if (builtin.os.tag == .macos) {
        exts = exts ++ &[_][*:0]const u8{
            vk.extensions.ext_metal_surface.name,
        };
    }

    break :blk exts;
};

pub fn create() !Instance {
    const app_info = vk.ApplicationInfo{
        .api_version = vk.API_VERSION_1_3.toU32(),
        .application_version = 0,
        .engine_version = 0,
        .p_application_name = "dissolve",
    };

    const vkb = vk.BaseWrapper.load(vkGetInstanceProcAddr);

    const create_info = vk.InstanceCreateInfo{
        .enabled_extension_count = extensions.len,
        .p_application_info = &app_info,
        .pp_enabled_extension_names = extensions.ptr,
    };

    const instance = try vkb.createInstance(&create_info, null);
    const vki = vk.InstanceWrapper.load(instance, vkGetInstanceProcAddr);

    return Instance{ .handle = instance, .wrapper = vki };
}

test "instance functions load" {
    const instance = try create();
    const dispatch = instance.wrapper.dispatch;

    const required = .{
        "vkDestroyInstance",
        "vkEnumeratePhysicalDevices",
        "vkGetPhysicalDeviceProperties",
        "vkGetPhysicalDeviceQueueFamilyProperties2",
        "vkGetPhysicalDeviceFeatures",
        "vkCreateDevice",
        "vkGetDeviceProcAddr",
    };

    inline for (required) |name| {
        try expect(@field(dispatch, name) != null);
    }
}
