pub const CellType = enum {
    Empty,
    Wall,
    Floor,
    Floor2,
};

pub const Cell = struct {
    x: i16,
    y: i16,
    kind: CellType = CellType.Empty,
};

pub const Terrain = struct {
    cell_size: i16 = 16,
    cells: [TERRAIN_WIDTH * TERRAIN_HEIGHT]Cell = undefined,

    pub fn init() Terrain {
        const w: usize = @intCast(TERRAIN_WIDTH);
        const h: usize = @intCast(TERRAIN_HEIGHT);
        const size = w * h;
        var cells: [size]Cell = undefined;
        for (cells[0..size], 0..size) |*cell, i| {
            const x = i % w;
            const y = i / h;
            var kind: CellType = if (i % 2 == 0 or i % 3 == 0) CellType.Floor else CellType.Floor2;
            if (i <= w or i % w == 0) kind = CellType.Wall;
            cell.* = .{ .x = @intCast(x), .y = @intCast(y), .kind = kind };
        }
        return .{
            .cells = cells,
        };
    }

    pub fn draw(self: Terrain) void {
        for (self.cells) |cell| {
            if (cell.x * self.cell_size >= WINDOW_WIDTH or cell.y * self.cell_size >= WINDOW_HEIGHT) continue;
            switch (cell.kind) {
                CellType.Empty => continue,
                CellType.Wall => rl.drawRectangle(cell.x * self.cell_size, cell.y * self.cell_size, self.cell_size, self.cell_size, DB16.DARK_GRAY),
                CellType.Floor => rl.drawRectangle(cell.x * self.cell_size, cell.y * self.cell_size, self.cell_size, self.cell_size, DB16.DARK_GREEN),
                CellType.Floor2 => rl.drawRectangle(cell.x * self.cell_size, cell.y * self.cell_size, self.cell_size, self.cell_size, DB16.GREEN),
            }
        }
    }
};
