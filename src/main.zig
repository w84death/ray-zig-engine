const Engine = @import("engine/core.zig").Engine;
const rl = @import("raylib");
const std = @import("std");
const Math = @import("engine/math.zig");

const SKIP_FACTOR: usize = 10;

const CamState = struct {
    distance: f32,
    theta: f32,
    phi: f32,
    initial_theta: f32,
    initial_phi: f32,
    dragging: bool = false,
    mouse_start: rl.Vector2,
    theta_start: f32,
    phi_start: f32,
};

const Splat = struct {
    pos: [3]f32,
    r: u8,
    g: u8,
    b: u8,
    a: u8,
};

const PlyLoadResult = struct {
    ply_data: []u8,
    splats: []Splat,
    vertex_count: usize,
};

fn loadPly(allocator: std.mem.Allocator) !PlyLoadResult {
    const ply_data = try std.fs.cwd().readFileAlloc(allocator, "assets/input.ply", std.math.maxInt(usize));

    // Find header end
    const header_end = std.mem.indexOf(u8, ply_data, "end_header") orelse return error.InvalidPly;
    const header = ply_data[0..header_end];
    var data_start = header_end + "end_header".len;
    while (data_start < ply_data.len and (ply_data[data_start] == '\r' or ply_data[data_start] == '\n')) data_start += 1;

    // Parse vertex count and properties from header
    var vertex_count: usize = 0;
    var properties: std.ArrayListUnmanaged([]const u8) = .{};
    defer properties.deinit(allocator);
    var in_vertex = false;
    var lines_iter = std.mem.splitScalar(u8, header, '\n');
    while (lines_iter.next()) |raw_line| {
        const line = std.mem.trim(u8, raw_line, "\r");
        if (std.mem.startsWith(u8, line, "element vertex ")) {
            var parts = std.mem.splitAny(u8, line, " ");
            _ = parts.next(); // "element"
            _ = parts.next(); // "vertex"
            if (parts.next()) |count_str| {
                vertex_count = try std.fmt.parseInt(usize, count_str, 10);
            }
            in_vertex = true;
        } else if (std.mem.startsWith(u8, line, "element ")) {
            in_vertex = false;
        } else if (in_vertex and std.mem.startsWith(u8, line, "property float ")) {
            var parts = std.mem.splitAny(u8, line, " ");
            _ = parts.next(); // "property"
            _ = parts.next(); // "float"
            if (parts.next()) |name| {
                try properties.append(allocator, name);
            }
        }
    }
    if (vertex_count == 0) return error.InvalidPly;

    const data = ply_data[data_start..];

    const splats = try allocator.alloc(Splat, vertex_count);
    std.debug.print("Loading binary PLY file with {} vertices...\n", .{vertex_count});
    // Binary parsing
    const stride = properties.items.len;
    const vertex_data_size = vertex_count * stride * 4;
    if (vertex_data_size > data.len) return error.InvalidData;
    const f32_slice = std.mem.bytesAsSlice(f32, data[0..vertex_data_size]);
    for (0..vertex_count) |ii| {
        const off = ii * stride;
        var pos: [3]f32 = undefined;
        var color_f: [3]f32 = undefined;
        var opacity: f32 = 0;
        for (properties.items, 0..) |name, idx| {
            const val = f32_slice[off + idx];
            if (std.mem.eql(u8, name, "x")) pos[0] = val else if (std.mem.eql(u8, name, "y")) pos[1] = val else if (std.mem.eql(u8, name, "z")) pos[2] = val else if (std.mem.eql(u8, name, "f_dc_0")) color_f[0] = val else if (std.mem.eql(u8, name, "f_dc_1")) color_f[1] = val else if (std.mem.eql(u8, name, "f_dc_2")) color_f[2] = val else if (std.mem.eql(u8, name, "opacity")) opacity = val;
        }
        const r_val = std.math.clamp((0.5 + color_f[0]) * 255.0, 0.0, 255.0);
        const g_val = std.math.clamp((0.5 + color_f[1]) * 255.0, 0.0, 255.0);
        const b_val = std.math.clamp((0.5 + color_f[2]) * 255.0, 0.0, 255.0);
        const a_val = std.math.clamp((1.0 / (1.0 + std.math.exp(-opacity))) * 255.0, 0.0, 255.0);
        const r = @as(u8, @intFromFloat(r_val));
        const g = @as(u8, @intFromFloat(g_val));
        const b = @as(u8, @intFromFloat(b_val));
        const a = @as(u8, @intFromFloat(a_val));
        splats[ii] = Splat{
            .pos = pos,
            .r = r,
            .g = g,
            .b = b,
            .a = a,
        };
        if (ii % 100000 == 0 or ii == vertex_count - 1) std.debug.print("Loaded {}/{} vertices\n", .{ ii + 1, vertex_count });
    }
    std.debug.print("Finished loading {} vertices from binary PLY\n", .{vertex_count});

    return PlyLoadResult{
        .ply_data = ply_data,
        .splats = splats,
        .vertex_count = vertex_count,
    };
}

const CameraInitResult = struct {
    camera: rl.Camera3D,
    cam_state: CamState,
};

fn initCamera(center: [3]f32) CameraInitResult {
    const distance = 1.0;
    const theta = std.math.pi / 2.0; // 90 degrees
    const phi = std.math.pi / -2.0;

    const camera = rl.Camera3D{
        .position = .{
            .x = center[0] + distance * std.math.sin(phi) * std.math.cos(theta),
            .y = center[1] + distance * std.math.cos(phi),
            .z = center[2] + distance * std.math.sin(phi) * std.math.sin(theta),
        },
        .target = .{ .x = center[0], .y = center[1], .z = center[2] },
        .up = .{ .x = 0, .y = -1, .z = 0 },
        .fovy = 45,
        .projection = rl.CameraProjection.perspective,
    };

    const cam_state = CamState{
        .distance = distance,
        .theta = theta,
        .phi = phi,
        .initial_theta = theta,
        .initial_phi = phi,
        .dragging = false,
        .mouse_start = .{ .x = 0, .y = 0 },
        .theta_start = theta,
        .phi_start = phi,
    };

    return CameraInitResult{
        .camera = camera,
        .cam_state = cam_state,
    };
}

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
    rendered_count: usize,

    pub fn init() !GameState {
        const allocator = std.heap.page_allocator;
        const result = try loadPly(allocator);
        const center: [3]f32 = [_]f32{ 0, 0, 0 };
        const cam = initCamera(center);

        return GameState{
            .camera = cam.camera,
            .cam_state = cam.cam_state,
            .center = center,
            .radius = 10.0,
            .splat_data = result.ply_data,
            .vertex_count = result.vertex_count,
            .splats = result.splats,
            .rendered_count = (result.vertex_count + SKIP_FACTOR - 1) / SKIP_FACTOR,
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
            self.cam_state.distance *= std.math.pow(f32, 0.9, wheel);
            self.cam_state.distance = std.math.clamp(self.cam_state.distance, 0.1, 4.0);
        }

        // Mouse drag for rotation
        if (rl.isMouseButtonPressed(rl.MouseButton.left)) {
            self.cam_state.dragging = true;
            self.cam_state.mouse_start = rl.getMousePosition();
            self.cam_state.theta_start = self.cam_state.theta;
            self.cam_state.phi_start = self.cam_state.phi;
        }

        if (rl.isMouseButtonReleased(rl.MouseButton.left)) {
            self.cam_state.dragging = false;
        }

        if (self.cam_state.dragging and rl.isMouseButtonDown(rl.MouseButton.left)) {
            const current_pos = rl.getMousePosition();
            const delta_x = current_pos.x - self.cam_state.mouse_start.x;
            const delta_y = current_pos.y - self.cam_state.mouse_start.y;
            const sensitivity: f32 = 0.001;
            self.cam_state.theta = self.cam_state.theta_start + delta_x * sensitivity;
            self.cam_state.phi = self.cam_state.phi_start + delta_y * sensitivity;
            self.cam_state.theta = std.math.clamp(self.cam_state.theta, -std.math.pi, std.math.pi);
            self.cam_state.phi = std.math.clamp(self.cam_state.phi, -std.math.pi / 2.0, std.math.pi / 2.0);
            const delta_rad: f32 = 20.0 * std.math.pi / 180.0;
            self.cam_state.theta = std.math.clamp(self.cam_state.theta, self.cam_state.initial_theta - delta_rad, self.cam_state.initial_theta + delta_rad);
            self.cam_state.phi = std.math.clamp(self.cam_state.phi, self.cam_state.initial_phi - delta_rad, self.cam_state.initial_phi + delta_rad);
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

        for (0..self.splats.len) |i| {
            if (i % SKIP_FACTOR != 0) continue;
            const s = self.splats[i];
            const color = rl.Color{
                .r = s.r,
                .g = s.g,
                .b = s.b,
                .a = s.a,
            };
            rl.drawPoint3D(rl.Vector3{ .x = s.pos[0], .y = s.pos[1], .z = s.pos[2] }, color);
        }

        rl.endMode3D();

        rl.drawFPS(10, 10);

        var buf: [64]u8 = undefined;
        _ = std.fmt.bufPrintZ(&buf, "Rendered points: {}", .{self.rendered_count}) catch "Error";
        rl.drawText(@ptrCast(&buf), 10, 30, 20, rl.Color.white);
    }
};

pub fn main() !void {
    try Engine.run(GameState);
}
