const std = @import("std");
const mem = std.mem;
const sdl3 = @import("sdl3");
const gpu = sdl3.gpu;
const math = @import("math.zig");
const vector3 = math.vector3;
const matrix = math.matrix;

const Transform = @This();

position: math.Vector3 = vector3.zero,
rotation: math.Vector3 = vector3.zero,
scale: math.Vector3 = vector3.one,

pub const new: Transform = .{};

pub fn pushData(transform: Transform, cmd_buf: gpu.CommandBuffer) void {
    cmd_buf.pushVertexUniformData(1, mem.asBytes(&.{
        matrix.recompose(transform.position, transform.rotation, transform.scale),
    }));
}
