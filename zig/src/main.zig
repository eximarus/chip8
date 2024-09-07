const std = @import("std");
const chip8 = @import("chip8.zig");
const c = @cImport({
    @cInclude("SDL2/SDL.h");
});

const display_height = chip8.display_height;
const display_width = chip8.display_width;

var display_scale: i32 = 10;

pub fn main() !void {
    var buf: [512]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buf);
    const allocator = fba.allocator();

    var iter = try std.process.argsWithAllocator(allocator);
    defer iter.deinit();
    _ = iter.skip();

    const timestamp = @as(u64, @intCast(std.time.timestamp()));
    var pcg = std.rand.Pcg.init(timestamp);
    const rng = pcg.random();

    var cpu = chip8.Cpu.init(rng);
    try cpu.loadRom(iter.next().?);

    std.debug.assert(c.SDL_Init(c.SDL_INIT_VIDEO | c.SDL_INIT_AUDIO) >= 0);
    defer c.SDL_Quit();

    const window = c.SDL_CreateWindow("chip8", // window title
        c.SDL_WINDOWPOS_UNDEFINED, // initial x position
        c.SDL_WINDOWPOS_UNDEFINED, // initial y position
        display_width * display_scale, // width, in pixels
        display_height * display_scale, // height, in pixels
        c.SDL_WINDOW_SHOWN // flags
    ).?;
    defer c.SDL_DestroyWindow(window);

    const renderer = c.SDL_CreateRenderer(window, -1, c.SDL_RENDERER_PRESENTVSYNC).?;
    defer c.SDL_DestroyRenderer(renderer);

    const framebuffer = c.SDL_CreateTexture(
        renderer,
        c.SDL_PIXELFORMAT_RGBA8888,
        c.SDL_TEXTUREACCESS_STREAMING,
        display_width,
        display_height,
    ).?;
    defer c.SDL_DestroyTexture(framebuffer);

    var last_ticks = c.SDL_GetTicks();
    var last_delta: u32 = 0;
    var step_delta: u32 = 0;
    var render_delta: u32 = 0;

    mainloop: while (true) {
        var sdl_event: c.SDL_Event = undefined;
        while (c.SDL_PollEvent(&sdl_event) != 0) {
            switch (sdl_event.type) {
                c.SDL_QUIT => break :mainloop,
                c.SDL_KEYDOWN => handleKey(&cpu, 1, sdl_event.key.keysym.sym),
                c.SDL_KEYUP => handleKey(&cpu, 0, sdl_event.key.keysym.sym),
                else => {},
            }
        }
        last_delta = c.SDL_GetTicks() - last_ticks;
        last_ticks = c.SDL_GetTicks();

        step_delta += last_delta;
        render_delta += last_delta;

        while (step_delta >= 1) {
            cpu.cycle();
            step_delta -= 1;
        }

        if (cpu.draw_flag and render_delta >= (1000 / 60)) {
            cpu.updateTimers();
            var pixels: [display_width * display_height]u32 = undefined;

            for (0..display_height) |y| {
                for (0..display_width) |x| {
                    const addr = y * @as(usize, display_width) + x;
                    if (cpu.fb[addr] == 0) {
                        pixels[addr] = 0x000000FF;
                    } else {
                        pixels[addr] = 0xFFFFFFFF;
                    }
                }
            }

            _ = c.SDL_UpdateTexture(
                framebuffer,
                null,
                &pixels,
                display_width * @sizeOf(u32),
            );
            _ = c.SDL_RenderClear(renderer);
            _ = c.SDL_RenderCopy(renderer, framebuffer, null, null);
            c.SDL_RenderPresent(renderer);

            cpu.draw_flag = false;
            render_delta = 0;
        }
    }
}

pub fn handleKey(cpu: *chip8.Cpu, key_value: u8, key: c.SDL_Keycode) void {
    const keycode: u8 = switch (key) {
        c.SDLK_1 => 0x1,
        c.SDLK_2 => 0x2,
        c.SDLK_3 => 0x3,
        c.SDLK_4 => 0xC,
        c.SDLK_q => 0x4,
        c.SDLK_w => 0x5,
        c.SDLK_e => 0x6,
        c.SDLK_r => 0xD,
        c.SDLK_a => 0x7,
        c.SDLK_s => 0x8,
        c.SDLK_d => 0x9,
        c.SDLK_f => 0xE,
        c.SDLK_z => 0xA,
        c.SDLK_x => 0x0,
        c.SDLK_c => 0xB,
        c.SDLK_v => 0xF,
        else => return,
    };
    cpu.key[keycode] = key_value;
}

// ensure all imported files have their tests run
test {
    std.testing.refAllDecls(@This());
}
