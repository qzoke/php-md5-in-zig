<?php
/**
 * Benchmark: PHP md5() vs Zig qzoke_md5() (Native Extension)
 *
 * Run: php -d "extension=./zig-out/lib/libqzoke.dylib" benchmark.php
 */

if (!function_exists('qzoke_md5')) {
    die("Error: qzoke extension not loaded.\n" .
        "Run: php -d \"extension=./zig-out/lib/libqzoke.dylib\" benchmark.php\n");
}

// Benchmark configuration
$iterations = 10000;

$testData = [
    'small'  => 'Hello, World!',
    'medium' => str_repeat('a', 1000),
    'large'  => str_repeat('b', 10000),
];

function formatBytes(int $bytes): string {
    if ($bytes < 1024) return $bytes . ' B';
    if ($bytes < 1048576) return round($bytes / 1024, 2) . ' KB';
    return round($bytes / 1048576, 2) . ' MB';
}

function formatTime(float $seconds): string {
    if ($seconds < 0.000001) return round($seconds * 1000000000, 2) . ' ns';
    if ($seconds < 0.001) return round($seconds * 1000000, 2) . ' µs';
    if ($seconds < 1) return round($seconds * 1000, 2) . ' ms';
    return round($seconds, 4) . ' s';
}

function runBenchmark(string $name, callable $fn, string $data, int $iterations): array {
    // Warmup
    for ($i = 0; $i < 100; $i++) {
        $fn($data);
    }

    gc_collect_cycles();
    $memBefore = memory_get_usage(true);

    $start = hrtime(true);
    for ($i = 0; $i < $iterations; $i++) {
        $fn($data . $i);
        // For larger random data, use:
        //$fn($data = random_bytes(4096));
    }
    $end = hrtime(true);

    $memAfter = memory_get_usage(true);
    $memPeak = memory_get_peak_usage(true);

    $totalTime = ($end - $start) / 1e9; // Convert to seconds
    $avgTime = $totalTime / $iterations;

    return [
        'name' => $name,
        'total_time' => $totalTime,
        'avg_time' => $avgTime,
        'mem_delta' => $memAfter - $memBefore,
        'mem_peak' => $memPeak,
        'ops_per_sec' => $iterations / $totalTime,
    ];
}

// Header
echo "\n";
echo "================================================================\n";
echo "  MD5 Benchmark: PHP native vs Zig (Native Extension)\n";
echo "================================================================\n";
echo "  Iterations: " . number_format($iterations) . "\n";
echo "  PHP Version: " . PHP_VERSION . "\n";
echo "  Extension: qzoke (Zig-powered)\n";
echo "================================================================\n\n";

$results = [];

foreach ($testData as $label => $data) {
    $dataSize = strlen($data);

    echo "--- Input: $label (" . formatBytes($dataSize) . ") ---\n\n";

    // Reset memory tracking
    gc_collect_cycles();

    // Benchmark PHP md5()
    $phpResult = runBenchmark('PHP md5()', 'md5', $data, $iterations);

    // Benchmark Zig qzoke_md5()
    $zigResult = runBenchmark('Zig qzoke_md5()', 'qzoke_md5', $data, $iterations);

    // Calculate comparison
    $speedup = $phpResult['avg_time'] / $zigResult['avg_time'];

    // Print results table
    printf("  %-20s %12s %12s %14s %12s %12s\n", 'Function', 'Total Time', 'Avg/Call', 'Ops/sec', 'Mem Delta', 'Mem Peak');
    printf("  %-20s %12s %12s %14s %12s %12s\n", str_repeat('-', 20), str_repeat('-', 12), str_repeat('-', 12), str_repeat('-', 14), str_repeat('-', 12), str_repeat('-', 12));

    printf("  %-20s %12s %12s %14s %12s %12s\n",
        $phpResult['name'],
        formatTime($phpResult['total_time']),
        formatTime($phpResult['avg_time']),
        number_format($phpResult['ops_per_sec'], 0),
        formatBytes($phpResult['mem_delta']),
        formatBytes($phpResult['mem_peak']),
    );

    printf("  %-20s %12s %12s %14s %12s %12s\n",
        $zigResult['name'],
        formatTime($zigResult['total_time']),
        formatTime($zigResult['avg_time']),
        number_format($zigResult['ops_per_sec'], 0),
        formatBytes($zigResult['mem_delta']),
        formatBytes($zigResult['mem_peak']),
    );

    echo "\n";

    // Comparison
    if ($speedup >= 1) {
        printf("  Zig is %.2fx faster than PHP\n", $speedup);
    } else {
        printf("  Zig is %.2fx slower than PHP\n", 1/$speedup);
    }

    echo "\n";

    $results[$label] = [
        'php' => $phpResult,
        'zig' => $zigResult,
        'speedup' => $speedup,
    ];
}