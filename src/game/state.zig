const std = @import("std");
const rl = @import("raylib");
const Math = @import("../engine/math.zig");
const Entity = @import("../engine/entity.zig").Entity;
const Engine = @import("../engine/core.zig").Engine;
const Sprites = @import("../engine/sprites.zig").Sprites;
const Parallax = @import("../engine/parallax.zig");
const palette = @import("../palette.zig");

const Vec2 = Math.Vec2;
const DB16 = palette.DB16;

const WINDOW_WIDTH = 800;
const WINDOW_HEIGHT = 600;
const MUSIC_VOLUME = 0.4;

pub const GameState = struct {
    // --- Resources ---
    sprites: Sprites,
    sfx_bounce: rl.Sound,
    music: rl.Music,
    jingle: rl.Sound,

    clouds_low_tex: [2]rl.Texture,
    clouds_high_tex: [2]rl.Texture,
    trees_tex: [7]rl.Texture,
    bushes_tex: [4]rl.Texture,
    flowers_tex: [5]rl.Texture,

    // Texture slices for entities
    player_frames: [2]rl.Texture,
    fruit_frames: [3]rl.Texture,

    // ── Game objects ──
    player: Entity,
    enemies: [3]Entity,

    // ── Parallax layers ──
    layer_clouds_low: Parallax.ParallaxLayer,
    layer_clouds_low2: Parallax.ParallaxLayer,
    layer_clouds_high: Parallax.ParallaxLayer,
    layer_clouds_high2: Parallax.ParallaxLayer,
    layer_trees: Parallax.ParallaxLayer,
    layer_trees_near: Parallax.ParallaxLayer,
    layer_bushes: Parallax.ParallaxLayer,
    layer_bushes_near: Parallax.ParallaxLayer,
    layer_flowers: Parallax.ParallaxLayer,
    layer_flowers_mid: Parallax.ParallaxLayer,
    layer_flowers_near: Parallax.ParallaxLayer,

    pub const config = .{
        .width = WINDOW_WIDTH,
        .height = WINDOW_HEIGHT,
        .title = "Fly vs Fruits - Raylib/Zig Engine",
        .target_fps = 60,
    };

    pub fn init() !GameState {
        var self: GameState = undefined;
        self.sprites = try Sprites.load();

        self.sfx_bounce = try rl.loadSound("assets/bounce.ogg");
        self.music = try rl.loadMusicStream("assets/music_1.ogg");
        self.jingle = try rl.loadSound("assets/intro.ogg");
        rl.setMusicVolume(self.music, MUSIC_VOLUME);
        rl.playMusicStream(self.music);
        rl.playSound(self.jingle);

        self.player_frames = [_]rl.Texture{
            self.sprites.get(.fly1),
            self.sprites.get(.fly2),
        };
        self.player = Entity.init(
            .Player,
            WINDOW_WIDTH / 2,
            WINDOW_HEIGHT / 2,
            48.0,
            &self.player_frames,
            0.08,
            self.sfx_bounce,
            true, // flying
        );

        self.fruit_frames = [_]rl.Texture{
            self.sprites.get(.fruit1),
            self.sprites.get(.fruit2),
            self.sprites.get(.fruit3),
        };
        self.enemies = [3]Entity{
            Entity.init(.Enemy, 300, 150, 60.0, &self.fruit_frames, 0.2, self.sfx_bounce, false),
            Entity.init(.Enemy, 500, 300, 50.0, &self.fruit_frames, 0.2, self.sfx_bounce, false),
            Entity.init(.Enemy, 700, 200, 70.0, &self.fruit_frames, 0.2, self.sfx_bounce, false),
        };
        self.enemies[0].setVelocity(-50, -70);
        self.enemies[1].setVelocity(60, -30);
        self.enemies[2].setVelocity(40, 50);

        self.clouds_low_tex = [_]rl.Texture{ self.sprites.get(.cloud3), self.sprites.get(.cloud4) };
        self.clouds_high_tex = [_]rl.Texture{ self.sprites.get(.cloud1), self.sprites.get(.cloud2) };
        self.trees_tex = [_]rl.Texture{ self.sprites.get(.tree1), self.sprites.get(.tree2), self.sprites.get(.tree3), self.sprites.get(.tree4), self.sprites.get(.tree5), self.sprites.get(.bush5), self.sprites.get(.bush6) };
        self.bushes_tex = [_]rl.Texture{ self.sprites.get(.bush1), self.sprites.get(.bush2), self.sprites.get(.bush3), self.sprites.get(.bush4) };
        self.flowers_tex = [_]rl.Texture{ self.sprites.get(.flower1), self.sprites.get(.flower2), self.sprites.get(.flower3), self.sprites.get(.flower4), self.sprites.get(.flower5) };

        self.layer_clouds_low = Parallax.make(&self.clouds_low_tex, 0.02, 200, 180, rl.Color.white, 1);
        self.layer_clouds_low2 = Parallax.make(&self.clouds_low_tex, 0.05, 240, 220, rl.Color.white, 2);
        self.layer_clouds_high = Parallax.make(&self.clouds_high_tex, 0.10, 100, 300, rl.Color.white, 3);
        self.layer_clouds_high2 = Parallax.make(&self.clouds_high_tex, 0.12, 120, 340, rl.Color.white, 4);

        self.layer_trees = Parallax.make(&self.trees_tex, 0.05, WINDOW_HEIGHT - 64, 128, rl.Color.init(192, 192, 210, 255), 5);
        self.layer_trees_near = Parallax.make(&self.trees_tex, 0.20, WINDOW_HEIGHT - 32, 200, rl.Color.white, 6);
        self.layer_bushes = Parallax.make(&self.bushes_tex, 0.10, WINDOW_HEIGHT - 32, 80, rl.Color.init(180, 180, 200, 255), 7);
        self.layer_bushes_near = Parallax.make(&self.bushes_tex, 0.30, WINDOW_HEIGHT, 64, rl.Color.white, 8);
        self.layer_flowers = Parallax.make(&self.flowers_tex, 0.15, WINDOW_HEIGHT - 48, 128, rl.Color.init(200, 220, 200, 255), 9);
        self.layer_flowers_mid = Parallax.make(&self.flowers_tex, 0.25, WINDOW_HEIGHT - 32, 96, rl.Color.white, 10);
        self.layer_flowers_near = Parallax.make(&self.flowers_tex, 0.40, WINDOW_HEIGHT, 200, rl.Color.white, 11);
        return self;
    }

    pub fn deinit(self: *GameState) void {
        rl.unloadSound(self.sfx_bounce);
        rl.unloadSound(self.jingle);
        rl.unloadMusicStream(self.music);
        self.sprites.deinit();
    }

    pub fn update(self: *GameState, dt: f32) void {
        rl.updateMusicStream(self.music);
        const input = Vec2.init(
            if (rl.isKeyDown(rl.KeyboardKey.right)) dt * self.player.speed else if (rl.isKeyDown(rl.KeyboardKey.left)) -dt * self.player.speed else 0,
            if (rl.isKeyDown(rl.KeyboardKey.down)) dt * self.player.speed else if (rl.isKeyDown(rl.KeyboardKey.up)) -dt * self.player.speed else 0,
        );
        self.player.addVel(input);
        self.player.update(dt);
        for (&self.enemies) |*e| e.update(dt);
        for (self.enemies) |e| {
            if (self.player.collidesWidth(e)) {
                self.player.health -= 1;
                if (self.player.health <= 0) {
                    self.player.health = 100;
                    self.player.pos = Vec2.init(WINDOW_WIDTH / 2, WINDOW_HEIGHT / 2);
                    rl.playSound(self.sfx_bounce);
                }
            }
        }
    }

    pub fn render(self: *GameState) void {
        const camera_x = self.player.pos.x - WINDOW_WIDTH / 2.0;

        rl.beginDrawing();
        defer rl.endDrawing();

        // --- Background ---
        rl.drawTexture(self.sprites.get(.bg2), 0, 0, rl.Color.white);

        // --- Background parallax ---
        self.layer_clouds_low.draw(camera_x);
        self.layer_clouds_low2.draw(camera_x);
        self.layer_trees.draw(camera_x);
        self.layer_bushes.draw(camera_x);
        self.layer_flowers.draw(camera_x);
        self.layer_trees_near.draw(camera_x);

        // --- Entities ---
        self.player.draw();
        for (self.enemies) |e| e.draw();

        // --- Foreground parallax ---
        self.layer_flowers_mid.draw(camera_x);
        self.layer_bushes_near.draw(camera_x);
        self.layer_flowers_near.draw(camera_x);
        self.layer_clouds_high.draw(camera_x);
        self.layer_clouds_high2.draw(camera_x);

        // --- UI ----------------------
        rl.drawRectangle(2, 2, 96, 32, DB16.YELLOW);
        const fps = rl.getFPS();
        var fps_buffer: [16]u8 = undefined;
        const fps_text = std.fmt.bufPrintZ(&fps_buffer, "FPS: {d}", .{fps}) catch "FPS: ?";
        rl.drawText(fps_text, 8, 8, 20, DB16.BLACK);

        rl.drawRectangle(150, 8, self.player.health * 3, 24, DB16.LIGHT_RED);
        rl.drawText("HP", 160, 10, 20, DB16.WHITE);
    }
};
