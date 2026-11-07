#include "gcd.h"

/* Binary GCD: uses only shifts, compares and subtraction, no division. */

/*
 * Count the trailing zero bits of x by binary search (16, 8, 4, 2, 1 bits).
 * The caller makes sure x is not 0.
 */
static uint32_t ctz32(uint32_t x)
{
    uint32_t n = 0;
    if ((x & 0xFFFFu) == 0) {
        n += 16;
        x >>= 16;
    }
    if ((x & 0xFFu) == 0) {
        n += 8;
        x >>= 8;
    }
    if ((x & 0xFu) == 0) {
        n += 4;
        x >>= 4;
    }
    if ((x & 0x3u) == 0) {
        n += 2;
        x >>= 2;
    }
    if ((x & 1u) == 0) {
        n += 1;
    }
    return n;
}

uint32_t gcd_u32(uint32_t a, uint32_t b)
{
    /* 1. Edge cases: gcd(0, b) = b and gcd(a, 0) = a */
    if (a == 0) {
        return b;
    }
    if (b == 0) {
        return a;
    }
    /* 2. k = number of factors of 2 that a and b share */
    uint32_t k = ctz32(a | b);
    /* 3. Drop the factors of 2 in a, so a becomes odd */
    a >>= ctz32(a);
    /* 4. Loop: make b odd, keep a <= b, then b -= a, until b == 0 */
    while (b) {
        b >>= ctz32(b); /* drop the factors of 2 in b, so b becomes odd */
        if (a > b) {    /* swap so that a <= b */
            uint32_t t = a;
            a = b;
            b = t;
        } else {
            b -= a;
        }
    }
    /* 5. Put the shared factor 2^k back */
    a = a << k;
    return a;
}
