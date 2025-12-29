const Engine = @import("engine/core.zig").Engine;
const rl = @import("raylib");
const std = @import("std");
const Math = @import("engine/math.zig");

const CamState = struct {
    distance: f32,
    theta: f32,
    phi: f32,
    initial_theta: f32,
    initial_phi: f32,
};

const Splat = struct {
    pos: [3]f32,
    scale: [3]f32,
    r: f32,
    g: f32,
    b: f32,
    a: f32,
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
        const ply_data = try std.fs.cwd().readFileAlloc(allocator, "assets/example.ply", std.math.maxInt(usize));

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
        const is_ascii = std.mem.indexOf(u8, header, "format ascii") != null;

        const splats = try allocator.alloc(Splat, vertex_count);
        if (is_ascii) {
            // ASCII parsing
            var lines_data = std.mem.splitScalar(u8, data, '\n');
            var i: usize = 0;
            while (lines_data.next()) |raw_line| {
                const line = std.mem.trim(u8, raw_line, &std.ascii.whitespace);
                if (line.len == 0) continue;
                var fields = std.mem.splitAny(u8, line, " ");
                var pos: [3]f32 = undefined;
                var color_f: [3]f32 = undefined;
                var opacity: f32 = 0;
                var scale_f: [3]f32 = undefined;
                var field_idx: usize = 0;
                while (fields.next()) |field| {
                    if (field.len == 0) continue;
                    const val = try std.fmt.parseFloat(f32, field);
                    const prop_name = if (field_idx < properties.items.len) properties.items[field_idx] else "";
                    if (std.mem.eql(u8, prop_name, "x")) pos[0] = val else if (std.mem.eql(u8, prop_name, "y")) pos[1] = val else if (std.mem.eql(u8, prop_name, "z")) pos[2] = val else if (std.mem.eql(u8, prop_name, "f_dc_0")) color_f[0] = val else if (std.mem.eql(u8, prop_name, "f_dc_1")) color_f[1] = val else if (std.mem.eql(u8, prop_name, "f_dc_2")) color_f[2] = val else if (std.mem.eql(u8, prop_name, "opacity")) opacity = val else if (std.mem.eql(u8, prop_name, "scale_0")) scale_f[0] = val else if (std.mem.eql(u8, prop_name, "scale_1")) scale_f[1] = val else if (std.mem.eql(u8, prop_name, "scale_2")) scale_f[2] = val;
                    field_idx += 1;
                }
                const r = (0.5 + color_f[0]) * 255.0;
                const g = (0.5 + color_f[1]) * 255.0;
                const b = (0.5 + color_f[2]) * 255.0;
                const a = (1.0 / (1.0 + std.math.exp(-opacity))) * 255.0;
                const scale = [_]f32{ std.math.exp(scale_f[0]), std.math.exp(scale_f[1]), std.math.exp(scale_f[2]) };
                splats[i] = Splat{
                    .pos = pos,
                    .scale = scale,
                    .r = r,
                    .g = g,
                    .b = b,
                    .a = a,
                };
                i += 1;
                if (i == vertex_count) break;
            }
        } else {
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
                var scale_f: [3]f32 = undefined;
                for (properties.items, 0..) |name, idx| {
                    const val = f32_slice[off + idx];
                    if (std.mem.eql(u8, name, "x")) pos[0] = val else if (std.mem.eql(u8, name, "y")) pos[1] = val else if (std.mem.eql(u8, name, "z")) pos[2] = val else if (std.mem.eql(u8, name, "f_dc_0")) color_f[0] = val else if (std.mem.eql(u8, name, "f_dc_1")) color_f[1] = val else if (std.mem.eql(u8, name, "f_dc_2")) color_f[2] = val else if (std.mem.eql(u8, name, "opacity")) opacity = val else if (std.mem.eql(u8, name, "scale_0")) scale_f[0] = val else if (std.mem.eql(u8, name, "scale_1")) scale_f[1] = val else if (std.mem.eql(u8, name, "scale_2")) scale_f[2] = val;
                }
                const r = (0.5 + color_f[0]) * 255.0;
                const g = (0.5 + color_f[1]) * 255.0;
                const b = (0.5 + color_f[2]) * 255.0;
                const a = (1.0 / (1.0 + std.math.exp(-opacity))) * 255.0;
                const scale = [_]f32{ std.math.exp(scale_f[0]), std.math.exp(scale_f[1]), std.math.exp(scale_f[2]) };
                splats[ii] = Splat{
                    .pos = pos,
                    .scale = scale,
                    .r = r,
                    .g = g,
                    .b = b,
                    .a = a,
                };
            }
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
        };

        return GameState{
            .camera = camera,
            .cam_state = cam_state,
            .center = center,
            .radius = 10.0,
            .splat_data = ply_data,
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
            const sensitivity: f32 = 0.001;
            self.cam_state.theta += delta.x * sensitivity;
            self.cam_state.phi += delta.y * sensitivity;
            // Restrict rotation to small amounts relative to initial
            self.cam_state.theta = std.math.clamp(self.cam_state.theta, self.cam_state.initial_theta - std.math.pi / 4.0, self.cam_state.initial_theta + std.math.pi / 4.0);
            self.cam_state.phi = std.math.clamp(self.cam_state.phi, self.cam_state.initial_phi - std.math.pi / 4.0, self.cam_state.initial_phi + std.math.pi / 4.0);
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

        for (0..self.splats.len) |i| {
            if (i % 10 != 0) continue;
            const s = self.splats[i];
            const pos = rl.Vector3{ .x = s.pos[0], .y = s.pos[1], .z = s.pos[2] };
            const color = rl.Color{
                .r = @as(u8, @intFromFloat(std.math.clamp(s.r, 0, 255))),
                .g = @as(u8, @intFromFloat(std.math.clamp(s.g, 0, 255))),
                .b = @as(u8, @intFromFloat(std.math.clamp(s.b, 0, 255))),
                .a = @as(u8, @intFromFloat(std.math.clamp(s.a, 0, 255))),
            };
            rl.drawPoint3D(pos, color);
        }

        rl.endMode3D();
    }
};

pub fn main() !void {
    try Engine.run(GameState);
}
