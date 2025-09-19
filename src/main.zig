const std = @import("std");
const builtin = @import("builtin");
const sdl3 = @import("sdl3");
const shadercross = sdl3.shadercross;
const gpu = sdl3.gpu;
const video = sdl3.video;
const events = sdl3.events;
const pipeline = @import("graphics/pipeline.zig");
const Asset = @import("graphics/Asset.zig");
const Camera = @import("core/Camera.zig");
const Transform = @import("core/Transform.zig");
const Light = @import("graphics/Light.zig");

const debug_mode = builtin.mode == .Debug;

pub fn main() !void {
    var gpa: std.heap.DebugAllocator(.{}) = .init;
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    try sdl3.init(.everything);

    sdl3.errors.error_callback = &sdl3.extras.sdlErrZigLog;
    sdl3.log.setLogOutputFunction(void, &sdl3.extras.sdlLogZigLog, null);

    const shader_formats = shadercross.getSpirvShaderFormats() orelse
        return error.NoSpirvShaderFormats;

    const device = try gpu.Device.init(shader_formats, debug_mode, null);
    defer device.deinit();

    const window = try video.Window.init("Tekhne", 800, 600, .{
        .vulkan = true,
    });
    defer window.deinit();
    try device.claimWindow(window);

    const texture_format = try device.getSwapchainTextureFormat(window);
    const graphic_pipeline = try pipeline.initGraphics(
        device,
        texture_format,
        @embedFile("default.vert"),
        @embedFile("default.frag"),
        debug_mode,
    );
    defer device.releaseGraphicsPipeline(graphic_pipeline);

    const window_size = try window.getSize();

    const depth_texture = try device.createTexture(.{
        .format = .depth32_float,
        .usage = .{ .depth_stencil_target = true },
        .width = @intCast(window_size.width),
        .height = @intCast(window_size.height),
        .layer_count_or_depth = 1,
        .num_levels = 1,
    });

    const asset = try Asset.createFromPath(allocator, device, "assets/test.gltf");
    defer asset.release(device);
    var transform: Transform = .{
        .position = .{ 0, 0, 0 },
        .rotation = .{ 0, 0, 0 },
        .scale = .{ 1, 1, 1 },
    };

    // const light_asset = try Asset.createFromPath(allocator, device, "assets/test.gltf");
    // const light_transform: Transform = .{
    //     .position = .{ -1, -1, 0 },
    //     .rotation = .{ 0, 0, 0 },
    //     .scale = .{ 1, 1, 1 },
    // };

    const light: Light = .{
        .position = .{ 0, 0, 2 },
        .color = .{ 1, 1, 1 },
    };

    var camera: Camera = .new;

    loop: while (true) {
        while (events.poll()) |event| {
            switch (event) {
                .quit, .terminating => break :loop,
                .key_down => |keyboard| if (keyboard.key) |key| {
                    switch (key) {
                        .a => camera.position -= .{ 0.01, 0, 0 },
                        .d => camera.position += .{ 0.01, 0, 0 },
                        .space => camera.position += .{ 0, 0.01, 0 },
                        .c => camera.position -= .{ 0, 0.01, 0 },
                        .w => camera.position -= .{ 0, 0, 0.01 },
                        .s => camera.position += .{ 0, 0, 0.01 },
                        .q => camera.rotation -= .{ 0, 1, 0 },
                        .e => camera.rotation += .{ 0, 1, 0 },
                        .z => camera.rotation += .{ 1, 0, 0 },
                        .x => camera.rotation -= .{ 1, 0, 0 },
                        else => {},
                    }
                },
                else => {},
            }
        }

        const cmd_buf = try device.acquireCommandBuffer();
        const swapchain_texture = try cmd_buf.acquireSwapchainTexture(window);
        const texture = swapchain_texture.texture orelse continue :loop;

        camera.pushData(cmd_buf, 4 / 3);

        {
            const color_target_info: gpu.ColorTargetInfo = .{
                .texture = texture,
                .clear_color = .{ .r = 0.1, .g = 0.1, .b = 0.1, .a = 1 },
                .load = .clear,
            };
            const depth_stencil_target_info: gpu.DepthStencilTargetInfo = .{
                .texture = depth_texture,
                .load = .clear,
                .clear_depth = 1,
                .store = .do_not_care,
                .clear_stencil = 1,
                .stencil_load = .do_not_care,
                .stencil_store = .do_not_care,
                .cycle = true,
            };

            const render_pass = cmd_buf.beginRenderPass(
                &.{color_target_info},
                depth_stencil_target_info,
            );
            defer render_pass.end();

            render_pass.bindGraphicsPipeline(graphic_pipeline);

            transform.pushData(cmd_buf);
            asset.render(render_pass);

            light.pushData(cmd_buf);
            // light_transform.pushData(cmd_buf);
            // light_asset.render(render_pass);
        }

        try cmd_buf.submit();
    }
}
