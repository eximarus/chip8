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

    assert(sdl.SDL_Init(sdl.SDL_INIT_VIDEO | sdl.SDL_INIT_AUDIO) >= 0);
    defer sdl.SDL_Quit();

    const window = sdl.SDL_CreateWindow("chip8", // window title
        sdl.SDL_WINDOWPOS_UNDEFINED, // initial x position
        sdl.SDL_WINDOWPOS_UNDEFINED, // initial y position
        SCREEN_WIDTH * display_scale, // width, in pixels
        SCREEN_HEIGHT * display_scale, // height, in pixels
        sdl.SDL_WINDOW_SHOWN // flags
    );
    defer sdl.SDL_DestroyWindow(window);
    assert(window != null);

    const renderer = sdl.SDL_CreateRenderer(window, -1, sdl.SDL_RENDERER_PRESENTVSYNC);
    defer sdl.SDL_DestroyRenderer(renderer);
    assert(renderer != null);

    var last_ticks = sdl.SDL_GetTicks();
    var last_delta: u32 = 0;
    var step_delta: u32 = 0;
    var render_delta: u32 = 0;

    mainloop: while (true) {
        var sdlEvent: sdl.SDL_Event = undefined;
        while (sdl.SDL_PollEvent(&sdlEvent) != 0) {
            switch (sdlEvent.type) {
                sdl.SDL_QUIT => break :mainloop,
                sdl.SDL_KEYDOWN, sdl.SDL_KEYUP => try input.handleKey(&cpu, sdlEvent.type, sdlEvent.key.keysym.sym),
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
                _ = sdl.SDL_SetRenderDrawColor(renderer, 0, 0, 0, 0xFF);
                _ = sdl.SDL_RenderClear(renderer);
                for (0..SCREEN_HEIGHT) |y| {
                    for (0..SCREEN_WIDTH) |x| {
                        const addr = y * @as(usize, SCREEN_WIDTH) + x;
                        if (cpu.gfx[addr] == 0) {
                            continue;
                        }
                        _ = sdl.SDL_SetRenderDrawColor(renderer, 0xFF, 0xFF, 0xFF, 0xFF);
                        const block = sdl.SDL_Rect{
                            .x = @as(i32, @intCast(x)) * display_scale,
                            .y = @as(i32, @intCast(y)) * display_scale,
                            .h = display_scale,
                            .w = display_scale,
                        };
                        _ = sdl.SDL_RenderDrawRect(renderer, &block);
                        _ = sdl.SDL_RenderFillRect(renderer, &block);
                    }
                }

                sdl.SDL_RenderPresent(renderer);
                cpu.drawFlag = false;
                render_delta -= (1000 / 60);
            }
        }
    }
}

// ensure all imported files have their tests run
test {
    std.testing.refAllDecls(@This());
}
