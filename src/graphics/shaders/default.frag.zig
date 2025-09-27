const std = @import("std");
const gpu = std.gpu;
const math = @import("math");
const vector3 = math.vector3;
const vector4 = math.vector4;

extern var position_in: @Vector(3, f32) addrspace(.input);
extern var normal_in: @Vector(3, f32) addrspace(.input);
extern var tex_coord_in: @Vector(2, f32) addrspace(.input);
extern var camera_pos_in: @Vector(3, f32) addrspace(.input);

extern var color_out: @Vector(4, f32) addrspace(.output);

const Light = extern struct {
    position: @Vector(4, f32),
    direction: @Vector(4, f32),
    properties: @Vector(4, f32),
    ambient: @Vector(3, f32),
    diffuse: @Vector(3, f32),
    specular: @Vector(3, f32),
};

extern var light: Light addrspace(.uniform);

fn sampler2d(
    comptime set: u32,
    comptime bind: u32,
    uv: @Vector(2, f32),
) @Vector(4, f32) {
    return asm volatile (
        \\%float          = OpTypeFloat 32
        \\%v4float        = OpTypeVector %float 4
        \\%img_type       = OpTypeImage %float 2D 0 0 0 1 Unknown
        \\%sampler_type   = OpTypeSampledImage %img_type
        \\%sampler_ptr    = OpTypePointer UniformConstant %sampler_type
        \\%tex            = OpVariable %sampler_ptr UniformConstant
        \\                  OpDecorate %tex DescriptorSet $set
        \\                  OpDecorate %tex Binding $bind
        \\%loaded_sampler = OpLoad %sampler_type %tex
        \\%ret            = OpImageSampleImplicitLod %v4float %loaded_sampler %uv
        : [ret] "" (-> @Vector(4, f32)),
        : [uv] "" (uv),
          [set] "c" (set),
          [bind] "c" (bind),
    );
}

export fn main() callconv(.spirv_fragment) void {
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

    color_out = sampler2d(2, 0, tex_coord_in) * vector4.fromVector3(light_result, 1.0);
}

fn calculateDirectional() @Vector(3, f32) {
    const light_direction = vector3.fromVector4(light.direction);
    const diffuse = calculateDiffuse(light_direction);
    const specular = calculateSpecular(light_direction);

    return light.ambient + diffuse + specular;
}

fn calculatePoint() @Vector(3, f32) {
    const light_position = vector3.fromVector4(light.position);
    const light_direction = vector3.normalize(light_position - position_in);

    const attenuation = calculateAttenuation(light_position);

    const diffuse = calculateDiffuse(light_direction) * attenuation;
    const specular = calculateSpecular(light_direction) * attenuation;

    return light.ambient * attenuation + diffuse + specular;
}

fn calculateSpotlight() @Vector(3, f32) {
    const light_position = vector3.fromVector4(light.position);
    const light_direction_pos = vector3.normalize(light_position - position_in);
    const light_direction = vector3.normalize(vector3.fromVector4(light.direction));

    const cut_off = light.position[3];
    const outer_cut_off = light.direction[3];

    const theta = vector3.dot(-light_direction_pos, -light_direction);
    const epsilon = cut_off - outer_cut_off;
    const intensity = vector3.splat(@max(0.0, @min((theta - outer_cut_off) / epsilon, 1.0)));

    const attenuation = calculateAttenuation(light_position);

    const diffuse = calculateDiffuse(light_direction_pos) * intensity * attenuation;
    const specular = calculateSpecular(light_direction_pos) * intensity * attenuation;

    return light.ambient * attenuation + diffuse + specular;
}

fn calculateDiffuse(direction: @Vector(3, f32)) @Vector(3, f32) {
    const diffuse_value = @max(vector3.dot(normal_in, direction), 0.0);

    return light.diffuse * vector3.splat(diffuse_value);
}

fn calculateSpecular(direction: @Vector(3, f32)) @Vector(3, f32) {
    const view_direction = vector3.normalize(camera_pos_in - position_in);
    const reflect_direction = reflect(-direction, normal_in);
    const max_direction = @max(vector3.dot(view_direction, reflect_direction), 0.0);
    const specular_value = pow(max_direction, 16);

    return light.specular * vector3.splat(specular_value);
}

fn calculateAttenuation(light_position: @Vector(3, f32)) @Vector(3, f32) {
    const constant = vector3.splat(light.properties[0]);
    const linear = vector3.splat(light.properties[1]);
    const quadratic = vector3.splat(light.properties[2]);

    const distance = vector3.splat(vector3.magnitude(light_position - position_in));
    const distance_sq = distance * distance;

    return vector3.splat(1) / (constant + linear * distance + quadratic * distance_sq);
}

fn reflect(vector: @Vector(3, f32), normal: @Vector(3, f32)) @Vector(3, f32) {
    return vector - vector3.splat(2.0) * vector3.splat(vector3.dot(normal, vector)) * normal;
}

fn pow(a: f32, b: usize) f32 {
    var result = a;

    for (1..b) |_| result *= a;

    return result;
}
