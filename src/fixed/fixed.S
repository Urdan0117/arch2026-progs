# op1, op2, op3 and q_mul: hand-written RV32I.
#
# uint32_t op1_asm(uint32_t a, uint32_t b, int *n)   a0, a1, a2 -> a0
# uint32_t op2_asm(uint32_t a, uint32_t b)           a0, a1 -> a0
# uint32_t op3_asm(uint32_t a, uint32_t b)           a0, a1 -> a0
# int32_t  q_mul_asm(int32_t a, int32_t b)           a0, a1 -> a0
#
# RV32I and Zicsr only: no mul, div, rem, no floating point, no compressed
# instructions. q_mul forms a 64-bit product in a register pair. Tests:
# tests/tfixed.c.

    .text

    .globl  op1_asm
    .type   op1_asm, @function
    .align  2
op1_asm:
    # a0 = a, a1 = b, a2 = n; t0 = pass count, t1 = carry
    add  t0, x0, x0
    beq  a1, x0, .L_op1_done
.L_op1_loop:
    and  t1, a0, a1         # carry bits
    xor  a0, a0, a1         # sum without carry; reads b before it changes
    slli a1, t1, 1          # b = carry << 1
    addi t0, t0, 1
    bne  a1, x0, .L_op1_loop
.L_op1_done:
    sw   t0, 0(a2)          # *n = pass count; the sum is already in a0
    ret
    .size   op1_asm, .-op1_asm

    .globl  op2_asm
    .type   op2_asm, @function
    .align  2
op2_asm:
    # a0 = a, a1 = b -> a0
    # a - b
    sub a0, a0, a1
    ret
    .size   op2_asm, .-op2_asm

    .globl  op3_asm
    .type   op3_asm, @function
    .align  2
op3_asm:
    # a0 = a, a1 = b -> a0; t0 = a & b
    and t0, a0, a1
    # 2. a ^ b
    xor a0, a0, a1
    # 3. shift right by one, unsigned
    srli a0, a0, 1
    # 4. add the two terms
    add a0, a0, t0
    ret
    .size   op3_asm, .-op3_asm

    .globl  q_mul_asm
    .type   q_mul_asm, @function
    .align  2
q_mul_asm:
    # a0 = a, a1 = b -> a0
    # t0=carry, t1= x_lo,t2 = x_hi,t3 = y, t4 = lo, t5 = hi, t6 = scratch
    # 1. x_lo = a, x_hi = 0, y = b, lo = 0, hi = 0
    addi   t1, a0, 0
    addi   t2, x0, 0
    addi   t3, a1, 0
    addi   t4, x0, 0
    addi   t5, x0, 0
    # 2. if y == 0, skip the loop
    beq    t3, x0, .Lq_done
.Lq_loop:
    # 3. if the low bit of y is 0, skip the add
    andi   t6, t3, 1
    beq    t6, x0, .Lq_skip
    # 4. lo += x_lo; carry = (lo < x_lo); hi += x_hi + carry
    add    t4, t4, t1
    sltu   t0, t4, t1
    add    t5, t5, t2
    add    t5, t5, t0   
.Lq_skip:
    # 5. shift x_hi:x_lo left by one; x_hi takes the top bit of x_lo
    srli   t6, t1, 31
    slli   t1, t1, 1
    slli   t2, t2, 1
    or     t2, t2, t6
    # 6. y >>= 1; repeat while y != 0
    srli   t3, t3, 1
    bne    t3, x0, .Lq_loop
.Lq_done:
    # 7. if a < 0, hi -= b
    bgez   a0, .Lq_skip_hi_sub
    sub    t5, t5, a1
.Lq_skip_hi_sub:   
    # 8. if b < 0, hi -= a
    bgez   a1, .Lq_afterskip
    sub    t5, t5, a0
.Lq_afterskip:
    # 9. lo += 2^19, carry into hi
    li     t6, 0x80000
    add    t4, t4, t6
    sltu   t0, t4, t6
    add    t5, t5, t0
    # 10. a0 = (hi << 12) | (lo >> 20)
    slli   t5, t5, 12
    srli   t4, t4, 20
    or     a0, t5, t4
    ret
    .size   q_mul_asm, .-q_mul_asm
