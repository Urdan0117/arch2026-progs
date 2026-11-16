# rubik_solve_asm: optimal 2x2x2 cube solver, hand-written RV32I.
#
# int rubik_solve_asm(const char *state, char *out, size_t cap)
#                                   a0 = state, a1 = out, a2 = cap; result in a0
#
# RV32I and Zicsr only: no mul, div, rem, no floating point, no compressed
# instructions, no heap, no recursion. Tests: tests/trubik.c.

    .text

    .globl  rubik_solve_asm
    .type   rubik_solve_asm, @function
    .align  2
rubik_solve_asm:
    # a0 = state
    # a1 = out 
    # a2 = cap -> a0 = moves, -1 or -2
    # A. 開 240 byte 的堆疊框
    addi    sp, sp, -240
    # A. 存 ra 到 236(sp)
    sw     ra, 236(sp)
    # A. 存 s0 到 232(sp)
    sw    s0, 232(sp)
    #    … s1 到 s10，每個往下 4
    sw    s1, 228(sp)
    sw    s2, 224(sp)
    sw    s3, 220(sp)
    sw    s4, 216(sp)       
    sw    s5, 212(sp)   
    sw    s6, 208(sp)
    sw    s7, 204(sp)
    sw    s8, 200(sp)
    sw    s9, 196(sp)
    sw    s10, 192(sp)
    # A. out 搬到 s3,
    mv    s3, a1
    # A. cap 搬到 s4
    mv    s4, a2


    # t0=seen, t1=i, t2=addr, t3=val, t4=mask, t5=tmp, t6=7

    # B1. seen = 0（t0）
    addi    t0, x0, 0
    # B1. i = 0（t1）
    addi    t1, x0, 0
    # B1. 常數 7（t6）
    addi    t6, x0, 7
.Lperm_chk:
    # 位址 = state + i（t2）
    add    t2, a0, t1
    # 讀 1 byte 到 t3
    lbu     t3, 0(t2)
    # t3 減 '1'
    addi   t3, t3, -'1'
    # 無號 t3 >= 7 → .Linvalid
    bgeu   t3, t6, .Linvalid
    # t4 = 1
    addi   t4, x0, 1
    # t4 = 1 << t3
    sll    t4, t4, t3
    # t5 = seen & t4
    and    t5, t0, t4
    # t5 不是 0 → .Linvalid（重複）
    bne    t5, x0, .Linvalid
    # seen |= t4
    or     t0, t0, t4
    # i + 1
    addi   t1, t1, 1
    # i < 7 → 回 .Lperm_chk
    blt    t1, t6, .Lperm_chk

    # B2: t0 = sum, t1 = i (still 7 from B1), t6 = 3, t5 = 14, t3 = c
    # t0 = 0                        (sum of orientation digits minus one)
    add t0, x0, x0
    # t6 = 3                        (digit limit: valid c is 0..2)
    addi t6, x0, 3
    # t5 = 14                       (loop limit)
    addi t5, x0, 14
.Lori_chk:
    # t2 = a0 + t1                  (&s[i])
    add t2, a0, t1
    # t3 = mem8[t2]                 (lbu: s[i])
    lbu t3, 0(t2)
    # t3 = t3 - '1'                 (c, valid: 0..2)
    addi t3, t3, -'1'
    # t3 >= t6 unsigned: invalid    (bgeu)
    bgeu t3, t6, .Linvalid
    # t0 = t0 + t3                  (sum += c)
    add t0, t0, t3
    # t1 = t1 + 1                   (i++)
    addi t1, t1, 1
    # t1 < t5: loop                 (blt)
    blt t1, t5, .Lori_chk
    # t3 = mem8[a0 + 14]            (lbu t3, 14(a0): must be the NUL)
    lbu t3, 14(a0)
    # t3 != 0: invalid              (bnez: string longer than 14)
    bnez t3, .Linvalid

    # B3: t0 = sum, t6 = 3
.Lmod3:
    # t0 < t6 unsigned: done        (bltu: sum is now 0, 1 or 2)
    bltu t0, t6, .Lmod3_done
    # t0 = t0 - 3                   (addi)
    addi t0, t0, -3
    # loop                          (j .Lmod3)
    j .Lmod3
.Lmod3_done:
    # t0 != 0: invalid              (bnez: not a multiple of 3)
    bnez t0, .Linvalid

    # B4: a3 = p, t1 = i, t4 = count then j, t5 = 7, t2 = old p then address,
    #     t3 = s[i], a5 = s[j]
    # a3 = 0                        (p)
    add a3, x0, x0
    # t1 = 0                        (i)
    addi t1, x0, 0
    # t5 = 7
    addi t5, x0, 7
.Lrank_i:
    # t4 = t5 - t1                  (7 - i, at least 1)
    sub t4, t5, t1
    # t2 = a3                       (mv: old p)
    mv  t2, a3
    # a3 = 0                        (p will become old p * (7 - i))
    add a3, x0, x0
.Lmul:
    # a3 = a3 + t2                  (add old p once)
    add a3, a3, t2
    # t4 = t4 - 1
    addi t4, t4, -1
    # t4 != 0: loop                 (bnez .Lmul: added 7 - i times)
    bnez t4, .Lmul
    # t2 = a0 + t1                  (&s[i])
    add t2, a0, t1
    # t3 = mem8[t2]                 (lbu: s[i])
    lbu t3, 0(t2)
    # t4 = t1 + 1                   (j = i + 1)
    add t4, t1, 1
.Lrank_j:
    # t4 >= t5: next i              (bge .Lrank_next: j reached 7)
    bge t4, t5, .Lrank_next
    # t2 = a0 + t4                  (&s[j])
    add t2, a0, t4
    # a5 = mem8[t2]                 (lbu: s[j])
    lbu a5, 0(t2)
    # a5 >= t3 unsigned: skip       (bgeu .Lnot_smaller: s[j] is not smaller)
    bgeu a5, t3, .Lnot_smaller
    # a3 = a3 + 1                   (++smaller, added straight into p)
    addi a3, a3, 1
.Lnot_smaller:
    # t4 = t4 + 1                   (j++)
    addi t4, t4, 1
    # loop                          (j .Lrank_j)
    j .Lrank_j
.Lrank_next:
    # t1 = t1 + 1                   (i++)
    addi t1, t1, 1
    # t1 < t5: loop                 (blt .Lrank_i)
    blt t1, t5, .Lrank_i

    # B5: a4 = o, t1 = i, t5 = 13, t3 = digit, t2 = address then o * 2
    # a4 = 0                        (o)
    add a4, x0, x0
    # t1 = 7                        (i)
    addi t1, x0, 7
    # t5 = 13                       (only the first six orientation digits)
    addi t5, x0, 13
.Lorank:
    # t2 = a0 + t1                  (&s[i])
    add t2, a0, t1
    # t3 = mem8[t2]                 (lbu: s[i])
    lbu t3, 0(t2)
    # t3 = t3 - '1'                 (digit 0..2)
    addi t3, t3, -49
    # t2 = a4 << 1                  (slli: o * 2)
    slli t2, a4, 1
    # a4 = a4 + t2                  (o * 3)
    add a4, a4, t2
    # a4 = a4 + t3                  (o * 3 + digit)
    add a4, a4, t3
    # t1 = t1 + 1                   (i++)
    addi t1, t1, 1
    # t1 < t5: loop                 (blt)
    blt t1, t5, .Lorank

    # temporary check: a0 = a3 + a4, jump to .Lexit
    add a0, a3, a4
    j .Lexit


.Linvalid:
    # a0 = -1
    addi a0, x0, -1
.Lexit:
    # 還原 ra、s0 … s10（和存的時候同一個位置）
    lw     ra, 236(sp)
    lw     s0, 232(sp)
    lw     s1, 228(sp)
    lw     s2, 224(sp)
    lw     s3, 220(sp)
    lw     s4, 216(sp)
    lw     s5, 212(sp)
    lw     s6, 208(sp)
    lw     s7, 204(sp)
    lw     s8, 200(sp)
    lw     s9, 196(sp)
    lw     s10, 192(sp)
    # 收回 240 byte
    addi    sp, sp, 240
    # 回傳
    ret
    .size   rubik_solve_asm, .-rubik_solve_asm




