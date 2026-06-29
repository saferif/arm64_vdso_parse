# arm64_vdso_parse

Pure ARM64 assembly VDSO symbol resolver — no libc, no dynamic linker, no dependencies.

This repo is a hand-written ARM64 assembler implementation of a minimal vDSO parser and symbol resolver. Given a pointer to the process's auxv, it walks the in-memory ELF image, locates the GNU hash table, and resolves symbol addresses by name at runtime — all in ~150 lines of assembly with zero C runtime involvement.

## API

Two functions are exported:

### vdso_syms_init
`int vdso_syms_init(void *stack)`

Parses the vDSO ELF image and performs initialization of internal structures.

- *Input:* `stack` – initial value of the program's stack pointer.
- *Returns:* `0` on success, `-1` on failure.

This function *MUST* be called before any call to `vdso_sym`.

### vdso_sym
`void *vdso_sym(const char *name)`

Looks up a vDSO symbol by name.

- *Input:* `name` – null-terminaled C-string name of the symbol to look up.
- *Returns:* resolved virtual address of the symbol, or `-1` if not found.
