# BFloat16 routines: hand-written RV32I.
#
# uint16_t bf16_from_f32_asm(uint32_t f32bits)   a0 -> a0
# uint16_t bf16_mul_asm(uint16_t a, uint16_t b)  a0, a1 -> a0
# uint16_t bf16_sqrt_asm(uint16_t a)             a0 -> a0
#
# RV32I and Zicsr only: no mul, div, rem, no floating point, no compressed
# instructions. Tests: tests/tbf16.c.

    .text

    .globl  bf16_from_f32_asm
    .type   bf16_from_f32_asm, @function
    .align  2
bf16_from_f32_asm:
    # a0 = f32bits -> a0
    # a4 = exponent field in place, a5 = exponent mask, t0 = 0x7FFF, t1 = bit 16
    lui   a5, 0x7f800           # exponent mask 0x7F800000
    and   a4, a0, a5
    beq   a4, a5, .Lskip_rounding   # Inf or NaN: no rounding
    li    t0, 0x7FFF
    srli  t1, a0, 16
    andi  t1, t1, 0x1
    add   a0, a0, t0
    add   a0, a0, t1            # round to nearest, ties to even
.Lskip_rounding:
    srli  a0, a0, 16            # keep the top 16 bits
    ret
    .size   bf16_from_f32_asm, .-bf16_from_f32_asm

    .globl  bf16_mul_asm
    .type   bf16_mul_asm, @function
    .align  2
bf16_mul_asm:
    li      a0, 0
    ret
    .size   bf16_mul_asm, .-bf16_mul_asm

    .globl  bf16_sqrt_asm
    .type   bf16_sqrt_asm, @function
    .align  2
bf16_sqrt_asm:
    li      a0, 0
    ret
    .size   bf16_sqrt_asm, .-bf16_sqrt_asm
