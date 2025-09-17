const std = @import("std");
const fmt = std.fmt;
const assert = std.debug.assert;
const json = std.json;
const mem = std.mem;
const Allocator = mem.Allocator;
const sdl3 = @import("sdl3");
const gpu = sdl3.gpu;
const Texture = @import("Texture.zig");
const Model = @import("Model.zig");
const Vertex = @import("Vertex.zig");

const Asset = @This();

texture: Texture,
model: Model,

pub fn createFromPath(
    allocator: Allocator,
    device: gpu.Device,
    path: []const u8,
) !Asset {
    const dir = blk: {
        if (mem.lastIndexOf(u8, path, "/")) |i|
            break :blk path[0 .. i + 1];
        break :blk "";
    };

    const gltf = try readFileToJson(allocator, path);
    defer gltf.deinit();
    const value = gltf.value;

    assert(value.nodes.len == 1);

    const bin_data = blk: {
        const bin_path = try fmt.allocPrint(
            allocator,
            "{s}{s}",
            .{ dir, value.buffers[0].uri },
        );
        defer allocator.free(bin_path);

        break :blk try readFile(allocator, bin_path);
    };
    defer allocator.free(bin_data);

    const texture_path = try fmt.allocPrintSentinel(
        allocator,
        "{s}{s}",
        .{ dir, value.images[0].uri },
        0,
    );
    defer allocator.free(texture_path);

    const position = readBuffer(f32, bin_data, value.bufferViews[0]);
    const normal = readBuffer(f32, bin_data, value.bufferViews[1]);
    const tex_coord = readBuffer(f32, bin_data, value.bufferViews[2]);
    const indices = readBuffer(u16, bin_data, value.bufferViews[3]);

    const vertices = try getVertices(
        allocator,
        position,
        normal,
        tex_coord,
    );
    defer allocator.free(vertices);

    return .{
        .texture = try Texture.createFromPath(device, texture_path),
        .model = try Model.create(device, vertices, indices),
    };
}

pub fn render(asset: Asset, render_pass: gpu.RenderPass) void {
    asset.texture.bind(render_pass);
    asset.model.render(render_pass);
}

pub fn release(asset: Asset, device: gpu.Device) void {
    asset.texture.release(device);
    asset.model.release(device);
}

fn readFile(allocator: Allocator, path: []const u8) ![]u8 {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    var reader = file.reader(&.{});
    return try reader.interface.allocRemaining(allocator, .unlimited);
}

fn readFileToJson(allocator: Allocator, path: []const u8) !json.Parsed(Gltf) {
    const data = try readFile(allocator, path);
    defer allocator.free(data);

    return try json.parseFromSlice(Gltf, allocator, data, .{
        .ignore_unknown_fields = true,
    });
}

fn getVertices(
    allocator: Allocator,
    position: []const f32,
    normal: []const f32,
    tex_coord: []const f32,
) ![]const Vertex {
    const vertices = try allocator.alloc(Vertex, position.len / 3);

    for (0..position.len / 3) |i| {
        vertices[i].position = .{ position[i * 3], position[i * 3 + 1], position[i * 3 + 2] };
        vertices[i].normal = .{ normal[i * 3], normal[i * 3 + 1], normal[i * 3 + 2] };
        vertices[i].tex_coord = .{ tex_coord[i * 2], tex_coord[i * 2 + 1] };
    }

    return vertices;
}

fn readBuffer(comptime T: type, data: []const u8, bufferView: Gltf.BufferView) []const T {
    const offset = bufferView.byteOffset;
    const length = bufferView.byteLength;
    const bytes = data[offset .. offset + length];
    return @alignCast(mem.bytesAsSlice(T, bytes));
}

const Gltf = struct {
    nodes: []struct {},
    images: []Image,
    bufferViews: []BufferView,
    buffers: []Buffer,

    pub const Image = struct {
        uri: []u8,
    };

    pub const BufferView = struct {
        byteOffset: usize,
        byteLength: usize,
    };

    pub const Buffer = struct {
        uri: []u8,
        byteLength: usize,
    };
};
