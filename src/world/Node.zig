const std = @import("std");
const mem = std.mem;
const sdl3 = @import("sdl3");
const gpu = sdl3.gpu;
const math = @import("../core/math.zig");
const Texture = @import("../graphics/Texture.zig");
const Model = @import("../graphics/Model.zig");

const Node = @This();

position: math.Vector3 = math.vector3.zero,
rotation: math.Vector3 = math.vector3.zero,
scale: math.Vector3 = math.vector3.one,

texture: Texture,
model: Model,

pub fn render(
    node: Node,
    cmd_buf: gpu.CommandBuffer,
    render_pass: gpu.RenderPass,
) void {
    cmd_buf.pushVertexUniformData(1, mem.asBytes(&.{
        math.matrix.recompose(node.position, node.rotation, node.scale),
    }));

    node.texture.bind(render_pass);
    node.model.render(render_pass);
}

pub fn release(node: Node, device: gpu.Device) void {
    node.texture.release(device);
    node.model.release(device);
}
