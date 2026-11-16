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


    # C: s5 = face bases, s7/s8 = pdb, s9/s10 = buckets, s0 = level 0 = sp
    # s5 = &.Lface_base             (la)
    la s5, .Lface_base
    # s7 = &rk_perm_pdb             (la)
    la s7, rk_perm_pdb
    # s8 = &rk_orient_pdb           (la)
    la s8, rk_orient_pdb
    # s9 = &rk_bucket_start         (la)
    la s9, rk_bucket_start
    # s10 = &rk_bucket_entry        (la)
    la s10, rk_bucket_entry
    # s0 = sp                       (mv: level 0 starts at the bottom of the frame)
    mv s0, sp
    # mem16[s0 + 0] = a3            (sh: ps = p)
    sh a3, 0(s0)
    # mem16[s0 + 2] = a4            (sh: os = o)
    sh a4, 2(s0)
    # a0 = a3                       (mv: lookup argument p)
    mv a0, a3
    # a1 = a4                       (mv: lookup argument o)
    mv a1, a4
    # call lookup                   (jal ra, .Llookup -> a0 = distance or -1)
    jal ra, .Llookup
    # a0 < 0: search                (bltz .Lsearch: more than 5 moves away)
    bltz a0, .Lsearch
    # s1 = a0                       (mv: k, moves left to walk)
    mv s1, a0
    # walk                          (j .Lwalk)
    j .Lwalk

.Lsearch:
    li   a0, 0          # temporary until part D
    j    .Lexit

    # E: s0 = level, s1 = k, t2 = face, t3 = &face_base[face],
    #    t4/t5 = perm/orient table of this face, a3/a4 = new cp/co
.Lwalk:
    # s1 == 0: write the output     (beqz .Lout)
    beqz s1, .Lout
    # mem16[s0 + 8] = 0             (sh zero, 8(s0): nf = 0 and nt = 0)
    sh x0, 8(s0)
    # t0 = mem32[s0 + 0]            (lw: ps and os together)
    lw t0, 0(s0)
    # mem32[s0 + 4] = t0            (sw: cp, co = ps, os)
    sw t0, 4(s0)
.Lw_try:
    # t2 = mem8[s0 + 8]             (lbu: nf)
    lbu t2, 8(s0)
    # t3 = t2 << 2                  (slli: face * 4, one word per face)
    slli t3, t2, 2
    # t3 = s5 + t3                  (&face_base[face])
    add t3, s5, t3  
    # t4 = mem32[t3]                (lw: perm table of this face)
    lw t4, 0(t3)
    # t5 = mem32[t3 + 12]           (lw: orient table, 3 words further)
    lw t5, 12(t3)
    # a3 = mem16[s0 + 4]            (lhu: cp)
    lhu a3, 4(s0)
    # a3 = a3 << 1                  (cp * 2 bytes)
    slli a3, a3, 1
    # a3 = t4 + a3                  (&perm_move[face][cp])
    add a3, t4, a3
    # a3 = mem16[a3]                (lhu: cp after one more quarter turn)
    lhu a3, 0(a3)
    # mem16[s0 + 4] = a3            (sh: store the new cp)
    sh a3, 4(s0)
    # a4 = mem16[s0 + 6]            (lhu: co)
    lhu a4, 6(s0)
    # a4 = a4 << 1
    slli a4, a4, 1
    # a4 = t5 + a4                  (&orient_move[face][co])
    add a4, t5, a4
    # a4 = mem16[a4]                (lhu: new co)
    lhu a4, 0(a4)
    # mem16[s0 + 6] = a4            (sh)
    sh a4, 6(s0)
    # t0 = mem8[s0 + 9]             (lbu: nt)
    lbu t0, 9(s0)
    # t0 = t0 + 1                   (one more quarter turn)
    addi t0, t0, 1
    # mem8[s0 + 9] = t0             (sb)
    sb t0, 9(s0)
    # a0 = a3                       (mv: lookup p)
    mv a0, a3
    # a1 = a4                       (mv: lookup o)
    mv a1, a4
    # call lookup                   (jal ra, .Llookup)
    jal ra, .Llookup
    # t0 = s1 - 1                   (addi: the distance we want)
    addi t0, s1, -1
    # a0 == t0: found               (beq .Lw_found)
    beq a0, t0, .Lw_found
    # t0 = mem8[s0 + 9]             (lbu: nt, lookup changed t0)
    lbu t0, 9(s0)
    # t1 = 3
    addi t1, x0, 3
    # t0 != t1: try the next turn   (bne .Lw_try: same face, one more turn)
    bne t0, t1, .Lw_try
    # t2 = mem8[s0 + 8]             (lbu: nf)
    lbu t2, 8(s0)
    # t2 = t2 + 1                   (next face)
    addi t2, t2, 1
    # mem8[s0 + 8] = t2             (sb)
    sb t2, 8(s0)
    # mem8[s0 + 9] = 0              (sb zero, 9(s0): nt = 0)
    sb x0, 9(s0)
    # t0 = mem32[s0 + 0]            (lw: ps, os)
    lw t0, 0(s0)
    # mem32[s0 + 4] = t0            (sw: cp, co start again from ps, os)
    sw t0, 4(s0)
    # loop                          (j .Lw_try)
    j .Lw_try
.Lw_found:
    # t0 = mem32[s0 + 4]            (lw: cp, co of this level)
    lw t0, 4(s0)
    # mem32[s0 + 16] = t0           (sw: ps, os of the next level)
    sw t0, 16(s0)
    # s0 = s0 + 16                  (next level)
    addi s0, s0, 16 
    # s1 = s1 - 1                   (one move closer)
    addi s1, s1, -1
    # loop                          (j .Lwalk)
    j .Lwalk

    # F1: need. t6 = n, t2 = end level, t1 = level, t0 = need, t3 = nt, t5 = 1
.Lout:
    # t6 = s0 - sp                  (sub: bytes of levels used)
    sub t6, s0, sp
    # t6 = t6 >> 4                  (srli: n = number of moves)
    srli t6, t6, 4
    # t0 = 1                        (need: the NUL)
    li t0, 1
    # t1 = sp                       (first move)
    mv t1, sp
    # t2 = t6 << 4                  (slli: n * 16)
    slli t2, t6, 4
    # t2 = sp + t2                  (end: level n)
    add t2, sp, t2
    # t5 = 1                        (turns == 1 takes one character)
    li t5, 1
.Lneed:
    # t1 >= t2 unsigned: done       (bgeu .Lneed_done)
    bgeu t1, t2, .Lneed_done
    # t1 == sp: no space            (beq to the next comment line's label)
    beq t1, sp,  .Lneed_nosp 
    # t0 = t0 + 1                   (the space before this move)
    addi t0, t0, 1
.Lneed_nosp:    
    # t3 = mem8[t1 + 9]             (lbu: nt of this move)
    lbu t3, 9(t1)
    # t0 = t0 + 1                   (the face letter)
    addi t0, t0, 1
    # t3 == t5: one character       (beq: R, B or D alone)
    beq t3, t5, .Lneed_one
    # t0 = t0 + 1                   (the '2' or the ')
    addi t0, t0, 1
.Lneed_one:
    # t1 = t1 + 16                  (next move)
    addi t1, t1, 16
    # loop                          (j .Lneed)
    j .Lneed
.Lneed_done:
    # s4 >= t0 unsigned: fits       (bgeu .Lwrite: cap >= need)
    bgeu s4, t0, .Lwrite
    # s4 == 0: skip the store       (beqz: cap 0 means out must not be touched)
    beqz s4, .Lneed_nostore 
    # mem8[s3] = 0                  (sb zero, 0(s3): out[0] = '\0')
    sb x0, 0(s3)
.Lneed_nostore:
    # a0 = -2
    addi a0, x0, -2                 # 不管 cap 是 0 還是 1..need-1，都回傳 -2
    # leave                         (j .Lexit)
    j .Lexit

    # F2: write. t1 = level, a1 = w, t4 = "RBD", t3 = character, t5 = 2, t0 = character
.Lwrite:
    # t1 = sp
    addi t1, sp, 0
    # a1 = s3                       (w = out)
    mv a1, s3
    # t4 = &.Lface_name             (la)
    la t4, .Lface_name
.Lw_loop:
    # t1 >= t2 unsigned: end        (bgeu .Lw_end)
    bgeu t1, t2, .Lw_end
    # t1 == sp: no space            (beq)
    beq  t1, sp, .Lw_nosp       # first move: skip the space only
    # t3 = 32                       (' ')
    addi t3, x0, 32
    # mem8[a1] = t3                 (sb)
    sb t3, 0(a1)
    # a1 = a1 + 1
    addi a1, a1, 1

.Lw_nosp:     
    # t3 = mem8[t1 + 8]             (lbu: nf)
    lbu t3, 8(t1)   
    # t3 = t4 + t3                  (&"RBD"[nf])
    add t3, t4, t3
    # t3 = mem8[t3]                 (lbu: 'R', 'B' or 'D')
    lbu t3, 0(t3)
    # mem8[a1] = t3                 (sb)
    sb t3, 0(a1)
    # a1 = a1 + 1
    addi a1, a1, 1
    # t3 = mem8[t1 + 9]             (lbu: nt)
    lbu t3, 9(t1)
    # t5 = 2
    addi t5, x0, 2
    # t3 < t5 unsigned: no suffix   (bltu: nt == 1)
    bltu t3, t5, .Lw_no_suffix
    # t0 = 50                       ('2')
    addi t0, x0, 50
    # t3 == t5: store it            (beq: nt == 2)
    beq t3, t5, .Lw_store_suffix
    # t0 = 39                       (the quote, nt == 3)
    addi t0, x0, 39
.Lw_store_suffix:
    # mem8[a1] = t0                 (sb: the suffix)
    sb t0, 0(a1)
    # a1 = a1 + 1
    addi a1, a1, 1
    # t1 = t1 + 16                  (next move)
    addi t1, t1, 16
    # loop                          (j .Lw_loop)
    j .Lw_loop
.Lw_no_suffix:
    # t1 = t1 + 16                  (next move)
    addi t1, t1, 16
    # loop                          (j .Lw_loop)
    j .Lw_loop  
.Lw_end:
    # mem8[a1] = 0                  (sb zero: the NUL)
    sb x0, 0(a1)
    # a0 = t6                       (mv: return n)
    mv a0, t6
    # leave                         (j .Lexit)
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

    # lookup: a0 = p, a1 = o -> a0 = distance or -1
    #         t0 = &start[p] then entry o, t1 = e, t2 = end, t3 = entry
    #         uses only t0..t3, a0: calls nothing, so no stack and no ra save
.Llookup:
    # t0 = a0 << 1                  (p * 2: start[] is half words)
    slli t0, a0, 1
    # t0 = s9 + t0                  (&bucket_start[p])
    add t0, s9, t0
    # t1 = mem16[t0]                (lhu t1, 0(t0): first entry index)
    lhu t1, 0(t0)
    # t2 = mem16[t0 + 2]            (lhu t2, 2(t0): start[p + 1] = end index)
    lhu t2, 2(t0)
    # t1 = t1 << 1                  (index * 2 bytes)
    slli t1, t1, 1
    # t1 = s10 + t1                 (e = &bucket_entry[first])
    add t1, s10, t1
    # t2 = t2 << 1
    slli t2, t2, 1
    # t2 = s10 + t2                 (end = &bucket_entry[last + 1])
    add t2, s10, t2
.Llk_loop:
    # t1 >= t2 unsigned: miss       (bgeu .Llk_miss: bucket used up)
    bgeu t1, t2, .Llk_miss
    # t3 = mem16[t1]                (lhu: o << 3 | distance)
    lhu t3, 0(t1)
    # t0 = t3 >> 3                  (srli: this entry's o)
    srli t0, t3, 3
    # t0 == a1: hit                 (beq .Llk_hit)
    beq t0, a1, .Llk_hit
    # a1 < t0 unsigned: miss        (bltu .Llk_miss: sorted, went past o)
    bltu a1, t0, .Llk_miss
    # t1 = t1 + 2                   (next entry)
    addi t1, t1, 2
    # loop                          (j .Llk_loop)
    j .Llk_loop
.Llk_hit:
    # a0 = t3 & 7                   (andi: the distance)
    andi a0, t3, 7
    # return                        (ret)
    ret

.Llk_miss:
    # a0 = -1
    addi a0, x0, -1
    # return                        (ret)
    ret


    .section .rodata
    .balign 4
.Lface_base:
    .word   rk_perm_move, rk_perm_move + 10080, rk_perm_move + 20160
    .word   rk_orient_move, rk_orient_move + 1458, rk_orient_move + 2916
.Lface_name:
    .ascii  "RBD"
    .text

    .size   rubik_solve_asm, .-rubik_solve_asm




