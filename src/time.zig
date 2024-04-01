const std = @import("std");
const builtin = @import("builtin");
const posix = std.posix;

const ns_per_s = 1_000_000_000;

pub const Clock = enum {
    real,
    process,
    thread,

    pub fn clockID(self: Clock) i32 {
        return switch (self) {
            .real => switch (builtin.os.tag) {
                .macos, .ios, .tvos, .watchos => posix.CLOCK.UPTIME_RAW,
                .freebsd, .dragonfly => posix.CLOCK.MONOTONIC_FAST,
                .linux => posix.CLOCK.BOOTTIME,
                .windows => @compileError("windows is not supported"),
                else => posix.CLOCK.MONOTONIC,
            },
            .process => posix.CLOCK.PROCESS_CPUTIME_ID,
            .thread => posix.CLOCK.THREAD_CPUTIME_ID,
        };
    }
};

// this is an adaptation of std.time.Instant
pub const Instant = struct {
    timestamp: posix.timespec,

    /// Queries the system for the current moment of time as an Instant.
    /// This is not guaranteed to be monotonic or steadily increasing, but for most implementations it is.
    /// Returns `error.Unsupported` when a suitable clock is not detected.
    pub fn now(clock_id: i32) error{Unsupported}!Instant {
        var ts: posix.timespec = undefined;
        posix.clock_gettime(clock_id, &ts) catch return error.Unsupported;
        return Instant{ .timestamp = ts };
    }

    /// Quickly compares two instances between each other.
    pub fn order(self: Instant, other: Instant) std.math.Order {
        var ord = std.math.order(self.timestamp.tv_sec, other.timestamp.tv_sec);
        if (ord == .eq) {
            ord = std.math.order(self.timestamp.tv_nsec, other.timestamp.tv_nsec);
        }
        return ord;
    }

    /// Returns elapsed time in nanoseconds since the `earlier` Instant.
    /// This assumes that the `earlier` Instant represents a moment in time before or equal to `self`.
    /// This also assumes that the time that has passed between both Instants fits inside a u64 (~585 yrs).
    pub fn since(self: Instant, earlier: Instant) u64 {
        // Convert timespec diff to ns
        const seconds: u64 = @intCast(self.timestamp.tv_sec - earlier.timestamp.tv_sec);
        const elapsed = (seconds * ns_per_s) + @as(u32, @intCast(self.timestamp.tv_nsec));
        return elapsed - @as(u32, @intCast(earlier.timestamp.tv_nsec));
    }
};

// this is adapted from std.time.Timer
pub const Timer = struct {
    clock_id: i32,
    started: Instant,
    previous: Instant,

    pub const Error = error{TimerUnsupported};

    /// Initialize the timer by querying for a supported clock.
    /// Returns `error.TimerUnsupported` when such a clock is unavailable.
    /// This should only fail in hostile environments such as linux seccomp misuse.
    pub fn start(clock_id: i32) Error!Timer {
        const current = Instant.now(clock_id) catch return error.TimerUnsupported;
        return Timer{ .clock_id = clock_id, .started = current, .previous = current };
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
    fn sample(self: *Timer) Instant {
        const current = Instant.now(self.clock_id) catch unreachable;
        if (current.order(self.previous) == .gt) {
            self.previous = current;
        }
        return self.previous;
    }
};
