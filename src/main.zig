const std = @import("std");
const vk = @import("vulkan");
const gpu = @import("gpu.zig");
const window = @import("window.zig");
const util = @import("util.zig");
const graphics = @import("graphics.zig");

const Io = std.Io;
const testing = std.testing;
const Window = window.Window;
const Pixel = graphics.Pixel;

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const gpa = init.gpa;

    window.init();

    var instance = try gpu.instance.create();
    defer instance.deinit();

    const w = try Window.create(1280, 720, "dissolve");
    defer w.destroy();

    var surface = try gpu.surface.create(&instance, w);
    defer surface.deinit();

    var device = try gpu.device.createForSurfaceAlloc(surface, gpa);
    defer device.deinit();
    const vkd = &device.wrapper;

    const gradient = try util.genImageAlloc(256, 256, gpa);
    defer gpa.free(gradient);

    var stage_buf = try gpu.mem.createBuffer(
        &device,
        &instance,
        .host,
        .{ .transfer_src_bit = true },
        gradient.len * @sizeOf(Pixel),
    );
    defer stage_buf.destroy();
    const mapped = try stage_buf.map_as(Pixel);
    @memcpy(mapped, gradient);

    var image = try gpu.mem.createImage(&device, &instance, 256, 256);
    defer image.destroy();

    const cpci = vk.CommandPoolCreateInfo{
        .flags = .{ .transient_bit = true },
        .queue_family_index = device.queue_family,
    };
    const cmd_pool = try vkd.createCommandPool(
        device.handle,
        &cpci,
        null,
    );
    defer vkd.destroyCommandPool(device.handle, cmd_pool, null);

    const cbai = vk.CommandBufferAllocateInfo{
        .command_buffer_count = 1,
        .command_pool = cmd_pool,
        .level = .primary,
    };
    var cmd: vk.CommandBuffer = undefined;
    try vkd.allocateCommandBuffers(device.handle, &cbai, @ptrCast(&cmd));

    try vkd.beginCommandBuffer(
        cmd,
        &vk.CommandBufferBeginInfo{ .flags = .{ .one_time_submit_bit = true } },
    );

    const to_transfer = vk.ImageMemoryBarrier2{
        .src_stage_mask = .{},
        .src_access_mask = .{},
        .dst_stage_mask = .{ .copy_bit = true },
        .dst_access_mask = .{ .transfer_write_bit = true },
        .old_layout = .undefined,
        .new_layout = .transfer_dst_optimal,
        .src_queue_family_index = vk.QUEUE_FAMILY_IGNORED,
        .dst_queue_family_index = vk.QUEUE_FAMILY_IGNORED,
        .image = image.handle,
        .subresource_range = .{
            .aspect_mask = .{ .color_bit = true },
            .base_array_layer = 0,
            .base_mip_level = 0,
            .layer_count = 1,
            .level_count = 1,
        },
    };

    vkd.cmdPipelineBarrier2(cmd, &vk.DependencyInfo{
        .image_memory_barrier_count = 1,
        .p_image_memory_barriers = @ptrCast(&to_transfer),
    });

    const regions = vk.BufferImageCopy{
        .buffer_offset = 0,
        .buffer_row_length = 0,
        .buffer_image_height = 0,
        .image_subresource = .{
            .aspect_mask = .{ .color_bit = true },
            .mip_level = 0,
            .base_array_layer = 0,
            .layer_count = 1,
        },
        .image_offset = .{ .x = 0, .y = 0, .z = 0 },
        .image_extent = .{ .depth = 1, .width = image.width, .height = image.height },
    };
    vkd.cmdCopyBufferToImage(
        cmd,
        stage_buf.handle,
        image.handle,
        .transfer_dst_optimal,
        @ptrCast(&regions),
    );

    const to_general = vk.ImageMemoryBarrier2{
        .src_stage_mask = .{ .copy_bit = true },
        .src_access_mask = .{ .transfer_write_bit = true },
        .dst_stage_mask = .{ .all_commands_bit = true },
        .dst_access_mask = .{ .memory_read_bit = true, .memory_write_bit = true },
        .old_layout = .transfer_dst_optimal,
        .new_layout = .general,
        .src_queue_family_index = vk.QUEUE_FAMILY_IGNORED,
        .dst_queue_family_index = vk.QUEUE_FAMILY_IGNORED,
        .image = image.handle,
        .subresource_range = .{
            .aspect_mask = .{ .color_bit = true },
            .base_array_layer = 0,
            .base_mip_level = 0,
            .layer_count = 1,
            .level_count = 1,
        },
    };
    vkd.cmdPipelineBarrier2(cmd, &vk.DependencyInfo{
        .image_memory_barrier_count = 1,
        .p_image_memory_barriers = @ptrCast(&to_general),
    });

    try vkd.endCommandBuffer(cmd);

    const fence = try vkd.createFence(device.handle, &.{}, null);
    defer vkd.destroyFence(device.handle, fence, null);

    const submit_info = vk.SubmitInfo2{
        .command_buffer_info_count = 1,
        .p_command_buffer_infos = @ptrCast(&vk.CommandBufferSubmitInfo{
            .command_buffer = cmd,
            .device_mask = 0,
        }),
    };
    try vkd.queueSubmit2(device.queue, @ptrCast(&submit_info), fence);

    _ = try vkd.waitForFences(device.handle, @ptrCast(&fence), .true, std.math.maxInt(u64));

    while (!w.shouldClose()) {
        window.pumpEvents();
        try io.sleep(.fromMilliseconds(16), .awake);
    }
}

test {
    testing.refAllDecls(@This());
}
