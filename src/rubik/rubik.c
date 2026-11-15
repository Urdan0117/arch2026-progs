#include "rubik.h"
#include <stdint.h>
#include "rubik_tables.h"

/* 合法就填 *p、*o 並回傳 0；不合法回傳 -1。 */
static int parse_state(const char *s, uint16_t *p, uint16_t *o)
{
    unsigned seen = 0, sum = 0;

    /* 1. 前 7 碼：'1'..'7'，而且不能重複 */
    for (int i = 0; i < 7; ++i) {
        if (s[i] < '1' || s[i] > '7')
            return -1;
        unsigned bit = 1 << (s[i] - '1');
        if (seen & bit)
            return -1;
        seen |= bit;
    }

    /* 2. 後 7 碼：'1'..'3'，順便加總 (值 - 1) */
    for (int i = 7; i < 14; ++i) {
        if (s[i] < '1' || s[i] > '3')
            return -1;
        sum += s[i] - '1';
    }

    /* 3. 前 14 碼都合格，才可以看第 15 個字元 */
    if (s[14] != '\0')
        return -1;

    /* 4. 3 的倍數：最多減 4 次 */
    while (sum >= 3)
        sum -= 3;
    if (sum != 0)
        return -1;

    /* 5. 排列 rank：p = p × (7 − i) + 後面比我小的個數 */
    unsigned pr = 0;
    for (int i = 0; i < 7; ++i) {
        unsigned smaller = 0;
        for (int j = i + 1; j < 7; ++j)
            if (s[j] < s[i])
                ++smaller;
        pr = pr * (7 - i) + smaller;
    }

    /* 6. 方向 rank：只用前 6 碼（第 7 碼由總和決定） */
    unsigned orr = 0;
    for (int i = 7; i < 13; ++i)
        orr = orr * 3 + (s[i] - '1');

    *p = (uint16_t) pr;
    *o = (uint16_t) orr;
    return 0;
}

static uint8_t h(uint16_t p, uint16_t o)
{
    uint8_t hp = perm_pdb[p], ho = orient_pdb[o];
    return hp > ho ? hp : ho;
}

/* 回傳最短步數，faces[]、turns[] 填解答。 */
static int ida_star(uint16_t p0,
                    uint16_t o0,
                    uint8_t faces[11],
                    uint8_t turns[11])
{
    uint16_t ps[12], os[12], cp[12], co[12];
    uint8_t nf[12], nt[12];

    for (int bound = h(p0, o0); bound <= 11; ++bound) {
        /* 1. 第 0 層從起點開始，還沒試任何一面 */
        int d = 0;
        ps[0] = p0;
        os[0] = o0;
        cp[0] = p0;
        co[0] = o0;
        nf[0] = 0;
        nt[0] = 0;

        while (d >= 0) {
            /* 2. 已解就回傳 */
            if (ps[d] == 0 && os[d] == 0)
                return d;

            /* 3. 這一面轉滿 3 次：換下一面，cp/co 回到這層的起點 */
            if (nt[d] == 3) {
                ++nf[d];
                nt[d] = 0;
                cp[d] = ps[d];
                co[d] = os[d];
            }

            /* 4. 三面都試完：回上一層 */
            if (nf[d] == 3) {
                --d;
                continue;
            }

            /* 5. 和上一步同一面：整面跳過（假裝已經轉滿 3 次） */
            if (d > 0 && nf[d] == nf[d - 1]) {
                nt[d] = 3;
                continue;
            }

            /* 6. 在目前結果上再轉一次四分之一轉，對 cp[d]
             * 轉一次四分之一轉，面是 nf[d]*/
            cp[d] = perm_move[nf[d]][cp[d]];
            co[d] = orient_move[nf[d]][co[d]];
            ++nt[d];

            /* 7. 剪枝：走到這一步 + 至少還要幾步 > bound 就不往下 */
            if (h(cp[d], co[d]) + d + 1 > bound)
                continue;

            /* 8. 往下一層：記下這一步，新的一層從 cp/co 開始 */
            faces[d] = nf[d];
            turns[d] = nt[d];
            ++d;
            /* (h) 六行：ps、os、cp、co、nf、nt */
            ps[d] = cp[d - 1];
            os[d] = co[d - 1];
            cp[d] = ps[d];
            co[d] = os[d];
            nf[d] = 0;
            nt[d] = 0;
        }
    }
    return -1;
}

int rubik_solve(const char *state, char *out, size_t cap)
{
    uint16_t p, o;
    uint8_t faces[11], turns[11];
    if (parse_state(state, &p, &o))
        return -1;

    int n = ida_star(p, o, faces, turns);

    /* 1. 算需要幾個 byte：每步 1 或 2 個字元，步和步之間 1 個空白，最後 1 個
     * '\0' */
    size_t need = 1; /* '\0' */
    for (int i = 0; i < n; ++i) {
        if (i > 0)
            ++need;                    /* 空白 */
        need += turns[i] == 1 ? 1 : 2; /* 1 或 2 個字元 */
    }

    /* 2. 放不下：cap ≥ 1 才能寫 out[0] */
    if (cap < need) {
        if (cap >= 1)
            out[0] = '\0';
        return -2;
    }

    /* 3. 一步一步寫 */
    static const char face_name[3] = {'R', 'B', 'D'};
    char *w = out;
    for (int i = 0; i < n; ++i) {
        if (i > 0)
            *w++ = ' ';
        *w++ = face_name[faces[i]];
        if (turns[i] == 2)
            *w++ = '2';
        else if (turns[i] == 3)
            *w++ = '\'';
    }
    *w = '\0';
    return n;
}