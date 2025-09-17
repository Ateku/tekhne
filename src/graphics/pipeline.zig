const sdl3 = @import("sdl3");
const shadercross = sdl3.shadercross;
const gpu = sdl3.gpu;
const Vertex = @import("Vertex.zig");

pub fn initGraphics(
    device: gpu.Device,
    texture_format: gpu.TextureFormat,
    vertex_shader_code: []const u8,
    fragment_shader_code: []const u8,
    enable_debug: bool,
) !gpu.GraphicsPipeline {
    const vertex_shader = try compileShader(
        device,
        vertex_shader_code,
        .vertex,
        enable_debug,
    );
    defer device.releaseShader(vertex_shader);

    const fragment_shader = try compileShader(
        device,
        fragment_shader_code,
        .fragment,
        enable_debug,
    );
    defer device.releaseShader(fragment_shader);

    const pipeline = try device.createGraphicsPipeline(.{
        .vertex_shader = vertex_shader,
        .fragment_shader = fragment_shader,
        .target_info = .{
            .color_target_descriptions = &.{
                .{
                    .format = texture_format,
                    .blend_state = .{
                        .enable_blend = true,
                        .alpha_blend = .add,
                        .color_blend = .add,
                        .source_color = .src_alpha,
                        .source_alpha = .src_alpha,
                        .destination_color = .one_minus_src_alpha,
                        .destination_alpha = .one_minus_src_alpha,
                    },
                },
            },
        },
        .vertex_input_state = .{
            .vertex_buffer_descriptions = &.{
                .{
                    .slot = 0,
                    .pitch = @sizeOf(Vertex),
                    .input_rate = .vertex,
                },
            },
            .vertex_attributes = &.{
                .{
                    .location = 0,
                    .buffer_slot = 0,
                    .format = .f32x3,
                    .offset = @offsetOf(Vertex, "position"),
                },
                .{
                    .location = 1,
                    .buffer_slot = 0,
                    .format = .f32x3,
                    .offset = @offsetOf(Vertex, "normal"),
                },
                .{
                    .location = 2,
                    .buffer_slot = 0,
                    .format = .f32x2,
                    .offset = @offsetOf(Vertex, "tex_coord"),
                },
            },
        },
        .rasterizer_state = .{
            .cull_mode = .back,
        },
    });

    return pipeline;
}

fn compileShader(
    device: gpu.Device,
    bytecode: []const u8,
    stage: shadercross.ShaderStage,
    enable_debug: bool,
) !gpu.Shader {
    const metadata = try shadercross.reflectGraphicsSpirv(bytecode);

    return shadercross.compileGraphicsShaderFromSpirv(device, .{
        .enable_debug = enable_debug,
        .entry_point = "main",
        .name = null,
        .bytecode = bytecode,
        .shader_stage = stage,
    }, metadata);
}
