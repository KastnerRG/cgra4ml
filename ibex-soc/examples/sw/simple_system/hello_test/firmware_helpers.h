static unsigned rng_state = 1u;
void srand(unsigned seed) { rng_state = seed ? seed : 1u; }
int  rand(void) {
  // LCG: simple, small, good enough for test input
  rng_state = 1664525u * rng_state + 1013904223u;
  return (int)(rng_state >> 1);
}

static void mini_vprintf(const char *fmt, va_list ap) {
    for (const char *p = fmt; *p; ++p) {
        if (*p != '%') { putchar(*p); continue; }

        ++p;                          /* skip '%' */
        if (*p == '\0') break;

        if (*p == '%') {              /* "%%" -> '%' */
            putchar('%');
            continue;
        }

        /* We ignore flags/width/precision/length.
           Only recognize specifiers below. Everything else -> hex. */

        switch (*p) {
        case 's': {                   /* string */
            const char *s = va_arg(ap, const char *);
            if (s) puts(s);
            else   puts("(null)");
            break;
        }
        case 'c': {                   /* character */
            int ch = va_arg(ap, int);
            putchar(ch);
            break;
        }
        case 'p': {                   /* pointer -> hex */
            uintptr_t v = (uintptr_t)va_arg(ap, void *);
            puthex(v);
            break;
        }
        default: {                    /* any “number” -> hex */
            /* Read as uintptr_t to be forgiving; OK for RV32 Ibex.
               If the caller passed an int/unsigned/etc., the usual
               default promotions mean we can safely read as unsigned int
               on RV32. But using uintptr_t keeps it uniform for pointers too. */
#if UINTPTR_MAX == 0xffffffffu
            /* RV32: pull a 32-bit value */
            unsigned int v = va_arg(ap, unsigned int);
            puthex((uintptr_t)v);
#else
            /* RV64 (in case you ever cross-compile): pull 64-bit */
            unsigned long long v = va_arg(ap, unsigned long long);
            puthex((uintptr_t)v);
#endif
            break;
        }
        }
    }
}

int printf(const char *fmt, ...) {
    va_list ap;
    va_start(ap, fmt);
    mini_vprintf(fmt, ap);
    va_end(ap);
    return 0;
}

static inline void __assert_fail(const char* expr, const char* file, int line){
    puts("ASSERT "); puts(expr); puts(" @ "); puts(file); puts(":"); puthex((unsigned long)line); putchar('\n');
    for(;;){}
}
#  define assert(c) ((c) ? (void)0 : __assert_fail(#c, __FILE__, __LINE__))

static inline void flush_cache(void *addr, uint32_t bytes) {} // Do nothing

static inline int64_t exp(int64_t x)
{
    // /* Constants for range reduction: x ≈ k*ln2 + r */
    // const double INV_LN2 = 1.4426950408889634073599;   /* 1/ln(2) */
    // const double LN2     = 0.6931471805599453094172;   /* ln(2)   */

    // /* Compute k = round(x / ln2) without <math.h> */
    // int k;
    // if (x >= 0.0) k = (int)(x * INV_LN2 + 0.5);
    // else          k = (int)(x * INV_LN2 - 0.5);

    // /* Reduced argument r = x - k*ln(2) (single-constant version is fine here) */
    // double r = x - (double)k * LN2;

    // /* 5th-order Taylor for exp(r):
    //    e^r ≈ 1 + r + r^2/2! + r^3/3! + r^4/4! + r^5/5!
    //    Horner form for fewer mults. */
    // double p = 1.0 +
    //            r * (1.0 +
    //            r * (0.5 +
    //            r * (1.0/6.0 +
    //            r * (1.0/24.0 +
    //            r * (1.0/120.0)))));

    // /* Scale by 2^k using multiplies/divides only (no ldexp/scalbn). */
    // if (k > 0) {
    //     /* jump in chunks to keep loop short */
    //     while (k >= 16) { p *= 65536.0; k -= 16; }
    //     while (k--)     { p *= 2.0; }
    // } else if (k < 0) {
    //     while (k <= -16) { p *= 1.0/65536.0; k += 16; }
    //     while (k++)      { p *= 0.5; }
    // }
    // return p;
    return 0;
}

typedef struct { int quot; int rem; } div_t;

static inline div_t div(int numer, int denom) {
    div_t r; r.quot = numer / denom; r.rem = numer % denom; return r;
}

static inline int abs(int x) { return x < 0 ? -x : x; }

int usleep(int x) { return x; } // Do nothing