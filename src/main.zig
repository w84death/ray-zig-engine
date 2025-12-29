const Engine = @import("engine/core.zig").Engine;
const rl = @import("raylib");

pub const GameState = struct {
    pub const config = .{
        .width = 800,
        .height = 600,
        .title = "Gaussian Splat Viewer",
        .target_fps = 60,
    };
    camera: rl.Camera3D,

    pub fn init() !GameState {
        rl.setMousePosition(GameState.config.width / 2, GameState.config.height / 2);

        return GameState{
            .camera = .{
                .position = .{ .x = 10, .y = 10, .z = -10 },
                .target = .{ .x = 0, .y = 0, .z = 0 },
                .up = .{ .x = 0, .y = 1, .z = 0 },
                .fovy = 45,
                .projection = rl.CameraProjection.perspective,
            },
        };
    }

    pub fn deinit(self: *GameState) void {
        // Add cleanup for splat data later
        _ = self;
    }

    pub fn update(self: *GameState, dt: f32) void {
        _ = dt;
        rl.updateCamera(&self.camera, rl.CameraMode.free);
    }

    pub fn render(self: *GameState) void {
        rl.beginDrawing();
        defer rl.endDrawing();
        rl.clearBackground(rl.Color.ray_white);

        rl.beginMode3D(self.camera);
        rl.drawCube(.{ .x = 0, .y = 0, .z = 0 }, 2, 2, 2, rl.Color.red);
        rl.drawGrid(10, 1);
        rl.endMode3D();

        rl.drawText("Gaussian Splat Viewer", 10, 10, 20, rl.Color.dark_gray);
    }
};

pub fn main() !void {
    try Engine.run(GameState);
}
