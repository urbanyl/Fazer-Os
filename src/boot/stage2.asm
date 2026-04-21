[bits 16]
[org 0x8000]

%ifndef STAGE2_SECTORS
%define STAGE2_SECTORS 32
%endif

KERNEL_LOAD_ADDR equ 0x00100000
KERNEL_TEMP_ADDR equ 0x00020000
PAGE_TABLE_BASE  equ 0x00090000
STACK_TOP        equ 0x0008F000

start:
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00
    sti

    mov [boot_drive], dl

    call enable_a20

    mov si, msg_loading
    call bios_print

    call load_kernel

    cli
    lgdt [gdt_ptr]

    mov eax, cr0
    or eax, 1
    mov cr0, eax
    jmp CODE32_SEL:pm_entry

[bits 32]
pm_entry:
    mov ax, DATA32_SEL
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov fs, ax
    mov gs, ax
    mov esp, STACK_TOP

    mov ecx, [kernel_sector_count]
    shl ecx, 7
    mov esi, KERNEL_TEMP_ADDR
    mov edi, KERNEL_LOAD_ADDR
    rep movsd

    call setup_paging

    mov ecx, 0xC0000080
    rdmsr
    or eax, 1 << 8
    wrmsr

    mov eax, cr4
    or eax, 1 << 5
    mov cr4, eax

    mov eax, PAGE_TABLE_BASE
    mov cr3, eax

    mov eax, cr0
    or eax, 1 << 31
    mov cr0, eax

    jmp CODE64_SEL:lm_entry

[bits 64]
lm_entry:
    mov ax, DATA64_SEL
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov fs, ax
    mov gs, ax

    mov rsp, 0x000000000008E000

    mov rax, KERNEL_LOAD_ADDR
    jmp rax

[bits 16]

load_kernel:
    mov dword [dap + 8], (1 + STAGE2_SECTORS)
    mov dword [dap + 12], 0
    mov cx, [kernel_sector_count]
    cmp cx, 0
    je .done

    mov dword [temp_addr], KERNEL_TEMP_ADDR

.next_chunk:
    mov ax, cx
    cmp ax, 32
    jbe .set
    mov ax, 32
.set:
    push cx
    mov dx, ax
    mov eax, [temp_addr]
    mov bx, ax
    and bx, 0x000F
    shr eax, 4
    mov es, ax
    mov [dap + 2], dx
    mov [dap + 4], bx
    mov [dap + 6], es
    mov dl, [boot_drive]
    mov si, dap
    mov ah, 0x42
    int 0x13
    jc disk_error

    movzx eax, word [dap + 2]
    shl eax, 9
    add [temp_addr], eax

    mov eax, [dap + 8]
    movzx edx, word [dap + 2]
    add eax, edx
    mov [dap + 8], eax

    pop cx
    sub cx, word [dap + 2]
    jnz .next_chunk

.done:
    ret

disk_error:
    mov si, msg_disk
    call bios_print
.halt:
    cli
    hlt
    jmp .halt

bios_print:
    pusha
.loop:
    lodsb
    test al, al
    jz .out
    mov ah, 0x0E
    mov bh, 0
    int 0x10
    jmp .loop
.out:
    popa
    ret

enable_a20:
    in al, 0x92
    or al, 0x02
    out 0x92, al
    ret

setup_paging:
    mov edi, PAGE_TABLE_BASE
    mov ecx, 0x3000 / 4
    xor eax, eax
    rep stosd

    mov dword [PAGE_TABLE_BASE + 0x0000], (PAGE_TABLE_BASE + 0x1000) | 0x003
    mov dword [PAGE_TABLE_BASE + 0x1000], (PAGE_TABLE_BASE + 0x2000) | 0x003

    mov dword [PAGE_TABLE_BASE + 0x2000 + 0*8], 0x00000083
    mov dword [PAGE_TABLE_BASE + 0x2000 + 1*8], 0x00200083
    ret

temp_addr:
    dd 0

msg_loading: db 'Loading kernel...',0
msg_disk:    db 'Stage2 disk error',0

boot_drive: db 0

dap:
    db 0x10
    db 0
    dw 0
    dw 0
    dw 0
    dq 0

kernel_sector_count:
    dd 0xCAFEBABE

gdt64:
    dq 0
    dq 0x00AF9A000000FFFF
    dq 0x00AF92000000FFFF

gdt32:
    dq 0
    dq 0x00CF9A000000FFFF
    dq 0x00CF92000000FFFF

gdt:
    dq 0
    dq 0x00CF9A000000FFFF
    dq 0x00CF92000000FFFF
    dq 0x00AF9A000000FFFF
    dq 0x00AF92000000FFFF

gdt_ptr:
    dw gdt_end - gdt - 1
    dd gdt

gdt_end:

CODE32_SEL equ 0x08
DATA32_SEL equ 0x10
CODE64_SEL equ 0x18
DATA64_SEL equ 0x20

