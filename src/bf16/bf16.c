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
    (void) a;
    (void) b;
    return 0;
}

uint16_t bf16_sqrt(uint16_t a)
{
    (void) a;
    return 0;
}
