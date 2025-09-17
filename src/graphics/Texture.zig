const sdl3 = @import("sdl3");
const gpu = sdl3.gpu;
const image = sdl3.image;
const Surface = sdl3.surface.Surface;
const Stream = sdl3.io_stream.Stream;

const Texture = @This();

texture: gpu.Texture,
sampler: gpu.Sampler,

pub fn createFromPath(device: gpu.Device, path: [:0]const u8) !Texture {
    const surface = try image.loadFile(path);
    defer surface.deinit();

    return create(device, surface);
}

pub fn createFromMemory(device: gpu.Device, data: []const u8) !Texture {
    const stream = try Stream.initFromConstMem(data);
    const surface = try image.loadIo(stream, true);
    defer surface.deinit();

    return create(device, surface);
}

fn create(device: gpu.Device, surface: Surface) !Texture {
    const converted = try surface.convertFormat(.packed_abgr_8_8_8_8);
    defer converted.deinit();

    const width: u32 = @intCast(converted.getWidth());
    const height: u32 = @intCast(converted.getHeight());
    const bytes = converted.getPixels() orelse return error.ImageNoPixels;

    const texture = try device.createTexture(.{
        .texture_type = .two_dimensional,
        .format = .r8g8b8a8_unorm,
        .width = width,
        .height = height,
        .layer_count_or_depth = 1,
        .num_levels = 1,
        .sample_count = .no_multisampling,
        .usage = .{
            .sampler = true,
            .color_target = true,
        },
    });
    errdefer device.releaseTexture(texture);

    const sampler = try device.createSampler(.{
        .address_mode_u = .clamp_to_edge,
        .address_mode_v = .clamp_to_edge,
        .address_mode_w = .clamp_to_edge,
        .min_filter = .linear,
        .mag_filter = .linear,
        .mipmap_mode = .linear,
        .max_anisotropy = 16,
    });
    errdefer device.releaseSampler(sampler);

    const tran_buf = try device.createTransferBuffer(.{
        .usage = .upload,
        .size = @intCast(bytes.len),
    });
    defer device.releaseTransferBuffer(tran_buf);

    {
        const mapped = try device.mapTransferBuffer(tran_buf, false);
        defer device.unmapTransferBuffer(tran_buf);
        @memcpy(mapped, bytes);
    }

    const cmd_buf = try device.acquireCommandBuffer();

    {
        const copy_pass = cmd_buf.beginCopyPass();
        defer copy_pass.end();

        copy_pass.uploadToTexture(.{
            .transfer_buffer = tran_buf,
            .offset = 0,
        }, .{
            .texture = texture,
            .width = width,
            .height = height,
            .depth = 1,
        }, false);
    }

    try cmd_buf.submit();

    return .{
        .texture = texture,
        .sampler = sampler,
    };
}

pub fn bind(texture: Texture, render_pass: gpu.RenderPass) void {
    const sampler: gpu.TextureSamplerBinding = .{
        .texture = texture.texture,
        .sampler = texture.sampler,
    };

    render_pass.bindFragmentSamplers(0, &.{sampler});
}

pub fn release(texture: Texture, device: gpu.Device) void {
    device.releaseTexture(texture.texture);
    device.releaseSampler(texture.sampler);
}
