#include "bf16.h"

/* Dummies: every function returns 0. Replace with the real routines. */
uint16_t bf16_from_f32(uint32_t f32bits)
{
    uint32_t exp = (f32bits >> 23) & 0xFF;

    if (exp == 0xFF) {
        return (uint16_t) (f32bits >> 16);
    }

    f32bits += 0x7FFF + ((f32bits >> 16) & 0x1);
    return (uint16_t) (f32bits >> 16);
}

uint16_t bf16_mul(uint16_t a, uint16_t b)
{
    uint16_t sign = (a ^ b) & 0x8000;
    int32_t ea = (a >> 7) & 0xFF, eb = (b >> 7) & 0xFF;
    uint32_t ma = a & 0x7F, mb = b & 0x7F;
    int32_t adj = 0;

    /* Special values: check a first, then b */
    if (ea == 0xFF) {
        if (ma)
            return a; /* NaN propagates */
        if (!eb && !mb)
            return 0x7FC0; /* Inf * 0 is NaN */
        return sign | 0x7F80;
    }
    if (eb == 0xFF) {
        if (mb)
            return b;
        if (!ea && !ma)
            return 0x7FC0;
        return sign | 0x7F80;
    }

    /* Either operand is +0 or -0 */
    if ((a & 0x7FFF) == 0 || (b & 0x7FFF) == 0)
        return sign;

    /* Normalize subnormals, otherwise restore the implicit 1 */
    if (!ea) {
        while (!(ma & 0x80)) {
            ma <<= 1;
            adj--;
        }
        ea = 1;
    } else {
        ma |= 0x80;
    }
    if (!eb) {
        while (!(mb & 0x80)) {
            mb <<= 1;
            adj--;
        }
        eb = 1;
    } else {
        mb |= 0x80;
    }

    /* 8x8-bit product lies in [1, 4) as a value scaled by 2^14 */
    uint32_t m = ma * mb;
    int32_t e = ea + eb - 127 + adj;

    /* Keep 7 fraction bits, truncating the rest */
    if (m & 0x8000) {
        m = (m >> 8) & 0x7F;
        e++;
    } else {
        m = (m >> 7) & 0x7F;
    }

    /* Overflow to Inf, underflow to subnormal or zero */
    if (e >= 0xFF)
        return sign | 0x7F80;
    if (e <= 0) {
        if (e < -6)
            return sign;
        m >>= 1 - e;
        e = 0;
    }
    return sign | ((e & 0xFF) << 7) | (m & 0x7F);
}

uint16_t bf16_sqrt(uint16_t a)
{
    uint32_t exp = (a >> 7) & 0xFF, mant = a & 0x7F;

    if (exp == 0xFF) {
        if (mant)
            return a;
        if (a & 0x8000)
            return 0x7FC0;
        return a;
    }
    if (a == 0x8000 || a == 0x0000)
        return 0x0000;
    if (a & 0x8000)
        return 0x7FC0;
    if (!exp)
        return 0x0000;

    int32_t e = (int32_t) exp - 127, new_exp;
    uint32_t m = 0x80 | mant;
    if (e & 1) {
        m <<= 1;
        new_exp = ((e - 1) >> 1) + 127;
    } else {
        new_exp = (e >> 1) + 127;
    }

    uint32_t low = 90, high = 256, result = 128;
    while (low <= high) {
        uint32_t mid = (low + high) >> 1;
        if ((mid * mid) / 128 <= m) {
            result = mid;
            low = mid + 1;
        } else {
            high = mid - 1;
        }
    }
    return (uint16_t) ((new_exp << 7) | (result & 0x7F));
}
