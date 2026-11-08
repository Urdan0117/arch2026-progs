# gcd_u32_asm: binary GCD, hand-written RV32I.
#
# uint32_t gcd_u32_asm(uint32_t a, uint32_t b)   a in a0, b in a1, result in a0
#
# Registers: t0 counts the shared factors of two, t1 is a scratch value for
# parity tests, t2 is the temporary of the swap. No stack is used.
#
# RV32I and Zicsr only: no mul, div, rem, no floating point, no compressed
# instructions. Tests: tests/tgcd.c.

    .text

    .globl  gcd_u32_asm
    .type   gcd_u32_asm, @function
    .align  2
gcd_u32_asm:
    beq     a0, x0, .L_alt          # a is zero: the answer is b
    beq     a1, x0, .L_end          # b is zero: a0 already holds a
    addi    t0, x0, 0               # shared twos = 0

    # 1. Strip the factors of two that a and b share, counting them in t0.
.L_both:
    or      t1, a0, a1              # bit 0 is 0 only if both are even
    andi    t1, t1, 1               # keep the parity bit
    bne     t1, x0, .L_left         # one of them is odd: no more shared twos
    srli    a0, a0, 1               # a /= 2 (logical: values are unsigned)
    srli    a1, a1, 1               # b /= 2
    addi    t0, t0, 1               # one more shared two
    jal     x0, .L_both

    # 2. Make a odd. Its remaining twos are not shared, so drop them.
.L_left:
    andi    t1, a0, 1               # parity of a
    bne     t1, x0, .L_right        # a is odd: go work on b
    srli    a0, a0, 1               # a /= 2
    jal     x0, .L_left

    # 3. Make b odd, for the same reason.
.L_right:
    andi    t1, a1, 1               # parity of b
    bne     t1, x0, .L_order        # b is odd: compare
    srli    a1, a1, 1               # b /= 2
    jal     x0, .L_right

    # 4. Keep a <= b, then b -= a. Both are odd, so b becomes even or 0.
.L_order:
    bgeu    a1, a0, .L_step         # b >= a (unsigned): no swap needed
    addi    t2, a0, 0               # swap a and b through t2
    addi    a0, a1, 0
    addi    a1, t2, 0
.L_step:
    sub     a1, a1, a0              # b -= a
    bne     a1, x0, .L_right        # b is not zero yet: repeat

    # 5. Put the shared factor 2^t0 back.
    sll     a0, a0, t0
    jalr    x0, ra, 0

.L_alt:
    addi    a0, a1, 0               # return b
.L_end:
    jalr    x0, ra, 0

    .size   gcd_u32_asm, .-gcd_u32_asm
