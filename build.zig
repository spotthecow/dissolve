const std = @import("std");

pub fn build(b: *std.Build) void { // test

    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const mod = b.addModule("dissolve", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
    });

    switch (target.result.os.tag) {
        .macos => {
            mod.addCSourceFile(.{
                .file = b.path("src/platform/macos/window.m"),
                .flags = &.{"-fobjc-arc"},
                .language = .objective_c,
            });
            mod.linkFramework("Cocoa", .{ .needed = false });
        },
        else => {},
    }

    const exe = b.addExecutable(.{
        .name = "dissolve",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
            .imports = &.{
                .{ .name = "dissolve", .module = mod },
            },
        }),
    });

    b.installArtifact(exe);
    const run_step = b.step("run", "Run the app");
    const run_cmd = b.addRunArtifact(exe);

    run_step.dependOn(&run_cmd.step);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const mod_tests = b.addTest(.{
        .root_module = mod,
    });
    const run_mod_tests = b.addRunArtifact(mod_tests);
    const exe_tests = b.addTest(.{
        .root_module = exe.root_module,
    });

    const run_exe_tests = b.addRunArtifact(exe_tests);
    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_mod_tests.step);
    test_step.dependOn(&run_exe_tests.step);
}
