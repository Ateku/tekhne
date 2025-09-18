const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "tekhne",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "sdl3", .module = b.dependency(
                    "sdl3",
                    .{
                        .target = target,
                        .optimize = optimize,
                        .ext_shadercross = true,
                        .ext_image = true,
                    },
                ).module("sdl3") },
            },
        }),
    });

    b.installArtifact(exe);

    const run_step = b.step("run", "Run the app");
    const run_cmd = b.addRunArtifact(exe);

    run_step.dependOn(&run_cmd.step);
    run_cmd.step.dependOn(b.getInstallStep());

    try addShader(b, exe.root_module, "default.vert");
    try addShader(b, exe.root_module, "default.frag");
}

fn addShader(
    b: *std.Build,
    module: *std.Build.Module,
    comptime name: []const u8,
) !void {
    const vulkan_target = b.resolveTargetQuery(.{
        .cpu_arch = .spirv32,
        .cpu_model = .{
            .explicit = &std.Target.spirv.cpu.vulkan_v1_2,
        },
        .os_tag = .vulkan,
        .ofmt = .spirv,
    });

    const shader = b.addObject(.{
        .name = name,
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/graphics/shaders/" ++ name ++ ".zig"),
            .target = vulkan_target,
            .optimize = .ReleaseFast,
            .imports = &.{
                .{ .name = "math", .module = b.createModule(.{
                    .root_source_file = b.path("src/core/math.zig"),
                }) },
            },
        }),
        .use_lld = false,
        .use_llvm = false,
    });

    module.addAnonymousImport(name, .{
        .root_source_file = shader.getEmittedBin(),
    });
}
