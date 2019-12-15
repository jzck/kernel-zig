pub usingnamespace @import("index.zig");

var timer_last_count: u64 = 0;
var boot_task = Task{ .tid = 0, .esp = 0x47, .state = .Running };
const ListOfTasks = std.TailQueue(*Task);
pub var current_task = &ListOfTasks.Node.init(&boot_task);
pub var ready_tasks = ListOfTasks.init();
pub var blocked_tasks = ListOfTasks.init();

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
    Paused,
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
    const node = try vmem.create(ListOfTasks.Node);
    node.data = try Task.create(entrypoint);
    ready_tasks.prepend(node);
}

/// Block the current task
pub fn block(state: TaskState) void {
    assert(state != .Running);
    assert(state != .ReadyToRun);

    lock_scheduler();
    current_task.data.state = state;
    schedule();
}

pub fn unblock(node: *ListOfTasks.Node) void {
    lock_scheduler();
    node.data.state = .ReadyToRun;
    if (ready_tasks.first == null) {
        // Only one task was running before, so pre-empt
        switch_to(node);
    } else {
        // There's at least one task on the "ready to run" queue already, so don't pre-empt
        ready_tasks.append(node);
        unlock_scheduler();
    }
}

pub fn switch_to(chosen: *ListOfTasks.Node) void {
    // save old stack
    const old_task_esp_addr = &current_task.data.esp;

    ready_tasks.remove(chosen);
    // switch states
    switch (current_task.data.state) {
        .Running => ready_tasks.append(current_task),
        else => blocked_tasks.append(current_task),
    }
    chosen.data.state = .Running;
    current_task = chosen;

    unlock_scheduler();

    // don't inline the asm function, it needs to ret
    @noInlineCall(switch_tasks, chosen.data.esp, @ptrToInt(old_task_esp_addr));
}

pub fn schedule() void {
    update_time_used();
    if (ready_tasks.first) |t| {
        switch_to(t);
    } else {
        unlock_scheduler();
    }
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

pub fn introspect() void {
    update_time_used();

    println("{}", current_task.data);
    var it = ready_tasks.first;
    while (it) |node| : (it = node.next) println("{}", node.data);
    it = blocked_tasks.first;
    while (it) |node| : (it = node.next) println("{}", node.data);
}

// fn initContext(entry_point: usize, stack: usize) isr.Context {
//     // Insert a trap return address to destroy the thread on return.
//     var stack_top = @intToPtr(*usize, stack + STACK_SIZE - @sizeOf(usize));
//     stack_top.* = layout.THREAD_DESTROY;

//     return isr.Context{
//         .cs = gdt.USER_CODE | gdt.USER_RPL,
//         .ss = gdt.USER_DATA | gdt.USER_RPL,
//         .eip = entry_point,
//         .esp = @ptrToInt(stack_top),
//         .eflags = 0x202,

//         .registers = isr.Registers.init(),
//         .interrupt_n = 0,
//         .error_code = 0,
//     };
// }
