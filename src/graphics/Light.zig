const std = @import("std");
const mem = std.mem;
const sdl3 = @import("sdl3");
const gpu = sdl3.gpu;
const math = @import("../core/math.zig");

const Light = @This();

position: math.Vector3,
color: math.Vector3,

pub fn pushData(light: Light, cmd_buf: gpu.CommandBuffer) void {
    cmd_buf.pushFragmentUniformData(1, mem.asBytes(&.{
        light.position,
        light.color,
    }));
}
