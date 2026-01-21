const std = @import("std");

pub fn build(b: *std.Build) void {
    // Use native CPU target to enable all available SIMD instructions
    // (AVX-512/AVX2/SSE on x86_64, NEON on ARM)
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Resolve target to enable CPU feature detection
    const resolved_target = target.result;

    // PHP include paths
    const php_includes = [_][]const u8{
        "/opt/homebrew/Cellar/php@8.4/8.4.17/include/php",
        "/opt/homebrew/Cellar/php@8.4/8.4.17/include/php/main",
        "/opt/homebrew/Cellar/php@8.4/8.4.17/include/php/TSRM",
        "/opt/homebrew/Cellar/php@8.4/8.4.17/include/php/Zend",
        "/opt/homebrew/Cellar/php@8.4/8.4.17/include/php/ext",
        "/opt/homebrew/Cellar/php@8.4/8.4.17/include/php/ext/date/lib",
    };

    // Create the shared library with native CPU optimizations
    const lib = b.addLibrary(.{
        .linkage = .dynamic,
        .name = "qzoke",
        .root_module = b.createModule(.{
            .root_source_file = b.path("md5.zig"),
            .target = target,
            // Use ReleaseFast for maximum performance if not specified
            .optimize = if (optimize == .Debug) .ReleaseFast else optimize,
        }),
    });

    // Enable native CPU features for SIMD (AVX/NEON)
    // This ensures the compiler uses all available vector instructions
    _ = resolved_target;

    // Add the C source file
    lib.addCSourceFile(.{
        .file = b.path("qzoke.c"),
        .flags = &.{
            "-O3",
            "-fPIC",
            "-DCOMPILE_DL_QZOKE",
        },
    });

    // Add PHP include paths
    for (php_includes) |inc| {
        lib.root_module.addIncludePath(.{ .cwd_relative = inc });
    }

    // Allow undefined symbols (they'll be resolved by PHP at load time)
    lib.linker_allow_shlib_undefined = true;

    // Install
    b.installArtifact(lib);

    // Add a test step
    const test_step = b.step("test", "Test the extension");
    const run_test = b.addSystemCommand(&.{
        "php",
        "-d",
        "extension=./zig-out/lib/libqzoke.dylib",
        "-r",
        "var_dump(qzoke_md5('hello') === md5('hello'));",
    });
    run_test.step.dependOn(b.getInstallStep());
    test_step.dependOn(&run_test.step);
}
