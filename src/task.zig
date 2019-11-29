pub usingnamespace @import("index.zig");
// var tasks = Array(?*Task).init(&mem.allocator);

const STACK_SIZE = x86.PAGE_SIZE; // Size of thread stacks.

pub const Task = struct {
    // context: isr.Context,

    ////
    // Create a new thread inside the current process.
    // NOTE: Do not call this function directly. Use Process.createThread instead.
    //
    // Arguments:
    //     entry_point: The entry point of the new thread.
    //
    // Returns:
    //     Pointer to the new thread structure.
    //
    tid: u16,

    pub fn stack(tid: u16) usize {
        const stack = layout.USER_STACKS + (2 * (tid - 1) * STACK_SIZE);
        assert(stack < layout.USER_STACKS_END);
        return stack;
    }

    pub fn new(entry_point: usize) !*Task {
        // assert(scheduler.current_process == process);

        // map the stack

        // Allocate and initialize the thread structure.
        var this = try vmem.allocate(Task);
        this.tid = 4;

        return this;
    }
};

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
