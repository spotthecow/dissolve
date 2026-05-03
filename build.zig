const std = @import("std");

pub fn build(b: *std.Build) void { // test

    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const vk_xml = b.dependency("vulkan_headers", .{}).path("registry/vk.xml");
    const vk_gen = b.dependency("vulkan", .{}).artifact("vulkan-zig-generator");
    const vk_generate_cmd = b.addRunArtifact(vk_gen);
    vk_generate_cmd.addFileArg(vk_xml);
    const vulkan_zig = b.addModule("vulkan-zig", .{
        .root_source_file = vk_generate_cmd.addOutputFileArg("vk.zig"),
    });

    const mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "vulkan", .module = vulkan_zig },
        },
    });

    switch (target.result.os.tag) {
        .macos => {
            mod.addCSourceFile(.{
                .file = b.path("src/platform/macos/window.m"),
                .flags = &.{"-fobjc-arc"},
                .language = .objective_c,
            });
            mod.linkFramework("Cocoa", .{});
            mod.linkFramework("QuartzCore", .{});

            mod.addObjectFile(b.path("third_party/moltenvk/lib/libMoltenVK.a"));
            mod.linkFramework("Metal", .{});
            mod.linkFramework("IOSurface", .{});
            mod.linkFramework("IOKit", .{});
            mod.linkFramework("CoreGraphics", .{});
            mod.linkFramework("Foundation", .{});
            mod.link_libcpp = true;
        },
        else => {},
    }

    const exe = b.addExecutable(.{
        .name = "dissolve",
        .root_module = mod,
    });

    b.installArtifact(exe);
    const run_step = b.step("run", "Run the app");
    const run_cmd = b.addRunArtifact(exe);

    run_step.dependOn(&run_cmd.step);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const exe_tests = b.addTest(.{
        .root_module = mod,
    });

    const run_exe_tests = b.addRunArtifact(exe_tests);
    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_exe_tests.step);
}
