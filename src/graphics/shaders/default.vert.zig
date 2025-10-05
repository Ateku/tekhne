const std = @import("std");
const gpu = std.gpu;
const math = @import("math");
const vector3 = math.vector3;
const vector4 = math.vector4;
const matrix = math.matrix;
const Vector2 = @Vector(2, f32);
const Vector3 = math.Vector3;
const Vector4 = math.Vector4;
const Matrix = math.Matrix;

extern var position_in: Vector3 addrspace(.input);
extern var normal_in: Vector3 addrspace(.input);
extern var tex_coord_in: Vector2 addrspace(.input);

extern var position_out: Vector3 addrspace(.output);
extern var normal_out: Vector3 addrspace(.output);
extern var tex_coord_out: Vector2 addrspace(.output);
extern var camera_pos_out: Vector3 addrspace(.output);

extern var camera: extern struct {
    view: Matrix,
    projection: Matrix,
    position: Vector3,
} addrspace(.uniform);

extern var transform: extern struct {
    mat: Matrix,
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
    gpu.location(&camera_pos_out, 3);

    const position: @Vector(4, f32) = .{ position_in[0], position_in[1], position_in[2], 1 };
    const model = matrix.mulVec(transform.mat, position);

    gpu.position_out.* = matrix.mulVec(
        camera.projection,
        matrix.mulVec(camera.view, model),
    );

    const normalv4 = vector4.fromVector3(normal_in, 0);
    const inverted_mat = matrix.invertTransform(transform.mat);
    const transformed_normal = matrix.mulVec(inverted_mat, normalv4);

    position_out = vector3.fromVector4(model);
    normal_out = vector3.fromVector4(transformed_normal);
    tex_coord_out = tex_coord_in;
    camera_pos_out = camera.position;
}
