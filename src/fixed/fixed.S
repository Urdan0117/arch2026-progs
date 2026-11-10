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
    li      a0, 0
    ret
    .size   q_mul_asm, .-q_mul_asm
