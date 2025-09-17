const std = @import("std");
const sdl3 = @import("sdl3");

pub fn main() !void {
    try sdl3.init(.everything);
    defer sdl3.shutdown();
    defer sdl3.quit(.everything);
}
