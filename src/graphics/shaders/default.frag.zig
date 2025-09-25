const std = @import("std");
const gpu = std.gpu;
const math = @import("math");
const vector3 = math.vector3;
const vector4 = math.vector4;

extern var position_in: @Vector(3, f32) addrspace(.input);
extern var normal_in: @Vector(3, f32) addrspace(.input);
extern var tex_coord_in: @Vector(2, f32) addrspace(.input);

extern var color_out: @Vector(4, f32) addrspace(.output);

extern var light: extern struct {
    position: @Vector(3, f32),
    ambient: @Vector(3, f32),
    diffuse: @Vector(3, f32),
} addrspace(.uniform);

extern var camera: extern struct {
    position: @Vector(3, f32),
} addrspace(.uniform);

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
    gpu.binding(&camera, 3, 1);

    gpu.location(&position_in, 0);
    gpu.location(&normal_in, 1);
    gpu.location(&tex_coord_in, 2);

    gpu.location(&color_out, 0);

    const ambient = light.ambient;

    const light_direction = vector3.normalize(light.position - position_in);
    const diffuse_value = @max(vector3.dot(normal_in, light_direction), 0.0);
    const diffuse = light.diffuse * vector3.splat(diffuse_value);

    const view_direction = vector3.normalize(camera.position - position_in);
    const reflect_direction = reflect(-light_direction, normal_in);
    const max_direction = @max(vector3.dot(view_direction, reflect_direction), 0.0);
    const specular_value = pow(max_direction, 16);
    const specular = vector3.splat(0.5) * vector3.splat(specular_value);

    const light_result = ambient + diffuse + specular;

    color_out = sampler2d(2, 0, tex_coord_in) * vector4.fromVector3(light_result, 1.0);
}

fn reflect(vector: @Vector(3, f32), normal: @Vector(3, f32)) @Vector(3, f32) {
    return vector - vector3.splat(2.0) * vector3.splat(vector3.dot(normal, vector)) * normal;
}

fn pow(a: f32, b: usize) f32 {
    var result = a;

    for (1..b) |_| result *= a;

    return result;
}
