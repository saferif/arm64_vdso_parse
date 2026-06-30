.global vdso_syms_init, vdso_sym

.equ ELF_MAGIC, 0x464C457F

.equ AT_SYSINFO_EHDR, 33

.equ E_PHOFF, 0x20
.equ E_PHENTSIZE, 0x36
.equ E_PHNUM, 0x38

.equ PT_LOAD, 1
.equ PT_DYNAMIC, 2

.equ P_OFFSET, 8
.equ P_VADDR, 0x10

.equ DT_STRTAB, 5
.equ DT_SYMTAB, 6
.equ DT_GNU_HASH, 0x6FFFFEF5

.equ SYM_SIZE, 24
.equ ST_NAME, 0
.equ ST_VALUE, 8

.macro mov32, reg, imm32
	.if ((\imm32) < 0)
		movn	\reg, ((~(\imm32)) & 0xFFFF)
	.else
		movz	\reg, ((\imm32) & 0xFFFF)
	.endif
	movk	\reg, (((\imm32) >> 16) & 0xFFFF), lsl #16
.endm

// ========================================================= //

.text

vdso_syms_init:
	ldr	x1, [x0]
	add	x0, x0, x1, lsl #3
	add	x0, x0, #16

.Lskip_envp:
	ldr	x1, [x0], #8
	cbnz	x1, .Lskip_envp

.Lfind_vdso:
	ldp	x1, x10, [x0], #16		// x10 - VDSO base
	cbz	x1, .Lfail
	cmp	x1, #AT_SYSINFO_EHDR
	b.ne	.Lfind_vdso

	ldr	w0, [x10]
	mov32	w1, ELF_MAGIC
	cmp	w0, w1
	b.ne	.Lfail

	ldr	x0, [x10, #E_PHOFF]
	ldrh	w1, [x10, #E_PHENTSIZE]
	ldrh	w2, [x10, #E_PHNUM]
	add	x11, x10, x0			// x11 - Program Headers

	mov	x9, xzr
	mov	x12, xzr
	mov	x5, xzr

.Lparse_ph:
	ldr	w0, [x11]
	cmp	w0, #PT_DYNAMIC
	b.eq	.Lfound_dynamic
	cmp	w0, #PT_LOAD
	b.eq	.Lfound_load

.Lparse_ph_cont:
	add	x11, x11, x1
	sub	w2, w2, #1
	cbnz	w2, .Lparse_ph
	b	.Lph_parsed

.Lfound_dynamic:
	ldr	x0, [x11, #P_OFFSET]
	add	x12, x10, x0			// x12 - Dynamic Section
	b	.Lparse_ph_cont

.Lfound_load:
	cbnz	x5, .Lparse_ph_cont
	ldr	x0, [x11, #P_OFFSET]
	add	x9, x10, x0
	ldr	x0, [x11, #P_VADDR]
	sub	x9, x9, x0			// x9 - Load Offset
	mov	x5, #1
	b	.Lparse_ph_cont

.Lph_parsed:
	cbz	x5, .Lfail
	cbz	x12, .Lfail

	mov	x13, xzr
	mov	x14, xzr
	mov	x15, xzr

	mov32	x3, DT_GNU_HASH

.Lparse_dynamic:
	ldp	x0, x1, [x12], #16
	cbz	x0, .Ldynamic_parsed

	cmp	x0, #DT_STRTAB
	b.ne	.Lcheck_symtab
	add	x13, x1, x9
	b	.Lparse_dynamic

.Lcheck_symtab:
	cmp	x0, #DT_SYMTAB
	b.ne	.Lcheck_hash
	add	x14, x1, x9
	b	.Lparse_dynamic

.Lcheck_hash:
	cmp	x0, x3
	b.ne	.Lparse_dynamic
	add	x15, x1, x9
	b	.Lparse_dynamic

.Ldynamic_parsed:
	cbz	x13, .Lfail
	cbz	x14, .Lfail
	cbz	x15, .Lfail

	ldp	w12, w0, [x15]
	ldr	w11, [x15, #8]
	add	x11, x15, x11, lsl #3
	add	x11, x11, #16

	adrp	x10, .Lcontext
	add	x10, x10, :lo12:.Lcontext
	stp	x9, x11, [x10], #16
	stp	w0, w12, [x10], #8
	stp	x13, x14, [x10] 

	mov	x0, xzr
	ret

// ========================================================= //

.Lfail:
	mov	x0, #-1
	ret

vdso_sym:
	mov	w1, #5381
	mov	x2, x0

.Lhash_loop:
	ldrb	w3, [x2], #1
	cbz	w3, .Lhash_ready
	add	w1, w1, w1, lsl #5
	add	w1, w1, w3
	b	.Lhash_loop

.Lhash_ready:
	adrp	x10, .Lcontext
	add	x10, x10, :lo12:.Lcontext
	ldp	x9, x11, [x10], #16
	ldp	w15, w12, [x10], #8
	ldp	x13, x14, [x10]

	udiv	w2, w1, w12
	msub	w2, w2, w12, w1
	add	x3, x11, x2, lsl #2
	ldr	w3, [x3]
	cbz	w3, .Lfail

	lsr	w1, w1, #1

	add	x4, x11, x12, lsl #2
	sub	w5, w3, w15
	add	x4, x4, x5, lsl #2

	mov	x5, #SYM_SIZE
	mul	x3, x3, x5

.Lwalk_chain:
	add	x10, x14, x3
	ldr	w11, [x4]
	cmp	w1, w11, lsr #1
	b.ne	.Lnot_match

	mov	x5, x0
	ldr	w15, [x10, #ST_NAME]
	add	x15, x15, x13
	
.Lstrcmp:
	ldrb	w7, [x5], #1
	ldrb	w12, [x15], #1
	subs	w7, w7, w12
	ccmp	w12, wzr, #4, eq
	b.ne	.Lstrcmp
	cbnz	w7, .Lnot_match

	ldr	x0, [x10, #ST_VALUE]
	add	x0, x0, x9

	ret

.Lnot_match:
	tbnz	w11, #0, .Lfail

	add	x4, x4, #4
	add	x3, x3, #SYM_SIZE
	b	.Lwalk_chain

// ========================================================= //

.bss
.balign 8
.Lcontext:
	.space 40

// Load Offset -- x9 -- 8  bytes
// GNU_BUCKET -- x11 -- 8 bytes
// SYMOFFSET -- w0 --> w15 -- 4 bytes
// NBUCKET -- w12 -- 4 bytes
// STRTAB -- x13 -- 8 bytes
// SYMTAB -- x14 -- 8 bytes

