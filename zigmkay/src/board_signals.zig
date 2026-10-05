//! Board signaling keeps pin selection and HAL timing at the call site.
pub fn blink(led: anytype, comptime sleep_us: anytype, count: u32, interval_ms: u32) void {
    var remaining = count;
    while (remaining > 0) : (remaining -= 1) {
        led.put(1);
        sleep_us(interval_ms * 1000);
        led.put(0);
        sleep_us(interval_ms * 1000);
    }
}

pub fn start(comptime pin_config: anytype, led: anytype, comptime sleep_us: anytype, count: u32, interval_ms: u32) void {
    _ = pin_config.apply();
    blink(led, sleep_us, count, interval_ms);
}

pub fn runUnibody(comptime runner: anytype, led: anytype, comptime sleep_us: anytype) void {
    runner.run_unibody() catch blink(led, sleep_us, 10000000, 500);
}
