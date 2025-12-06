const std = @import("std");
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const raylib_dep = b.dependency("raylib_zig", .{
        .target = target,
        .optimize = optimize,
        .linkage = .static,
    });
    const raylib = raylib_dep.module("raylib");
    const raygui = raylib_dep.module("raygui");
    const raylib_artifact = raylib_dep.artifact("raylib");

    const exe = b.addExecutable(.{
        .name = "ray_zig_engine",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    exe.linkLibrary(raylib_artifact);
    exe.root_module.addAnonymousImport("bg_1", .{
        .root_source_file = b.path("assets/bg_1.gif"),
    });
    exe.root_module.addAnonymousImport("palm", .{
        .root_source_file = b.path("assets/palm.gif"),
    });
    exe.root_module.addAnonymousImport("bush", .{
        .root_source_file = b.path("assets/bush.gif"),
    });
    exe.root_module.addAnonymousImport("fly", .{
        .root_source_file = b.path("assets/fly.gif"),
    });
    exe.root_module.addAnonymousImport("fly2", .{
        .root_source_file = b.path("assets/fly2.gif"),
    });
    exe.root_module.addAnonymousImport("apple", .{
        .root_source_file = b.path("assets/apple.gif"),
    });

    exe.root_module.addImport("raylib", raylib);
    exe.root_module.addImport("raygui", raygui);

    b.installArtifact(exe);
    const run_step = b.step("run", "Run the app");
    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| run_cmd.addArgs(args);

    const upx_step = b.step("upx", "Compress binary");
    const install_path = b.getInstallPath(.bin, "ray_zig_engine");
    const compress = b.addSystemCommand(&[_][]const u8{
        "upx",
        "--best",
        "--lzma",
        "--compress-icons=0",
        install_path,
    });
    compress.step.dependOn(b.getInstallStep());
    upx_step.dependOn(&compress.step);
}
