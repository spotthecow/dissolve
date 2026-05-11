const vk = @import("vulkan");
const Instance = @import("instance.zig").Instance;
const Device = @import("device.zig").Device;

pub const Location = enum { host, device };

pub const Buffer = struct {
    handle: vk.Buffer,
    device: *const Device,
    mem: vk.DeviceMemory,
    location: Location,
    len: usize,
    mapped: ?[*]u8,

    pub fn destroy(self: *Buffer) void {
        self.unmap();
        self.device.wrapper.destroyBuffer(self.device.handle, self.handle, null);
        self.device.wrapper.freeMemory(self.device.handle, self.mem, null);
        self.* = undefined;
    }

    pub fn unmap(self: *Buffer) void {
        if (self.mapped) |_| {
            self.device.wrapper.unmapMemory(self.device.handle, self.mem);
            self.mapped = null;
        }
    }

    pub fn map(self: *Buffer) ![]u8 {
        if (self.mapped) |m| return m[0..self.len];

        const ptr = try self.device.wrapper.mapMemory(
            self.device.handle,
            self.mem,
            0,
            vk.WHOLE_SIZE,
            .{},
        ) orelse return error.MapFailure;

        const typed: [*]u8 = @ptrCast(@alignCast(ptr));
        self.mapped = typed;
        return typed[0..self.len];
    }

    pub fn map_as(self: *Buffer, T: type) ![]T {
        const mapped = try self.map();
        return @ptrCast(@alignCast(mapped));
    }
};

pub fn createBuffer(
    device: *const Device,
    instance: *const Instance,
    location: Location,
    usage: vk.BufferUsageFlags,
    len: usize,
) !Buffer {
    const vki = &instance.wrapper;
    const vkd = &device.wrapper;

    const bci = vk.BufferCreateInfo{
        .size = @intCast(len),
        .usage = usage,
        .sharing_mode = .exclusive,
    };
    const buf = try vkd.createBuffer(device.handle, &bci, null);

    const reqs = vkd.getBufferMemoryRequirements(device.handle, buf);
    const props = vki.getPhysicalDeviceMemoryProperties(device.phy);
    const flags = switch (location) {
        .host => vk.MemoryPropertyFlags{ .host_visible_bit = true, .host_coherent_bit = true },
        .device => vk.MemoryPropertyFlags{ .device_local_bit = true },
    };
    const mem_type = try findMemoryType(&props, reqs.memory_type_bits, flags);

    const mai = vk.MemoryAllocateInfo{
        .allocation_size = reqs.size,
        .memory_type_index = mem_type,
    };
    const mem = try vkd.allocateMemory(device.handle, &mai, null);

    try vkd.bindBufferMemory(device.handle, buf, mem, 0);

    return Buffer{
        .handle = buf,
        .mem = mem,
        .device = device,
        .len = len,
        .location = location,
        .mapped = null,
    };
}

pub const Image = struct {
    handle: vk.Image,
    device: *const Device,
    mem: vk.DeviceMemory,
    width: u32,
    height: u32,

    pub fn destroy(self: *Image) void {
        self.device.wrapper.destroyImage(self.device.handle, self.handle, null);
        self.device.wrapper.freeMemory(self.device.handle, self.mem, null);
    }
};

pub fn createImage(
    device: *const Device,
    instance: *const Instance,
    width: u32,
    height: u32,
) !Image {
    const vkd = &device.wrapper;
    const vki = &instance.wrapper;

    const ici = vk.ImageCreateInfo{
        .array_layers = 1,
        .extent = .{ .depth = 1, .width = width, .height = height },
        .format = .r8g8b8a8_unorm,
        .image_type = .@"2d",
        .initial_layout = .undefined,
        .mip_levels = 1,
        .samples = .{ .@"1_bit" = true },
        .sharing_mode = .exclusive,
        .tiling = .optimal,
        .usage = .{ .transfer_src_bit = true, .transfer_dst_bit = true, .storage_bit = true },
        .flags = .{},
    };
    const image = try vkd.createImage(device.handle, &ici, null);

    const reqs = vkd.getImageMemoryRequirements(device.handle, image);
    const props = vki.getPhysicalDeviceMemoryProperties(device.phy);
    const flags = vk.MemoryPropertyFlags{ .device_local_bit = true };
    const mem_type = try findMemoryType(&props, reqs.memory_type_bits, flags);
    const mai = vk.MemoryAllocateInfo{
        .allocation_size = reqs.size,
        .memory_type_index = mem_type,
    };
    const mem = try vkd.allocateMemory(device.handle, &mai, null);
    try vkd.bindImageMemory(device.handle, image, mem, 0);

    return Image{
        .handle = image,
        .device = device,
        .mem = mem,
        .width = width,
        .height = height,
    };
}

fn findMemoryType(
    props: *const vk.PhysicalDeviceMemoryProperties,
    type_bits: u32,
    flags: vk.MemoryPropertyFlags,
) !u32 {
    for (0..props.memory_type_count) |i| {
        const idx: u5 = @intCast(i);
        if (type_bits & (@as(u32, 1) << idx) != 0 and props.memory_types[i].property_flags.contains(flags)) {
            return @intCast(i);
        }
    }
    return error.NoSuitableMemoryType;
}
