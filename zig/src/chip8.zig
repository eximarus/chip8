const std = @import("std");
const graphics = @import("graphics.zig");

const SCREEN_WIDTH = graphics.SCREEN_WIDTH;
const SCREEN_HEIGHT = graphics.SCREEN_HEIGHT;

const MEMORY_SIZE = 4096;
const APP_MEMORY_OFFSET = 0x200;

pub const Cpu = struct {
    opcode: u16 = 0,
    memory: [MEMORY_SIZE]u8 = undefined,
    v: [16]u8 = undefined,
    i: u12 = 0,
    pc: u12 = APP_MEMORY_OFFSET,
    gfx: [SCREEN_WIDTH * SCREEN_HEIGHT]u32 = undefined,
    delayTimer: u8 = 0,
    soundTimer: u8 = 0,
    stack: [16]u12 = undefined,
    sp: u12 = 0,
    key: [16]u8 = undefined,
    drawFlag: bool = false,
    pcg: std.rand.Pcg = undefined,
};

const OperandType = enum {
    nn,
    nnn,
    x,
    xnn,
    xy,
    xyn,
};

const Operands = union(OperandType) {
    nn: u8,
    nnn: u12,
    x: u4,
    xnn: XNN,
    xy: XY,
    xyn: XYN,

    fn extractX(opcode: u16) u4 {
        return @as(u4, @intCast((opcode & 0x0F00) >> 8));
    }

    fn extractY(opcode: u16) u4 {
        return @as(u4, @intCast((opcode & 0x00F0) >> 4));
    }

    pub fn initXYN(operands: *Operands, opcode: u16) *Operands {
        operands.* = Operands{
            .xyn = XYN{
                .x = extractX(opcode),
                .y = extractY(opcode),
                .n = @as(u4, @intCast(opcode & 0x000F)),
            },
        };

        return operands;
    }

    pub fn initXY(operands: *Operands, opcode: u16) *Operands {
        operands.* = Operands{
            .xy = XY{
                .x = extractX(opcode),
                .y = extractY(opcode),
            },
        };
        return operands;
    }

    pub fn initXNN(operands: *Operands, opcode: u16) *Operands {
        operands.* = Operands{
            .xnn = XNN{
                .x = extractX(opcode),
                .nn = @as(u8, @intCast(opcode & 0x00FF)),
            },
        };
        return operands;
    }

    pub fn initX(operands: *Operands, opcode: u16) *Operands {
        operands.* = Operands{
            .x = extractX(opcode),
        };
        return operands;
    }

    pub fn initNN(operands: *Operands, opcode: u16) *Operands {
        operands.* = Operands{
            .nn = @as(u8, @intCast(opcode & 0x00FF)),
        };
        return operands;
    }

    pub fn initNNN(operands: *Operands, opcode: u16) *Operands {
        operands.* = Operands{
            .nnn = @as(u12, @intCast(opcode & 0x0FFF)),
        };
        return operands;
    }
};

const XNN = struct {
    x: u4,
    nn: u8,
};

const XYN = struct {
    x: u4,
    y: u4,
    n: u4,
};

const XY = struct {
    x: u4,
    y: u4,
};

const chip8Fontset = [80]u8{
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

pub fn initialize(cpu: *Cpu) void {
    for (chip8Fontset, 0..) |value, i| {
        cpu.memory[i] = value;
    }

    const timestamp = @as(u64, @intCast(std.time.timestamp()));
    cpu.pcg = std.rand.Pcg.init(timestamp);
}

pub fn updateTimers(cpu: *Cpu) void {
    if (cpu.delayTimer > 0) {
        cpu.delayTimer -= 1;
    }

    if (cpu.soundTimer > 0) {
        if (cpu.soundTimer == 1) {
            std.log.info("BEEP", .{});
        }
        cpu.soundTimer -= 1;
    }
}

fn fetchOpcode(cpu: *Cpu) u16 {
    cpu.opcode = @as(u16, cpu.memory[cpu.pc]) << 8 | cpu.memory[cpu.pc + 1];
    return cpu.opcode;
}

// 0NNN and 2NNN
fn callSubroutine(cpu: *Cpu, operands: *Operands) void {
    cpu.stack[cpu.sp] = cpu.pc;
    cpu.sp += 1;
    cpu.pc = operands.nnn;
}

test "callSubroutine" {
    var cpu = Cpu{};
    initialize(&cpu);

    var operands = Operands{ .nnn = 0x123 };
    callSubroutine(&cpu, &operands);
    try std.testing.expectEqual(@as(u12, @intCast(APP_MEMORY_OFFSET)), cpu.stack[0]);
    try std.testing.expectEqual(@as(u12, @intCast(1)), cpu.sp);
    try std.testing.expectEqual(@as(u12, @intCast(operands.nnn)), cpu.pc);
}

// 00E0
fn clearDisplay(cpu: *Cpu) void {
    for (cpu.gfx, 0..) |_, i| {
        cpu.gfx[i] = 0;
    }
    cpu.drawFlag = true;
    cpu.pc += 2;
}

test "clearDisplay" {
    var cpu = Cpu{};
    initialize(&cpu);
    clearDisplay(&cpu);

    for (cpu.gfx, 0..) |_, i| {
        try std.testing.expectEqual(@as(u32, @intCast(0)), cpu.gfx[i]);
    }
    try std.testing.expectEqual(true, cpu.drawFlag);
    try std.testing.expectEqual(@as(u12, @intCast(APP_MEMORY_OFFSET + 2)), cpu.pc);
}

// 00EE
fn returnFromAddress(cpu: *Cpu) void {
    cpu.sp -= 1;
    cpu.pc = cpu.stack[cpu.sp];
    cpu.pc += 2;
}

test "returnFromAddress" {
    var cpu = Cpu{};
    initialize(&cpu);
    var operands = Operands{ .nnn = 0x123 };
    callSubroutine(&cpu, &operands);
    returnFromAddress(&cpu);
    try std.testing.expectEqual(@as(u12, @intCast(0)), cpu.sp);
    try std.testing.expectEqual(@as(u12, @intCast(APP_MEMORY_OFFSET + 2)), cpu.pc);
}

// 1NNN
fn gotoAddress(cpu: *Cpu, operands: *Operands) void {
    cpu.pc = operands.nnn;
}

test "gotoAddress" {
    var cpu = Cpu{};
    initialize(&cpu);
    var operands = Operands{ .nnn = 0x123 };
    gotoAddress(&cpu, &operands);
    try std.testing.expectEqual(@as(u12, @intCast(operands.nnn)), cpu.pc);
}

// 3XNN
fn skipIfEquals(cpu: *Cpu, operands: *Operands) void {
    if (cpu.v[operands.xnn.x] == operands.xnn.nn) {
        cpu.pc += 4;
    } else {
        cpu.pc += 2;
    }
}

test "skipIfEquals" {
    var cpu = Cpu{};
    initialize(&cpu);
    var operands = Operands{ .xnn = XNN{ .x = 1, .nn = 0x23 } };
    skipIfEquals(&cpu, &operands);
    try std.testing.expectEqual(@as(u12, @intCast(APP_MEMORY_OFFSET + 2)), cpu.pc);

    cpu.v[operands.xnn.x] = operands.xnn.nn;
    skipIfEquals(&cpu, &operands);
    try std.testing.expectEqual(@as(u12, @intCast(APP_MEMORY_OFFSET + 6)), cpu.pc);
}

// 4XNN
fn skipIfNotEquals(cpu: *Cpu, operands: *Operands) void {
    if (cpu.v[operands.xnn.x] != operands.xnn.nn) {
        cpu.pc += 4;
    } else {
        cpu.pc += 2;
    }
}

test "skipIfNotEquals" {
    var cpu = Cpu{};
    initialize(&cpu);
    var operands = Operands{ .xnn = XNN{ .x = 1, .nn = 0x23 } };
    skipIfNotEquals(&cpu, &operands);
    try std.testing.expectEqual(@as(u12, @intCast(APP_MEMORY_OFFSET + 4)), cpu.pc);

    cpu.v[operands.xnn.x] = operands.xnn.nn;
    skipIfNotEquals(&cpu, &operands);
    try std.testing.expectEqual(@as(u12, @intCast(APP_MEMORY_OFFSET + 6)), cpu.pc);
}

// 5XY0
fn skipIfEqualsRegister(cpu: *Cpu, operands: *Operands) void {
    if (cpu.v[operands.xy.x] == cpu.v[operands.xy.y]) {
        cpu.pc += 4;
    } else {
        cpu.pc += 2;
    }
}

test "skipIfEqualsRegister" {
    var cpu = Cpu{};
    initialize(&cpu);
    var operands = Operands{ .xy = XY{ .x = 1, .y = 2 } };
    cpu.v[1] = 69;
    cpu.v[2] = 69;
    skipIfEqualsRegister(&cpu, &operands);
    try std.testing.expectEqual(@as(u12, @intCast(APP_MEMORY_OFFSET + 4)), cpu.pc);

    cpu.v[2] = 105;
    skipIfEqualsRegister(&cpu, &operands);
    try std.testing.expectEqual(@as(u12, @intCast(APP_MEMORY_OFFSET + 6)), cpu.pc);
}

// 6XNN
fn setRegisterValue(cpu: *Cpu, operands: *Operands) void {
    cpu.v[operands.xnn.x] = operands.xnn.nn;
    cpu.pc += 2;
}

test "setRegisterValue" {
    var cpu = Cpu{};
    initialize(&cpu);
    var operands = Operands{ .xnn = XNN{ .x = 1, .nn = 69 } };
    setRegisterValue(&cpu, &operands);
    try std.testing.expectEqual(@as(u12, @intCast(APP_MEMORY_OFFSET + 2)), cpu.pc);
    try std.testing.expectEqual(operands.xnn.nn, cpu.v[operands.xnn.x]);
}

// 7XNN
fn addToRegisterValue(cpu: *Cpu, operands: *Operands) void {
    const vIndex = operands.xnn.x;
    const result = @addWithOverflow(cpu.v[vIndex], operands.xnn.nn)[0];
    cpu.v[vIndex] = result;
    cpu.pc += 2;
}

test "addToRegisterValue" {
    var cpu = Cpu{};
    initialize(&cpu);
    var operands = Operands{ .xnn = XNN{ .x = 0, .nn = 17 } };
    addToRegisterValue(&cpu, &operands);
    try std.testing.expectEqual(operands.xnn.nn, cpu.v[operands.xnn.x]);
    try std.testing.expectEqual(@as(u12, @intCast(APP_MEMORY_OFFSET + 2)), cpu.pc);

    addToRegisterValue(&cpu, &operands);
    try std.testing.expectEqual(operands.xnn.nn * 2, cpu.v[operands.xnn.x]);
    try std.testing.expectEqual(@as(u12, @intCast(APP_MEMORY_OFFSET + 4)), cpu.pc);

    var secondOperands = Operands{ .xnn = XNN{ .x = 1, .nn = 1 } };
    addToRegisterValue(&cpu, &secondOperands);
    try std.testing.expectEqual(secondOperands.xnn.nn, cpu.v[secondOperands.xnn.x]);
    try std.testing.expectEqual(@as(u12, @intCast(APP_MEMORY_OFFSET + 6)), cpu.pc);
}

// 8XY0
fn copyRegisterValue(cpu: *Cpu, operands: *Operands) void {
    cpu.v[operands.xy.x] = cpu.v[operands.xy.y];
    cpu.pc += 2;
}

test "copyRegisterValue" {
    var cpu = Cpu{};
    initialize(&cpu);
    var operands = Operands{ .xy = XY{ .x = 2, .y = 1 } };
    const testValue: u8 = 25;
    cpu.v[1] = testValue;
    cpu.v[2] = 0;
    copyRegisterValue(&cpu, &operands);
    try std.testing.expectEqual(testValue, cpu.v[operands.xy.x]);
    try std.testing.expectEqual(@as(u12, @intCast(APP_MEMORY_OFFSET + 2)), cpu.pc);
}

// 8XY1
fn bitwiseOrRegisterValues(cpu: *Cpu, operands: *Operands) void {
    cpu.v[operands.xy.x] |= cpu.v[operands.xy.y];
    cpu.pc += 2;
}

test "bitwiseOrRegisterValues" {
    var cpu = Cpu{};
    initialize(&cpu);
    var operands = Operands{ .xy = XY{ .x = 2, .y = 1 } };
    cpu.v[1] = 0b0000_1111;
    cpu.v[2] = 0b1111_0000;
    bitwiseOrRegisterValues(&cpu, &operands);
    try std.testing.expectEqual(@as(u8, @intCast(0b1111_1111)), cpu.v[operands.xy.x]);
    try std.testing.expectEqual(@as(u12, @intCast(APP_MEMORY_OFFSET + 2)), cpu.pc);
}

// 8XY2
fn bitwiseAndRegisterValues(cpu: *Cpu, operands: *Operands) void {
    cpu.v[operands.xy.x] &= cpu.v[operands.xy.y];
    cpu.pc += 2;
}

test "bitwiseAndRegisterValues" {
    var cpu = Cpu{};
    initialize(&cpu);
    var operands = Operands{ .xy = XY{ .x = 2, .y = 1 } };
    cpu.v[1] = 0b0001_0111;
    cpu.v[2] = 0b1111_1000;
    bitwiseAndRegisterValues(&cpu, &operands);
    try std.testing.expectEqual(@as(u8, @intCast(0b0001_0000)), cpu.v[operands.xy.x]);
    try std.testing.expectEqual(@as(u12, @intCast(APP_MEMORY_OFFSET + 2)), cpu.pc);
}

// 8XY3
fn bitwiseXorRegisterValues(cpu: *Cpu, operands: *Operands) void {
    cpu.v[operands.xy.x] ^= cpu.v[operands.xy.y];
    cpu.pc += 2;
}

test "bitwiseXorRegisterValues" {
    var cpu = Cpu{};
    initialize(&cpu);

    var operands = Operands{ .xy = XY{ .x = 2, .y = 1 } };
    cpu.v[1] = 0b0001_0111;
    cpu.v[2] = 0b1111_1000;
    bitwiseXorRegisterValues(&cpu, &operands);
    try std.testing.expectEqual(@as(u8, @intCast(0b1110_1111)), cpu.v[operands.xy.x]);
    try std.testing.expectEqual(@as(u12, @intCast(APP_MEMORY_OFFSET + 2)), cpu.pc);
}

// 8XY4
fn addRegisterValues(cpu: *Cpu, operands: *Operands) void {
    const yValue = cpu.v[operands.xy.y];
    const xAddr = operands.xy.x;
    var v = &cpu.v;

    if (yValue > (0xFF - v[xAddr])) {
        v[0xF] = 1; // carry
    } else {
        v[0xF] = 0;
    }
    v[xAddr] += yValue;
    cpu.pc += 2;
}

test "addRegisterValues" {
    var cpu = Cpu{};
    initialize(&cpu);
    var operands = Operands{ .xy = XY{ .x = 2, .y = 1 } };
    cpu.v[1] = 69;
    cpu.v[2] = 105;
    addRegisterValues(&cpu, &operands);
    try std.testing.expectEqual(@as(u8, @intCast(0)), cpu.v[0xF]);
    try std.testing.expectEqual(@as(u8, @intCast(174)), cpu.v[operands.xy.x]);
    try std.testing.expectEqual(@as(u12, @intCast(APP_MEMORY_OFFSET + 2)), cpu.pc);
}

// 8XY5
fn subRegisterValues(cpu: *Cpu, operands: *Operands) void {
    const yValue = cpu.v[operands.xy.y];
    const xAddr = operands.xy.x;
    var v = &cpu.v;

    if (yValue > v[xAddr]) {
        v[0xF] = 0; // borrow
    } else {
        v[0xF] = 1;
    }
    const result = @subWithOverflow(v[xAddr], yValue)[0];
    v[xAddr] = result;
    cpu.pc += 2;
}

test "subRegisterValues" {
    var cpu = Cpu{};
    initialize(&cpu);
    var operands = Operands{ .xy = XY{ .x = 2, .y = 1 } };
    cpu.v[1] = 69;
    cpu.v[2] = 105;
    subRegisterValues(&cpu, &operands);
    try std.testing.expectEqual(@as(u8, @intCast(1)), cpu.v[0xF]);
    try std.testing.expectEqual(@as(u8, @intCast(36)), cpu.v[operands.xy.x]);
    try std.testing.expectEqual(@as(u12, @intCast(APP_MEMORY_OFFSET + 2)), cpu.pc);
}

// 8XY6
fn shiftRegisterBy1Right(cpu: *Cpu, operands: *Operands) void {
    const xAddr = operands.xy.x;
    var v = &cpu.v;

    v[0xF] = v[xAddr] & 0x1;
    v[xAddr] >>= 1;
    cpu.pc += 2;
}

test "shiftRegisterBy1Right" {
    var cpu = Cpu{};
    initialize(&cpu);
    var operands = Operands{ .xy = XY{ .x = 1, .y = 0 } };
    cpu.v[1] = 69;
    shiftRegisterBy1Right(&cpu, &operands);
    try std.testing.expectEqual(@as(u8, @intCast((69 & 0x1))), cpu.v[0xF]);
    try std.testing.expectEqual(@as(u8, @intCast((69 >> 1))), cpu.v[operands.xy.x]);
    try std.testing.expectEqual(@as(u12, @intCast(APP_MEMORY_OFFSET + 2)), cpu.pc);
}

// 8XY7
fn subRegisterValuesReversed(cpu: *Cpu, operands: *Operands) void {
    const yValue = cpu.v[operands.xy.y];
    const xAddr = operands.xy.x;
    var v = &cpu.v;

    if (yValue < v[xAddr]) {
        v[0xF] = 0; // borrow
    } else {
        v[0xF] = 1;
    }

    const result = @subWithOverflow(yValue, v[xAddr])[0];
    v[xAddr] = result;
    cpu.pc += 2;
}

test "subRegisterValuesReversed" {
    var cpu = Cpu{};
    initialize(&cpu);
    var operands = Operands{ .xy = XY{ .x = 2, .y = 1 } };
    cpu.v[1] = 69;
    cpu.v[2] = 105;
    subRegisterValuesReversed(&cpu, &operands);
    try std.testing.expectEqual(@as(u8, @intCast(0)), cpu.v[0xF]);
    try std.testing.expectEqual(@as(u8, @bitCast(@as(i8, -36))), cpu.v[operands.xy.x]);
    try std.testing.expectEqual(@as(u12, @intCast(APP_MEMORY_OFFSET + 2)), cpu.pc);
}

// 8XYE
fn shiftRegisterBy1Left(cpu: *Cpu, operands: *Operands) void {
    const xAddr = operands.xy.x;
    var v = &cpu.v;

    v[0xF] = v[xAddr] >> 7;
    v[xAddr] <<= 1;
    cpu.pc += 2;
}

test "shiftRegisterBy1Left" {
    var cpu = Cpu{};
    initialize(&cpu);
    var operands = Operands{ .xy = XY{ .x = 1, .y = 0 } };
    cpu.v[1] = 69;
    shiftRegisterBy1Left(&cpu, &operands);
    try std.testing.expectEqual(@as(u8, @intCast((69 >> 7))), cpu.v[0xF]);
    try std.testing.expectEqual(@as(u8, @intCast((69 << 1))), cpu.v[operands.xy.x]);
    try std.testing.expectEqual(@as(u12, @intCast(APP_MEMORY_OFFSET + 2)), cpu.pc);
}

// 9XY0
fn skipIfNotEqualsRegister(cpu: *Cpu, operands: *Operands) void {
    if (cpu.v[operands.xy.x] != cpu.v[operands.xy.y]) {
        cpu.pc += 4;
    } else {
        cpu.pc += 2;
    }
}

test "skipIfNotEqualsRegister" {
    var cpu = Cpu{};
    initialize(&cpu);
    var operands = Operands{ .xy = XY{ .x = 2, .y = 1 } };
    cpu.v[1] = 1;
    cpu.v[2] = 2;
    skipIfNotEqualsRegister(&cpu, &operands);
    try std.testing.expectEqual(@as(u12, @intCast(APP_MEMORY_OFFSET + 4)), cpu.pc);
    cpu.v[1] = 2;
    skipIfNotEqualsRegister(&cpu, &operands);
    try std.testing.expectEqual(@as(u12, @intCast(APP_MEMORY_OFFSET + 6)), cpu.pc);
}

// ANNN
fn setIndexRegAddr(cpu: *Cpu, operands: *Operands) void {
    cpu.i = operands.nnn;
    cpu.pc += 2;
}

test "setIndexRegAddr" {
    var cpu = Cpu{};
    initialize(&cpu);
    var operands = Operands{ .nnn = 123 };
    setIndexRegAddr(&cpu, &operands);
    try std.testing.expectEqual(operands.nnn, cpu.i);
    try std.testing.expectEqual(@as(u12, @intCast(APP_MEMORY_OFFSET + 2)), cpu.pc);
}

// BNNN
fn jumpToAddrPlusV0(cpu: *Cpu, operands: *Operands) void {
    cpu.pc = operands.nnn + cpu.v[0];
}

test "jumpToAddrPlusV0" {
    var cpu = Cpu{};
    initialize(&cpu);
    var operands = Operands{ .nnn = 123 };
    cpu.v[0] = 69;
    jumpToAddrPlusV0(&cpu, &operands);
    try std.testing.expectEqual(@as(u12, @intCast(123 + 69)), cpu.pc);
}

// CXNN
fn setRegisterRand(cpu: *Cpu, operands: *Operands) void {
    // rand returns a 32bit integer
    // so we have to ensure we get a number less than 255
    cpu.v[operands.xnn.x] = operands.xnn.nn & @as(u8, @intCast(cpu.pcg.random().int(u32) % 0xFF));
    cpu.pc += 2;
}

test "setRegisterRand" {
    var cpu = Cpu{};
    initialize(&cpu);
    var operands = Operands{ .xnn = XNN{ .x = 2, .nn = 79 } };
    setRegisterRand(&cpu, &operands);

    try std.testing.expect(cpu.v[operands.xnn.x] >= 0);
    try std.testing.expect(cpu.v[operands.xnn.x] <= std.math.maxInt(u8));
    try std.testing.expectEqual(@as(u12, @intCast(APP_MEMORY_OFFSET + 2)), cpu.pc);
}

// DXYN
fn drawSprite(cpu: *Cpu, operands: *Operands) void {
    const opX = cpu.v[operands.xyn.x];
    const opY = cpu.v[operands.xyn.y];
    const height = operands.xyn.n;
    const width = 8;

    cpu.v[0xF] = 0;
    var y: i32 = 0;
    while (y < height) : (y += 1) {
        var x: u4 = 0;
        while (x < width) : (x += 1) {
            const pixel = cpu.memory[cpu.i + @as(usize, @intCast(y))];
            const start: u16 = 0x80;
            if ((pixel & (start >> x)) > 0) {
                const index = @as(usize, @intCast((opX + x) % 64 + @rem((opY + y), 32) * 64));
                if (cpu.gfx[index] == 1) {
                    cpu.v[0xF] = 1;
                    cpu.gfx[index] = 0;
                } else {
                    cpu.gfx[index] = 1;
                }
                cpu.drawFlag = true;
            }
        }
    }
    cpu.pc += 2;
}

test "drawSprite" {
    var cpu = Cpu{};
    initialize(&cpu);
    var operands = Operands{ .xyn = XYN{ .x = 2, .y = 1, .n = 12 } };
    cpu.v[operands.xyn.x] = 123;
    cpu.v[operands.xyn.y] = 105;
    drawSprite(&cpu, &operands);
    try std.testing.expect(cpu.drawFlag);
    try std.testing.expectEqual(@as(u12, @intCast(APP_MEMORY_OFFSET + 2)), cpu.pc);
}

// EX9E
fn skipIfKeyPressed(cpu: *Cpu, operands: *Operands) void {
    if (cpu.key[cpu.v[operands.x]] != 0) {
        cpu.pc += 4;
    } else {
        cpu.pc += 2;
    }
}

test "skipIfKeyPressed" {
    var cpu = Cpu{};
    initialize(&cpu);
    var operands = Operands{ .x = 1 };
    skipIfKeyPressed(&cpu, &operands);
    try std.testing.expectEqual(@as(u12, @intCast(APP_MEMORY_OFFSET + 2)), cpu.pc);

    cpu.key[cpu.v[operands.x]] = 1;
    skipIfKeyPressed(&cpu, &operands);
    try std.testing.expectEqual(@as(u12, @intCast(APP_MEMORY_OFFSET + 6)), cpu.pc);
}

// EXA1
fn skipIfKeyNotPressed(cpu: *Cpu, operands: *Operands) void {
    if (cpu.key[cpu.v[operands.x]] == 0) {
        cpu.pc += 4;
    } else {
        cpu.pc += 2;
    }
}

test "skipIfKeyNotPressed" {
    var cpu = Cpu{};
    initialize(&cpu);
    var operands = Operands{ .x = 1 };
    skipIfKeyNotPressed(&cpu, &operands);
    try std.testing.expectEqual(@as(u12, @intCast(APP_MEMORY_OFFSET + 4)), cpu.pc);

    cpu.key[cpu.v[operands.x]] = 1;
    skipIfKeyNotPressed(&cpu, &operands);
    try std.testing.expectEqual(@as(u12, @intCast(APP_MEMORY_OFFSET + 6)), cpu.pc);
}

// FX07
fn getDelayTimer(cpu: *Cpu, operands: *Operands) void {
    cpu.v[operands.x] = cpu.delayTimer;
    cpu.pc += 2;
}

test "getDelayTimer" {
    var cpu = Cpu{};
    initialize(&cpu);
    var operands = Operands{ .x = 1 };
    cpu.delayTimer = 69;
    getDelayTimer(&cpu, &operands);
    try std.testing.expectEqual(cpu.delayTimer, cpu.v[operands.x]);
    try std.testing.expectEqual(@as(u12, @intCast(APP_MEMORY_OFFSET + 2)), cpu.pc);
}

// FX0A
fn getKey(cpu: *Cpu, operands: *Operands) void {
    var keyPress = false;
    var i: usize = 0;
    while (i < 16) : (i += 1) {
        if (cpu.key[i] != 0) {
            cpu.v[operands.x] = @as(u8, @intCast(i));
            keyPress = true;
        }
    }

    // if no press, retry on next cycle
    if (!keyPress) {
        return;
    }
    cpu.pc += 2;
}

test "getKey" {
    var cpu = Cpu{};
    initialize(&cpu);
    var operands = Operands{ .x = 1 };
    getKey(&cpu, &operands);
    try std.testing.expectEqual(cpu.key[1], cpu.v[operands.x]);
    try std.testing.expectEqual(@as(u12, @intCast(APP_MEMORY_OFFSET)), cpu.pc);

    cpu.key[1] = 1;
    getKey(&cpu, &operands);
    try std.testing.expectEqual(cpu.key[1], cpu.v[operands.x]);
    try std.testing.expectEqual(@as(u12, @intCast(APP_MEMORY_OFFSET + 2)), cpu.pc);
}

// FX15
fn setDelayTimer(cpu: *Cpu, operands: *Operands) void {
    cpu.delayTimer = cpu.v[operands.x];
    cpu.pc += 2;
}

test "setDelayTimer" {
    var cpu = Cpu{};
    initialize(&cpu);
    var operands = Operands{ .x = 1 };
    cpu.v[operands.x] = 69;
    setDelayTimer(&cpu, &operands);
    try std.testing.expectEqual(cpu.v[operands.x], cpu.delayTimer);
    try std.testing.expectEqual(@as(u12, @intCast(APP_MEMORY_OFFSET + 2)), cpu.pc);
}

// FX18
fn setSoundTimer(cpu: *Cpu, operands: *Operands) void {
    cpu.soundTimer = cpu.v[operands.x];
    cpu.pc += 2;
}

test "setSoundTimer" {
    var cpu = Cpu{};
    initialize(&cpu);
    var operands = Operands{ .x = 1 };
    cpu.v[operands.x] = 69;
    setSoundTimer(&cpu, &operands);
    try std.testing.expectEqual(cpu.v[operands.x], cpu.soundTimer);
    try std.testing.expectEqual(@as(u12, @intCast(APP_MEMORY_OFFSET + 2)), cpu.pc);
}

// FX1E
fn addRegisterValueToIndex(cpu: *Cpu, operands: *Operands) void {
    cpu.i += cpu.v[operands.x];
    cpu.pc += 2;
}

test "addRegisterValueToIndex" {
    var cpu = Cpu{};
    initialize(&cpu);
    var operands = Operands{ .x = 1 };
    cpu.v[operands.x] = 69;
    addRegisterValueToIndex(&cpu, &operands);
    try std.testing.expectEqual(@as(u12, @intCast(cpu.v[operands.x])), cpu.i);
    try std.testing.expectEqual(@as(u12, @intCast(APP_MEMORY_OFFSET + 2)), cpu.pc);
}

// FX29
fn setIndexToSpriteAddr(cpu: *Cpu, operands: *Operands) void {
    cpu.i = cpu.v[operands.x] * 5;
    cpu.pc += 2;
}

test "setIndexToSpriteAddr" {
    var cpu = Cpu{};
    initialize(&cpu);
    var operands = Operands{ .x = 1 };
    cpu.v[operands.x] = 2;
    setIndexToSpriteAddr(&cpu, &operands);
    try std.testing.expectEqual(@as(u12, @intCast(cpu.v[operands.x])) * 5, cpu.i);
    try std.testing.expectEqual(@as(u12, @intCast(APP_MEMORY_OFFSET + 2)), cpu.pc);
}

// FX33
fn storeBCD(cpu: *Cpu, operands: *Operands) void {
    const x = cpu.v[operands.x];
    const i = cpu.i;
    cpu.memory[i + 0] = x / 100;
    cpu.memory[i + 1] = (x / 10) % 10;
    cpu.memory[i + 2] = (x % 100) % 10;
    cpu.pc += 2;
}

test "storeBCD" {
    var cpu = Cpu{};
    initialize(&cpu);
    var operands = Operands{ .x = 1 };
    const testValue: u8 = 69;
    const i: u12 = 99;
    cpu.v[operands.x] = testValue;
    cpu.i = i;
    storeBCD(&cpu, &operands);
    try std.testing.expectEqual(@as(u12, @intCast(testValue / 100)), cpu.memory[i + 0]);
    try std.testing.expectEqual(@as(u12, @intCast((testValue / 10) % 10)), cpu.memory[i + 1]);
    try std.testing.expectEqual(@as(u12, @intCast((testValue % 100) % 10)), cpu.memory[i + 2]);
    try std.testing.expectEqual(@as(u12, @intCast(APP_MEMORY_OFFSET + 2)), cpu.pc);
}

// FX55
fn regDump(cpu: *Cpu, operands: *Operands) void {
    const x = operands.x;
    const i = cpu.i;
    var j: usize = 0;
    while (j <= x) : (j += 1) {
        cpu.memory[i + j] = cpu.v[j];
    }
    cpu.i += (x + 1);
    cpu.pc += 2;
}

test "regDump" {
    var cpu = Cpu{};
    initialize(&cpu);
    var operands = Operands{ .x = 1 };
    const testValue: u8 = 69;
    const i: u12 = 99;
    cpu.v[operands.x] = testValue;
    cpu.i = i;

    regDump(&cpu, &operands);
    try std.testing.expectEqual(cpu.v[0], cpu.memory[i + 0]);
    try std.testing.expectEqual(cpu.v[1], cpu.memory[i + 1]);
    try std.testing.expectEqual(i + operands.x + 1, cpu.i);
    try std.testing.expectEqual(@as(u12, @intCast(APP_MEMORY_OFFSET + 2)), cpu.pc);
}

// FX65
fn regLoad(cpu: *Cpu, operands: *Operands) void {
    const x = operands.x;
    const i = cpu.i;
    var j: usize = 0;
    while (j <= x) : (j += 1) {
        cpu.v[j] = cpu.memory[i + j];
    }
    cpu.i += (x + 1);
    cpu.pc += 2;
}

test "regLoad" {
    var cpu = Cpu{};
    initialize(&cpu);
    var operands = Operands{ .x = 1 };
    const i: u12 = 99;
    cpu.memory[i + 0] = 24;
    cpu.memory[i + 1] = 25;
    cpu.i = i;

    regLoad(&cpu, &operands);
    try std.testing.expectEqual(cpu.memory[i + 0], cpu.v[0]);
    try std.testing.expectEqual(cpu.memory[i + 1], cpu.v[1]);
    try std.testing.expectEqual(i + operands.x + 1, cpu.i);
    try std.testing.expectEqual(@as(u12, @intCast(APP_MEMORY_OFFSET + 2)), cpu.pc);
}

fn decodeOpcode(cpu: *Cpu, opcode: u16) void {
    var operands: Operands = undefined;
    switch (opcode & 0xF000) {
        0x0000 => switch (opcode & 0x00FF) {
            0x00E0 => clearDisplay(cpu),
            0x00EE => returnFromAddress(cpu),
            else => {},
        },
        0x1000 => gotoAddress(cpu, operands.initNNN(opcode)),
        0x2000 => callSubroutine(cpu, operands.initNNN(opcode)),
        0x3000 => skipIfEquals(cpu, operands.initXNN(opcode)),
        0x4000 => skipIfNotEquals(cpu, operands.initXNN(opcode)),
        0x5000 => skipIfEqualsRegister(cpu, operands.initXY(opcode)),
        0x6000 => setRegisterValue(cpu, operands.initXNN(opcode)),
        0x7000 => addToRegisterValue(cpu, operands.initXNN(opcode)),
        0x8000 => switch (opcode & 0x000F) {
            0x0000 => copyRegisterValue(cpu, operands.initXY(opcode)),
            0x0001 => bitwiseOrRegisterValues(cpu, operands.initXY(opcode)),
            0x0002 => bitwiseAndRegisterValues(cpu, operands.initXY(opcode)),
            0x0003 => bitwiseXorRegisterValues(cpu, operands.initXY(opcode)),
            0x0004 => addRegisterValues(cpu, operands.initXY(opcode)),
            0x0005 => subRegisterValues(cpu, operands.initXY(opcode)),
            0x0006 => shiftRegisterBy1Right(cpu, operands.initXY(opcode)),
            0x0007 => subRegisterValuesReversed(cpu, operands.initXY(opcode)),
            0x000E => shiftRegisterBy1Left(cpu, operands.initXY(opcode)),
            else => {},
        },
        0x9000 => skipIfNotEqualsRegister(cpu, operands.initXY(opcode)),
        0xA000 => setIndexRegAddr(cpu, operands.initNNN(opcode)),
        0xB000 => jumpToAddrPlusV0(cpu, operands.initNNN(opcode)),
        0xC000 => setRegisterRand(cpu, operands.initXNN(opcode)),
        0xD000 => drawSprite(cpu, operands.initXYN(opcode)),
        0xE000 => switch (opcode & 0x00FF) {
            0x009E => skipIfKeyPressed(cpu, operands.initX(opcode)),
            0x00A1 => skipIfKeyNotPressed(cpu, operands.initX(opcode)),
            else => {},
        },
        0xF000 => switch (opcode & 0x00FF) {
            0x0007 => getDelayTimer(cpu, operands.initX(opcode)),
            0x000A => getKey(cpu, operands.initX(opcode)),
            0x0015 => setDelayTimer(cpu, operands.initX(opcode)),
            0x0018 => setSoundTimer(cpu, operands.initX(opcode)),
            0x001E => addRegisterValueToIndex(cpu, operands.initX(opcode)),
            0x0029 => setIndexToSpriteAddr(cpu, operands.initX(opcode)),
            0x0033 => storeBCD(cpu, operands.initX(opcode)),
            0x0055 => regDump(cpu, operands.initX(opcode)),
            0x0065 => regLoad(cpu, operands.initX(opcode)),
            else => {},
        },
        else => {
            std.log.err("Unknown opcode: 0x{X}", .{opcode});
            return;
        },
    }
}

pub fn emulateCycle(cpu: *Cpu) void {
    const opcode = fetchOpcode(cpu);
    decodeOpcode(cpu, opcode);
    updateTimers(cpu);
}

pub const ApplicationLoadError = error{
    RomTooBig,
    ReadSizeMismatch,
} || std.fs.File.OpenError || std.fs.File.GetSeekPosError || std.mem.Allocator.Error || std.os.ReadError;

pub fn loadApplication(cpu: *Cpu, fileName: []const u8) ApplicationLoadError!void {
    const f = try std.fs.openFileAbsolute(fileName, std.fs.File.OpenFlags{ .mode = .read_only });
    defer f.close();

    const fileSize = try f.getEndPos();
    if (fileSize > MEMORY_SIZE - APP_MEMORY_OFFSET) {
        return ApplicationLoadError.RomTooBig;
    }

    const allocator = std.heap.page_allocator;
    const buffer = try allocator.alloc(u8, fileSize);
    defer allocator.free(buffer);

    const pLen = try f.read(buffer);
    if (pLen != fileSize) {
        return ApplicationLoadError.ReadSizeMismatch;
    }

    for (buffer, 0..) |value, i| {
        cpu.memory[i + APP_MEMORY_OFFSET] = value;
    }
}
