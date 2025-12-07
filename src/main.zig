const std = @import("std");
const rl = @import("raylib");
const WINDOW_WIDTH = 640;
const WINDOW_HEIGHT = 480;
const GRAVITY = 98.1;
const SEED = 1337;
const MUSIC_VOLUME = 0.4;

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
    color: rl.Color = rl.Color.white,
    tex: rl.Texture,
    tex2: rl.Texture,
    flying: bool = false,
    frame: i8 = 0,
    sfx: rl.Sound,

    pub fn init(x: f32, y: f32, speed: f32, tex: rl.Texture, tex2: rl.Texture, sfx: rl.Sound, flying: bool) Block {
        return .{
            .pos = Vec2.init(x, y),
            .size = IVec2.init(tex.width, tex.height),
            .speed = speed,
            .tex = tex,
            .tex2 = tex2,
            .flying = flying,
            .sfx = sfx,
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
        const t = if (self.frame > 8) self.tex2 else self.tex;
        var w: f32 = @floatFromInt(self.size.x);
        if (self.vel.x < 0) w *= -1.0;
        rl.drawTextureRec(t, .{ .x = 0, .y = 0, .width = w, .height = @floatFromInt(self.size.y) }, rl.Vector2.init(self.pos.x, self.pos.y), self.color);
    }

    pub fn update(self: *Block, dt: f32) void {
        if (!self.flying) self.vel.y += GRAVITY * dt;
        const new_pos = self.pos.add(.{ .x = self.vel.x * dt, .y = self.vel.y * dt });
        const window_w: f32 = @floatFromInt(WINDOW_WIDTH);
        const window_h: f32 = @floatFromInt(WINDOW_HEIGHT);
        const size_w: f32 = @floatFromInt(self.size.x);
        const size_h: f32 = @floatFromInt(self.size.y);
        var play_sfx = false;

        if (new_pos.x <= 0 or new_pos.x + size_w >= window_w) {
            self.vel.x = -self.vel.x;
            play_sfx = true;
        }

        if (new_pos.y <= 0 or new_pos.y + size_h >= window_h) {
            self.vel.y = -self.vel.y;
            play_sfx = true;
        }

        self.pos = self.pos.add(.{ .x = self.vel.x * dt, .y = self.vel.y * dt });
        self.pos.x = std.math.clamp(self.pos.x, 0.0, window_w - size_w);
        self.pos.y = std.math.clamp(self.pos.y, 0.0, window_h - size_h);

        if (self.flying) {
            self.vel.x *= 0.98;
            self.vel.y *= 0.98;
        }

        self.frame += 1;
        self.frame = @mod(self.frame, 16);
        if (play_sfx) rl.playSound(self.sfx);
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

pub const EntityType = enum { Player, Enemy, Pickup, Powerup };
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

fn drawProceduralSprites(camera_x: f32, ground_y: f32, defs: []const rl.Texture, tint: rl.Color, density: f32, seed: u64) void {
    var rng = std.Random.DefaultPrng.init(seed);
    const rng_rand = rng.random();
    const random = std.Random.float(rng_rand, f32);
    var x: f32 = -200;
    while (x < camera_x + WINDOW_WIDTH + 300) : (x += density + random * density) {
        const kind_roll = std.Random.float(rng_rand, f32);
        const l: f32 = @floatFromInt(defs.len);
        const def = defs[@intFromFloat(kind_roll * l)];
        const sprite_h: f32 = @floatFromInt(def.height);
        const h: f32 = kind_roll * sprite_h * 0.75;
        const y: i32 = @intFromFloat(ground_y - sprite_h + h + 12.0);
        const screen_x: i32 = @intFromFloat(x - camera_x);
        rl.drawTexture(def, screen_x, y, tint);
    }
}

pub fn main() !void {
    rl.initWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "Zig/Raylib Engine");
    defer rl.closeWindow();

    rl.initAudioDevice();
    defer rl.closeAudioDevice();

    rl.setTargetFPS(60);

    const bg_img = try rl.loadImage("assets/hd_bg_1.gif");
    const bg_texture = try rl.loadTextureFromImage(bg_img);
    defer rl.unloadImage(bg_img);
    defer rl.unloadTexture(bg_texture);

    const cloud_img = try rl.loadImage("assets/hd_cloud_1.gif");
    const cloud_texture = try rl.loadTextureFromImage(cloud_img);
    defer rl.unloadImage(cloud_img);
    defer rl.unloadTexture(cloud_texture);

    const cloud2_img = try rl.loadImage("assets/hd_cloud_2.gif");
    const cloud2_texture = try rl.loadTextureFromImage(cloud2_img);
    defer rl.unloadImage(cloud2_img);
    defer rl.unloadTexture(cloud2_texture);

    const cloud3_img = try rl.loadImage("assets/hd_cloud_3.gif");
    const cloud3_texture = try rl.loadTextureFromImage(cloud3_img);
    defer rl.unloadImage(cloud3_img);
    defer rl.unloadTexture(cloud3_texture);

    const cloud4_img = try rl.loadImage("assets/hd_cloud_4.gif");
    const cloud4_texture = try rl.loadTextureFromImage(cloud4_img);
    defer rl.unloadImage(cloud4_img);
    defer rl.unloadTexture(cloud4_texture);

    const palm_img = try rl.loadImage("assets/hd_palm_1.gif");
    const palm_texture = try rl.loadTextureFromImage(palm_img);
    defer rl.unloadImage(palm_img);
    defer rl.unloadTexture(palm_texture);

    const palm2_img = try rl.loadImage("assets/hd_tree_1.gif");
    const palm2_texture = try rl.loadTextureFromImage(palm2_img);
    defer rl.unloadImage(palm2_img);
    defer rl.unloadTexture(palm2_texture);

    const bush_img = try rl.loadImage("assets/hd_bush_1.gif");
    const bush_texture = try rl.loadTextureFromImage(bush_img);
    defer rl.unloadImage(bush_img);
    defer rl.unloadTexture(bush_texture);

    const bush2_img = try rl.loadImage("assets/hd_bush_2.gif");
    const bush2_texture = try rl.loadTextureFromImage(bush2_img);
    defer rl.unloadImage(bush2_img);
    defer rl.unloadTexture(bush2_texture);

    const flower_img = try rl.loadImage("assets/hd_flower_1.gif");
    const flower_texture = try rl.loadTextureFromImage(flower_img);
    defer rl.unloadImage(flower_img);
    defer rl.unloadTexture(flower_texture);

    const flower2_img = try rl.loadImage("assets/hd_flower_2.gif");
    const flower2_texture = try rl.loadTextureFromImage(flower2_img);
    defer rl.unloadImage(flower2_img);
    defer rl.unloadTexture(flower2_texture);

    const flower3_img = try rl.loadImage("assets/hd_flower_3.gif");
    const flower3_texture = try rl.loadTextureFromImage(flower3_img);
    defer rl.unloadImage(flower3_img);
    defer rl.unloadTexture(flower3_texture);

    const flower4_img = try rl.loadImage("assets/hd_flower_4.gif");
    const flower4_texture = try rl.loadTextureFromImage(flower4_img);
    defer rl.unloadImage(flower4_img);
    defer rl.unloadTexture(flower4_texture);

    const flower5_img = try rl.loadImage("assets/hd_flower_5.gif");
    const flower5_texture = try rl.loadTextureFromImage(flower5_img);
    defer rl.unloadImage(flower5_img);
    defer rl.unloadTexture(flower5_texture);

    const trees_defs = [_]rl.Texture{
        palm_texture,
        palm2_texture,
    };

    const plants_defs = [_]rl.Texture{
        bush_texture,
        bush2_texture,
    };

    const flowers_defs = [_]rl.Texture{
        flower_texture,
        flower2_texture,
        flower3_texture,
        flower4_texture,
        flower5_texture,
    };

    const sky_hi_defs = [_]rl.Texture{
        cloud_texture,
        cloud2_texture,
    };

    const sky_low_defs = [_]rl.Texture{
        cloud3_texture,
        cloud4_texture,
    };

    const fly_img = try rl.loadImage("assets/fly.gif");
    const fly_texture = try rl.loadTextureFromImage(fly_img);
    defer rl.unloadImage(fly_img);
    defer rl.unloadTexture(fly_texture);

    const fly2_img = try rl.loadImage("assets/fly2.gif");
    const fly2_texture = try rl.loadTextureFromImage(fly2_img);
    defer rl.unloadImage(fly2_img);
    defer rl.unloadTexture(fly2_texture);

    const fruit1_img = try rl.loadImage("assets/hd_fruit_1.gif");
    const fruit1_texture = try rl.loadTextureFromImage(fruit1_img);
    defer rl.unloadImage(fruit1_img);
    defer rl.unloadTexture(fruit1_texture);

    const fruit2_img = try rl.loadImage("assets/hd_fruit_2.gif");
    const fruit2_texture = try rl.loadTextureFromImage(fruit2_img);
    defer rl.unloadImage(fruit2_img);
    defer rl.unloadTexture(fruit2_texture);

    const fruit3_img = try rl.loadImage("assets/hd_fruit_3.gif");
    const fruit3_texture = try rl.loadTextureFromImage(fruit3_img);
    defer rl.unloadImage(fruit3_img);
    defer rl.unloadTexture(fruit3_texture);

    const sfx_music = try rl.loadMusicStream("assets/music_1.ogg");
    defer rl.unloadMusicStream(sfx_music);
    rl.setMusicVolume(sfx_music, MUSIC_VOLUME);
    rl.playMusicStream(sfx_music);

    const sfx_intro = try rl.loadSound("assets/intro.ogg");
    defer rl.unloadSound(sfx_intro);
    rl.playSound(sfx_intro);

    const sfx_bounce = try rl.loadSound("assets/bounce.ogg");
    defer rl.unloadSound(sfx_bounce);

    var player = Entity.init(Block.init(100, 100, 200.0, fly_texture, fly2_texture, sfx_bounce, true), EntityType.Player, 100);
    var enemy = Entity.init(Block.init(200, 200, 50.0, fruit1_texture, fruit1_texture, sfx_bounce, false), EntityType.Enemy, 10);
    var enemy2 = Entity.init(Block.init(300, 300, 50.0, fruit2_texture, fruit2_texture, sfx_bounce, false), EntityType.Enemy, 10);
    var enemy3 = Entity.init(Block.init(400, 200, 50.0, fruit3_texture, fruit3_texture, sfx_bounce, false), EntityType.Enemy, 10);

    enemy.block.setVelocity(-40.0, -80.0);
    enemy2.block.setVelocity(60.0, -40.0);
    enemy3.block.setVelocity(60.0, 40.0);

    while (rl.windowShouldClose() == false) {
        const dt: f32 = rl.getFrameTime();
        rl.updateMusicStream(sfx_music);

        if (rl.isKeyDown(rl.KeyboardKey.right)) player.block.addVel(Vec2.init(dt, 0.0));
        if (rl.isKeyDown(rl.KeyboardKey.left)) player.block.addVel(Vec2.init(-dt, 0.0));
        if (rl.isKeyDown(rl.KeyboardKey.up)) player.block.addVel(Vec2.init(0.0, -dt));
        if (rl.isKeyDown(rl.KeyboardKey.down)) player.block.addVel(Vec2.init(0.0, dt));

        player.block.update(dt);
        enemy.block.update(dt);
        enemy2.block.update(dt);
        enemy3.block.update(dt);

        const colliding = player.block.collidesWidth(enemy.block) or player.block.collidesWidth(enemy2.block) or player.block.collidesWidth(enemy3.block);

        rl.beginDrawing();
        defer rl.endDrawing();

        rl.drawTexture(bg_texture, 0, 0, rl.Color.white);

        drawProceduralSprites(player.block.pos.x * 0.02, 128.0, &sky_hi_defs, rl.Color.white, 128, SEED + 111);
        drawProceduralSprites(0, 256.0, &sky_low_defs, rl.Color.white, 64, SEED + 321);
        drawProceduralSprites(player.block.pos.x * 0.02, WINDOW_HEIGHT, &trees_defs, rl.Color.init(192, 192, 192, 255), 50, SEED + 1444);
        drawProceduralSprites(player.block.pos.x * 0.04, WINDOW_HEIGHT, &plants_defs, rl.Color.init(192, 192, 192, 255), 64, SEED + 333);
        drawProceduralSprites(player.block.pos.x * 0.04, WINDOW_HEIGHT, &flowers_defs, rl.Color.init(192, 192, 192, 255), 48, SEED + 988);
        player.block.draw();
        enemy.block.draw();
        enemy2.block.draw();
        enemy3.block.draw();
        drawProceduralSprites(player.block.pos.x * 0.05, WINDOW_HEIGHT, &trees_defs, rl.Color.white, 96, SEED + 3232);
        drawProceduralSprites(player.block.pos.x * 0.1, WINDOW_HEIGHT, &plants_defs, rl.Color.init(192, 192, 192, 255), 64, SEED + 123);
        drawProceduralSprites(player.block.pos.x * 0.125, WINDOW_HEIGHT, &flowers_defs, rl.Color.init(192, 192, 192, 255), 32, SEED + 1523);
        drawProceduralSprites(player.block.pos.x * 0.15, WINDOW_HEIGHT, &plants_defs, rl.Color.white, 64, SEED + 4323);
        drawProceduralSprites(player.block.pos.x * 0.1, 64.0, &sky_hi_defs, rl.Color.white, 96, SEED + 123);

        rl.drawRectangle(2, 2, 38, 32, DB16.YELLOW);
        var fps_buffer: [32]u8 = undefined;
        const fps_text = std.fmt.bufPrintZ(&fps_buffer, "{d}", .{rl.getFPS()}) catch "0";
        rl.drawText(fps_text, 8, 8, 20, DB16.BLACK);

        rl.drawRectangle(50, 2, player.health * 5, 32, DB16.WHITE);
        var health_buffer: [32]u8 = undefined;
        const health_text = std.fmt.bufPrintZ(&health_buffer, "{d}", .{player.health}) catch "0";
        rl.drawText(health_text, 54, 8, 20, DB16.BLACK);

        if (colliding) {
            player.health -= 1;
            if (player.health <= 0) {
                player.block.pos = Vec2.init(WINDOW_WIDTH / 2, WINDOW_HEIGHT / 2);
                player.health = 100;
            }
        }
    }
}
