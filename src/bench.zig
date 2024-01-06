const std = @import("std");
const builtin = @import("builtin");

const time = @import("time.zig");
const Timer = time.Timer;

const Allocator = std.mem.Allocator;

const stats = @import("statistics.zig");

pub const Clock = time.Clock;

pub const default_sample_spec = if (builtin.os.tag != .windows)
    [_]Clock{
        .real,
        .process,
    }
else
    [_]Clock{.real};

pub const sample_spec = if (@hasDecl(@import("root"), "sample_spec"))
    @import("root").sample_spec
else
    default_sample_spec;

fn StructArray(comptime T: type) type {
    var fields: [sample_spec.len]std.builtin.Type.StructField = undefined;
    inline for (&fields, sample_spec) |*field, spec_elt| {
        field.* = .{
            .name = @tagName(spec_elt),
            .type = T,
            .default_value = null,
            .is_comptime = false,
            .alignment = @alignOf(T),
        };
    }
    return @Type(.{
        .Struct = .{
            .layout = .Auto,
            .fields = &fields,
            .decls = &.{},
            .is_tuple = false,
        },
    });
}

pub const Sample = StructArray(u64);

const sample_fields = std.meta.fields(Sample);

pub const Samples = struct {
    multi_array_list: std.MultiArrayList(Sample),

    pub fn init(allocator: Allocator, max_samples: usize) !Samples {
        var multi_array_list = std.MultiArrayList(Sample){};
        try multi_array_list.setCapacity(allocator, max_samples);
        return Samples{
            .multi_array_list = multi_array_list,
        };
    }

    pub fn deinit(self: *Samples, allocator: Allocator) void {
        self.multi_array_list.deinit(allocator);
    }

    pub fn append(self: *Samples, sample: Sample) void {
        @setRuntimeSafety(true);
        self.multi_array_list.appendAssumeCapacity(sample);
    }

    /// Get statistics from benchmarking context
    pub fn generateStatistics(self: Samples) RunStats {
        const slice = self.multi_array_list.slice();
        var result: RunStats = undefined;
        inline for (sample_fields, 0..) |field, i| {
            const values = slice.items(@enumFromInt(i));
            const avg = stats.mean(values);
            const std_dev = stats.correctedSampleStdDev(values, avg);
            @field(result, field.name) = Statistics{
                .n_samples = values.len,
                .mean = avg,
                .std_dev = std_dev,
            };
        }
        return result;
    }
};

fn startCounters() !Counters {
    var counters: Counters = undefined;
    for (&counters, sample_spec) |*counter, spec_elt| {
        const clock_id = spec_elt.clockID();
        counter.* = try time.Timer.start(clock_id);
    }
    return counters;
}

fn resetCounters(counters: *Counters) void {
    for (counters) |*counter| {
        counter.reset();
    }
}

pub const Counters = [sample_spec.len]Timer;

pub const Statistics = struct {
    n_samples: usize,
    mean: f32,
    std_dev: f32,
};

pub const RunStats = StructArray(Statistics);

pub const Context = struct {
    counters: Counters,
    samples: Samples,

    // Call `deinit()` to free allocated samples
    pub fn init(allocator: Allocator, max_samples: usize) !Context {
        return Context{
            .counters = try startCounters(),
            .samples = try Samples.init(allocator, max_samples),
        };
    }

    pub fn deinit(self: *Context, allocator: Allocator) void {
        self.samples.deinit(allocator);
    }
};

pub const Report = struct {
    // Thie field should probably be declared as comptime, but the compiler
    // doesn't seem to allow initialising a struct with normal and comptime fields
    // in the interrupt handler
    mode: []const u8 = @tagName(builtin.mode),
    name: []const u8,
    total_runs: usize,
    discarded_runs: u64 = 0,
    results: RunStats,

    pub fn format(value: Report, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = options;
        _ = fmt;

        const header_fmt =
            \\  » {s}
            \\    discarded {d} outliers from {d} runs ({d:.2}% of total runs)
            \\
        ;
        const pct = pct: {
            const numerator: f32 = @floatFromInt(value.discarded_runs);
            const denominator: f32 = @floatFromInt(value.total_runs);
            break :pct numerator / denominator * 100;
        };
        try writer.print(header_fmt, .{ value.name, value.discarded_runs, value.total_runs, pct });
        const counter_fmt =
            \\      {s}:
            \\        mean: {d: >6.2}
            \\           σ: {d: >6.2}
            \\         num: {d}
            \\
        ;
        inline for (sample_fields) |field| {
            const counter_stats = @field(value.results, field.name);
            try writer.print(counter_fmt, .{
                field.name,
                std.fmt.fmtDuration(@intFromFloat(counter_stats.mean)),
                std.fmt.fmtDuration(@intFromFloat(counter_stats.std_dev)),
                counter_stats.n_samples,
            });
        }
    }
};

pub const Options = struct {
    outlier_detection: Outlier = .{ .MAD = 1.4286 * 10.0 },

    pub const Outlier = union(enum) {
        none: void,
        MAD: f32,
    };
};

pub fn Benchmark(comptime Func: type) type {
    return struct {
        allocator: Allocator,
        name: []const u8,
        func: *const Func,
        args: Args,
        options: Options,
        progress: *std.Progress,
        ctx: Context,

        pub const Args = std.meta.ArgsTuple(Func);

        /// borrows `name`; `name` should remain valid while the Benchmark (or its Report) is in use.
        pub fn init(
            allocator: Allocator,
            name: []const u8,
            func: *const Func,
            args: Args,
            options: Options,
            max_samples: usize,
            progress: *std.Progress,
        ) error{ TimerUnsupported, OutOfMemory }!@This() {
            const ctx = try Context.init(allocator, max_samples);
            return @This(){
                .allocator = allocator,
                .name = name,
                .func = func,
                .args = args,
                .options = options,
                .progress = progress,
                .ctx = ctx,
            };
        }

        pub fn deinit(self: *@This()) void {
            self.ctx.deinit(self.allocator);
            self.name = undefined;
        }

        // returns a new `Samples` that contains the samples that
        // have 'MAD z-score' for each eounter less than or equal to `cutoff`.
        //
        // The 'MAD z-score' is the z-score ((x-μ)/σ) with mean replaced by median and
        // standard deviation replaced by median absolute deviation from the median.
        //
        // Assuming a normal distribution, it would make sense to set `cutoff` to `n * 1.4286`,
        // where `n` is the cutoff for z-scores you want to keep.
        pub fn cleanSamples(self: *@This(), cutoff: f32) !Samples {
            const mul_ar = self.ctx.samples.multi_array_list;
            const max_len = mul_ar.len;
            var result = try Samples.init(self.allocator, max_len);
            // assuming that the length of `self` is less than `maxInt(u16)`
            var centre: [sample_fields.len]f32 = undefined;
            var dispersion: [sample_fields.len]f32 = undefined;
            const slice = mul_ar.slice();
            {
                const buf = try self.allocator.alloc(u64, max_len);
                defer self.allocator.free(buf);
                inline for (sample_fields, 0..) |_, i| {
                    const data = slice.items(@enumFromInt(i));
                    @memcpy(buf, data);
                    centre[i] = stats.median(buf);
                    dispersion[i] = stats.medianAbsDev(buf, centre[i]);
                }
            }

            for (0..max_len) |i| {
                const sample = mul_ar.get(i);
                var outlier = false;
                inline for (sample_fields, dispersion, centre) |field, dispersion_elt, centre_elt| {
                    const zscore = stats.zScore(
                        dispersion_elt,
                        centre_elt,
                        @field(sample, field.name),
                    );
                    outlier = outlier or zscore > cutoff;
                }
                if (!outlier) {
                    result.append(sample);
                }
            }
            return result;
        }

        pub fn run(self: *@This()) !Report {
            const mul_ar = &self.ctx.samples.multi_array_list;
            const max_iterations = mul_ar.capacity;
            const node = self.progress.start(self.name, max_iterations);
            node.activate();

            while (mul_ar.len < mul_ar.capacity) {
                resetCounters(&self.ctx.counters);

                switch (@typeInfo(@typeInfo(Func).Fn.return_type.?)) {
                    .ErrorUnion => {
                        _ = @call(.never_inline, self.func, self.args) catch |err| {
                            std.debug.panic("Benchmark {s} returned error {s}", .{ self.name, @errorName(err) });
                        };
                    },
                    else => _ = @call(.never_inline, self.func, self.args),
                }

                var sample: Sample = undefined;
                inline for (sample_fields, &self.ctx.counters) |field, *timer| {
                    @field(sample, field.name) = timer.read();
                }

                // WARNING: append() increments samples.len BEFORE adding the data.
                //          This may mean an asynchronous singal handler will think
                //          there is one more sample than has actually been stored.
                self.ctx.samples.append(sample);
                node.completeOne();
            }
            node.end();

            var cleaned_samples = switch (self.options.outlier_detection) {
                .none => self.ctx.samples,
                .MAD => |cutoff| try self.cleanSamples(cutoff),
            };
            defer if (self.options.outlier_detection != .none) cleaned_samples.deinit(self.allocator);

            return Report{
                .name = self.name,
                .results = cleaned_samples.generateStatistics(),
                .discarded_runs = cleaned_samples.multi_array_list.capacity - cleaned_samples.multi_array_list.len,
                .total_runs = cleaned_samples.multi_array_list.capacity,
            };
        }
    };
}

pub fn Spec(comptime func: anytype) type {
    if (@typeInfo(@TypeOf(func)).Fn.params.len == 0)
        return struct {
            args: std.meta.ArgsTuple(@TypeOf(func)) = .{},
            max_samples: usize,
            func: @TypeOf(func) = func,
            opts: Options = .{},
        };
    return struct {
        args: std.meta.ArgsTuple(@TypeOf(func)),
        max_samples: usize,
        func: @TypeOf(func) = func,
        opts: Options = .{},
    };
}

test {
    std.testing.refAllDeclsRecursive(@This());
}
