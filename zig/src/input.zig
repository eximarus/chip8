const chip8 = @import("chip8.zig");
const sdl = @import("sdl.zig");
const std = @import("std");

pub const InputError = error{
    UnknownAction,
};

pub fn handleKey(cpu: *chip8.Cpu, action: sdl.EventType, key: sdl.Keycode) InputError!void {
    var keyValue: u8 = undefined;
    if (action == .keydown) {
        keyValue = 1;
    } else if (action == .keyup) {
        keyValue = 0;
    } else {
        return InputError.UnknownAction;
    }

    const keycode: u8 = switch (key) {
        .@"1" => 0x1,
        .@"2" => 0x2,
        .@"3" => 0x3,
        .@"4" => 0xC,
        .q => 0x4,
        .w => 0x5,
        .e => 0x6,
        .r => 0xD,
        .a => 0x7,
        .s => 0x8,
        .d => 0x9,
        .f => 0xE,
        .z => 0xA,
        .x => 0x0,
        .c => 0xB,
        .v => 0xF,
        else => return,
    };
    cpu.key[keycode] = keyValue;
}

test "handleKey" {
    var cpu = chip8.Cpu{};
    chip8.initialize(&cpu);
    try std.testing.expectError(InputError.UnknownAction, handleKey(&cpu, 99, .@"1"));
    try std.testing.expectEqual(@as(u8, 0), cpu.key[0x1]);

    try handleKey(&cpu, sdl.SDL_KEYDOWN, .@"1");
    try std.testing.expectEqual(@as(u8, 1), cpu.key[0x1]);

    try handleKey(&cpu, sdl.SDL_KEYUP, .@"1");
    try std.testing.expectEqual(@as(u8, 0), cpu.key[0x1]);
}
