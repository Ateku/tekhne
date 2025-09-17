const std = @import("std");
const builtin = @import("builtin");
const sdl3 = @import("sdl3");
const shadercross = sdl3.shadercross;
const gpu = sdl3.gpu;
const video = sdl3.video;
const events = sdl3.events;
const pipeline = @import("graphics/pipeline.zig");

const debug_mode = builtin.mode == .Debug;

pub fn main() !void {
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

    loop: while (true) {
        while (events.poll()) |event| {
            switch (event) {
                .quit, .terminating => break :loop,
                else => {},
            }
        }

        const cmd_buf = try device.acquireCommandBuffer();
        const swapchain_texture = try cmd_buf.acquireSwapchainTexture(window);
        const texture = swapchain_texture.texture orelse continue :loop;

        {
            const target_info: gpu.ColorTargetInfo = .{
                .texture = texture,
                .clear_color = .{ .r = 0, .g = 0, .b = 0, .a = 1 },
                .load = .clear,
            };
            const render_pass = cmd_buf.beginRenderPass(&.{target_info}, null);
            defer render_pass.end();

            render_pass.bindGraphicsPipeline(graphic_pipeline);
        }

        try cmd_buf.submit();
    }
}
