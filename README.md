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
  - [x] option to define benchmarks as Zig tests
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

The *main* branch follows Zig's master branch, for Zig 0.12 use the *zig-0.12* branch.

The simplest way to create and run benchmarks is using one of the Zig build system integrations. There are currently two integrations, one utilising the Zig test system, and one utilising public declarations.

Both integrations will compile an executable that takes a collection of functions to benchmark, runs them repeatedly and reports timing statistics. The differences between the two integrations are how you define benchmarks in your source files, and how benchmarking options are determined.

### test integration
The simplest way to define and run benchmarks is utilising the Zig test system. **zubench** will use a custom test runner to run the benchmarks. This means that benchmarks are simply Zig tests, i.e. `test { // code to benchmark }`. In order to avoid benchmarking regular tests when using this system, you should consider the way that Zig analyses test declarations and either give the names of benchmark tests a unique substring that can be used as a test filter or organise your tests so that when the compiller analyses the root file for benchmark tests, it will not analyse regular tests.

The following snippets show how you can use this integration.
```zig
const addTestBench = @import("zubench/build.zig").addTestBench;

pub fn build(b: *std.build.Builder) void {
    // existing build function
    // ...

    // benchmark all tests analysed by the compiler rooted in "src/file.zig", compiled in ReleaseSafe mode
    const benchmark_exe = zubench.addTestBench(b, "src/file.zig", .ReleaseSafe);
    // use a test filter to only benchmark tests whose name include the substring "bench"
    // note that this is not required if the compiler will not analyse tests that you don't want to benchmark
    benchmark_exe.setTestFilter("bench");

    const bench_step = b.step("bench", "Run the benchmarks");
    bench_step.dependOn(&benchmark_exe.run().step);
}
```
This will make `zig build bench` benchmark tests the compiler analyses by starting at `src/file.zig`. `addTestBench()` returns a `*LibExeObjStep` for an executable that runs the benchmarks; you can integrate it into your `build.zig` however you wish. Benchmarks are `test` declarations the compiler analyses staring from `src/file.zig`:
```zig
// src/file.zig

test "bench 1" {
    // this will be benchmarked
    // ...
}

test "also a benchmark" {
    // this will be benchmarked
    // ...
}

test {
    // this will be benchmarked
    // the test filter is ignored for unnamed tests
    // ...
}

test "regular test" {
    // this will not be benchmarked
    return error.NotABenchmark;
}
```

### public decl integration
This integration allows for fine-grained control over the execution of benchmarks, allowing you to specify various options as well as benchmark functions that take parameters.

The following snippets shows how you can use this integration.
```zig
// build.zig

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
This will make `zig build bench` run the benchmarks in `src/file.zig`, and print the results. `addBench()` returns a `*LibExeObjStep` for an executable that runs the benchmarks; you can integrate it into your `build.zig` however you wish. Benchmarks are specified in `src/file.zig` by creating a `pub const benchmarks` declaration:
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
var progress = std.Progress.start(.{});
var bm = try Benchmark(func).init(allocator, "benchmark name", .{ func_arg_1, … }, .{}, max_samples, progress);
const report = bm.run();
bm.deinit();
```

The `report` then holds a statistical summary of the benchmark and can used with `std.io.Writer.print` (for terminal-style readable output) or `std.json.stringify` (for JSON output). See `examples/` for complete examples.

### Custom exectuable

It is also possible to write a custom benchmarking executable using **zubench** as a dependency. There is a simple example of this in `examples/fib2.zig` or, you can examine `src/bench_runner.zig`.

## examples

Examples showing some ways of producing and running benchmarks can be found the `examples/` directory. Each of these files are built using the root `build.zig` file. All examples can be built using `zig build examples` and they can be run using `zig build run`.

## status

**zubench** is in early development—the API is not stable at the moment and experiments with the API are planned, so feel free to make suggestions for the API or features you would find useful.
