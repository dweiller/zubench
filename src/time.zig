const std = @import("std");
const builtin = @import("builtin");
const posix = std.posix;

pub const Clock = enum {
    real,
    process,
    thread,

    pub fn now(self: Clock) error{Unsupported}!std.time.Instant {
        if (posix.CLOCK == void) return .now();
        const clock_id = switch (self) {
            .real => switch (builtin.os.tag) {
                .macos, .ios, .tvos, .watchos => posix.CLOCK.UPTIME_RAW,
                .freebsd, .dragonfly => posix.CLOCK.MONOTONIC_FAST,
                .linux => posix.CLOCK.BOOTTIME,
                else => posix.CLOCK.MONOTONIC,
            },
            .process => posix.CLOCK.PROCESS_CPUTIME_ID,
            .thread => posix.CLOCK.THREAD_CPUTIME_ID,
        };
        return .{ .timestamp = posix.clock_gettime(clock_id) catch return error.Unsupported };
    }
};

// this is adapted from std.time.Timer
pub const Timer = struct {
    clock: Clock,
    started: std.time.Instant,
    previous: std.time.Instant,

    pub const Error = error{TimerUnsupported};

    /// Initialize the timer by querying for a supported clock.
    /// Returns `error.TimerUnsupported` when such a clock is unavailable.
    /// This should only fail in hostile environments such as linux seccomp misuse.
    pub fn start(clock: Clock) Error!Timer {
        const current = clock.now() catch return error.TimerUnsupported;
        return Timer{ .clock = clock, .started = current, .previous = current };
    }

    /// Reads the timer value since start or the last reset in nanoseconds.
    pub fn read(self: *Timer) u64 {
        const current = self.sample();
        return current.since(self.started);
    }

    /// Resets the timer value to 0/now.
    pub fn reset(self: *Timer) void {
        const current = self.sample();
        self.started = current;
    }

    /// Returns the current value of the timer in nanoseconds, then resets it.
    pub fn lap(self: *Timer) u64 {
        const current = self.sample();
        defer self.started = current;
        return current.since(self.started);
    }

    /// Returns an Instant sampled at the callsite that is
    /// guaranteed to be monotonic with respect to the timer's starting point.
    fn sample(self: *Timer) std.time.Instant {
        const current = self.clock.now() catch unreachable;
        if (current.order(self.previous) == .gt) {
            self.previous = current;
        }
        return self.previous;
    }
};
