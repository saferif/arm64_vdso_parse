.global gettimeofday, clock_gettime, clock_getres

.text

gettimeofday:
	mov	x6, #0
	b	.Ltrampoline

clock_gettime:
	mov	x6, #1
	b	.Ltrampoline

clock_getres:
	mov	x6, #2

.Ltrampoline:
	adrp	x5, .Lvdso_addrs
	add	x5, x5, :lo12:.Lvdso_addrs
	add	x5, x5, x6, lsl #3
	ldr	x7, [x5]
	cbz	x7, .Lresolve
	br	x7

.Lresolve:
	stp	x29, x30, [sp, #-16]!
	stp	x0, x1, [sp, #-16]!
	stp	x5, x6, [sp, #-16]!
	adr	x0, .Lvdso_names
	ldr	x0, [x0, x6, lsl #3]
	bl	vdso_sym
	mov	x7, x0
	ldp	x5, x6, [sp], #16
	ldp	x0, x1, [sp], #16
	ldp	x29, x30, [sp], #16
	cmp	x7, #-1
	b.eq	.Lfail

.Lsave_and_jump:
	str	x7, [x5]
	br	x7

.Lfail:
	adr	x7, .Lsyscall_fallbacks
	add	x7, x7, x6, lsl #3
	b	.Lsave_and_jump

.balign 8
.Lsyscall_fallbacks:
	mov	x8, #169
	b	.Ldo_svc
	mov	x8, #113
	b	.Ldo_svc
	mov	x8, #114

.Ldo_svc:
	svc	#0
	ret

.Lvdso_names:
	.quad .Lname_gtod
	.quad .Lname_cgt
	.quad .Lname_cgr

	.Lname_gtod:	.asciz "__kernel_gettimeofday"
	.Lname_cgt:	.asciz "__kernel_clock_gettime"
	.Lname_cgr:	.asciz "__kernel_clock_getres"

.data
.balign 8
.Lvdso_addrs:
	.quad 0
	.quad 0
	.quad 0
