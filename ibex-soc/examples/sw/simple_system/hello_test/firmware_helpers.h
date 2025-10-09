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

static inline int32_t exp(int32_t x) { return x; } // Exp is only used in softmax. We run models without softmax in ibex

static inline int abs(int x) { return x < 0 ? -x : x; }

int usleep(int x) { return x; } // Do nothing