/*
 * clock.c — Optional native high-resolution clock for Lua 5.1+.
 *
 * Provides nanosecond-resolution wall-clock timing without LuaJIT FFI.
 * Auto-detected by chrono.timer; not required — os.clock() is the fallback.
 *
 * Build:
 *   Linux/macOS:  cc -O2 -shared -fPIC -o clock.so clock.c -llua5.1
 *   Windows MSVC: cl /O2 /LD clock.c /I<lua-include> lua51.lib /Fe:clock.dll
 *   Windows GCC:  gcc -O2 -shared -o clock.dll clock.c -I<lua-include> -llua51
 *
 * The resulting .so/.dll must sit in c/ (the cpath picks it up as chrono.clock).
 */

#ifdef _WIN32
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <time.h>
#else
#include <time.h>
#ifdef __APPLE__
#include <mach/mach_time.h>
#endif
#endif

#include <lua.h>
#include <lauxlib.h>

/* ------------------------------------------------------------------ */
/* Wall-clock: highest-resolution monotonic source per platform       */
/* ------------------------------------------------------------------ */

#ifdef _WIN32

static double qpc_frequency = 0.0;

static void init_wall(void)
{
    LARGE_INTEGER freq;
    QueryPerformanceFrequency(&freq);
    qpc_frequency = (double)freq.QuadPart;
}

static int l_wall(lua_State *L)
{
    LARGE_INTEGER ctr;
    QueryPerformanceCounter(&ctr);
    lua_pushnumber(L, (double)ctr.QuadPart / qpc_frequency);
    return 1;
}

#elif defined(__APPLE__) && !defined(CLOCK_MONOTONIC)

/* macOS < 10.12: fall back to mach_absolute_time */
static double mach_timebase = 0.0;

static void init_wall(void)
{
    mach_timebase_info_data_t info;
    mach_timebase_info(&info);
    mach_timebase = (double)info.numer / (double)info.denom * 1e-9;
}

static int l_wall(lua_State *L)
{
    lua_pushnumber(L, (double)mach_absolute_time() * mach_timebase);
    return 1;
}

#else

/* POSIX: clock_gettime(CLOCK_MONOTONIC) */
static void init_wall(void) { /* nothing */ }

static int l_wall(lua_State *L)
{
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    lua_pushnumber(L, (double)ts.tv_sec + (double)ts.tv_nsec * 1e-9);
    return 1;
}

#endif

/* ------------------------------------------------------------------ */
/* CPU-time (higher resolution than os.clock on some platforms)       */
/* ------------------------------------------------------------------ */

#ifdef _WIN32

static int l_cpu(lua_State *L)
{
    /* GetProcessTimes gives 100-ns units */
    FILETIME creation, exit_t, kernel, user;
    if (GetProcessTimes(GetCurrentProcess(), &creation, &exit_t, &kernel, &user))
    {
        ULARGE_INTEGER k, u;
        k.LowPart = kernel.dwLowDateTime;
        k.HighPart = kernel.dwHighDateTime;
        u.LowPart = user.dwLowDateTime;
        u.HighPart = user.dwHighDateTime;
        lua_pushnumber(L, (double)(k.QuadPart + u.QuadPart) * 1e-7);
    }
    else
    {
        lua_pushnumber(L, (double)clock() / (double)CLOCKS_PER_SEC);
    }
    return 1;
}

#else

static int l_cpu(lua_State *L)
{
#ifdef CLOCK_PROCESS_CPUTIME_ID
    struct timespec ts;
    clock_gettime(CLOCK_PROCESS_CPUTIME_ID, &ts);
    lua_pushnumber(L, (double)ts.tv_sec + (double)ts.tv_nsec * 1e-9);
#else
    lua_pushnumber(L, (double)clock() / (double)CLOCKS_PER_SEC);
#endif
    return 1;
}

#endif

/* ------------------------------------------------------------------ */
/* Source name strings                                                 */
/* ------------------------------------------------------------------ */

static int l_wall_source(lua_State *L)
{
#ifdef _WIN32
    lua_pushliteral(L, "QueryPerformanceCounter (C)");
#elif defined(__APPLE__) && !defined(CLOCK_MONOTONIC)
    lua_pushliteral(L, "mach_absolute_time (C)");
#else
    lua_pushliteral(L, "clock_gettime(MONOTONIC) (C)");
#endif
    return 1;
}

static int l_cpu_source(lua_State *L)
{
#if defined(_WIN32)
    lua_pushliteral(L, "GetProcessTimes (C)");
#elif defined(CLOCK_PROCESS_CPUTIME_ID)
    lua_pushliteral(L, "clock_gettime(PROCESS_CPUTIME) (C)");
#else
    lua_pushliteral(L, "clock() (C)");
#endif
    return 1;
}

/* ------------------------------------------------------------------ */
/* Module registration                                                */
/* ------------------------------------------------------------------ */

static const luaL_Reg funcs[] = {
    {"wall", l_wall},
    {"cpu", l_cpu},
    {"wall_source", l_wall_source},
    {"cpu_source", l_cpu_source},
    {NULL, NULL}};

#ifdef _WIN32
__declspec(dllexport)
#endif
int luaopen_chrono_clock(lua_State *L)
{
    init_wall();
#if LUA_VERSION_NUM >= 502
    luaL_newlib(L, funcs);
#else
    luaL_register(L, "chrono_clock", funcs);
#endif
    return 1;
}
