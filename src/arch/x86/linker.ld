ENTRY(_start)
/* OUTPUT_FORMAT(elf32-i386) */

SECTIONS {
	 /* VGA, cannot use section for this */
	VGA_PTR = 0xb8000;
	. = 0xb8000;
	. += 80 * 25 * 2;

	. = 1M;
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

	/* NOT A GOOD IDEA TO GROUP debug_* SYMBOLS ! */
	/* .debug : */
	/* { */
	/* 	/1* KEEP(*(.debug_*)) *1/ */
	/* 	*(.debug_*) */
	/* 	. = ALIGN(4K); */
	/* } */

	.gdt :
	{
		*(.gdt)
		. = ALIGN(4K);
	}

	.got :
	{
		*(.got)
		. = ALIGN(4K);
	}

	.got.plt :
	{
		*(.got.plt)
		. = ALIGN(4K);
	}

	.bss :
	{
		*(.bss .bss.*)
		. = ALIGN(4K);
	}

	/* .stab : */
	/* { */
	/* 	KEEP(*(.stab)) */
	/* 	. = ALIGN(4K); */
	/* } */

	/* .stabstr : */
	/* { */
	/* 	KEEP(*(.stabstr)) */
	/* 	. = ALIGN(4K); */
	/* } */
}
