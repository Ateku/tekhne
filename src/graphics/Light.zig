const std = @import("std");
const mem = std.mem;
const sdl3 = @import("sdl3");
const gpu = sdl3.gpu;
const math = @import("../core/math.zig");

const Light = @This();

position: math.Vector3,
diffuse: math.Vector3,
specular: math.Vector3,
kind: union(enum) {
    directional: struct {
        direction: math.Vector3,
    },

    spotlight: struct {
        direction: math.Vector3,
        cut_off: f32,
        outer_cut_off: f32,

        constant: f32,
        linear: f32,
        quadratic: f32,
    },

    point: struct {
        constant: f32,
        linear: f32,
        quadratic: f32,
    },
},

pub fn pushData(light: Light, cmd_buf: gpu.CommandBuffer) void {
    switch (light.kind) {
        .directional => |d| cmd_buf.pushFragmentUniformData(0, mem.asBytes(&.{
            math.vector4.fromVector3(d.direction, -1),
            math.vector4.fromVector3(.{ 0, 0, 0 }, 0),
            light.position,
            light.diffuse,
            light.specular,
        })),
        .spotlight => |s| cmd_buf.pushFragmentUniformData(0, mem.asBytes(&.{
            math.vector4.fromVector3(s.direction, s.cut_off),
            math.Vector4{ s.constant, s.linear, s.quadratic, s.outer_cut_off },
            light.position,
            light.diffuse,
            light.specular,
        })),
        .point => |p| cmd_buf.pushFragmentUniformData(0, mem.asBytes(&.{
            math.vector4.fromVector3(.{ 0, 0, 0 }, -2),
            math.Vector4{ p.constant, p.linear, p.quadratic, 0 },
            light.position,
            light.diffuse,
            light.specular,
        })),
    }
}
