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
  - [ ] declarative `zig test` style benchmark runner
  - [ ] adaptive sample sizes

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

The planned build system integration is not yet implemented. In the meantime it is relatively straightforward to write a standalone executable to perform benchmarks. To create a benchmark for a function `func`, run it (measure process and wall time) and obtain a report, all that is needed is

```zig
var progress = std.Progress{};
var bm = try Benchmark(func).init(allocator, "benchmark name", .{ func_arg_1, … }, max_samples, &progress);
const report = bm.run();
bm.deinit();
```

The `report` then holds a statistical summary of the benchmark and can used with `std.io.Writer.print` (for terminal-style readable output) or `std.json.stringify` (for JSON output). See `examples/` for complete examples.

## status

**zubench** is in early development—the API is not stable at the moment and experiments with the API are planned, so feel free to make suggestions for the API or features you would find useful.
