const std = @import("std");
const gpu = std.gpu;
const helper = @import("helper.zig");
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
extern var camera_pos_in: Vector3 addrspace(.input);

extern var color_out: Vector4 addrspace(.output);

extern var light: extern struct {
    direction: Vector4,
    properties: Vector4,
    position: Vector3,
    diffuse: Vector3,
    specular: Vector3,
} addrspace(.uniform);

export fn main() callconv(.{
    .spirv_fragment = .{},
}) void {
    gpu.binding(&light, 3, 0);

    gpu.location(&position_in, 0);
    gpu.location(&normal_in, 1);
    gpu.location(&tex_coord_in, 2);
    gpu.location(&camera_pos_in, 3);

    gpu.location(&color_out, 0);

    const light_result = blk: {
        if (light.direction[3] == -1)
            break :blk calculateDirectional();
        if (light.direction[3] == -2)
            break :blk calculatePoint();
        break :blk calculateSpotlight();
    };

    color_out = helper.sampler2d(2, 0, tex_coord_in) * vector4.fromVector3(light_result, 1.0);
}

fn calculateDirectional() @Vector(3, f32) {
    const light_direction = helper.normalize(vector3.fromVector4(-light.direction));
    const diffuse = calculateDiffuse(light_direction);
    const specular = calculateSpecular(light_direction);

    if (vector3.dot(diffuse, diffuse) == 0)
        return vector3.zero;

    return diffuse + specular;
}

fn calculatePoint() @Vector(3, f32) {
    const light_direction = helper.normalize(light.position - position_in);

    const attenuation = calculateAttenuation(light.position);

    const diffuse = calculateDiffuse(light_direction) * attenuation;
    const specular = calculateSpecular(light_direction) * attenuation;

    if (vector3.dot(diffuse, diffuse) == 0)
        return vector3.zero;

    return diffuse + specular;
}

fn calculateSpotlight() @Vector(3, f32) {
    const light_direction_pos = helper.normalize(light.position - position_in);
    const light_direction = helper.normalize(vector3.fromVector4(light.direction));

    const cut_off = light.direction[3];
    const outer_cut_off = light.properties[3];

    const theta = vector3.dot(-light_direction_pos, -light_direction);
    const epsilon = cut_off - outer_cut_off;
    const intensity = vector3.splat(@max(0.0, @min((theta - outer_cut_off) / epsilon, 1.0)));

    const attenuation = calculateAttenuation(light.position);

    const diffuse = calculateDiffuse(light_direction_pos) * intensity * attenuation;
    const specular = calculateSpecular(light_direction_pos) * intensity * attenuation;

    if (vector3.dot(diffuse, diffuse) == 0)
        return vector3.zero;

    return diffuse + specular;
}

fn calculateDiffuse(direction: @Vector(3, f32)) @Vector(3, f32) {
    const diffuse_value = @max(vector3.dot(helper.normalize(normal_in), direction), 0.0);

    return light.diffuse * vector3.splat(diffuse_value);
}

fn calculateSpecular(direction: @Vector(3, f32)) @Vector(3, f32) {
    const view_direction = helper.normalize(camera_pos_in - position_in);
    const halfway_direction = helper.normalize(direction + view_direction);
    const max_direction = @max(vector3.dot(helper.normalize(normal_in), halfway_direction), 0.0);
    const specular_value = helper.pow(vector3.splat(max_direction), vector3.splat(32));

    return light.specular * specular_value;
}

fn calculateAttenuation(light_position: @Vector(3, f32)) @Vector(3, f32) {
    const constant = vector3.splat(light.properties[0]);
    const linear = vector3.splat(light.properties[1]);
    const quadratic = vector3.splat(light.properties[2]);

    const distance = vector3.splat(helper.length(light_position - position_in));
    return vector3.splat(1) / (constant + linear * distance + quadratic * distance * distance);
}

fn reflect(vector: @Vector(3, f32), normal: @Vector(3, f32)) @Vector(3, f32) {
    return vector - vector3.splat(2.0) * vector3.splat(vector3.dot(normal, vector)) * normal;
}
