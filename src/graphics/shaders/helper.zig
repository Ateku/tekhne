const math = @import("math");
const Vector2 = @Vector(2, f32);
const Vector3 = math.Vector3;
const Vector4 = math.Vector4;
const Matrix = math.Matrix;

pub fn sampler2d(
    comptime set: u32,
    comptime bind: u32,
    uv: Vector2,
) Vector4 {
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
        : [ret] "" (-> Vector4),
        : [uv] "" (uv),
          [set] "c" (set),
          [bind] "c" (bind),
    );
}

// TODO: Use this GLSL function until zig supports @sqrt
pub fn normalize(
    vec: Vector3,
) Vector3 {
    return asm volatile (
        \\%glsl_ext       = OpExtInstImport "GLSL.std.450"
        \\%float          = OpTypeFloat 32
        \\%v3float        = OpTypeVector %float 3
        \\%ret            = OpExtInst %v3float %glsl_ext $inst %vec
        : [ret] "" (-> Vector3),
        : [vec] "" (vec),
          [inst] "c" (69),
    );
}

// TODO: Use this GLSL function until zig supports std.math.pow
pub fn pow(
    a: anytype,
    b: anytype,
) @TypeOf(a, b) {
    return asm volatile (
        \\%glsl_ext       = OpExtInstImport "GLSL.std.450"
        \\%float          = OpTypeFloat 32
        \\%v3float        = OpTypeVector %float 3
        \\%ret            = OpExtInst %v3float %glsl_ext $inst %a %b
        : [ret] "" (-> @TypeOf(a, b)),
        : [a] "" (a),
          [b] "" (b),
          [inst] "c" (26),
    );
}

// TODO: Use this GLSL function until zig supports @sqrt
pub fn length(
    vec: Vector3,
) f32 {
    return asm volatile (
        \\%glsl_ext       = OpExtInstImport "GLSL.std.450"
        \\%float          = OpTypeFloat 32
        \\%v3float        = OpTypeVector %float 3
        \\%ret            = OpExtInst %v3float %glsl_ext $inst %vec
        : [ret] "" (-> f32),
        : [vec] "" (vec),
          [inst] "c" (66),
    );
}
