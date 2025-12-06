const std = @import("std");
const rl = @import("raylib");

const WINDOW_WIDTH = 640;
const WINDOW_HEIGHT = 480;
const TERRAIN_WIDTH = 256;
const TERRAIN_HEIGHT = 256;
const GRAVITY = 98.1;

pub const DB16 = struct {
    pub const BLACK = rl.Color{ .r = 20, .g = 12, .b = 28, .a = 255 };
    pub const PURPLE = rl.Color{ .r = 68, .g = 36, .b = 52, .a = 255 };
    pub const RED = rl.Color{ .r = 148, .g = 0, .b = 52, .a = 255 };
    pub const BROWN = rl.Color{ .r = 116, .g = 60, .b = 0, .a = 255 };
    pub const DARK_GREEN = rl.Color{ .r = 0, .g = 92, .b = 0, .a = 255 };
    pub const DARK_GRAY = rl.Color{ .r = 76, .g = 76, .b = 84, .a = 255 };
    pub const GRAY = rl.Color{ .r = 136, .g = 136, .b = 136, .a = 255 };
    pub const WHITE = rl.Color{ .r = 248, .g = 248, .b = 248, .a = 255 };
    pub const LIGHT_RED = rl.Color{ .r = 248, .g = 56, .b = 0, .a = 255 };
    pub const ORANGE = rl.Color{ .r = 228, .g = 92, .b = 16, .a = 255 };
    pub const YELLOW = rl.Color{ .r = 248, .g = 216, .b = 120, .a = 255 };
    pub const GREEN = rl.Color{ .r = 0, .g = 168, .b = 0, .a = 255 };
    pub const CYAN = rl.Color{ .r = 0, .g = 184, .b = 248, .a = 255 };
    pub const BLUE = rl.Color{ .r = 0, .g = 88, .b = 248, .a = 255 };
    pub const LIGHT_BLUE = rl.Color{ .r = 136, .g = 180, .b = 248, .a = 255 };
    pub const PINK = rl.Color{ .r = 248, .g = 120, .b = 248, .a = 255 };
};

const Vec2 = struct {
    x: f32,
    y: f32,

    pub fn init(
        x: f32,
        y: f32,
    ) Vec2 {
        return .{ .x = x, .y = y };
    }

    pub fn add(self: Vec2, other: Vec2) Vec2 {
        return .{ .x = self.x + other.x, .y = self.y + other.y };
    }

    pub fn mul(self: Vec2, other: Vec2) Vec2 {
        return .{ .x = self.x * other.x, .y = self.y * other.y };
    }

    pub fn clamp(self: Vec2, min: f32, max: f32) Vec2 {
        return .{ .x = std.math.clamp(self.x, min, max), .y = std.math.clamp(self.y, min, max) };
    }
};

pub const IVec2 = struct {
    x: i32,
    y: i32,

    pub fn init(
        x: i32,
        y: i32,
    ) IVec2 {
        return .{ .x = x, .y = y };
    }

    pub fn add(self: IVec2, other: IVec2) IVec2 {
        return .{ .x = self.x + other.x, .y = self.y + other.y };
    }

    pub fn mul(self: IVec2, other: IVec2) IVec2 {
        return .{ .x = self.x * other.x, .y = self.y * other.y };
    }
};

pub const Block = struct {
    pos: Vec2,
    size: IVec2,
    vel: Vec2 = Vec2.init(0, 0),
    max_vel: f32 = 250.0,
    speed: f32 = 0.0,
    color: rl.Color,

    pub fn init(x: f32, y: f32, w: i32, h: i32, speed: f32, color: rl.Color) Block {
        return .{
            .pos = Vec2.init(x, y),
            .size = IVec2.init(w, h),
            .speed = speed,
            .color = color,
        };
    }

    pub fn getRect(self: Block) struct { x: i32, y: i32, w: i32, h: i32 } {
        return .{
            .x = @intFromFloat(self.pos.x),
            .y = @intFromFloat(self.pos.y),
            .w = self.size.x,
            .h = self.size.y,
        };
    }

    pub fn draw(self: Block) void {
        rl.drawRectangle(@intFromFloat(self.pos.x), @intFromFloat(self.pos.y), self.size.x, self.size.y, self.color);
    }

    pub fn update(self: *Block, dt: f32) void {
        self.vel.y += GRAVITY * dt;
        const new_pos = self.pos.add(.{ .x = self.vel.x * dt, .y = self.vel.y * dt });
        const window_w: f32 = @floatFromInt(WINDOW_WIDTH);
        const window_h: f32 = @floatFromInt(WINDOW_HEIGHT);
        const size_w: f32 = @floatFromInt(self.size.x);
        const size_h: f32 = @floatFromInt(self.size.y);

        if (new_pos.x <= 0 or new_pos.x + size_w >= window_w) {
            self.vel.x = -self.vel.x;
        }

        if (new_pos.y <= 0 or new_pos.y + size_h >= window_h) {
            self.vel.y = -self.vel.y;
        }

        self.pos = self.pos.add(.{ .x = self.vel.x * dt, .y = self.vel.y * dt });
        self.pos.x = std.math.clamp(self.pos.x, 0.0, window_w - size_w);
        self.pos.y = std.math.clamp(self.pos.y, 0.0, window_h - size_h);
    }

    pub fn bounceOff(self: *Block) void {
        self.vel.x = -self.vel.x;
        self.vel.y = -self.vel.y;
        self.vel.x *= 0.25;
        self.vel.y *= 0.25;
    }

    pub fn setVelocity(self: *Block, vx: f32, vy: f32) void {
        self.vel = Vec2.init(vx, vy);
    }

    pub fn addVel(self: *Block, vel: Vec2) void {
        self.vel = self.vel.add(Vec2.init(vel.x * self.speed, vel.y * self.speed));
        self.vel = self.vel.clamp(-self.max_vel, self.max_vel);
    }

    pub fn collidesWidth(self: Block, other: Block) bool {
        const a = self.getRect();
        const b = other.getRect();
        return a.x < b.x + b.w and
            a.x + a.w > b.x and
            a.y < b.y + b.h and
            a.y + a.h > b.y;
    }
};

pub const EntityType = enum { Player, Enemy, Bullet, Obstacle };
pub const Entity = struct {
    block: Block,
    kind: EntityType,
    health: i32 = 0,

    pub fn init(block: Block, kind: EntityType, health: i32) Entity {
        return .{
            .block = block,
            .kind = kind,
            .health = health,
        };
    }
};

pub fn main() !void {
    rl.initWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "Zig/Raylib Engine");
    defer rl.closeWindow();

    rl.setTargetFPS(60);

    // var terrain = Terrain.init();
    var player = Entity.init(Block.init(100, 100, 24, 24, 100.0, DB16.BLACK), EntityType.Player, 100);
    var enemy = Entity.init(Block.init(200, 200, 12, 12, 50.0, DB16.PURPLE), EntityType.Enemy, 10);
    var enemy2 = Entity.init(Block.init(300, 300, 12, 12, 50.0, DB16.ORANGE), EntityType.Enemy, 10);

    enemy.block.setVelocity(-40.0, -80.0);
    enemy2.block.setVelocity(60.0, -40.0);

    while (rl.windowShouldClose() == false) {
        const dt: f32 = rl.getFrameTime();

        if (rl.isKeyDown(rl.KeyboardKey.right)) player.block.addVel(Vec2.init(dt, 0.0));
        if (rl.isKeyDown(rl.KeyboardKey.left)) player.block.addVel(Vec2.init(-dt, 0.0));
        if (rl.isKeyDown(rl.KeyboardKey.up)) player.block.addVel(Vec2.init(0.0, -dt));
        if (rl.isKeyDown(rl.KeyboardKey.down)) player.block.addVel(Vec2.init(0.0, dt));

        player.block.update(dt);
        enemy.block.update(dt);
        enemy2.block.update(dt);

        const colliding = player.block.collidesWidth(enemy.block) or player.block.collidesWidth(enemy2.block);

        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(DB16.LIGHT_BLUE);

        // terrain.draw();

        rl.drawRectangle(2, 2, 38, 32, DB16.YELLOW);
        var fps_buffer: [32]u8 = undefined;
        const fps_text = std.fmt.bufPrintZ(&fps_buffer, "{d}", .{rl.getFPS()}) catch "0";
        rl.drawText(fps_text, 8, 8, 20, DB16.BLACK);

        rl.drawRectangle(50, 2, player.health * 5, 32, DB16.WHITE);
        var health_buffer: [32]u8 = undefined;
        const health_text = std.fmt.bufPrintZ(&health_buffer, "{d}", .{player.health}) catch "0";
        rl.drawText(health_text, 54, 8, 20, DB16.BLACK);

        player.block.draw();
        enemy.block.draw();
        enemy2.block.draw();

        if (colliding) {
            player.block.bounceOff();
            player.health -= 1;
            if (player.health <= 0) {
                player.block.pos = Vec2.init(WINDOW_WIDTH / 2, WINDOW_HEIGHT / 2);
                player.health = 100;
            }
        }
    }
}
