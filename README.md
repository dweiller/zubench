# zubench

A micro-benchmarking package for [Zig](https://ziglang.org).

## goals

The primary goals of **zubench** are to:

  - be simple to use - there should be no need to wrap a function just to benchmark it
  - provide standard machine-readable output for archiving or post-processing
  - given the user the choice of which system clock(s) to use
  - provide statistically relevant and accurate results
  - integrate with the Zig build system

Not all these goals are currently met, and its always possible to debate how well they are met; feel free to open an issue (if one doesn't exist) or pull request if you would like to see improvement in one of these areas.

## features

  - [x] human-readable terminal-style output
  - [x] machine-readable JSON output
  - [x] wall, process, and thread time
  - [ ] kernel/user mode times
  - [x] declarative `zig test` style benchmark runner
  - [ ] adaptive sample sizes
  - [x] [MAD](https://en.wikipedia.org/wiki/Median_absolute_deviation)-based outlier rejection

## platforms

Some attempt has been made to work on the below platforms; those with a '️️️️️⚠️' in the table below haven't been tested, but _should_ work for all implemented clocks. Windows currently only has the wall time clock implemented. If you find a non-Linux platform either works or has issues please raise an issue.

| Platform | Status |
| :------: | :----: |
|   Linux  |   ✅   |
|  Windows |   ❗   |
|  Darwin  |   ⚠️    |
|    BSD   |   ⚠️    |
|   WASI   |   ⚠️    |

## usage

The simplest way to create and run benchmarks is using the Zig build system. All that is needed is to add
```zig
const addBench = @import("zubench/build.zig").addBench;

pub fn build(b: *std.build.Builder) void {
    // existing build function
    // ...

    // benchmarks in "src/file.zig", compiled in ReleaseSafe mode
    const benchmark_exe = addBench(b, "src/file.zig", .ReleaseSafe);

    const bench_step = b.step("bench", "Run the benchmarks");
    bench_step.dependOn(&benchmark_exe.run().step);
}
```
This will make `zig build bench` run the benchmarks in `src/file.zig`, and print the results. `addBench()` returns a `*LibExecObjStep` for an executable that runs the benchmarks; you can integrate it into your `build.zig` however you wish. Benchmarks are specified in `src/file.zig` by creating a `pub const benchmarks` declaration:
```zig
// add to src/file.zig

// the zubench package
const bench = @import("src/bench.zig");
pub const benchmarks = .{
    .@"benchmark func1" = bench.Spec(func1){ .args = .{ arg1, arg2 }, .max_samples = 100 },
    .@"benchmark func2" = bench.Spec(func2){
        .args = .{ arg1, arg2, arg3 },
        .max_samples = 1000,
        .opts = .{ .outlier_detection = .none }}, // disable outlier detection
}
```

The above snippet would cause two benchmarks to be run called "benchmark func1" and "benchmark func2" for functions `func1` and `func2` respectively. The `.args` field of a `Spec` is a `std.meta.ArgsTuple` for the corresponding function, and `.max_samples` determines the maximum number of times the function is run during benchmarking. A complete example can be found in `examples/fib_build.zig`.

It is also relatively straightforward to write a standalone executable to perform benchmarks without using the build system integration. To create a benchmark for a function `func`, run it (measuring process and wall time) and obtain a report, all that is needed is

```zig
var progress = std.Progress{};
var bm = try Benchmark(func).init(allocator, "benchmark name", .{ func_arg_1, … }, .{}, max_samples, &progress);
const report = bm.run();
bm.deinit();
```

The `report` then holds a statistical summary of the benchmark and can used with `std.io.Writer.print` (for terminal-style readable output) or `std.json.stringify` (for JSON output). See `examples/` for complete examples.

## examples

Examples showing some ways of producing and running benchmarks can be found the `examples/` directory. Each of these files are built using the root `build.zig` file. The examples with the suffix `_build` utilise **zubench**'s integration with the Zig build system. All examples can be built using `zig build examples` and they can be run using `zig build run`.

## status

**zubench** is in early development—the API is not stable at the moment and experiments with the API are planned, so feel free to make suggestions for the API or features you would find useful.
