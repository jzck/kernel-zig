pub usingnamespace @import("index.zig");

var timer_last_count: u64 = 0;
var boot_task = Task{ .tid = 0, .esp = 0x47, .state = .Running };

const TaskNode = std.TailQueue(*Task).Node;
const SleepNode = DeltaQueue(*TaskNode).Node;

pub var current_task: *TaskNode = &TaskNode.init(&boot_task);
pub var ready_tasks = std.TailQueue(*Task).init();
pub var blocked_tasks = std.TailQueue(*Task).init();
pub var sleeping_tasks = DeltaQueue(*TaskNode).init();

const STACK_SIZE = x86.PAGE_SIZE; // Size of thread stacks.
var tid_counter: u16 = 1;

///ASM
extern fn switch_tasks(new_esp: u32, old_esp_addr: u32) void;

pub fn update_time_used() void {
    const current_count = time.offset_us;
    const elapsed = current_count - timer_last_count;
    timer_last_count = current_count;
    current_task.data.time_used += elapsed;
}

pub const TaskState = enum {
    Running,
    ReadyToRun,
    Blocked,
    Sleeping,
};

pub const Task = struct {
    esp: usize,
    tid: u16,
    time_used: u64 = 0,
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
        vmem.free(@ptrToInt(self));
    }
};

pub fn new(entrypoint: usize) !void {
    const node = try vmem.create(TaskNode);
    node.data = try Task.create(entrypoint);
    ready_tasks.prepend(node);
}

// TODO: make a sleep without malloc
pub fn usleep(usec: u64) !void {
    const node = try vmem.create(SleepNode);
    lock_scheduler();
    current_task.data.state = .Sleeping;
    node.data = current_task;
    node.counter = usec;
    sleeping_tasks.insert(node);
    schedule();
}

pub fn block(state: TaskState) void {
    assert(state != .Running);
    assert(state != .ReadyToRun);

    lock_scheduler();
    current_task.data.state = state;
    blocked_tasks.append(current_task);
    schedule();
}

pub fn unblock(node: *TaskNode) void {
    lock_scheduler();
    node.data.state = .ReadyToRun;
    blocked_tasks.remove(node);
    if (ready_tasks.first == null) {
        // Only one task was running before, so pre-empt
        switch_to(node);
    } else {
        // There's at least one task on the "ready to run" queue already, so don't pre-empt
        ready_tasks.append(node);
        unlock_scheduler();
    }
}

// expects:
//  - chosen is .ReadyToRun
//  - chosen is not in any scheduler lists
pub fn switch_to(chosen: *TaskNode) void {
    assert(chosen.data.state == .ReadyToRun);

    // in case of self preemption
    if (current_task.data.state == .Running) {
        current_task.data.state = .ReadyToRun;
        ready_tasks.append(current_task);
    }

    // save old stack
    const old_task_esp_addr = &current_task.data.esp;

    // switch states
    chosen.data.state = .Running;
    current_task = chosen;

    unlock_scheduler();

    // don't inline the asm function, it needs to ret
    @noInlineCall(switch_tasks, chosen.data.esp, @ptrToInt(old_task_esp_addr));
}

pub fn schedule() void {
    assert(IRQ_disable_counter > 0);

    update_time_used();

    // check if somebody wants to run
    const chosen = ready_tasks.popFirst();
    if (chosen == null) return unlock_scheduler();

    // std doesn't do this, for developer flexibility maybe?
    chosen.?.prev = null;
    chosen.?.next = null;

    // switch
    switch_to(chosen.?);
}

var IRQ_disable_counter: usize = 0;
pub fn lock_scheduler() void {
    if (constants.SMP == false) {
        x86.cli();
        IRQ_disable_counter += 1;
    }
}
pub fn unlock_scheduler() void {
    if (constants.SMP == false) {
        IRQ_disable_counter -= 1;
        if (IRQ_disable_counter == 0) x86.sti();
    }
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
