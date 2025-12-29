const Engine = @import("engine/core.zig").Engine;
const rl = @import("raylib");
const std = @import("std");

const Splat = struct {
    pos: [3]f32,
    scale: [3]f32,
    r: f32,
    g: f32,
};

pub const GameState = struct {
    pub const config = .{
        .width = 800,
        .height = 600,
        .title = "Gaussian Splat Viewer",
        .target_fps = 60,
    };
    camera: rl.Camera3D,
    splat_data: []u8,
    vertex_count: usize,
    splats: []Splat,

    pub fn init() !GameState {
        const allocator = std.heap.page_allocator;
        const splat_data = try std.fs.cwd().readFileAlloc(allocator, "assets/example.splat", std.math.maxInt(usize));
        const vertex_count = splat_data.len / 32;

        const f32_data = std.mem.bytesAsSlice(f32, splat_data);
        const splats = try allocator.alloc(Splat, vertex_count);
        for (0..vertex_count) |i| {
            const offset = i * 8;
            splats[i] = Splat{
                .pos = [_]f32{ f32_data[offset + 0], f32_data[offset + 1], f32_data[offset + 2] },
                .scale = [_]f32{ f32_data[offset + 3], f32_data[offset + 4], f32_data[offset + 5] },
                .r = f32_data[offset + 6],
                .g = f32_data[offset + 7],
            };
        }

        rl.setMousePosition(GameState.config.width / 2, GameState.config.height / 2);

        return GameState{
            .camera = .{
                .position = .{ .x = 10, .y = 10, .z = -10 },
                .target = .{ .x = 0, .y = 0, .z = 0 },
                .up = .{ .x = 0, .y = 1, .z = 0 },
                .fovy = 45,
                .projection = rl.CameraProjection.perspective,
            },
            .splat_data = splat_data,
            .vertex_count = vertex_count,
            .splats = splats,
        };
    }

    pub fn deinit(self: *GameState) void {
        const allocator = std.heap.page_allocator;
        allocator.free(self.splats);
        allocator.free(self.splat_data);
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
        var vertex_buffer: [100]u8 = undefined;
        const vertex_text = std.fmt.bufPrintZ(&vertex_buffer, "Vertices: {d}", .{self.vertex_count}) catch "Vertices: ?";
        rl.drawText(vertex_text, 10, 30, 20, rl.Color.dark_gray);

        // Temporary: draw first splat as cube for testing
        if (self.vertex_count > 0) {
            const s = &self.splats[0];
            const r_val = std.math.clamp(s.r * 255, 0, 255);
            const g_val = std.math.clamp(s.g * 255, 0, 255);
            rl.drawCube(.{ .x = s.pos[0], .y = s.pos[1], .z = s.pos[2] }, s.scale[0], s.scale[1], s.scale[2], rl.Color{ .r = @intFromFloat(r_val), .g = @intFromFloat(g_val), .b = 255, .a = 255 });

            // Debug output for first splat
            var pos_buffer: [200]u8 = undefined;
            const pos_text = std.fmt.bufPrintZ(&pos_buffer, "First Splat Pos: {d:.2},{d:.2},{d:.2}", .{ s.pos[0], s.pos[1], s.pos[2] }) catch "First Splat Pos: err";
            rl.drawText(pos_text, 10, 50, 20, rl.Color.black);

            var scale_buffer: [200]u8 = undefined;
            const scale_text = std.fmt.bufPrintZ(&scale_buffer, "Scale: {d:.2},{d:.2},{d:.2}", .{ s.scale[0], s.scale[1], s.scale[2] }) catch "Scale: err";
            rl.drawText(scale_text, 10, 70, 20, rl.Color.black);
        }
    }
};

pub fn main() !void {
    try Engine.run(GameState);
}
