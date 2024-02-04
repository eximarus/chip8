#include "cpu.h"
#include "instr.h"

// 0NNN and 2NNN
static void op_call_nnn(struct cpu* cpu, union instr instr) {
    cpu->stack[cpu->sp] = cpu->pc;
    cpu->sp++;
    cpu->pc = instr.nnn;
}

// 00E0
static void op_cls(struct cpu* cpu) {
    for (int32_t i = 0; i < 2048; ++i) {
        cpu->graphics->vram[i] = 0;
    }
    graphics_request_draw(cpu->graphics);
    cpu->pc += 2;
}

// 00EE
static void op_ret(struct cpu* cpu) {
    uint16_t sp = --cpu->sp;
    cpu->pc = cpu->stack[sp];
    cpu->pc += 2;
}

// 1NNN
static void op_jmp_nnn(struct cpu* cpu, union instr instr) {
    cpu->pc = instr.nnn;
}

// 3XNN
static void op_se_vx_nn(struct cpu* cpu, union instr instr) {
    if (cpu->v[instr.x] == instr.nn) {
        cpu->pc += 4;
    } else {
        cpu->pc += 2;
    }
}

// 4XNN
static void op_sne_vx_nn(struct cpu* cpu, union instr instr) {
    if (cpu->v[instr.x] != instr.nn) {
        cpu->pc += 4;
    } else {
        cpu->pc += 2;
    }
}

// 5XY0 SE
static void op_se_vx_vy(struct cpu* cpu, union instr instr) {
    if (cpu->v[instr.x] == cpu->v[instr.y]) {
        cpu->pc += 4;
    } else {
        cpu->pc += 2;
    }
}

// 6XNN
static void op_ld_vx_nn(struct cpu* cpu, union instr instr) {
    cpu->v[instr.x] = instr.nn;
    cpu->pc += 2;
}

// 7XNN
static void op_add_vx_nn(struct cpu* cpu, union instr instr) {
    cpu->v[instr.x] += instr.nn;
    cpu->pc += 2;
}

// 8XY0
static void op_ld_vx_vy(struct cpu* cpu, union instr instr) {
    cpu->v[instr.x] = cpu->v[instr.y];
    cpu->pc += 2;
}

// 8XY1
static void op_or_vx_vy(struct cpu* cpu, union instr instr) {
    cpu->v[instr.x] |= cpu->v[instr.y];
    cpu->pc += 2;
}

// 8XY2
static void op_and_vx_vy(struct cpu* cpu, union instr instr) {
    cpu->v[instr.x] &= cpu->v[instr.y];
    cpu->pc += 2;
}

// 8XY3
static void op_xor_vx_vy(struct cpu* cpu, union instr instr) {
    cpu->v[instr.x] ^= cpu->v[instr.y];
    cpu->pc += 2;
}

// 8XY4
static void op_add_vx_vy(struct cpu* cpu, union instr instr) {
    uint8_t* v = cpu->v;
    uint8_t y_value = v[instr.y];

    if (y_value > (0xFF - v[instr.x])) {
        v[0xF] = 1; // carry
    } else {
        v[0xF] = 0;
    }
    v[instr.x] += y_value;
    cpu->pc += 2;
}

// 8XY5
static void op_sub_vx_vy(struct cpu* cpu, union instr instr) {
    uint8_t* v = cpu->v;
    uint8_t y_value = v[instr.y];

    if (y_value > v[instr.x]) {
        v[0xF] = 0; // borrow
    } else {
        v[0xF] = 1;
    }
    v[instr.x] -= y_value;
    cpu->pc += 2;
}

// 8XY6
static void op_shr_vx_vy(struct cpu* cpu, union instr instr) {
    uint8_t* v = cpu->v;

    v[0xFU] = v[instr.x] & 0x1U;
    v[instr.x] >>= 1U;
    cpu->pc += 2;
}

// 8XY7
static void op_subn_vx_vy(struct cpu* cpu, union instr instr) {
    uint8_t* v = cpu->v;
    uint8_t y_value = v[instr.y];

    if (y_value < v[instr.x]) {
        v[0xF] = 0; // borrow
    } else {
        v[0xF] = 1;
    }
    v[instr.x] = y_value - v[instr.x];
    cpu->pc += 2;
}

// 8XYE
static void op_shl_vx_vy(struct cpu* cpu, union instr instr) {
    uint8_t* v = cpu->v;

    v[0xFU] = v[instr.x] >> 7U;
    v[instr.x] <<= 1U;
    cpu->pc += 2;
}

// 9XY0
static void op_sne_vx_vy(struct cpu* cpu, union instr instr) {
    if (cpu->v[instr.x] != cpu->v[instr.y]) {
        cpu->pc += 4;
    } else {
        cpu->pc += 2;
    }
}

// ANNN
static void op_ld_i_nnn(struct cpu* cpu, union instr instr) {
    cpu->i = instr.nnn;
    cpu->pc += 2;
}

// BNNN
static void op_jmp_v0_nnn(struct cpu* cpu, union instr instr) {
    cpu->pc = instr.nnn + cpu->v[0];
}

// CXNN
static void op_rnd_vx_nn(struct cpu* cpu, union instr instr) {
    // rand returns a 32bit integer
    // so we have to ensure we get a number less than 255
    cpu->v[instr.x] = instr.nn & ((uint32_t)random() % 0xFFU);
    cpu->pc += 2;
}

// DXYN
static void op_drw_vx_vy_n(struct cpu* cpu, union instr instr) {
    uint8_t vx = cpu->v[instr.x];
    uint8_t vy = cpu->v[instr.y];

    cpu->v[0xF] = 0;
    for (uint32_t i = 0; i < instr.n; i++) {
        uint8_t sprite = cpu->ram[cpu->i + i];
        uint8_t y = (vy + i) % SCREEN_HEIGHT;

        for (uint32_t j = 0; j < 8; j++) {
            uint8_t x = (vx + j) % SCREEN_WIDTH;
            size_t addr = y * SCREEN_WIDTH + x;
            uint8_t sprite_pixel = (sprite & 0x80U) >> 7U;

            if (sprite_pixel == 1) {
                uint32_t curr_pixel = cpu->graphics->vram[addr];
                if (curr_pixel != 0) {
                    cpu->v[0xF] = 1;
                    cpu->graphics->vram[addr] = 0;
                } else {
                    cpu->graphics->vram[addr] = 1;
                }
                graphics_request_draw(cpu->graphics);
            }
            sprite <<= 1U;
        }
    }

    cpu->pc += 2;
}

// EX9E
static void op_skp_vx(struct cpu* cpu, union instr instr) {
    if (input_get_key(cpu->input, cpu->v[instr.x])) {
        cpu->pc += 4;
    } else {
        cpu->pc += 2;
    }
}

// EXA1
static void op_sknp_vx(struct cpu* cpu, union instr instr) {
    if (!input_get_key(cpu->input, cpu->v[instr.x])) {
        cpu->pc += 4;
    } else {
        cpu->pc += 2;
    }
}

// FX07
static void op_ld_vx_dt(struct cpu* cpu, union instr instr) {
    cpu->v[instr.x] = cpu->dt;
    cpu->pc += 2;
}

// FX0A
static void op_ld_vx_key(struct cpu* cpu, union instr instr) {
    bool key_press = false;
    for (int32_t i = 0; i < 16; i++) {
        if (input_get_key(cpu->input, i)) {
            cpu->v[instr.x] = i;
            key_press = true;
        }
    }

    // if no press, retry on next cycle
    if (!key_press) {
        return;
    }
    cpu->pc += 2;
}

// FX15
static void op_ld_dt_vx(struct cpu* cpu, union instr instr) {
    cpu->dt = cpu->v[instr.x];
    cpu->pc += 2;
}

// FX18
static void op_ld_st_vx(struct cpu* cpu, union instr instr) {
    cpu->st = cpu->v[instr.x];
    cpu->pc += 2;
}

// FX1E
static void op_add_i_vx(struct cpu* cpu, union instr instr) {
    cpu->i += cpu->v[instr.x];
    cpu->pc += 2;
}

// FX29
static void op_ld_i_font_vx(struct cpu* cpu, union instr instr) {
    cpu->i = cpu->v[instr.x] * 5;
    cpu->pc += 2;
}

// FX33
static void op_bcd_vx(struct cpu* cpu, union instr instr) {
    uint8_t x = cpu->v[instr.x];
    uint16_t i = cpu->i;
    cpu->ram[i + 0] = x / 100;
    cpu->ram[i + 1] = (x / 10) % 10;
    cpu->ram[i + 2] = (x % 100) % 10;
    cpu->pc += 2;
}

// FX55
static void op_ld_i_vx(struct cpu* cpu, union instr instr) {
    uint16_t i = cpu->i;
    for (int32_t j = 0; j <= instr.x; j++) {
        cpu->ram[i + j] = cpu->v[j];
    }
    cpu->i += (instr.x + 1);
    cpu->pc += 2;
}

// FX65
static void op_ld_vx_i(struct cpu* cpu, union instr instr) {
    uint16_t i = cpu->i;
    for (int32_t j = 0; j <= instr.x; j++) {
        cpu->v[j] = cpu->ram[i + j];
    }
    cpu->i += (instr.x + 1);
    cpu->pc += 2;
}

void cpu_update_timers(struct cpu* cpu) {
    // TODO ensure 60hz
    if (cpu->dt > 0) {
        cpu->dt--;
    }
    if (cpu->st > 0) {
        if (cpu->st == 1) {
            audio_beep(cpu->audio, 1500);
        }
        cpu->st--;
    }
}

static void decode_opcode(struct cpu* cpu, uint16_t opcode) {
    union instr instr = {.instr = opcode};

    switch (instr.opcode) {
    case 0x0:
        switch (instr.nn) {
        case 0xE0:
            op_cls(cpu);
            break;
        case 0xEE:
            op_ret(cpu);
            break;
        default:
            printf("Unknown opcode: 0x%X\n", opcode);
            cpu->pc += 2;
            return;
        }
        break;
    case 0x1:
        op_jmp_nnn(cpu, instr);
        break;
    case 0x2:
        op_call_nnn(cpu, instr);
        break;
    case 0x3:
        op_se_vx_nn(cpu, instr);
        break;
    case 0x4:
        op_sne_vx_nn(cpu, instr);
        break;
    case 0x5:
        op_se_vx_vy(cpu, instr);
        break;
    case 0x6:
        op_ld_vx_nn(cpu, instr);
        break;
    case 0x7:
        op_add_vx_nn(cpu, instr);
        break;
    case 0x8:
        switch (instr.n) {
        case 0x0:
            op_ld_vx_vy(cpu, instr);
            break;
        case 0x1:
            op_or_vx_vy(cpu, instr);
            break;
        case 0x2:
            op_and_vx_vy(cpu, instr);
            break;
        case 0x3:
            op_xor_vx_vy(cpu, instr);
            break;
        case 0x4:
            op_add_vx_vy(cpu, instr);
            break;
        case 0x5:
            op_sub_vx_vy(cpu, instr);
            break;
        case 0x6:
            op_shr_vx_vy(cpu, instr);
            break;
        case 0x7:
            op_subn_vx_vy(cpu, instr);
            break;
        case 0xE:
            op_shl_vx_vy(cpu, instr);
            break;
        default:
            cpu->pc += 2;
            printf("Unknown opcode: 0x%X\n", opcode);
            return;
        }
        break;
    case 0x9:
        op_sne_vx_vy(cpu, instr);
        break;
    case 0xA:
        op_ld_i_nnn(cpu, instr);
        break;
    case 0xB:
        op_jmp_v0_nnn(cpu, instr);
        break;
    case 0xC:
        op_rnd_vx_nn(cpu, instr);
        break;
    case 0xD:
        op_drw_vx_vy_n(cpu, instr);
        break;
    case 0xE:
        switch (instr.nn) {
        case 0x9E:
            op_skp_vx(cpu, instr);
            break;
        case 0xA1:
            op_sknp_vx(cpu, instr);
            break;
        default:
            cpu->pc += 2;
            printf("Unknown opcode: 0x%X\n", opcode);
            return;
        }
        break;
    case 0xF:
        switch (instr.nn) {
        case 0x07:
            op_ld_vx_dt(cpu, instr);
            break;
        case 0x0A:
            op_ld_vx_key(cpu, instr);
            break;
        case 0x15:
            op_ld_dt_vx(cpu, instr);
            break;
        case 0x18:
            op_ld_st_vx(cpu, instr);
            break;
        case 0x1E:
            op_add_i_vx(cpu, instr);
            break;
        case 0x29:
            op_ld_i_font_vx(cpu, instr);
            break;
        case 0x33:
            op_bcd_vx(cpu, instr);
            break;
        case 0x55:
            op_ld_i_vx(cpu, instr);
            break;
        case 0x65:
            op_ld_vx_i(cpu, instr);
            break;
        default:
            cpu->pc += 2;
            printf("Unknown opcode: 0x%X\n", opcode);
            return;
        }

        break;
    default:
        cpu->pc += 2;
        printf("Unknown opcode: 0x%X\n", opcode);
        return;
    }

    // printf("executed opcode: 0x%X\n", opcode);
}

static uint16_t fetch_opcode(struct cpu* cpu) {
    return (uint32_t)cpu->ram[cpu->pc] << 8U |
           cpu->ram[cpu->pc + 1];
}

void cpu_emulate_cycle(struct cpu* cpu) {
    uint16_t opcode = fetch_opcode(cpu);
    decode_opcode(cpu, opcode);
}

