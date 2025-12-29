const Engine = @import("engine/core.zig").Engine;
const rl = @import("raylib");
const std = @import("std");
const Math = @import("engine/math.zig");

const CamState = struct {
    distance: f32,
    theta: f32,
    phi: f32,
};

const Splat = struct {
    pos: [3]f32,
    scale: [3]f32,
    r: f32,
    g: f32,
};

pub const GameState = struct {
    pub const config = .{
        .width = 1024,
        .height = 800,
        .title = "Gaussian Splat Viewer",
        .target_fps = 60,
    };
    camera: rl.Camera3D,
    cam_state: CamState,
    center: [3]f32,
    radius: f32,
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
        rl.hideCursor();

        const center: [3]f32 = [_]f32{ 0, 0, 0 };
        const distance = 4.0;
        const theta = std.math.pi / 2.0; // 90 degrees
        const phi = std.math.pi / -2.0;

        const camera = rl.Camera3D{
            .position = .{
                .x = center[0] + distance * std.math.sin(phi) * std.math.cos(theta),
                .y = center[1] + distance * std.math.cos(phi),
                .z = center[2] + distance * std.math.sin(phi) * std.math.sin(theta),
            },
            .target = .{ .x = center[0], .y = center[1], .z = center[2] },
            .up = .{ .x = 0, .y = 1, .z = 0 },
            .fovy = 45,
            .projection = rl.CameraProjection.perspective,
        };

        const cam_state = CamState{
            .distance = distance,
            .theta = theta,
            .phi = phi,
        };

        return GameState{
            .camera = camera,
            .cam_state = cam_state,
            .center = center,
            .radius = 10.0,
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

        // Wheel for distance
        const wheel = rl.getMouseWheelMove();
        if (wheel != 0) {
            self.cam_state.distance *= std.math.pow(f32, 0.95, wheel);
            self.cam_state.distance = std.math.clamp(self.cam_state.distance, 0.1, 50.0);
        }

        // Mouse drag for rotation
        if (rl.isMouseButtonDown(rl.MouseButton.left)) {
            const delta = rl.getMouseDelta();
            const sensitivity: f32 = 0.005;
            self.cam_state.theta += delta.x * sensitivity;
            self.cam_state.phi += delta.y * sensitivity;
            const phi_min = -std.math.pi / 2.0;
            const phi_max = std.math.pi / 2.0;
            self.cam_state.phi = std.math.clamp(self.cam_state.phi, phi_min, phi_max);
            rl.setMousePosition(GameState.config.width / 2, GameState.config.height / 2);
        }

        // Update camera position
        const cx = self.cam_state.distance * std.math.sin(self.cam_state.phi) * std.math.cos(self.cam_state.theta);
        const cy = self.cam_state.distance * std.math.cos(self.cam_state.phi);
        const cz = self.cam_state.distance * std.math.sin(self.cam_state.phi) * std.math.sin(self.cam_state.theta);
        self.camera.position = .{ .x = self.center[0] + cx, .y = self.center[1] + cy, .z = self.center[2] + cz };
    }

    pub fn render(self: *GameState) void {
        rl.beginDrawing();
        defer rl.endDrawing();
        rl.clearBackground(rl.Color.black);

        rl.beginMode3D(self.camera);

        // Render every 20th splat to show whole picture with less resolution
        for (0..self.splats.len) |i| {
            if (i % 500 != 0) continue;
            const s = self.splats[i];
            const r_val = std.math.clamp(s.r * 255, 0, 255);
            const g_val = std.math.clamp(s.g * 255, 0, 255);
            const size = 0.02; // small cube size
            rl.drawCube(rl.Vector3{ .x = s.pos[0], .y = s.pos[1], .z = s.pos[2] }, size, size, size, rl.Color{ .r = @intFromFloat(r_val), .g = @intFromFloat(g_val), .b = 0, .a = 255 });
        }

        rl.endMode3D();
    }
};

pub fn main() !void {
    try Engine.run(GameState);
}
