const Engine = @import("engine/core.zig").Engine;
const GameState = @import("game/main.zig").GameState;

pub fn main() !void {
    try Engine.run(GameState);
}
