pub usingnamespace @import("index.zig");

var boot_task = Task{ .tid = 0, .esp = 0x47, .state = .Running, .born = true };
var tid_counter: u16 = 1;

pub const TaskNode = std.TailQueue(*Task).Node;
pub const SleepNode = DeltaQueue(*TaskNode).Node;

pub var current_task: *TaskNode = &TaskNode.init(&boot_task);
pub var cleaner_task: *TaskNode = undefined;
pub var ready_tasks = std.TailQueue(*Task).init();
pub var blocked_tasks = std.TailQueue(*Task).init();
pub var terminated_tasks = std.TailQueue(*Task).init();
pub var sleeping_tasks = DeltaQueue(*TaskNode).init();

const STACK_SIZE = x86.PAGE_SIZE; // Size of thread stacks.

var timer_last_count: u64 = 0;
pub fn update_time_used() void {
    const current_count = time.offset_us;
    const elapsed = current_count - timer_last_count;
    // if (current_task.data.tid == 1) println("{} adding {} time", current_task.data.tid, elapsed);
    timer_last_count = current_count;
    current_task.data.time_used += elapsed;
}

pub const TaskState = enum {
    Running, // <=> current_task
    ReadyToRun, // <=> inside of ready_tasks
    IOWait, // waiting to be woken up by IO
    Paused, // unpaused arbitrarily by another process
    Sleeping, // woken up by timer
    Terminated, // <=> inside of terminated_tasks, waiting to be destroyed
};

pub const Task = struct {
    esp: usize,
    tid: u16,
    time_used: u64 = 0,
    born: bool = false,
    state: TaskState,
    //context: isr.Context,
    //cr3: usize,

    pub fn create(entrypoint: usize) !*Task {
        // Allocate and initialize the thread structure.
        var t = try vmem.create(Task);

        t.time_used = 0;
        t.state = .ReadyToRun;
        t.tid = tid_counter;
        tid_counter +%= 1;
        assert(tid_counter != 0); //overflow

        // allocate a new stack
        t.esp = (try vmem.malloc(STACK_SIZE)) + STACK_SIZE;
        // this will be what ret goes to
        t.esp -= 4;
        @intToPtr(*usize, t.esp).* = entrypoint;
        // this will be popped into ebp
        t.esp -= 4;
        @intToPtr(*usize, t.esp).* = t.esp + 8;

        return t;
    }

    pub fn destroy(self: *Task) void {
        vmem.free(self.esp);
        vmem.destroy(self);
    }
};

///ASM
extern fn switch_tasks(new_esp: usize, old_esp_addr: usize) void;

pub fn new(entrypoint: usize) !*TaskNode {
    task.lock_scheduler();
    defer task.unlock_scheduler();

    const node = try vmem.create(TaskNode);
    node.data = try Task.create(entrypoint);
    ready_tasks.prepend(node);
    return node;
}

pub fn sleep_tick(tick: usize) void {
    task.lock_scheduler();
    defer task.unlock_scheduler();

    task.sleeping_tasks.decrement(tick);
    var popped = false;
    while (task.sleeping_tasks.popZero()) |sleepnode| {
        // println("finished sleeping");
        // task.format();
        const tasknode = sleepnode.data;
        tasknode.data.state = .ReadyToRun;
        vmem.free(@ptrToInt(sleepnode));
        task.ready_tasks.prepend(tasknode);
        popped = true;
    }
    if (popped) preempt();
}

// TODO: make a sleep without malloc
pub fn usleep(usec: u64) !void {
    assert(current_task.data.state == .Running);

    const node = try vmem.create(SleepNode);

    update_time_used();

    lock_scheduler();
    defer unlock_scheduler();

    current_task.data.state = .Sleeping;
    node.data = current_task;
    node.counter = usec;
    sleeping_tasks.insert(node);
    schedule();
}

pub fn block(state: TaskState) void {
    assert(current_task.data.state == .Running);

    assert(state != .Running);
    assert(state != .ReadyToRun);

    // println("blocking {} as {}", current_task.data.tid, state);

    lock_scheduler();
    defer unlock_scheduler();

    update_time_used();
    current_task.data.state = state;
    blocked_tasks.append(current_task);
    schedule();
}

pub fn unblock(node: *TaskNode) void {
    if (node.data.state != .Paused and node.data.state != .IOWait) return;
    lock_scheduler();
    defer unlock_scheduler();

    node.data.state = .ReadyToRun;
    blocked_tasks.remove(node);

    // TODO: find a way to fastpath here, hard because of unblock inside of interrupts
    // if (current_task.data.state != .Running and ready_tasks.first == null) {
    //     // Only one task was running before, fastpath
    //     switch_to(node);
    // } else {
    //     // There's at least one task on the "ready to run" queue already, so don't pre-empt
    //     ready_tasks.append(node);
    // }
    ready_tasks.append(node);
}

pub fn terminate() void {
    assert(current_task.data.state == .Running);
    lock_scheduler();

    current_task.data.state = .Terminated;
    terminated_tasks.append(current_task);

    // Block this task (note: task switch will be postponed until scheduler lock is released)

    // Make sure the cleaner task isn't paused
    unblock(cleaner_task);
    unlock_scheduler();

    preempt();

    println("Terminated task was revived, what the fuck?");
    x86.hang();
}

pub fn cleaner_loop() noreturn {
    while (true) {
        if (terminated_tasks.popFirst()) |n| {
            notify("DESTROYING {}", n.data.tid);
            n.data.destroy();
            vmem.destroy(n);
        } else {
            notify("NOTHING TO CLEAN");
            block(.Paused);
        }
    }
}

pub var IRQ_disable_counter: usize = 0;
pub var postpone_task_switches_counter: isize = 0; // this counter can go negative when we are scheduling after a postpone
pub var postpone_task_switches_flag: bool = false;
pub fn lock_scheduler() void {
    if (constants.SMP == false) {
        x86.cli();
        IRQ_disable_counter += 1;
        postpone_task_switches_counter += 1;
    }
}
pub fn unlock_scheduler() void {
    if (constants.SMP == false) {
        assert(IRQ_disable_counter > 0);
        postpone_task_switches_counter -= 1;
        if (postpone_task_switches_flag == true and postpone_task_switches_counter == 0) {
            postpone_task_switches_flag = false;
            notify("AFTER POSTPONE");
            schedule();
        }
        IRQ_disable_counter -= 1;
        // must be the last instruction because we do interrupts inside interrupts
        if (IRQ_disable_counter == 0) x86.sti();
    }
}

pub fn preempt() void {
    if (current_task.data.state != .Running and current_task.data.state != .Terminated) return;

    update_time_used();
    if (ready_tasks.first == null) {
        notify("NO PREEMPT SINGLE TASK");
        time.task_slice_remaining = 0;
        return;
    }

    lock_scheduler();
    schedule();
    unlock_scheduler();
}

// expects:
//  - chosen is .ReadyToRun
//  - chosen is not in any scheduler lists
//  - current_task has been moved to a queue
//  - scheduler is locked
//  - the tasks being switched to will unlock_scheduler()
pub fn switch_to(chosen: *TaskNode) void {
    assert(chosen.data.state == .ReadyToRun);
    assert(current_task.data.state != .Running);

    // save old stack
    const old_task_esp_addr = &current_task.data.esp;

    // switch states
    chosen.data.state = .Running;
    current_task = chosen;
    if (ready_tasks.first == null) time.task_slice_remaining = 0;
    if (ready_tasks.first != null) time.task_slice_remaining = time.TASK_SLICE;

    // we don't have any startup code for tasks, so i do it here
    if (current_task.data.born == false) {
        current_task.data.born = true;
        unlock_scheduler();
    }

    // don't inline the asm function, it needs to ret
    @noInlineCall(switch_tasks, chosen.data.esp, @ptrToInt(old_task_esp_addr));
}

pub var CPU_idle_time: u64 = 0;
pub var CPU_idle_start_time: u64 = 0;
// expects:
//  lock_scheduler should be called before
//  unlock_scheduler should be called after
//  current_task is blocked or running (preemption)
pub fn schedule() void {
    assert(IRQ_disable_counter > 0);
    assert(current_task.data.state != .ReadyToRun);

    // postponed
    if (postpone_task_switches_counter != 0 and current_task.data.state == .Running) {
        postpone_task_switches_flag = true;
        notify("POSTPONING SCHEDULE");
        return;
    }
    // next task
    if (ready_tasks.popFirst()) |t| {
        t.prev = null;
        t.next = null;

        // notify("SWITCHING TO 0x{x}", t.data.esp);
        if (current_task.data.state == .Running) {
            current_task.data.state = .ReadyToRun;
            ready_tasks.append(current_task);
        }
        return switch_to(t);
    }
    // single task
    if (current_task.data.state == .Running) {
        notify("SINGLE TASK");
        time.task_slice_remaining = 0;
        return;
    }
    // no tasks
    idle_mode();
}

fn idle_mode() void {
    assert(ready_tasks.first == null);
    assert(current_task.data.state != .Running);
    assert(current_task.data.state != .ReadyToRun);

    notify("IDLE");

    // borrow the current task
    const borrow = current_task;

    CPU_idle_start_time = time.offset_us; //for power management

    while (true) { // idle loop
        if (ready_tasks.popFirst()) |t| { // found a new task
            CPU_idle_time += time.offset_us - CPU_idle_start_time; // count time as idle
            timer_last_count = time.offset_us; // don't count time as used
            // println("went into idle mode for {}usecs", time.offset_us - CPU_idle_start_time);

            if (t == borrow) {
                t.data.state = .Running;
                return; //no need to ctx_switch we are already running this
            }
            return switch_to(t);
        } else { // no tasks ready, let the timer fire
            x86.sti(); // enable interrupts to allow the timer to fire
            x86.hlt(); // halt and wait for the timer to fire
            x86.cli(); // disable interrupts again to see if there is something to do
        }
    }
}

pub fn notify(comptime message: []const u8, args: ...) void {
    const bg = vga.background;
    const fg = vga.foreground;
    const cursor = vga.cursor;
    vga.background = fg;
    vga.foreground = bg;
    vga.cursor = 80 - message.len - 10;
    vga.cursor_enabled = false;

    print(message, args);

    vga.cursor_enabled = true;
    vga.cursor = cursor;
    vga.background = bg;
    vga.foreground = fg;
}

pub fn format_short() void {
    print("{}R {}B {}S", ready_tasks.len, blocked_tasks.len, sleeping_tasks.len);
}

pub fn format() void {
    update_time_used();

    println("{}", current_task.data);

    var it = ready_tasks.first;
    while (it) |node| : (it = node.next) println("{}", node.data);
    it = blocked_tasks.first;
    while (it) |node| : (it = node.next) println("{}", node.data);
    var sit = sleeping_tasks.first;
    while (sit) |node| : (sit = node.next) println("{} {}", node.data.data, node.counter);
}
