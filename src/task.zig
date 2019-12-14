pub usingnamespace @import("index.zig");
const TASK_MAX = 1024;
var boot_task = Task{ .tid = 0, .esp = 0x47 };
var current_task: *Task = &boot_task;
pub var tasks = [1]?*Task{&boot_task} ++ ([1]?*Task{null} ** TASK_MAX);

const STACK_SIZE = x86.PAGE_SIZE; // Size of thread stacks.
var tid_counter: u16 = 1;

///ASM
extern fn switch_tasks(new_esp: u32, old_esp_addr: u32) void;

pub const Task = packed struct {
    esp: usize,
    tid: u16,
    //context: isr.Context,
    //cr3: usize,

    pub fn new(entrypoint: usize) !*Task {
        // Allocate and initialize the thread structure.
        var t = try vmem.allocate(Task);

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

        println("new task esp=0x{x}, eip=0x{x}", t.esp, entrypoint);

        tasks[t.tid] = t;
        return t;
    }

    pub fn destroy(self: *Task) void {
        tasks[self.tid] = null;
        vmem.free(self.esp);
        vmem.free(@ptrToInt(self));
    }

    pub fn switch_to(self: *Task) void {
        assert(self != current_task);
        // save old stack
        const old_task_esp_addr = &current_task.esp;
        current_task = self;
        // x86.cli();
        // don't inline the asm function, it needs to ret
        @noInlineCall(switch_tasks, self.esp, @ptrToInt(old_task_esp_addr));
        // comptime {
        //     asm (
        //         \\mov +8(%esp), %eax
        //         \\mov %esp, (%eax)
        //         \\mov +4(%esp), %eax
        //         \\mov %eax, %esp
        //         \\pop %ebp
        //         \\ret
        //     );
        // }
        // x86.sti();
        println("after switch");
    }
};

pub fn introspect() void {
    for (tasks) |t| {
        if (t == null) continue;
        if (t != current_task) println("{}", t);
        if (t == current_task) println("*{}", t);
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
