const std = @import("std");
const rl = @import("raylib");

const WINDOW_WIDTH = 640;
const WINDOW_HEIGHT = 480;
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
    x: i32,
    y: i32,

    pub fn init(
        x: i32,
        y: i32,
    ) Vec2 {
        return .{ .x = x, .y = y };
    }

    pub fn add(self: Vec2, other: Vec2) Vec2 {
        return .{ .x = self.x + other.x, .y = self.y + other.y };
    }
};

pub const Block = struct {
    pos: Vec2,
    size: Vec2,
    vel: Vec2 = Vec2.init(0, 0),
    color: rl.Color,
    base_color: rl.Color,

    pub fn init(x: i32, y: i32, w: i32, h: i32, color: rl.Color) Block {
        return .{
            .pos = Vec2.init(x, y),
            .size = Vec2.init(w, h),
            .color = color,
            .base_color = color,
        };
    }

    pub fn getRect(self: Block) struct { x: i32, y: i32, w: i32, h: i32 } {
        return .{
            .x = self.pos.x,
            .y = self.pos.y,
            .w = self.size.x,
            .h = self.size.y,
        };
    }

    pub fn draw(self: Block) void {
        rl.drawRectangle(self.pos.x, self.pos.y, self.size.x, self.size.y, self.color);
    }

    pub fn update(self: *Block) void {
        self.pos.x += self.vel.x;
        self.pos.y += self.vel.y;
        self.pos.x = std.math.clamp(self.pos.x, 0, WINDOW_WIDTH - self.size.x);
        self.pos.y = std.math.clamp(self.pos.y, 0, WINDOW_HEIGHT - self.size.y);
    }

    pub fn bounce(self: *Block) void {
        const new_pos = Vec2.init(self.pos.x + self.vel.x, self.pos.y + self.vel.y);
        if (new_pos.x <= 0 or new_pos.x + self.size.x >= WINDOW_WIDTH) {
            self.vel.x = -self.vel.x;
        }

        if (new_pos.y <= 0 or new_pos.y + self.size.y >= WINDOW_HEIGHT) {
            self.vel.y = -self.vel.y;
        }
        self.update();
    }

    pub fn setVelocity(self: *Block, vx: i32, vy: i32) void {
        self.vel = Vec2.init(vx, vy);
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

const EntityType = enum { Player, Enemy, Bullet, Obstacle };
const Entity = struct {
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
    const title_pos = Vec2.init(10, 10);

    var player = Entity.init(Block.init(100, 100, 50, 50, DB16.BLACK), EntityType.Player, 100);
    var enemy = Entity.init(Block.init(200, 200, 50, 50, DB16.PINK), EntityType.Enemy, 10);
    var enemy2 = Entity.init(Block.init(300, 300, 50, 50, DB16.PINK), EntityType.Enemy, 10);

    player.block.setVelocity(2, -3);
    enemy.block.setVelocity(-2, -3);
    enemy2.block.setVelocity(3, -4);

    while (rl.windowShouldClose() == false) {
        player.block.bounce();
        enemy.block.bounce();
        enemy2.block.bounce();

        const colliding = player.block.collidesWidth(enemy.block) or player.block.collidesWidth(enemy2.block);

        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(DB16.LIGHT_BLUE);
        rl.drawRectangle(title_pos.x - 8, title_pos.y - 8, 256, 32, DB16.YELLOW);
        rl.drawText("Zig/Raylib Engine", title_pos.x, title_pos.y, 20, DB16.BLUE);

        player.block.draw();
        enemy.block.draw();
        enemy2.block.draw();

        if (colliding) {
            rl.drawText("COLLISION!", 250, 60, 32, DB16.RED);
        }
    }
}
