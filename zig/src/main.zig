const std = @import("std");
const input = @import("input.zig");
const chip8 = @import("chip8.zig");
const graphics = @import("graphics.zig");
const SCREEN_HEIGHT = graphics.SCREEN_HEIGHT;
const SCREEN_WIDTH = graphics.SCREEN_WIDTH;
var display_scale: i32 = 10;
const sdl = @import("sdl.zig");
const assert = std.debug.assert;

var cpu = chip8.Cpu{};
pub fn main() anyerror!void {
    var general_purpose_allocator = std.heap.GeneralPurposeAllocator(.{}){};
    const gpa = general_purpose_allocator.allocator();
    const args = try std.process.argsAlloc(gpa);
    defer std.process.argsFree(gpa, args);
    assert(args.len > 1);

    chip8.initialize(&cpu);
    try chip8.loadApplication(&cpu, args[1]);

    try sdl.init(.{ .audio = true, .video = true });
    errdefer sdl.quit();

    const window = try sdl.Window.create("chip8", // window title
        sdl.Window.pos_undefined, // initial x position
        sdl.Window.pos_undefined, // initial y position
        SCREEN_WIDTH * display_scale, // width, in pixels
        SCREEN_HEIGHT * display_scale, // height, in pixels
        .{ .shown = true } // flags
    );
    defer window.destroy();

    const renderer = try sdl.Renderer.create(window, -1, .{ .present_vsync = true });
    defer renderer.destroy();

    var last_ticks = sdl.SDL_GetTicks();
    var last_delta: u32 = 0;
    var step_delta: u32 = 0;
    var render_delta: u32 = 0;

    mainloop: while (true) {
        var sdlEvent: sdl.Event = undefined;
        while (sdl.pollEvent(&sdlEvent)) {
            switch (sdlEvent.type) {
                .quit => break :mainloop,
                .keydown, .keyup => try input.handleKey(&cpu, sdlEvent.type, sdlEvent.key.keysym.sym),
                else => {},
            }
        }
        last_delta = sdl.SDL_GetTicks() - last_ticks;
        last_ticks = sdl.SDL_GetTicks();

        step_delta += last_delta;
        render_delta += last_delta;

        while (step_delta >= 1) {
            chip8.emulateCycle(&cpu);
            step_delta -= 1;
        }

        if (cpu.drawFlag) {
            while (render_delta >= (1000 / 60)) {
                try renderer.setDrawColor(.{ 0, 0, 0, 0xFF });
                try renderer.clear();
                for (0..SCREEN_HEIGHT) |y| {
                    for (0..SCREEN_WIDTH) |x| {
                        const addr = @as(i32, y) * SCREEN_WIDTH + @as(i32, x);
                        if (cpu.gfx[addr] == 0) {
                            continue;
                        }
                        try renderer.setDrawColor(.{ 0xFF, 0xFF, 0xFF, 0xFF });
                        const block = sdl.Rect{
                            .x = x * display_scale,
                            .y = y * display_scale,
                            .h = display_scale,
                            .w = display_scale,
                        };
                        try renderer.drawRect(&block);
                        try renderer.fillRect(&block);
                    }
                    renderer.present();

                    render_delta -= (1000 / 60);
                }
                cpu.drawFlag = false;
            }
        }
    }
}

// ensure all imported files have their tests run
test {
    std.testing.refAllDecls(@This());
}
