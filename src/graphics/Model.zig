const std = @import("std");
const mem = std.mem;
const sdl3 = @import("sdl3");
const gpu = sdl3.gpu;

const Model = @This();

pub const Vertex = struct {
    position: @Vector(3, f32),
    normal: @Vector(3, f32),
    tex_coord: @Vector(2, f32),
};

vertex_buffer: gpu.Buffer,
index_buffer: gpu.Buffer,
size: u32,

pub fn create(
    device: gpu.Device,
    vertices: []const Vertex,
    indices: []const u16,
) !Model {
    const vertices_bytes: []const u8 = mem.sliceAsBytes(vertices);
    const vertices_bytes_len: u32 = @intCast(vertices_bytes.len);
    const indices_bytes: []const u8 = mem.sliceAsBytes(indices);
    const indices_bytes_len: u32 = @intCast(indices_bytes.len);

    const vertex_buffer = try device.createBuffer(.{
        .usage = .{ .vertex = true },
        .size = vertices_bytes_len,
    });
    errdefer device.releaseBuffer(vertex_buffer);

    const index_buffer = try device.createBuffer(.{
        .usage = .{ .index = true },
        .size = indices_bytes_len,
    });
    errdefer device.releaseBuffer(index_buffer);

    const tran_buf = try device.createTransferBuffer(.{
        .usage = .upload,
        .size = vertices_bytes_len + indices_bytes_len,
    });
    defer device.releaseTransferBuffer(tran_buf);

    {
        const mapped = try device.mapTransferBuffer(tran_buf, false);
        defer device.unmapTransferBuffer(tran_buf);
        @memcpy(mapped[0..vertices_bytes_len], vertices_bytes);
        @memcpy(mapped[vertices_bytes_len..], indices_bytes);
    }

    const cmd_buf = try device.acquireCommandBuffer();

    {
        const copy_pass = cmd_buf.beginCopyPass();
        defer copy_pass.end();

        copy_pass.uploadToBuffer(.{
            .transfer_buffer = tran_buf,
            .offset = 0,
        }, .{
            .buffer = vertex_buffer,
            .offset = 0,
            .size = vertices_bytes_len,
        }, false);

        copy_pass.uploadToBuffer(.{
            .transfer_buffer = tran_buf,
            .offset = vertices_bytes_len,
        }, .{
            .buffer = index_buffer,
            .offset = 0,
            .size = indices_bytes_len,
        }, false);
    }

    try cmd_buf.submit();

    return .{
        .vertex_buffer = vertex_buffer,
        .index_buffer = index_buffer,
        .size = @intCast(indices.len),
    };
}

pub fn render(model: Model, render_pass: gpu.RenderPass) void {
    const vertex_buffer_binding: gpu.BufferBinding = .{
        .buffer = model.vertex_buffer,
        .offset = 0,
    };

    const index_buffer_binding: gpu.BufferBinding = .{
        .buffer = model.index_buffer,
        .offset = 0,
    };

    render_pass.bindVertexBuffers(0, &.{vertex_buffer_binding});
    render_pass.bindIndexBuffer(index_buffer_binding, .indices_16bit);
    render_pass.drawIndexedPrimitives(model.size, 1, 0, 0, 0);
}

pub fn release(model: Model, device: gpu.Device) void {
    device.releaseBuffer(model.vertex_buffer);
    device.releaseBuffer(model.index_buffer);
}
