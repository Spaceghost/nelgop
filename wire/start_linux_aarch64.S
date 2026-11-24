.text
.global _start
.type _start, %function
_start:
    bl gop_selftest
    mov x8, #93
    svc #0
    brk #0
.size _start, .-_start
.section .note.GNU-stack,"",%progbits
