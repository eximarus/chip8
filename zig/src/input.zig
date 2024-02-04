const chip8 = @import("chip8.zig");
const sdl = @import("sdl.zig");
const std = @import("std");

pub const InputError = error{
    UnknownAction,
};

pub fn handleKey(cpu: *chip8.Cpu, action: sdl.SDL_EventType, key: sdl.SDL_Keycode) InputError!void {
    var keyValue: u8 = undefined;
    if (action == sdl.SDL_KEYDOWN) {
        keyValue = 1;
    } else if (action == sdl.SDL_KEYUP) {
        keyValue = 0;
    } else {
        return InputError.UnknownAction;
    }

    const keycode: u8 = switch (key) {
        sdl.SDLK_1 => 0x1,
        sdl.SDLK_2 => 0x2,
        sdl.SDLK_3 => 0x3,
        sdl.SDLK_4 => 0xC,
        sdl.SDLK_q => 0x4,
        sdl.SDLK_w => 0x5,
        sdl.SDLK_e => 0x6,
        sdl.SDLK_r => 0xD,
        sdl.SDLK_a => 0x7,
        sdl.SDLK_s => 0x8,
        sdl.SDLK_d => 0x9,
        sdl.SDLK_f => 0xE,
        sdl.SDLK_z => 0xA,
        sdl.SDLK_x => 0x0,
        sdl.SDLK_c => 0xB,
        sdl.SDLK_v => 0xF,
        else => return,
    };
    cpu.key[keycode] = keyValue;
}

test "handleKey" {
    var cpu = chip8.Cpu{};
    chip8.initialize(&cpu);
    try std.testing.expectError(InputError.UnknownAction, handleKey(&cpu, 99, sdl.SDLK_1));
    try std.testing.expectEqual(@as(u8, 0), cpu.key[0x1]);

    try handleKey(&cpu, sdl.SDL_KEYDOWN, sdl.SDLK_1);
    try std.testing.expectEqual(@as(u8, 1), cpu.key[0x1]);

    try handleKey(&cpu, sdl.SDL_KEYUP, sdl.SDLK_1);
    try std.testing.expectEqual(@as(u8, 0), cpu.key[0x1]);
}
