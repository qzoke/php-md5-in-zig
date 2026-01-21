# PHP's md5() implementation in Zig

### Links
- [https://www.php.net/manual/en/function.md5.php](https://www.php.net/manual/en/function.md5.php)

-  [https://github.com/php/php-src/blob/eb1d45bd425a16f4ca891648051e5f2b660429aa/ext/standard/md5.h](https://github.com/php/php-src/blob/eb1d45bd425a16f4ca891648051e5f2b660429aa/ext/standard/md5.h)

-  [https://github.com/php/php-src/blob/eb1d45bd425a16f4ca891648051e5f2b660429aa/ext/standard/md5.c](https://github.com/php/php-src/blob/eb1d45bd425a16f4ca891648051e5f2b660429aa/ext/standard/md5.c)


### Custom MD5 implementation - 
    - Fully unrolled rounds (all 64 operations at compile time)
    - comptime loop unrolling for zero runtime overhead
    - Native rotl instruction via std.math.rotl
### SIMD-vectorized hex conversion 
 Uses @Vector(16, u8) to convert 16 bytes to 32 hex chars in parallel using:

    - Vector shifts and masks for nibble extraction
    - SIMD @select for branchless digit/letter conversion
    - Compiles to NEON on ARM/M-series Mac or AVX/SSE on x86_64

### Performance Results
  ```
================================================================
  MD5 Benchmark: PHP native vs Zig (Native Extension)
================================================================
  Iterations: 10,000
  PHP Version: 8.4.17
  Extension: qzoke (Zig-powered)
================================================================

--- Input: small (13 B) ---

  Function               Total Time     Avg/Call        Ops/sec    Mem Delta     Mem Peak
  -------------------- ------------ ------------ -------------- ------------ ------------
  PHP md5()                 1.85 ms    185.05 ns      5,403,945          0 B         2 MB
  Zig qzoke_md5()           1.64 ms    164.09 ns      6,094,309          0 B         2 MB

  Zig is 1.13x faster than PHP

--- Input: medium (1000 B) ---

  Function               Total Time     Avg/Call        Ops/sec    Mem Delta     Mem Peak
  -------------------- ------------ ------------ -------------- ------------ ------------
  PHP md5()                17.27 ms     1.73 µs        578,878          0 B         2 MB
  Zig qzoke_md5()             17 ms      1.7 µs        588,234          0 B         2 MB

  Zig is 1.02x faster than PHP

--- Input: large (9.77 KB) ---

  Function               Total Time     Avg/Call        Ops/sec    Mem Delta     Mem Peak
  -------------------- ------------ ------------ -------------- ------------ ------------
  PHP md5()               159.86 ms    15.99 µs         62,556          0 B         2 MB
  Zig qzoke_md5()          158.8 ms    15.88 µs         62,973          0 B         2 MB

  Zig is 1.01x faster than PHP
```

For larger inputs inputs performance is same.

### Usage 

1. Build : ```zig build```

2. Test : ```zig build test```

3. Usage : ```php -d "extension=$(OUTPUT)" benchmark.php```

example for mac : 
```php -d "extension=./zig-out/lib/libqzoke.dylib" benchmark.php```

### Tools
```
➜ zig version
0.15.2
```
```
➜ php -v
PHP 8.4.17 (cli)
```