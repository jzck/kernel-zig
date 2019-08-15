ENTRY(__start)
/* ENTRY(x86_main) */
/* OUTPUT_FORMAT(elf32-i386) */

SECTIONS {
	 /* VGA, cannot use section for this */
	VGA_PTR = 0xb8000;
	. = 0xb8000;
	. += 80 * 25 * 2;

    /* lower half kernel <1MiB */
	. = 0x10000;

	/* ensure that the multiboot header is at the beginning */
	.multiboot :
	{
		/* KEEP otherwise it gets garbage collected by linker */
		KEEP(*(.multiboot))
		. = ALIGN(4K);
	}

	.text :
	{
		*(.text .text.*)
		. = ALIGN(4K);
	}

	.rodata :
	{
		*(.rodata .rodata.*)
		. = ALIGN(4K);
	}

	.data :
	{
		*(.data.rel.ro.local*) *(.data.rel.ro .data.rel.ro.*) *(.data.*)
		. = ALIGN(4K);
	}

	.gdt :
	{
		*(.gdt)
		. = ALIGN(4K);
	}

	.bss :
	{
		*(.bss .bss.*)
		. = ALIGN(4K);
	}
}
