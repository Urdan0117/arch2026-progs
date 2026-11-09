#include "fixed.h"

uint32_t op1(uint32_t a, uint32_t b, int *n)
{
    int count = 0;

    while (b) {
        uint32_t c = (a & b) << 1;
        a = a ^ b;
        b = c;
        count++;
    }

    *n = count;
    return a;
}

uint32_t op2(uint32_t a, uint32_t b)
{
    return a - b;
}

uint32_t op3(uint32_t a, uint32_t b)
{
    return ((a ^ b) >> 1) + (a & b);
}

int32_t q_mul(int32_t a, int32_t b)
{
    uint32_t x_lo = (uint32_t) a, x_hi = 0;
    uint32_t y = (uint32_t) b;
    uint32_t lo = 0, hi = 0;

    while (y != 0) {
        if (y & 1) {
            uint32_t old = lo;
            lo += x_lo;
            hi += x_hi + (lo < old);
        }
        x_hi = (x_hi << 1) | (x_lo >> 31);
        x_lo = x_lo << 1;
        y = y >> 1;
    }

    if (a < 0)
        hi -= b;
    if (b < 0)
        hi -= a;

    hi += lo >= 0xFFF80000u;
    lo += 1u << 19;

    return (int32_t) ((hi << 12) | (lo >> 20));
}