const std = @import("std");
const graphics = @import("graphics.zig");
const Io = std.Io;
const Pixel = graphics.Pixel;

pub fn genImageAlloc(w: u32, h: u32, allocator: std.mem.Allocator) ![]Pixel {
    var image = try allocator.alloc(Pixel, w * h);
    for (0..h) |y| {
        for (0..w) |x| {
            const val: u8 = @intCast(x * 255 / (w - 1));
            image[y * w + x] = .{ .r = val, .g = val, .b = val, .a = 255 };
        }
    }

    return image;
}

pub fn writePpm(image: []const u8, w: usize, h: usize, name: []const u8, io: std.Io) !void {
    const file = try Io.Dir.cwd().createFile(io, name, .{});
    defer file.close(io);

    var buf: [4096]u8 = undefined;
    var file_writer = file.writer(io, &buf);
    var writer = &file_writer.interface;
    try writer.print("P3\n", .{});
    try writer.print("{} {}\n", .{ w, h });
    try writer.print("255\n", .{});

    var it = std.mem.window(u8, image, 3, 4);
    while (it.next()) |px| {
        try writer.print("{} {} {}\n", .{ px[0], px[1], px[2] });
    }
    try writer.flush();
}
