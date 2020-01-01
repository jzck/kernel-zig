usingnamespace @import("index.zig");

pub var offset_us: u64 = 0;
pub var task_slice_remaining: u64 = 0;
pub var TASK_SLICE: u64 = 50 * 1000;
pub fn increment() void {
    const tick = x86.interrupt.tick; //us

    offset_us += tick; //global time counter

    var should_preempt = task.wakeup_tick(tick);

    if (task_slice_remaining != 0) {
        // There is a time slice length
        if (task_slice_remaining <= tick) should_preempt = true;
        if (task_slice_remaining > tick) task_slice_remaining -= tick;
    }
    if (should_preempt) task.preempt();
}

pub fn uptime() void {
    var offset_ms: u64 = offset_us / 1000;
    const offset_s: u64 = offset_ms / 1000;
    offset_ms = @mod(offset_ms / 100, 10);

    print("{}.{:.3}", offset_s, offset_ms);
}

pub fn utilisation() void {
    print("{}%", 100 * (offset_us - task.CPU_idle_time) / offset_us);
}
