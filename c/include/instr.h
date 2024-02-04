#pragma once
#include <stdint.h>

union instr {
    uint16_t instr;
    struct {
        uint8_t n : 4;
        uint8_t y : 4;
        uint8_t x : 4;
        uint8_t opcode : 4;
    } __attribute__((aligned(4)));

    struct {
        uint8_t nn : 8;
    } __attribute__((aligned(1)));

    struct {
        uint16_t nnn : 12;
    } __attribute__((aligned(1)));
} __attribute__((aligned(8)));
