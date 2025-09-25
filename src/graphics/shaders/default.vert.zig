const std = @import("std");
const gpu = std.gpu;
const math = @import("math");
const vector3 = math.vector3;
const vector4 = math.vector4;
const matrix = math.matrix;

extern var position_in: @Vector(3, f32) addrspace(.input);
extern var normal_in: @Vector(3, f32) addrspace(.input);
extern var tex_coord_in: @Vector(2, f32) addrspace(.input);

extern var position_out: @Vector(3, f32) addrspace(.output);
extern var normal_out: @Vector(3, f32) addrspace(.output);
extern var tex_coord_out: @Vector(2, f32) addrspace(.output);

extern var camera: extern struct {
    view: math.Matrix,
    projection: math.Matrix,
} addrspace(.uniform);

extern var transform: extern struct {
    mat: math.Matrix,
} addrspace(.uniform);

export fn main() callconv(.spirv_vertex) void {
    gpu.binding(&camera, 1, 0);
    gpu.binding(&transform, 1, 1);

    gpu.location(&position_in, 0);
    gpu.location(&normal_in, 1);
    gpu.location(&tex_coord_in, 2);

    gpu.location(&position_out, 0);
    gpu.location(&normal_out, 1);
    gpu.location(&tex_coord_out, 2);

    const position: @Vector(4, f32) = .{ position_in[0], position_in[1], position_in[2], 1 };
    const model = matrix.mulVec(transform.mat, position);

    gpu.position_out.* = matrix.mulVec(
        camera.projection,
        matrix.mulVec(camera.view, model),
    );

    // Smooth shading - use position_in rather than normal_in
    const normalv4 = vector4.fromVector3(normal_in, 0);
    const transformed_normal = matrix.mulVec(transform.mat, normalv4);

    position_out = vector3.fromVector4(model);
    normal_out = vector3.fromVector4(transformed_normal);
    tex_coord_out = tex_coord_in;
}
