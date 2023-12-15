const std = @import("std");
const sdl = @cImport(@cInclude("SDL2/SDL.h"));

const SCREEN_WIDTH = 384;
const SCREEN_HEIGHT = 216;
const MAP_SIZE = 8;

const MAPDATA: [MAP_SIZE * MAP_SIZE]u8 = &.{
    1, 1, 1, 1, 1, 1, 1, 1,
    1, 0, 0, 0, 0, 0, 0, 1,
    1, 0, 0, 0, 0, 3, 0, 1,
    1, 0, 0, 0, 0, 0, 0, 1,
    1, 0, 2, 0, 4, 4, 0, 1,
    1, 0, 0, 0, 4, 0, 0, 1,
    1, 0, 3, 0, 0, 0, 0, 1,
    1, 1, 1, 1, 1, 1, 1, 1,
};

fn Vec2(comptime T: type) type {
    return struct {
        x: T,
        y: T,
        const Self = @This();

        pub fn init(x: T, y: T) Self {
            return Self{ .x = x, .y = y };
        }
        pub fn initVec(vector: Self) Self {
            return Self{ .x = vector.x, .y = vector.y };
        }
        pub fn dot(self: *Self, other: Self) T {
            return (self.x * other.x) + (self.y * other.y);
        }
        pub fn len(self: *Self) T {
            return @sqrt(self.dot(self.*));
        }
        pub fn normalize(self: *Self) Self {
            const l = self.len();
            return Self{
                .x = self.x / l,
                .y = self.y / l,
            };
        }
    };
}

const State = struct {
    window: ?*sdl.SDL_Window = null,
    texture: ?*sdl.SDL_Texture = null,
    renderer: ?*sdl.SDL_Renderer = null,
    pixels: [SCREEN_HEIGHT * SCREEN_WIDTH]u32 = [_]u32{0} ** (SCREEN_HEIGHT * SCREEN_WIDTH),
    quit: bool = false,
    pos: Vec2(f32) = undefined,
    dir: Vec2(f32) = undefined,
    plane: Vec2(f32) = undefined,
};

var state: State = State{};

fn render() !void {
    for (0..SCREEN_WIDTH) |x| {
        const xcam: f32 = (2 * @divExact(@as(f32, @floatFromInt(x)), SCREEN_WIDTH)) - 1;

        const dir: Vec2(f32) = .{
            .x = state.dir.x + state.plane.x * xcam,
            .y = state.dir.y + state.plane.y * xcam,
        };
        const pos = state.pos;
        var iPos: Vec2(i32) = .{
            .x = @as(i32, @intFromFloat(pos.x)),
            .y = @as(i32, @intFromFloat(pos.y)),
        };

        const deltaDist: Vec2(f32) = .{
            .x = if (@as(f32, @floatFromInt(try std.math.absInt(@as(i32, @intFromFloat(pos.x))))) < 1e-20)
                1e30
            else
                @as(f32, @floatFromInt(try std.math.absInt(@as(i32, @intFromFloat(1.0 / dir.x))))),
            .y = if (@as(f32, @floatFromInt(try std.math.absInt(@as(i32, @intFromFloat(pos.y))))) < 1e-20)
                1e30
            else
                @as(f32, @floatFromInt(try std.math.absInt(@as(i32, @intFromFloat(1.0 / dir.y))))),
        };
        var sideDist: Vec2(f32) = .{
            .x = deltaDist.x * (if (dir.x < 0)
                pos.x - @as(f32, @floatFromInt(iPos.x))
            else
                @as(f32, @floatFromInt(iPos.x)) + 1 - pos.x),
            .y = deltaDist.y * (if (dir.y < 0)
                pos.y - @as(f32, @floatFromInt(iPos.y))
            else
                @as(f32, @floatFromInt(iPos.y)) + 1 - pos.y),
        };
        const step: Vec2(i32) = .{
            .x = @as(i32, std.math.sign(@as(i32, @intFromFloat(dir.x)))),
            .y = @as(i32, std.math.sign(@as(i32, @intFromFloat(dir.y)))),
        };
        var hit: struct { val: i32, side: i32, pos: Vec2(f32) } = .{
            .val = 0,
            .side = 0,
            .pos = .{ .x = 0.0, .y = 0.0 },
        };

        while (hit.val != 0) {
            if (sideDist.x < sideDist.y) {
                sideDist.x += deltaDist.x;
                iPos.x += step.x;
                hit.side = 0;
            } else {
                sideDist.y += deltaDist.y;
                iPos.y += step.y;
                hit.side = 1;
            }
            std.debug.assert(iPos.x >= 0 and
                iPos.x < MAP_SIZE and
                iPos.y >= 0 and
                iPos.y < MAP_SIZE);
        }

        var color: u32 = switch (hit.val) {
            1 => 0xFF0000FF,
            2 => 0xFF00FF00,
            3 => 0xFFFF0000,
            4 => 0xFFFF00FF,
            else => undefined,
        };
        if (hit.side == 1) {
            const blueRed: u32 = ((color & 0xFF00FF) * 0xC0) >> 8;
            const green: u32 = ((color & 0x00FF00) * 0xC0) >> 8;

            color = 0xFF000000 | (blueRed & 0xFF00FF) | (green & 0x00FF00);
        }
        hit.pos = .{
            .x = pos.x + sideDist.x,
            .y = pos.y + sideDist.y,
        };
        const distance: f32 = if (hit.side == 0)
            sideDist.x - deltaDist.x
        else
            sideDist.y - deltaDist.y;

        const sh = @as(f32, SCREEN_HEIGHT);
        std.debug.print("sh {} dist {}\n", .{ sh, distance });
        const h: i32 = @intFromFloat(@divFloor(sh, distance));
        const y0: i32 = @intCast(@max((SCREEN_HEIGHT / 2) - @divFloor(h, 2), 0));
        const y1: i32 = @intCast(@min((SCREEN_HEIGHT / 2) + @divFloor(h, 2), SCREEN_HEIGHT));
        verticalLine(x, 0, y0, 0xFF202020);
        verticalLine(x, y0, y1, color);
        verticalLine(x, y1, SCREEN_HEIGHT - 1, 0xFF505050);
    }
}
fn verticalLine(x: usize, y0: i32, y1: i32, color: u32) void {
    var i = @min(y0, y1);
    const lim = @max(y0, y1) - 1;
    std.debug.print("x {} y0 {} y1 {} i {} lim {} color: {x:08}\n", .{
        x,
        y0,
        y1,
        i,
        lim,
        color,
    });
    while (i < lim) : (i += 1)
        state.pixels[(@as(usize, @intCast(i)) * SCREEN_WIDTH) + x] = color;
}
fn rotate(rotation: f32) void {
    const d = Vec2(f32).initVec(state.dir);
    const p = Vec2(f32).initVec(state.plane);
    state.dir.x = d.x * @cos(rotation) - d.y * @sin(rotation);
    state.dir.y = d.x * @sin(rotation) + d.y * @cos(rotation);
    state.plane.x = p.x * @cos(rotation) - p.y * @sin(rotation);
    state.plane.y = p.x * @sin(rotation) + p.y * @cos(rotation);
}

pub fn initWindow() !void {
    _ = sdl.SDL_Init(sdl.SDL_INIT_VIDEO);
    state.window = sdl.SDL_CreateWindow(
        "DEMO",
        sdl.SDL_WINDOWPOS_CENTERED_DISPLAY(0),
        sdl.SDL_WINDOWPOS_CENTERED_DISPLAY(0),
        1280,
        720,
        sdl.SDL_WINDOW_ALLOW_HIGHDPI,
    );
    defer sdl.SDL_DestroyWindow(state.window.?);
    if (state.window == null) {
        std.debug.print("Failed to created SDL window: {s}\n", .{sdl.SDL_GetError()});
        std.process.exit(1);
    }
    state.renderer = sdl.SDL_CreateRenderer(
        state.window,
        -1,
        sdl.SDL_RENDERER_PRESENTVSYNC,
    );
    defer sdl.SDL_DestroyRenderer(state.renderer);
    if (state.window == null) {
        std.debug.print("Failed to created SDL renderer: {s}\n", .{sdl.SDL_GetError()});
        std.process.exit(1);
    }
    state.texture = sdl.SDL_CreateTexture(
        state.renderer,
        sdl.SDL_PIXELFORMAT_ABGR8888,
        sdl.SDL_TEXTUREACCESS_STREAMING,
        SCREEN_WIDTH,
        SCREEN_HEIGHT,
    );
    defer sdl.SDL_DestroyTexture(state.texture);

    if (state.texture == null) {
        std.debug.print("Failed to created SDL texture: {s}\n", .{sdl.SDL_GetError()});
        std.process.exit(1);
    }

    var unit = Vec2(f32).init(-1.0, 0.1);
    state.pos = Vec2(f32).init(2, 2);
    state.dir = unit.normalize();
    state.plane = .{ .x = 0.0, .y = 0.66 };

    while (!state.quit) {
        var ev: sdl.SDL_Event = undefined;
        while (sdl.SDL_PollEvent(&ev) != 0) {
            switch (ev.type) {
                sdl.SDL_QUIT => {
                    state.quit = true;
                    break;
                },
                else => continue,
            }
        }

        const rotSpeed = 3.0 * 0.016;
        const moveSpeed = 3.0 * 0.016;

        const keyState = sdl.SDL_GetKeyboardState(null);
        if (keyState[sdl.SDL_SCANCODE_LEFT] == 1)
            rotate(rotSpeed);
        if (keyState[sdl.SDL_SCANCODE_RIGHT] == 1)
            rotate(-rotSpeed);
        if (keyState[sdl.SDL_SCANCODE_UP] == 1) {
            state.pos.x += state.dir.x * moveSpeed;
            state.pos.y += state.dir.y * moveSpeed;
        }
        if (keyState[sdl.SDL_SCANCODE_DOWN] == 1) {
            state.pos.x -= state.dir.x * moveSpeed;
            state.pos.y -= state.dir.y * moveSpeed;
        }

        @memset(&state.pixels, 0);
        try render();

        _ = sdl.SDL_UpdateTexture(
            state.texture,
            null,
            &state.pixels,
            SCREEN_WIDTH * 4,
        );
        _ = sdl.SDL_RenderCopyEx(
            state.renderer,
            state.texture,
            null,
            null,
            0.0,
            null,
            sdl.SDL_FLIP_VERTICAL,
        );
        sdl.SDL_RenderPresent(state.renderer);
    }
}
test "initwindow" {
    try initWindow();
}
