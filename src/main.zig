const std = @import("std");
const rl = @import("raylib");

const WINDOW_WIDTH = 800;
const WINDOW_HEIGHT = 600;
const GRAVITY = 98.1;
const SEED = 87654;
const MUSIC_VOLUME = 0.4;
const MAX_SPRITES_PER_LAYER = 64;
const WORLD_WIDTH = 1200.0;

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

// pub const Vec2 = rl.Vector2;
pub const Vec2 = struct {
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

pub const EntityType = enum { Player, Enemy, Pickup, Powerup };
pub const Entity = struct {
    kind: EntityType,
    pos: Vec2,
    size: IVec2,
    vel: Vec2 = Vec2.init(0, 0),
    max_vel: f32 = 250.0,
    speed: f32 = 0.0,
    color: rl.Color = rl.Color.white,
    health: i16 = 100,

    frames: []const rl.Texture,
    frame_count: usize = 0,
    current_frame: usize = 0,
    frame_timer: f32 = 0.0,
    frame_duration: f32 = 0.1,

    flying: bool = false,
    sfx: rl.Sound,

    pub fn init(kind: EntityType, x: f32, y: f32, speed: f32, frames: []const rl.Texture, frame_duration: f32, sfx: rl.Sound, flying: bool) Entity {
        return .{
            .kind = kind,
            .pos = Vec2.init(x, y),
            .size = IVec2{ .x = frames[0].width, .y = frames[0].height },
            .speed = speed,
            .frames = frames,
            .frame_count = frames.len,
            .frame_duration = frame_duration,
            .sfx = sfx,
            .flying = flying,
        };
    }

    pub fn getRect(self: Entity) struct { x: i32, y: i32, w: i32, h: i32 } {
        return .{
            .x = @intFromFloat(self.pos.x),
            .y = @intFromFloat(self.pos.y),
            .w = self.size.x,
            .h = self.size.y,
        };
    }

    pub fn update(self: *Entity, dt: f32) void {
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

        self.updateAnimation(dt);
        if (play_sfx) rl.playSound(self.sfx);
    }

    pub fn updateAnimation(self: *Entity, dt: f32) void {
        if (self.frame_count <= 1) return;
        self.frame_timer += dt;
        if (self.frame_timer >= self.frame_duration) {
            self.frame_timer -= self.frame_duration;
            self.current_frame = (self.current_frame + 1) % self.frame_count;
        }
    }

    pub fn draw(self: Entity) void {
        const tex = self.frames[self.current_frame];
        var w: f32 = @floatFromInt(tex.width);
        const h: f32 = @floatFromInt(tex.height);
        if (self.vel.x < 0) w *= -1.0;
        rl.drawTextureRec(tex, .{ .x = 0, .y = 0, .width = w, .height = h }, rl.Vector2.init(self.pos.x, self.pos.y), self.color);
    }

    pub fn setVelocity(self: *Entity, vx: f32, vy: f32) void {
        self.vel = Vec2.init(vx, vy);
    }

    pub fn addVel(self: *Entity, vel: Vec2) void {
        self.vel = self.vel.add(Vec2.init(vel.x * self.speed, vel.y * self.speed));
        self.vel = self.vel.clamp(-self.max_vel, self.max_vel);
    }

    pub fn collidesWidth(self: Entity, other: Entity) bool {
        const a = self.getRect();
        const b = other.getRect();
        return a.x < b.x + b.w and
            a.x + a.w > b.x and
            a.y < b.y + b.h and
            a.y + a.h > b.y;
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

pub const TextureList = struct {
    pub const paths = [_][:0]const u8{
        "assets/hd_bg_1.gif",
        "assets/hd_bg_2.gif",
        "assets/hd_cloud_1.gif",
        "assets/hd_cloud_2.gif",
        "assets/hd_cloud_3.gif",
        "assets/hd_cloud_4.gif",
        "assets/hd_palm_1.gif",
        "assets/hd_tree_1.gif",
        "assets/hd_tree_2.gif",
        "assets/hd_tree_3.gif",
        "assets/hd_tree_4.gif",
        "assets/hd_tree_5.gif",
        "assets/hd_bush_1.gif",
        "assets/hd_bush_2.gif",
        "assets/hd_bush_3.gif",
        "assets/hd_bush_4.gif",
        "assets/hd_bush_5.gif",
        "assets/hd_bush_6.gif",
        "assets/hd_flower_1.gif",
        "assets/hd_flower_2.gif",
        "assets/hd_flower_3.gif",
        "assets/hd_flower_4.gif",
        "assets/hd_flower_5.gif",
        "assets/fly.gif",
        "assets/fly2.gif",
        "assets/hd_fruit_1.gif",
        "assets/hd_fruit_2.gif",
        "assets/hd_fruit_3.gif",
    };

    pub const count = paths.len;
    pub const Id = enum {
        bg1,
        bg2,
        cloud1,
        cloud2,
        cloud3,
        cloud4,
        palm,
        tree1,
        tree2,
        tree3,
        tree4,
        tree5,
        bush1,
        bush2,
        bush3,
        bush4,
        bush5,
        bush6,
        flower1,
        flower2,
        flower3,
        flower4,
        flower5,
        fly1,
        fly2,
        fruit1,
        fruit2,
        fruit3,
    };
};

pub const Sprites = struct {
    textures: [TextureList.count]rl.Texture = undefined,

    pub fn load() !Sprites {
        var s: Sprites = .{};
        inline for (TextureList.paths, 0..) |path, i| {
            s.textures[i] = try rl.loadTexture(path);
        }
        return s;
    }

    pub fn get(self: Sprites, id: TextureList.Id) rl.Texture {
        return self.textures[@intFromEnum(id)];
    }

    pub fn deinit(self: *Sprites) void {
        for (&self.textures) |*tex| {
            if (tex.id != 0) {
                rl.unloadTexture(tex.*);
            }
        }
    }
};

pub fn makeParallaxLayer(
    textures: []const rl.Texture,
    parallax: f32,
    ground_y: f32,
    density: f32,
    tint: rl.Color,
    seed_offset: u64,
) ParallaxLayer {
    var layer = ParallaxLayer{
        .sprites = undefined,
        .count = 0,
        .parallax = parallax,
        .textures = textures,
    };
    fillLayer(&layer, ground_y, density, tint, seed_offset, WORLD_WIDTH);
    return layer;
}

pub fn main() !void {
    // ── Init Window ──────────────────
    rl.initWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "Zig/Raylib Engine");
    defer rl.closeWindow();
    rl.setTargetFPS(60);

    // ── Init Audio ───────────────────
    rl.initAudioDevice();
    defer rl.closeAudioDevice();

    // ── Load Sprites ─────────────────
    var spr = try Sprites.load();
    defer spr.deinit();

    // ── Clouds ─────────────────────────────────────
    const sky_hi_defs = [_]rl.Texture{
        spr.get(.cloud1),
        spr.get(.cloud2),
    };
    const sky_low_defs = [_]rl.Texture{
        spr.get(.cloud3),
        spr.get(.cloud4),
    };
    var layer_clouds_low = makeParallaxLayer(&sky_low_defs, 0.02, 200, 180, rl.Color.white, 111);
    var layer_clouds_low2 = makeParallaxLayer(&sky_low_defs, 0.05, 240, 220, rl.Color.white, 112);
    var layer_clouds_high = makeParallaxLayer(&sky_hi_defs, 0.10, 100, 300, rl.Color.white, 321);
    var layer_clouds_high2 = makeParallaxLayer(&sky_hi_defs, 0.12, 120, 340, rl.Color.white, 322);

    // ── Trees ──────────────────────────────────────
    const trees_defs = [_]rl.Texture{
        spr.get(.tree1),
        spr.get(.tree2),
        spr.get(.tree3),
        spr.get(.tree4),
        spr.get(.tree5),
        spr.get(.bush5),
        spr.get(.bush6),
    };
    var layer_tree = makeParallaxLayer(&trees_defs, 0.05, WINDOW_HEIGHT - 32, 128, rl.Color.init(192, 192, 210, 255), 1414);
    var layer_tree2 = makeParallaxLayer(&trees_defs, 0.20, WINDOW_HEIGHT, 200, rl.Color.white, 148);

    // ── Bushes ─────────────────────────────────────
    const bushes_defs = [_]rl.Texture{
        spr.get(.bush1),
        spr.get(.bush2),
        spr.get(.bush3),
        spr.get(.bush4),
    };
    var layer_bush = makeParallaxLayer(&bushes_defs, 0.10, WINDOW_HEIGHT - 24, 80, rl.Color.init(180, 180, 200, 255), 1314);
    var layer_bush2 = makeParallaxLayer(&bushes_defs, 0.30, WINDOW_HEIGHT, 64, rl.Color.white, 984);

    // ── Flowers ──────────────────────
    const flowers_defs = [_]rl.Texture{
        spr.get(.flower1),
        spr.get(.flower2),
        spr.get(.flower3),
        spr.get(.flower4),
        spr.get(.flower5),
    };
    var layer_flower = makeParallaxLayer(&flowers_defs, 0.15, WINDOW_HEIGHT - 32, 128, rl.Color.init(200, 220, 200, 255), 988);
    var layer_flower2 = makeParallaxLayer(&flowers_defs, 0.25, WINDOW_HEIGHT - 32, 96, rl.Color.white, 153);
    var layer_flower3 = makeParallaxLayer(&flowers_defs, 0.40, WINDOW_HEIGHT, 200, rl.Color.white, 999);

    // ── SFX ----──────────────────────
    const sfx_bounce = try rl.loadSound("assets/bounce.ogg");
    defer rl.unloadSound(sfx_bounce);

    // ── Player -──────────────────────
    const fly_anim = [_]rl.Texture{ spr.get(.fly1), spr.get(.fly2) };
    var player = Entity.init(EntityType.Player, 100, 100, 200.0, &fly_anim, 0.08, sfx_bounce, true);

    // --- Fruits ----------------------
    const fruit_anim = [_]rl.Texture{ spr.get(.fruit1), spr.get(.fruit2), spr.get(.fruit3) };
    var enemy = Entity.init(EntityType.Enemy, 200, 200, 50.0, &fruit_anim, 0.2, sfx_bounce, false);
    var enemy2 = Entity.init(EntityType.Enemy, 300, 300, 50.0, &fruit_anim, 0.2, sfx_bounce, false);
    var enemy3 = Entity.init(EntityType.Enemy, 400, 200, 50.0, &fruit_anim, 0.2, sfx_bounce, false);
    enemy.setVelocity(-40.0, -80.0);
    enemy2.setVelocity(60.0, -40.0);
    enemy3.setVelocity(60.0, 40.0);

    // ── Music ─────────────────────---
    const sfx_music = try rl.loadMusicStream("assets/music_1.ogg");
    defer rl.unloadMusicStream(sfx_music);
    rl.setMusicVolume(sfx_music, MUSIC_VOLUME);
    rl.playMusicStream(sfx_music);

    // ── Jingle -──────────────────────
    const sfx_intro = try rl.loadSound("assets/intro.ogg");
    defer rl.unloadSound(sfx_intro);
    rl.playSound(sfx_intro);

    // ── Render & Logic Loop -─────────
    while (rl.windowShouldClose() == false) {
        const dt: f32 = rl.getFrameTime();
        rl.updateMusicStream(sfx_music);

        if (rl.isKeyDown(rl.KeyboardKey.right)) player.addVel(Vec2.init(dt, 0.0));
        if (rl.isKeyDown(rl.KeyboardKey.left)) player.addVel(Vec2.init(-dt, 0.0));
        if (rl.isKeyDown(rl.KeyboardKey.up)) player.addVel(Vec2.init(0.0, -dt));
        if (rl.isKeyDown(rl.KeyboardKey.down)) player.addVel(Vec2.init(0.0, dt));

        player.update(dt);
        const camera_x = player.pos.x - WINDOW_WIDTH / 2.0;

        enemy.update(dt);
        enemy2.update(dt);
        enemy3.update(dt);

        const colliding = player.collidesWidth(enemy) or player.collidesWidth(enemy2) or player.collidesWidth(enemy3);
        if (colliding) {
            player.health -= 1;
            if (player.health <= 0) {
                player.pos = Vec2.init(WINDOW_WIDTH / 2, WINDOW_HEIGHT / 2);
                player.health = 100;
            }
        }

        // --- Rendering ---------------
        rl.beginDrawing();
        defer rl.endDrawing();

        // --- Game Assets -------------
        rl.drawTexture(spr.get(.bg2), 0, 0, rl.Color.white);
        layer_clouds_low.draw(camera_x);
        layer_clouds_low2.draw(camera_x);
        layer_tree.draw(camera_x);
        layer_bush.draw(camera_x);
        layer_flower.draw(camera_x);
        layer_tree2.draw(camera_x);
        player.draw();
        enemy.draw();
        enemy2.draw();
        enemy3.draw();
        layer_flower2.draw(camera_x);
        layer_bush2.draw(camera_x);
        layer_flower3.draw(camera_x);
        layer_clouds_high.draw(camera_x);
        layer_clouds_high2.draw(camera_x);

        // --- UI ----------------------
        rl.drawRectangle(2, 2, 38, 32, DB16.YELLOW);
        var fps_buffer: [32]u8 = undefined;
        const fps_text = std.fmt.bufPrintZ(&fps_buffer, "{d}", .{rl.getFPS()}) catch "0";
        rl.drawText(fps_text, 8, 8, 20, DB16.BLACK);

        rl.drawRectangle(50, 2, player.health * 5, 32, DB16.WHITE);
        var health_buffer: [32]u8 = undefined;
        const health_text = std.fmt.bufPrintZ(&health_buffer, "{d}", .{player.health}) catch "0";
        rl.drawText(health_text, 54, 8, 20, DB16.BLACK);
    }
}
