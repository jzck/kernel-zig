//https://wiki.osdev.org/Multitasking_Systems

//C declaration:
//   void switch_tasks(thread_control_block *next_thread)//
//
//WARNING: Caller is expected to disable IRQs before calling, and enable IRQs again after function returns

.type switch_tasks, @function
.global switch_tasks
switch_tasks:
    push %ebp
    mov %esp, %ebp
    mov +12(%esp), %eax
    mov %esp, (%eax) //save old esp
    mov +8(%esp), %eax
    mov %eax, %esp // move the forged stack to esp
    pop %ebp // the top of the forged stack contains ebp
    ret //the top of the forged stack contains eip to go to

// .type jmp_to_entrypoint, @function
// .global jmp_to_entrypoint
// jmp_to_entrypoint:
//     mov %esp, %ebp
//     mov +4(%esp), %eax
//     jmp *%eax

// .type birthasm, @function
// .global birthasm
// birthasm:
//     call unlock_scheduler
//     mov %esp, %ebp
//     mov +4(%esp), %eax
//     jmp *%eax
