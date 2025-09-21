const std = @import("std");
const mem = std.mem;
const sdl3 = @import("sdl3");
const gpu = sdl3.gpu;
const math = @import("../core/math.zig");
const Vector3 = math.Vector3;

const Material = @This();

ambient: Vector3,
diffuse: Vector3,

pub fn pushData(material: Material, cmd_buf: gpu.CommandBuffer) void {
    cmd_buf.pushFragmentUniformData(0, mem.asBytes(&.{material}));
}
