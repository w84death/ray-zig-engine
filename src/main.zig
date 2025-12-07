const std = @import("std");
const rl = @import("raylib");
const ArrayList = std.ArrayList;

const WINDOW_WIDTH = 640;
const WINDOW_HEIGHT = 480;
const GRAVITY = 98.1;
const SEED = 87654;
const MUSIC_VOLUME = 0.4;
const MAX_SPRITES_PER_LAYER = 256;

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

const ParallaxSprite = struct {
    x: f32,
    y: f32,
    tex_index: u8,
    tint: rl.Color,
};

const ParallaxLayer = struct {
    sprites: [MAX_SPRITES_PER_LAYER]ParallaxSprite,
    count: usize,
    parallax: f32,
    textures: []const rl.Texture,

    pub fn draw(self: *const ParallaxLayer, camera_x: f32) void {
        const offset_x = camera_x * self.parallax;
        var i: usize = 0;
        while (i < self.count) : (i += 1) {
            const spr = self.sprites[i];
            const screen_x = spr.x - offset_x;
            if (screen_x > -400 and screen_x < WINDOW_WIDTH + 400) {
                const tex = self.textures[spr.tex_index];
                rl.drawTexture(tex, @intFromFloat(screen_x), @intFromFloat(spr.y), spr.tint);
            }
        }
    }
};

fn fillLayer(
    layer: *ParallaxLayer,
    ground_y: f32,
    base_density: f32,
    tint: rl.Color,
    seed_offset: u64,
    world_width: f32,
) void {
    var rng = std.Random.DefaultPrng.init(SEED + seed_offset);
    const rand = rng.random();

    var x: f32 = -500;
    var idx: usize = 0;

    while (x < world_width + 500 and idx < MAX_SPRITES_PER_LAYER) : ({
        x += base_density + rand.float(f32) * base_density * 0.7;
        idx += 1;
    }) {
        const tex_idx = rand.uintLessThan(u8, @as(u8, @intCast(layer.textures.len)));
        const tex = layer.textures[tex_idx];
        const h_offset = rand.float(f32) * @as(f32, @floatFromInt(tex.height)) * 0.6;
        const y = ground_y - @as(f32, @floatFromInt(tex.height)) + h_offset;

        layer.sprites[idx] = ParallaxSprite{
            .x = x,
            .y = y,
            .tex_index = tex_idx,
            .tint = tint,
        };
    }
    layer.count = idx;
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

    const tree_img = try rl.loadImage("assets/hd_palm_1.gif");
    const tree_texture = try rl.loadTextureFromImage(tree_img);
    defer rl.unloadImage(tree_img);
    defer rl.unloadTexture(tree_texture);

    const tree2_img = try rl.loadImage("assets/hd_tree_1.gif");
    const tree2_texture = try rl.loadTextureFromImage(tree2_img);
    defer rl.unloadImage(tree2_img);
    defer rl.unloadTexture(tree2_texture);

    const tree3_img = try rl.loadImage("assets/hd_tree_3.gif");
    const tree3_texture = try rl.loadTextureFromImage(tree3_img);
    defer rl.unloadImage(tree3_img);
    defer rl.unloadTexture(tree3_texture);

    const tree4_img = try rl.loadImage("assets/hd_tree_4.gif");
    const tree4_texture = try rl.loadTextureFromImage(tree4_img);
    defer rl.unloadImage(tree4_img);
    defer rl.unloadTexture(tree4_texture);

    const tree5_img = try rl.loadImage("assets/hd_tree_5.gif");
    const tree5_texture = try rl.loadTextureFromImage(tree5_img);
    defer rl.unloadImage(tree5_img);
    defer rl.unloadTexture(tree5_texture);

    const bush_img = try rl.loadImage("assets/hd_bush_1.gif");
    const bush_texture = try rl.loadTextureFromImage(bush_img);
    defer rl.unloadImage(bush_img);
    defer rl.unloadTexture(bush_texture);

    const bush2_img = try rl.loadImage("assets/hd_bush_2.gif");
    const bush2_texture = try rl.loadTextureFromImage(bush2_img);
    defer rl.unloadImage(bush2_img);
    defer rl.unloadTexture(bush2_texture);

    const bush3_img = try rl.loadImage("assets/hd_bush_3.gif");
    const bush3_texture = try rl.loadTextureFromImage(bush3_img);
    defer rl.unloadImage(bush3_img);
    defer rl.unloadTexture(bush3_texture);

    const bush4_img = try rl.loadImage("assets/hd_bush_4.gif");
    const bush4_texture = try rl.loadTextureFromImage(bush4_img);
    defer rl.unloadImage(bush4_img);
    defer rl.unloadTexture(bush4_texture);

    const bush5_img = try rl.loadImage("assets/hd_bush_5.gif");
    const bush5_texture = try rl.loadTextureFromImage(bush5_img);
    defer rl.unloadImage(bush5_img);
    defer rl.unloadTexture(bush5_texture);

    const bush6_img = try rl.loadImage("assets/hd_bush_6.gif");
    const bush6_texture = try rl.loadTextureFromImage(bush6_img);
    defer rl.unloadImage(bush6_img);
    defer rl.unloadTexture(bush6_texture);

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

    const trees_defs = [_]rl.Texture{
        tree_texture,
        tree2_texture,
        tree3_texture,
        tree4_texture,
        tree5_texture,
        bush5_texture,
        bush6_texture,
    };

    const plants_defs = [_]rl.Texture{
        bush_texture,
        bush2_texture,
        bush3_texture,
        bush4_texture,
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

    var layer1 = ParallaxLayer{ .sprites = undefined, .count = 0, .parallax = 0.02, .textures = &sky_hi_defs };
    var layer2 = ParallaxLayer{ .sprites = undefined, .count = 0, .parallax = 0.05, .textures = &sky_hi_defs };
    var layer3 = ParallaxLayer{ .sprites = undefined, .count = 0, .parallax = 0.08, .textures = &sky_low_defs };
    var layer4 = ParallaxLayer{ .sprites = undefined, .count = 0, .parallax = 0.10, .textures = &sky_low_defs };
    var layer5 = ParallaxLayer{ .sprites = undefined, .count = 0, .parallax = 0.30, .textures = &trees_defs };
    var layer6 = ParallaxLayer{ .sprites = undefined, .count = 0, .parallax = 0.50, .textures = &trees_defs };
    var layer7 = ParallaxLayer{ .sprites = undefined, .count = 0, .parallax = 0.60, .textures = &plants_defs };
    var layer8 = ParallaxLayer{ .sprites = undefined, .count = 0, .parallax = 0.80, .textures = &plants_defs };
    var layer9 = ParallaxLayer{ .sprites = undefined, .count = 0, .parallax = 0.90, .textures = &flowers_defs };
    var layer10 = ParallaxLayer{ .sprites = undefined, .count = 0, .parallax = 1.00, .textures = &flowers_defs };

    const WORLD_WIDTH = 12000.0;

    fillLayer(&layer1, 100, 180, rl.Color.white, 111, WORLD_WIDTH);
    fillLayer(&layer2, 140, 220, rl.Color.init(255, 255, 255, 180), 112, WORLD_WIDTH);
    fillLayer(&layer3, 200, 300, rl.Color.white, 321, WORLD_WIDTH);
    fillLayer(&layer4, 240, 340, rl.Color.init(255, 255, 255, 200), 322, WORLD_WIDTH);
    fillLayer(&layer5, WINDOW_HEIGHT, 120, rl.Color.init(220, 220, 230, 255), 1444, WORLD_WIDTH);
    fillLayer(&layer6, WINDOW_HEIGHT, 180, rl.Color.init(180, 180, 200, 255), 3232, WORLD_WIDTH);
    fillLayer(&layer7, WINDOW_HEIGHT, 80, rl.Color.init(200, 220, 200, 255), 333, WORLD_WIDTH);
    fillLayer(&layer8, WINDOW_HEIGHT, 100, rl.Color.white, 123, WORLD_WIDTH);
    fillLayer(&layer9, WINDOW_HEIGHT, 60, rl.Color.init(255, 255, 220, 240), 988, WORLD_WIDTH);
    fillLayer(&layer10, WINDOW_HEIGHT, 50, rl.Color.init(255, 240, 255, 220), 1523, WORLD_WIDTH);

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
        const camera_x = player.block.pos.x - WINDOW_WIDTH / 2.0;

        rl.beginDrawing();
        defer rl.endDrawing();

        rl.drawTexture(bg_texture, 0, 0, rl.Color.white);

        layer1.draw(camera_x);
        layer2.draw(camera_x);
        layer3.draw(camera_x);
        layer4.draw(camera_x);
        layer5.draw(camera_x);
        player.block.draw();
        enemy.block.draw();
        enemy2.block.draw();
        enemy3.block.draw();
        layer6.draw(camera_x);
        layer7.draw(camera_x);
        layer8.draw(camera_x);
        layer9.draw(camera_x);
        layer10.draw(camera_x);

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
