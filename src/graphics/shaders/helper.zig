pub fn sampler2d(
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

// TODO: Use this GLSL function until zig supports @sqrt
pub fn normalize(
    vec: anytype,
) @TypeOf(vec) {
    return asm volatile (
        \\%glsl_ext       = OpExtInstImport "GLSL.std.450"
        \\%float          = OpTypeFloat 32
        \\%v3float        = OpTypeVector %float 3
        \\%ret            = OpExtInst %v3float %glsl_ext $inst %vec
        : [ret] "" (-> @TypeOf(vec)),
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
    vec: anytype,
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
