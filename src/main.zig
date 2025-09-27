const std = @import("std");
const builtin = @import("builtin");
const sdl3 = @import("sdl3");
const shadercross = sdl3.shadercross;
const gpu = sdl3.gpu;
const video = sdl3.video;
const events = sdl3.events;
const keyboard = sdl3.keyboard;
const pipeline = @import("graphics/pipeline.zig");
const Camera = @import("core/Camera.zig");
const Light = @import("graphics/Light.zig");
const math = @import("core/math.zig");
const gltf = @import("core/gltf.zig");

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
    // set unlimited frames;
    try device.setSwapchainParameters(window, .sdr, .immediate);
    try sdl3.mouse.setWindowRelativeMode(window, true);

    var capper: sdl3.extras.FramerateCapper(f32) = .{ .mode = .{ .unlimited = undefined } };

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

    var asset = try gltf.fromPath(allocator, device, "assets/test.gltf");
    defer asset.release(device);
    asset.position = .{ -2, 0, 4 };
    asset.rotation = .{ 45, 0, 0 };

    var assett = try gltf.fromPath(allocator, device, "assets/test.gltf");
    defer assett.release(device);
    assett.position = .{ -10, 0, 4 };
    assett.rotation = .{ 45, 0, 0 };

    var cube_asset = try gltf.fromPath(allocator, device, "assets/light.gltf");
    defer cube_asset.release(device);
    cube_asset.scale = .{ 2, 2, 2 };

    const light: Light = .{
        .position = .{ 0, 0, 5 },
        .ambient = .{ 0.2, 0.2, 0.2 },
        .diffuse = .{ 0.5, 0.5, 0.5 },
        .specular = .{ 1.0, 1.0, 1.0 },
        .kind = .{
            .spotlight = .{
                .direction = .{ 0, 0, 1 },
                .cut_off = @cos(std.math.degreesToRadians(25)),
                .outer_cut_off = @cos(std.math.degreesToRadians(35)),
                .constant = 1.0,
                .linear = 0.007,
                .quadratic = 0.0002,
            },
        },
    };

    var light_cube = try gltf.fromPath(allocator, device, "assets/light.gltf");
    defer light_cube.release(device);
    light_cube.position = .{ 0, 0, 5 };
    light_cube.rotation = .{ 0, 0, 0 };
    light_cube.scale = .{ 0.2, 0.2, 0.2 };

    var grid = try gltf.fromPath(allocator, device, "assets/grid.gltf");
    defer grid.release(device);

    var camera: Camera = .new;

    const keyboard_state = keyboard.getState();

    loop: while (true) {
        const dt = capper.delay();
        // std.log.info("{}", .{1 / dt});
        const ms = 3 * dt;
        while (events.poll()) |event| {
            switch (event) {
                .quit, .terminating => break :loop,
                .key_down => |k| if (k.key) |key| {
                    switch (key) {
                        .escape => break :loop,
                        else => {},
                    }
                },
                .mouse_motion => |mouse| {
                    camera.rotation += .{ -mouse.y_rel * 0.1, mouse.x_rel * 0.1, 0 };
                },
                else => {},
            }
        }

        {
            if (keyboard_state[getScancodePosition(.a)])
                camera.position -= .{ ms, 0, 0 };
            if (keyboard_state[getScancodePosition(.d)])
                camera.position += .{ ms, 0, 0 };
            if (keyboard_state[getScancodePosition(.space)])
                camera.position += .{ 0, ms, 0 };
            if (keyboard_state[getScancodePosition(.left_ctrl)])
                camera.position -= .{ 0, ms, 0 };
            if (keyboard_state[getScancodePosition(.w)])
                camera.position -= .{ 0, 0, ms };
            if (keyboard_state[getScancodePosition(.s)])
                camera.position += .{ 0, 0, ms };
        }

        const cmd_buf = try device.acquireCommandBuffer();
        const swapchain_texture = try cmd_buf.waitAndAcquireSwapchainTexture(window);
        const texture = swapchain_texture.texture orelse continue :loop;

        camera.pushData(cmd_buf, 1.333);

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

            light.pushData(cmd_buf);

            asset.render(cmd_buf, render_pass);
            assett.render(cmd_buf, render_pass);
            cube_asset.render(cmd_buf, render_pass);
            light_cube.render(cmd_buf, render_pass);
            // grid.render(cmd_buf, render_pass);
        }

        try cmd_buf.submit();
    }
}

fn getScancodePosition(key: sdl3.keycode.Keycode) usize {
    return @intFromEnum(keyboard.getScancodeFromKey(key).?.code.?);
}
