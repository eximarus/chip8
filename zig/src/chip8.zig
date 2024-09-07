const std = @import("std");

pub const display_width: i32 = 64;
pub const display_height: i32 = 32;

const memory_size = 4096;
const app_memory_offset = 0x200;
const max_rom_size = memory_size - app_memory_offset;

const fontset = [_]u8{
    0xF0, 0x90, 0x90, 0x90, 0xF0, // 0
    0x20, 0x60, 0x20, 0x20, 0x70, // 1
    0xF0, 0x10, 0xF0, 0x80, 0xF0, // 2
    0xF0, 0x10, 0xF0, 0x10, 0xF0, // 3
    0x90, 0x90, 0xF0, 0x10, 0x10, // 4
    0xF0, 0x80, 0xF0, 0x10, 0xF0, // 5
    0xF0, 0x80, 0xF0, 0x90, 0xF0, // 6
    0xF0, 0x10, 0x20, 0x40, 0x40, // 7
    0xF0, 0x90, 0xF0, 0x90, 0xF0, // 8
    0xF0, 0x90, 0xF0, 0x10, 0xF0, // 9
    0xF0, 0x90, 0xF0, 0x90, 0x90, // A
    0xE0, 0x90, 0xE0, 0x90, 0xE0, // B
    0xF0, 0x80, 0x80, 0x80, 0xF0, // C
    0xE0, 0x90, 0x90, 0x90, 0xE0, // D
    0xF0, 0x80, 0xF0, 0x80, 0xF0, // E
    0xF0, 0x80, 0xF0, 0x80, 0x80, // F
};

const Instr align(8) = packed union {
    opcode: u16,
    nib: packed struct(u16) {
        n: u4,
        y: u4,
        x: u4,
        c: u4,
    } align(4),
    kk: u8 align(1),
    nnn: u12 align(1),
};

test Instr {
    try std.testing.expectEqual(16, @bitSizeOf(Instr));

    const instr = Instr{ .opcode = 0x4321 };
    try std.testing.expectEqual(0x4321, instr.opcode);
    try std.testing.expectEqual(0x4, instr.nib.c);
    try std.testing.expectEqual(0x3, instr.nib.x);
    try std.testing.expectEqual(0x2, instr.nib.y);
    try std.testing.expectEqual(0x1, instr.nib.n);
    try std.testing.expectEqual(0x21, instr.kk);
    try std.testing.expectEqual(0x321, instr.nnn);
}

pub const Cpu = struct {
    mem: [memory_size]u8 = fontset ++ [_]u8{0} ** (memory_size - fontset.len),

    v: [16]u8,
    i: u12,
    dt: u8,
    st: u8,

    pc: u12 = app_memory_offset,
    sp: u12,

    stack: [16]u12,
    key: [16]u8,
    fb: [display_width * display_height]u32,

    draw_flag: bool,
    rng: std.rand.Random,

    pub inline fn init(rng: std.rand.Random) Cpu {
        return std.mem.zeroInit(Cpu, .{ .rng = rng });
    }

    pub fn loadRom(self: *Cpu, file_name: []const u8) !void {
        const f = try std.fs.openFileAbsolute(file_name, .{});
        defer f.close();

        _ = try f.read(self.mem[app_memory_offset..]);

        if (try f.read(@constCast(&[_]u8{0})) != 0) {
            return error.RomTooBig;
        }
    }

    pub fn cycle(self: *Cpu) void {
        // fetch
        const instr = Instr{
            .opcode = @as(u16, self.mem[self.pc]) << 8 | self.mem[self.pc + 1],
        };

        // execute
        switch (instr.nib.c) {
            0x0 => switch (instr.kk) {
                0xE0 => self.cls(),
                0xEE => self.ret(),
                else => {
                    std.log.err("Unknown opcode: 0x{X}", .{instr.opcode});
                },
            },
            0x1 => self.@"jp addr"(instr.nnn),
            0x2 => self.@"call addr"(instr.nnn),
            0x3 => self.@"se Vx, byte"(instr.nib.x, instr.kk),
            0x4 => self.@"sne Vx, byte"(instr.nib.x, instr.kk),
            0x5 => self.@"se Vx, Vy"(instr.nib.x, instr.nib.y),
            0x6 => self.@"ld Vx, byte"(instr.nib.x, instr.kk),
            0x7 => self.@"add Vx, byte"(instr.nib.x, instr.kk),
            0x8 => switch (instr.nib.n) {
                0x0 => self.@"ld Vx, Vy"(instr.nib.x, instr.nib.y),
                0x1 => self.@"or Vx, Vy"(instr.nib.x, instr.nib.y),
                0x2 => self.@"and Vx, Vy"(instr.nib.x, instr.nib.y),
                0x3 => self.@"xor Vx, Vy"(instr.nib.x, instr.nib.y),
                0x4 => self.@"add Vx, Vy"(instr.nib.x, instr.nib.y),
                0x5 => self.@"sub Vx, Vy"(instr.nib.x, instr.nib.y),
                0x6 => self.@"shr Vx, {, Vy}"(instr.nib.x, instr.nib.y),
                0x7 => self.@"subn Vx, Vy"(instr.nib.x, instr.nib.y),
                0xE => self.@"shl Vx {,Vy}"(instr.nib.x, instr.nib.y),
                else => {
                    std.log.err("Unknown opcode: 0x{X}", .{instr.opcode});
                },
            },
            0x9 => self.@"sne Vx, Vy"(instr.nib.x, instr.nib.y),
            0xA => self.@"ld I, addr"(instr.nnn),
            0xB => self.@"jp V0, addr"(instr.nnn),
            0xC => self.@"rnd Vx, byte"(instr.nib.x, instr.kk),
            0xD => self.@"drw Vx, Vy, byte"(instr.nib.x, instr.nib.y, instr.nib.n),
            0xE => switch (instr.kk) {
                0x9E => self.@"skp Vx"(instr.nib.x),
                0xA1 => self.@"sknp Vx"(instr.nib.x),
                else => {
                    std.log.err("Unknown opcode: 0x{X}", .{instr.opcode});
                },
            },
            0xF => switch (instr.kk) {
                0x07 => self.@"ld Vx, DT"(instr.nib.x),
                0x0A => self.@"ld Vx, K"(instr.nib.x),
                0x15 => self.@"ld DT, Vx"(instr.nib.x),
                0x18 => self.@"ld ST, Vx"(instr.nib.x),
                0x1E => self.@"add I, Vx"(instr.nib.x),
                0x29 => self.@"ld F, Vx"(instr.nib.x),
                0x33 => self.@"ld B, Vx"(instr.nib.x),
                0x55 => self.@"ld [I], Vx"(instr.nib.x),
                0x65 => self.@"ld Vx [I]"(instr.nib.x),
                else => {
                    std.log.err("Unknown opcode: 0x{X}", .{instr.opcode});
                },
            },
        }
    }

    pub fn updateTimers(self: *Cpu) void {
        if (self.dt > 0) {
            self.dt -= 1;
        }

        if (self.st > 0) {
            if (self.st == 1) {
                std.log.info("BEEP", .{});
            }
            self.st -= 1;
        }
    }

    inline fn testRng() std.rand.Random {
        if (!@import("builtin").is_test) {
            @compileError("Cannot use testRng outside of test block");
        }
        var pcg = std.rand.Pcg.init(0);
        return pcg.random();
    }

    // 00E0
    inline fn cls(self: *Cpu) void {
        @memset(&self.fb, 0);
        self.draw_flag = true;
        self.pc += 2;
    }

    test cls {
        var cpu = Cpu.init(testRng());
        cpu.cls();

        for (cpu.fb, 0..) |_, i| {
            try std.testing.expectEqual(@as(u32, @intCast(0)), cpu.fb[i]);
        }
        try std.testing.expectEqual(true, cpu.draw_flag);
        try std.testing.expectEqual(@as(u12, @intCast(app_memory_offset + 2)), cpu.pc);
    }

    // 00EE
    inline fn ret(self: *Cpu) void {
        self.sp -= 1;
        self.pc = self.stack[self.sp];
        self.pc += 2;
    }

    test ret {
        var cpu = Cpu.init(testRng());
        cpu.@"call addr"(0x123);
        cpu.ret();
        try std.testing.expectEqual(@as(u12, @intCast(0)), cpu.sp);
        try std.testing.expectEqual(@as(u12, @intCast(app_memory_offset + 2)), cpu.pc);
    }

    // 1NNN
    inline fn @"jp addr"(self: *Cpu, addr: u12) void {
        self.pc = addr;
    }

    test @"jp addr" {
        const addr = 0x123;
        var cpu = Cpu.init(testRng());
        cpu.@"jp addr"(addr);
        try std.testing.expectEqual(@as(u12, @intCast(addr)), cpu.pc);
    }

    // 2NNN
    inline fn @"call addr"(self: *Cpu, addr: u12) void {
        self.stack[self.sp] = self.pc;
        self.sp += 1;
        self.pc = addr;
    }

    test @"call addr" {
        const addr = 0x123;
        var cpu = Cpu.init(testRng());
        cpu.@"call addr"(addr);
        try std.testing.expectEqual(@as(u12, @intCast(app_memory_offset)), cpu.stack[0]);
        try std.testing.expectEqual(@as(u12, @intCast(1)), cpu.sp);
        try std.testing.expectEqual(@as(u12, @intCast(addr)), cpu.pc);
    }

    // 3XKK
    inline fn @"se Vx, byte"(self: *Cpu, x: u4, byte: u8) void {
        if (self.v[x] == byte) {
            self.pc += 4;
        } else {
            self.pc += 2;
        }
    }

    test @"se Vx, byte" {
        const x = 1;
        const kk = 0x23;
        var cpu = Cpu.init(testRng());
        cpu.@"se Vx, byte"(x, kk);
        try std.testing.expectEqual(@as(u12, @intCast(app_memory_offset + 2)), cpu.pc);

        cpu.v[x] = kk;
        cpu.@"se Vx, byte"(x, kk);
        try std.testing.expectEqual(@as(u12, @intCast(app_memory_offset + 6)), cpu.pc);
    }

    // 4XKK
    inline fn @"sne Vx, byte"(self: *Cpu, x: u4, byte: u8) void {
        if (self.v[x] != byte) {
            self.pc += 4;
        } else {
            self.pc += 2;
        }
    }

    test @"sne Vx, byte" {
        const x = 1;
        const kk = 0x23;
        var cpu = Cpu.init(testRng());
        cpu.@"sne Vx, byte"(x, kk);
        try std.testing.expectEqual(@as(u12, @intCast(app_memory_offset + 4)), cpu.pc);

        cpu.v[x] = kk;
        cpu.@"sne Vx, byte"(x, kk);
        try std.testing.expectEqual(@as(u12, @intCast(app_memory_offset + 6)), cpu.pc);
    }

    // 5XY0
    inline fn @"se Vx, Vy"(self: *Cpu, x: u4, y: u4) void {
        if (self.v[x] == self.v[y]) {
            self.pc += 4;
        } else {
            self.pc += 2;
        }
    }

    test @"se Vx, Vy" {
        const x = 1;
        const y = 2;

        var cpu = Cpu.init(testRng());
        cpu.v[1] = 69;
        cpu.v[2] = 69;
        cpu.@"se Vx, Vy"(x, y);
        try std.testing.expectEqual(@as(u12, @intCast(app_memory_offset + 4)), cpu.pc);

        cpu.v[2] = 105;
        cpu.@"se Vx, Vy"(x, y);
        try std.testing.expectEqual(@as(u12, @intCast(app_memory_offset + 6)), cpu.pc);
    }

    // 6XKK
    inline fn @"ld Vx, byte"(self: *Cpu, x: u4, byte: u8) void {
        self.v[x] = byte;
        self.pc += 2;
    }

    test @"ld Vx, byte" {
        const x = 1;
        const kk = 69;
        var cpu = Cpu.init(testRng());
        cpu.@"ld Vx, byte"(x, kk);
        try std.testing.expectEqual(@as(u12, @intCast(app_memory_offset + 2)), cpu.pc);
        try std.testing.expectEqual(kk, cpu.v[x]);
    }

    // 7XKK
    inline fn @"add Vx, byte"(self: *Cpu, x: u4, byte: u8) void {
        const result, _ = @addWithOverflow(self.v[x], byte);
        self.v[x] = result;
        self.pc += 2;
    }

    test @"add Vx, byte" {
        const x1 = 0;
        const kk1 = 17;
        var cpu = Cpu.init(testRng());
        cpu.@"add Vx, byte"(x1, kk1);
        try std.testing.expectEqual(kk1, cpu.v[x1]);
        try std.testing.expectEqual(@as(u12, @intCast(app_memory_offset + 2)), cpu.pc);

        cpu.@"add Vx, byte"(x1, kk1);
        try std.testing.expectEqual(kk1 * 2, cpu.v[x1]);
        try std.testing.expectEqual(@as(u12, @intCast(app_memory_offset + 4)), cpu.pc);
    }

    // 8XY0
    inline fn @"ld Vx, Vy"(self: *Cpu, x: u4, y: u4) void {
        self.v[x] = self.v[y];
        self.pc += 2;
    }

    test @"ld Vx, Vy" {
        var cpu = Cpu.init(testRng());
        const x = 2;
        const y = 1;
        const testValue = 25;

        cpu.v[1] = testValue;
        cpu.v[2] = 0;
        cpu.@"ld Vx, Vy"(x, y);

        try std.testing.expectEqual(testValue, cpu.v[x]);
        try std.testing.expectEqual(@as(u12, @intCast(app_memory_offset + 2)), cpu.pc);
    }

    // 8XY1
    inline fn @"or Vx, Vy"(self: *Cpu, x: u4, y: u4) void {
        self.v[x] |= self.v[y];
        self.pc += 2;
    }

    test @"or Vx, Vy" {
        var cpu = Cpu.init(testRng());
        const x = 2;
        const y = 1;
        cpu.v[1] = 0b0000_1111;
        cpu.v[2] = 0b1111_0000;
        cpu.@"or Vx, Vy"(x, y);
        try std.testing.expectEqual(@as(u8, @intCast(0b1111_1111)), cpu.v[x]);
        try std.testing.expectEqual(@as(u12, @intCast(app_memory_offset + 2)), cpu.pc);
    }

    // 8XY2
    inline fn @"and Vx, Vy"(self: *Cpu, x: u4, y: u4) void {
        self.v[x] &= self.v[y];
        self.pc += 2;
    }

    test @"and Vx, Vy" {
        var cpu = Cpu.init(testRng());
        const x = 2;
        const y = 1;
        cpu.v[1] = 0b0001_0111;
        cpu.v[2] = 0b1111_1000;
        cpu.@"and Vx, Vy"(x, y);
        try std.testing.expectEqual(@as(u8, @intCast(0b0001_0000)), cpu.v[x]);
        try std.testing.expectEqual(@as(u12, @intCast(app_memory_offset + 2)), cpu.pc);
    }

    // 8XY3
    inline fn @"xor Vx, Vy"(self: *Cpu, x: u4, y: u4) void {
        self.v[x] ^= self.v[y];
        self.pc += 2;
    }

    test @"xor Vx, Vy" {
        var cpu = Cpu.init(testRng());

        const x = 2;
        const y = 1;
        cpu.v[1] = 0b0001_0111;
        cpu.v[2] = 0b1111_1000;
        cpu.@"xor Vx, Vy"(x, y);
        try std.testing.expectEqual(@as(u8, @intCast(0b1110_1111)), cpu.v[x]);
        try std.testing.expectEqual(@as(u12, @intCast(app_memory_offset + 2)), cpu.pc);
    }

    // 8XY4
    inline fn @"add Vx, Vy"(self: *Cpu, x: u4, y: u4) void {
        if (self.v[y] > (0xFF - self.v[x])) {
            self.v[0xF] = 1; // carry
        } else {
            self.v[0xF] = 0;
        }
        self.v[x] += self.v[y];
        self.pc += 2;
    }

    test @"add Vx, Vy" {
        var cpu = Cpu.init(testRng());
        const x = 2;
        const y = 1;
        cpu.v[1] = 69;
        cpu.v[2] = 105;
        cpu.@"add Vx, Vy"(x, y);
        try std.testing.expectEqual(@as(u8, @intCast(0)), cpu.v[0xF]);
        try std.testing.expectEqual(@as(u8, @intCast(174)), cpu.v[x]);
        try std.testing.expectEqual(@as(u12, @intCast(app_memory_offset + 2)), cpu.pc);
    }

    // 8XY5
    inline fn @"sub Vx, Vy"(self: *Cpu, x: u4, y: u4) void {
        const vy = self.v[y];
        const vx = self.v[x];

        if (vy > vx) {
            self.v[0xF] = 0; // borrow
        } else {
            self.v[0xF] = 1;
        }
        const result, _ = @subWithOverflow(vx, vy);
        self.v[x] = result;
        self.pc += 2;
    }

    test @"sub Vx, Vy" {
        var cpu = Cpu.init(testRng());
        const x = 2;
        const y = 1;
        cpu.v[1] = 69;
        cpu.v[2] = 105;
        cpu.@"sub Vx, Vy"(x, y);
        try std.testing.expectEqual(@as(u8, @intCast(1)), cpu.v[0xF]);
        try std.testing.expectEqual(@as(u8, @intCast(36)), cpu.v[x]);
        try std.testing.expectEqual(@as(u12, @intCast(app_memory_offset + 2)), cpu.pc);
    }

    // 8XY6
    inline fn @"shr Vx, {, Vy}"(self: *Cpu, x: u4, y: u4) void {
        self.v[0xF] = self.v[x] & 0x1;
        self.v[x] >>= 1;
        self.pc += 2;
        _ = y;
    }

    test @"shr Vx, {, Vy}" {
        var cpu = Cpu.init(testRng());
        const x = 1;
        const y = 0;
        cpu.v[1] = 69;
        cpu.@"shr Vx, {, Vy}"(x, y);
        try std.testing.expectEqual(@as(u8, @intCast((69 & 0x1))), cpu.v[0xF]);
        try std.testing.expectEqual(@as(u8, @intCast((69 >> 1))), cpu.v[x]);
        try std.testing.expectEqual(@as(u12, @intCast(app_memory_offset + 2)), cpu.pc);
    }

    // 8XY7
    inline fn @"subn Vx, Vy"(self: *Cpu, x: u4, y: u4) void {
        const vx = self.v[x];
        const vy = self.v[y];

        if (vy < vx) {
            self.v[0xF] = 0; // borrow
        } else {
            self.v[0xF] = 1;
        }

        const result, _ = @subWithOverflow(vy, vx);
        self.v[x] = result;
        self.pc += 2;
    }

    test @"subn Vx, Vy" {
        var cpu = Cpu.init(testRng());
        const x = 2;
        const y = 1;
        cpu.v[1] = 69;
        cpu.v[2] = 105;
        cpu.@"subn Vx, Vy"(x, y);
        try std.testing.expectEqual(@as(u8, @intCast(0)), cpu.v[0xF]);
        try std.testing.expectEqual(@as(u8, @bitCast(@as(i8, -36))), cpu.v[x]);
        try std.testing.expectEqual(@as(u12, @intCast(app_memory_offset + 2)), cpu.pc);
    }

    // 8XYE
    inline fn @"shl Vx {,Vy}"(self: *Cpu, x: u4, y: u4) void {
        self.v[0xF] = self.v[x] >> 7;
        self.v[x] <<= 1;
        self.pc += 2;
        _ = y;
    }

    test @"shl Vx {,Vy}" {
        var cpu = Cpu.init(testRng());
        const x = 1;
        const y = 0;
        cpu.v[1] = 69;
        cpu.@"shl Vx {,Vy}"(x, y);
        try std.testing.expectEqual(@as(u8, @intCast((69 >> 7))), cpu.v[0xF]);
        try std.testing.expectEqual(@as(u8, @intCast((69 << 1))), cpu.v[x]);
        try std.testing.expectEqual(@as(u12, @intCast(app_memory_offset + 2)), cpu.pc);
    }

    // 9XY0
    inline fn @"sne Vx, Vy"(self: *Cpu, x: u4, y: u4) void {
        if (self.v[x] != self.v[y]) {
            self.pc += 4;
        } else {
            self.pc += 2;
        }
    }

    test @"sne Vx, Vy" {
        var cpu = Cpu.init(testRng());
        const x = 2;
        const y = 1;
        cpu.v[1] = 1;
        cpu.v[2] = 2;
        cpu.@"sne Vx, Vy"(x, y);
        try std.testing.expectEqual(@as(u12, @intCast(app_memory_offset + 4)), cpu.pc);
        cpu.v[1] = 2;
        cpu.@"sne Vx, Vy"(x, y);
        try std.testing.expectEqual(@as(u12, @intCast(app_memory_offset + 6)), cpu.pc);
    }

    // ANNN
    inline fn @"ld I, addr"(self: *Cpu, addr: u12) void {
        self.i = addr;
        self.pc += 2;
    }

    test @"ld I, addr" {
        var cpu = Cpu.init(testRng());
        const nnn = 123;
        cpu.@"ld I, addr"(nnn);
        try std.testing.expectEqual(nnn, cpu.i);
        try std.testing.expectEqual(@as(u12, @intCast(app_memory_offset + 2)), cpu.pc);
    }

    // BNNN
    inline fn @"jp V0, addr"(self: *Cpu, addr: u12) void {
        self.pc = addr + self.v[0];
    }

    test @"jp V0, addr" {
        var cpu = Cpu.init(testRng());
        const nnn = 123;
        cpu.v[0] = 69;
        cpu.@"jp V0, addr"(nnn);
        try std.testing.expectEqual(@as(u12, @intCast(nnn + 69)), cpu.pc);
    }

    // CXKK
    inline fn @"rnd Vx, byte"(self: *Cpu, x: u4, byte: u8) void {
        self.v[x] = byte & @as(u8, @intCast(self.rng.int(u32) % 0xFF));
        self.pc += 2;
    }

    test @"rnd Vx, byte" {
        const x = 2;
        const kk = 79;
        var cpu = Cpu.init(testRng());
        cpu.@"rnd Vx, byte"(x, kk);
        try std.testing.expectEqual(6, cpu.v[x]);
        try std.testing.expectEqual(@as(u12, @intCast(app_memory_offset + 2)), cpu.pc);
    }

    // DXYN
    inline fn @"drw Vx, Vy, byte"(self: *Cpu, x: u4, y: u4, n: u4) void {
        const vx = self.v[x];
        const vy = self.v[y];

        self.v[0xF] = 0;

        for (0..n) |i| {
            const pixel = self.mem[self.i + i];
            for (0..8) |j| {
                if ((pixel & (@as(u16, 0x80) >> @as(u4, @intCast(j)))) > 0) {
                    const idx = (vx + j) % 64 + @rem((vy + i), 32) * 64;
                    if (self.fb[idx] == 1) {
                        self.v[0xF] = 1;
                        self.fb[idx] = 0;
                    } else {
                        self.fb[idx] = 1;
                    }
                    self.draw_flag = true;
                }
            }
        }
        self.pc += 2;
    }

    test @"drw Vx, Vy, byte" {
        const x = 2;
        const y = 1;
        const n = 12;
        var cpu = Cpu.init(testRng());
        cpu.v[x] = 123;
        cpu.v[y] = 105;
        cpu.@"drw Vx, Vy, byte"(x, y, n);

        try std.testing.expect(cpu.draw_flag);
        try std.testing.expectEqual(0, cpu.v[0xF]);
        try std.testing.expectEqual(@as(u12, @intCast(app_memory_offset + 2)), cpu.pc);
    }

    // EX9E
    inline fn @"skp Vx"(self: *Cpu, x: u4) void {
        if (self.key[self.v[x]] != 0) {
            self.pc += 4;
        } else {
            self.pc += 2;
        }
    }

    test @"skp Vx" {
        const x = 1;
        var cpu = Cpu.init(testRng());
        cpu.@"skp Vx"(x);
        try std.testing.expectEqual(@as(u12, @intCast(app_memory_offset + 2)), cpu.pc);

        cpu.key[cpu.v[x]] = 1;
        cpu.@"skp Vx"(x);
        try std.testing.expectEqual(@as(u12, @intCast(app_memory_offset + 6)), cpu.pc);
    }

    // EXA1
    inline fn @"sknp Vx"(self: *Cpu, x: u4) void {
        if (self.key[self.v[x]] == 0) {
            self.pc += 4;
        } else {
            self.pc += 2;
        }
    }

    test @"sknp Vx" {
        const x = 1;
        var cpu = Cpu.init(testRng());
        cpu.@"sknp Vx"(x);
        try std.testing.expectEqual(@as(u12, @intCast(app_memory_offset + 4)), cpu.pc);

        cpu.key[cpu.v[x]] = 1;
        cpu.@"sknp Vx"(x);
        try std.testing.expectEqual(@as(u12, @intCast(app_memory_offset + 6)), cpu.pc);
    }

    // FX07
    inline fn @"ld Vx, DT"(self: *Cpu, x: u4) void {
        self.v[x] = self.dt;
        self.pc += 2;
    }

    test @"ld Vx, DT" {
        const x = 1;
        var cpu = Cpu.init(testRng());
        cpu.dt = 69;
        cpu.@"ld Vx, DT"(x);
        try std.testing.expectEqual(cpu.dt, cpu.v[x]);
        try std.testing.expectEqual(@as(u12, @intCast(app_memory_offset + 2)), cpu.pc);
    }

    // FX0A
    inline fn @"ld Vx, K"(self: *Cpu, x: u4) void {
        var keyPress = false;
        var i: usize = 0;
        while (i < 16) : (i += 1) {
            if (self.key[i] != 0) {
                self.v[x] = @as(u8, @intCast(i));
                keyPress = true;
            }
        }

        // if no press, retry on next cycle
        if (!keyPress) {
            return;
        }
        self.pc += 2;
    }

    test @"ld Vx, K" {
        const x = 1;
        var cpu = Cpu.init(testRng());
        cpu.@"ld Vx, K"(x);

        try std.testing.expectEqual(cpu.key[1], cpu.v[x]);
        try std.testing.expectEqual(@as(u12, @intCast(app_memory_offset)), cpu.pc);

        cpu.key[1] = 1;
        cpu.@"ld Vx, K"(x);
        try std.testing.expectEqual(cpu.key[1], cpu.v[x]);
        try std.testing.expectEqual(@as(u12, @intCast(app_memory_offset + 2)), cpu.pc);
    }

    // FX15
    inline fn @"ld DT, Vx"(self: *Cpu, x: u4) void {
        self.dt = self.v[x];
        self.pc += 2;
    }

    test @"ld DT, Vx" {
        const x = 1;
        var cpu = Cpu.init(testRng());
        cpu.v[x] = 69;
        cpu.@"ld DT, Vx"(x);
        try std.testing.expectEqual(cpu.v[x], cpu.dt);
        try std.testing.expectEqual(@as(u12, @intCast(app_memory_offset + 2)), cpu.pc);
    }

    // FX18
    inline fn @"ld ST, Vx"(self: *Cpu, x: u4) void {
        self.st = self.v[x];
        self.pc += 2;
    }

    test @"ld ST, Vx" {
        const x = 1;
        var cpu = Cpu.init(testRng());
        cpu.v[x] = 69;
        cpu.@"ld ST, Vx"(x);
        try std.testing.expectEqual(cpu.v[x], cpu.st);
        try std.testing.expectEqual(@as(u12, @intCast(app_memory_offset + 2)), cpu.pc);
    }

    // FX1E
    inline fn @"add I, Vx"(self: *Cpu, x: u4) void {
        self.i += self.v[x];
        self.pc += 2;
    }

    test @"add I, Vx" {
        const x = 1;
        var cpu = Cpu.init(testRng());
        cpu.v[x] = 69;
        cpu.@"add I, Vx"(x);
        try std.testing.expectEqual(@as(u12, @intCast(cpu.v[x])), cpu.i);
        try std.testing.expectEqual(@as(u12, @intCast(app_memory_offset + 2)), cpu.pc);
    }

    // FX29
    inline fn @"ld F, Vx"(self: *Cpu, x: u4) void {
        self.i = self.v[x] * 5;
        self.pc += 2;
    }

    test @"ld F, Vx" {
        const x = 1;
        var cpu = Cpu.init(testRng());
        cpu.v[x] = 2;
        cpu.@"ld F, Vx"(x);
        try std.testing.expectEqual(@as(u12, @intCast(cpu.v[x])) * 5, cpu.i);
        try std.testing.expectEqual(@as(u12, @intCast(app_memory_offset + 2)), cpu.pc);
    }

    // FX33
    inline fn @"ld B, Vx"(self: *Cpu, x: u4) void {
        const vx = self.v[x];
        const i = self.i;
        self.mem[i + 0] = vx / 100;
        self.mem[i + 1] = (vx / 10) % 10;
        self.mem[i + 2] = (vx % 100) % 10;
        self.pc += 2;
    }

    test @"ld B, Vx" {
        const x = 1;
        var cpu = Cpu.init(testRng());
        const testValue: u8 = 69;
        const i: u12 = 99;
        cpu.v[x] = testValue;
        cpu.i = i;
        cpu.@"ld B, Vx"(x);
        try std.testing.expectEqual(@as(u12, @intCast(testValue / 100)), cpu.mem[i + 0]);
        try std.testing.expectEqual(@as(u12, @intCast((testValue / 10) % 10)), cpu.mem[i + 1]);
        try std.testing.expectEqual(@as(u12, @intCast((testValue % 100) % 10)), cpu.mem[i + 2]);
        try std.testing.expectEqual(@as(u12, @intCast(app_memory_offset + 2)), cpu.pc);
    }

    // FX55
    inline fn @"ld [I], Vx"(self: *Cpu, x: u4) void {
        const i = self.i;

        for (0..(x + 1)) |j| {
            self.mem[i + j] = self.v[j];
        }
        self.i += (x + 1);
        self.pc += 2;
    }

    test @"ld [I], Vx" {
        const x = 1;
        var cpu = Cpu.init(testRng());
        const testValue: u8 = 69;
        const i: u12 = 99;
        cpu.v[x] = testValue;
        cpu.i = i;

        cpu.@"ld [I], Vx"(x);
        try std.testing.expectEqual(cpu.v[0], cpu.mem[i + 0]);
        try std.testing.expectEqual(cpu.v[1], cpu.mem[i + 1]);
        try std.testing.expectEqual(i + x + 1, cpu.i);
        try std.testing.expectEqual(@as(u12, @intCast(app_memory_offset + 2)), cpu.pc);
    }

    // FX65
    inline fn @"ld Vx [I]"(self: *Cpu, x: u4) void {
        const i = self.i;
        for (0..(x + 1)) |j| {
            self.v[j] = self.mem[i + j];
        }
        self.i += (x + 1);
        self.pc += 2;
    }

    test @"ld Vx [I]" {
        const x = 1;
        var cpu = Cpu.init(testRng());
        const i: u12 = 99;
        cpu.mem[i + 0] = 24;
        cpu.mem[i + 1] = 25;
        cpu.i = i;

        cpu.@"ld Vx [I]"(x);
        try std.testing.expectEqual(cpu.mem[i + 0], cpu.v[0]);
        try std.testing.expectEqual(cpu.mem[i + 1], cpu.v[1]);
        try std.testing.expectEqual(i + x + 1, cpu.i);
        try std.testing.expectEqual(@as(u12, @intCast(app_memory_offset + 2)), cpu.pc);
    }
};
