pub usingnamespace @import("index.zig");

var timer_last_count: u64 = 0;
var boot_task = Task{ .tid = 0, .esp = 0x47, .state = .Running };
const ListOfTasks = std.TailQueue(*Task);
var first_task = ListOfTasks.Node.init(&boot_task);
var current_task = &first_task;
var tasks = ListOfTasks{
    .first = &first_task,
    .last = &first_task,
    .len = 1,
};

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
        // top of stack is the address that ret will pop
        t.esp -= 4;
        @intToPtr(*usize, t.esp).* = entrypoint;
        // top of stack is ebp that we will pop
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
    tasks.append(node);
}

pub fn switch_to(new_task: *ListOfTasks.Node) void {
    assert(new_task.data != current_task.data);

    // switch states
    current_task.data.state = .ReadyToRun;
    new_task.data.state = .Running;

    // save old stack
    const old_task_esp_addr = &current_task.data.esp;
    current_task = new_task;
    // x86.cli();
    // don't inline the asm function, it needs to ret
    @noInlineCall(switch_tasks, new_task.data.esp, @ptrToInt(old_task_esp_addr));
    // x86.sti();
}

// circular next
pub fn next(node: *ListOfTasks.Node) ?*ListOfTasks.Node {
    return if (node.next) |n| n else tasks.first;
}

pub fn first_ready_to_run() ?*ListOfTasks.Node {
    var node = current_task;
    while (next(node)) |n| {
        if (n.data.state == .ReadyToRun) return n;
        if (n.data.state == .Running) return null;
    }
    return null;
}

pub fn schedule() void {
    update_time_used();
    if (first_ready_to_run()) |t| switch_to(t);
}

pub fn introspect() void {
    update_time_used();

    var it = tasks.first;
    println("{} tasks", tasks.len);
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
