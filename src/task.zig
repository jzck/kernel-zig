pub usingnamespace @import("index.zig");
const TASK_MAX = 1024;
var tasks = [1]?*Task{null} ** TASK_MAX;

const STACK_SIZE = x86.PAGE_SIZE; // Size of thread stacks.
var tid_counter: u16 = 1;

pub const Task = struct {
    tid: u16,
    stack_top: usize,
    entrypoint: usize,
    // context: isr.Context,
    //cr3: usize,

    pub fn new(entrypoint: usize) !*Task {
        // Allocate and initialize the thread structure.
        var t = try vmem.allocate(Task);

        t.entrypoint = entrypoint;
        t.tid = tid_counter;
        tid_counter +%= 1;
        assert(tid_counter != 0); //overflow

        t.stack_top = try vmem.malloc(STACK_SIZE);
        assert(t.stack_top < layout.USER_STACKS_END);

        tasks[t.tid] = t;
        return t;
    }

    pub fn destroy(self: *Task) void {
        tasks[self.tid] = null;
        vmem.free(self.stack_top);
        vmem.free(@ptrToInt(self));
    }
};

pub fn initialize() !void {
    const t = try Task.new(0x0);
    println("task=0x{x}", t.stack_top);
}

pub fn introspect() void {
    for (tasks) |t| {
        if (t == null) continue;
        println("{}", t);
    }
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
