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
    # a0 = a, a1 = b -> a0
    # t0 = sign, t1 = 0x8000, t2/t3 = ea/eb, t4/t5 = ma/mb, t6 = temp
    # a2 = adj, a3 = product, a4 = 0xFF

    # 1. sign = (a ^ b) & 0x8000; exponents ea, eb; fractions ma, mb
    xor   t0, a0, a1
    li    t1, 0x8000
    and   t0, t0, t1            # sign
    li    a4, 0xFF
    srli  t2, a0, 7
    andi  t2, t2, 0xFF          # ea
    srli  t3, a1, 7
    andi  t3, t3, 0xFF          # eb
    andi  t4, a0, 0x7F          # ma
    andi  t5, a1, 0x7F          # mb
    and   a2, a2, x0            # adj = 0

    # 2. a has exponent 0xFF: NaN a, Inf times zero, or signed Inf
    bne   t2, a4, .Lcheck_b_NaN
    bnez  t4, .Lret_a           # a is NaN: return a
    or    t6, t3, t5
    beqz  t6, .LNaN             # a is Inf and b is zero: quiet NaN
    j     .LInf                 # otherwise signed Inf

    # 3. b has exponent 0xFF: same rules
.Lcheck_b_NaN:
    bne   t3, a4, .Lcheck_zero
    bnez  t5, .Lret_b           # b is NaN: return b
    or    t6, t2, t4
    beqz  t6, .LNaN             # b is Inf and a is zero: quiet NaN
    j     .LInf                 # otherwise signed Inf

    # 4. a or b is zero (e and f both 0): return sign
.Lcheck_zero:
    or    t6, t2, t4
    beqz  t6, .Lzero
    or    t6, t3, t5
    beqz  t6, .Lzero

    # 5. a: normalize a subnormal (adj--), or restore the implicit 1
    beq   t2, x0, .La_norm_loop # ea == 0: subnormal
    ori   t4, t4, 0x80          # ma |= 0x80
    j     .Lb_prep
.La_norm_loop:
    andi  t6, t4, 0x80
    bnez  t6, .La_norm_done     # bit 7 set: done
    slli  t4, t4, 1             # ma <<= 1
    addi  a2, a2, -1            # adj--
    j     .La_norm_loop
.La_norm_done:
    addi  t2, x0, 1             # ea = 1

    # 6. b: same as step 5
.Lb_prep:
    beq   t3, x0, .Lb_norm_loop # eb == 0: subnormal
    ori   t5, t5, 0x80          # mb |= 0x80
    j     .Lmul_init
.Lb_norm_loop:
    andi  t6, t5, 0x80
    bnez  t6, .Lb_norm_done     # bit 7 set: done
    slli  t5, t5, 1             # mb <<= 1
    addi  a2, a2, -1            # adj--
    j     .Lb_norm_loop
.Lb_norm_done:
    addi  t3, x0, 1             # eb = 1

    # 7. shift-and-add multiply of the two 8-bit mantissas
    #    product = a3, multiplicand = t4, multiplier = t5
.Lmul_init:
    add   a3, x0, x0            # product = 0
.Lmul:
    andi  t6, t5, 1             # lowest bit of the multiplier
    beqz  t6, .Lmul_shift       # 0: skip the add
    add   a3, a3, t4            # product += multiplicand
.Lmul_shift:
    slli  t4, t4, 1             # multiplicand <<= 1
    srli  t5, t5, 1             # multiplier >>= 1
    beqz  t5, .Lmul_done        # multiplier == 0: done
    j     .Lmul
.Lmul_done:

    # 8. e = ea + eb - 127 + adj
    add   t2, t2, t3
    addi  t2, t2, -127
    add   t2, t2, a2

    # 9. bit 15 set: shift by 8 and e++, else shift by 7; keep 7 bits
    and   t6, a3, t1
    beqz  t6, .Lshift7
    srli  a3, a3, 8
    andi  a3, a3, 0x7F
    addi  t2, t2, 1
    j     .Lpack
.Lshift7:
    srli  a3, a3, 7
    andi  a3, a3, 0x7F

    # 10. e >= 0xFF: Inf; e <= 0: subnormal or zero; otherwise pack
.Lpack:
    bge   t2, a4, .LInf
    blez  t2, .Lsubnormal
    slli  t2, t2, 7
    or    a0, t0, t2
    or    a0, a0, a3
    ret

    # e <= 0: zero when e < -6, else shift the fraction right by 1 - e
.Lsubnormal:
    li    t6, -6
    blt   t2, t6, .Lzero
    addi  t6, zero, 1
    sub   t6, t6, t2            # t6 = 1 - e
    srl   a3, a3, t6
    or    a0, t0, a3
    ret

    # shared exits: zero, Inf, quiet NaN, a, b
.Lzero:
    and   a0, t0, t1            # signed zero
    ret
.LInf:
    li    a0, 0x7F80
    or    a0, a0, t0            # signed Inf
    ret
.LNaN:
    li    a0, 0x7FC0            # quiet NaN
    ret
.Lret_a:
    ret                         # a0 already holds a
.Lret_b:
    mv    a0, a1
    ret

    .size   bf16_mul_asm, .-bf16_mul_asm

    .globl  bf16_sqrt_asm
    .type   bf16_sqrt_asm, @function
    .align  2
bf16_sqrt_asm:
    li      a0, 0
    ret
    .size   bf16_sqrt_asm, .-bf16_sqrt_asm
