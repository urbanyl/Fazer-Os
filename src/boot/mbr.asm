[bits 16]
[org 0x7C00]

%ifndef STAGE2_SECTORS
%define STAGE2_SECTORS 32
%endif

start:
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00
    sti

    mov [boot_drive], dl

    mov si, dap
    mov byte [si + 0], 0x10
    mov byte [si + 1], 0
    mov word [si + 2], STAGE2_SECTORS
    mov word [si + 4], 0x8000
    mov word [si + 6], 0x0000
    mov dword [si + 8], 1
    mov dword [si + 12], 0

    mov dl, [boot_drive]
    mov ah, 0x42
    int 0x13
    jc disk_error

    jmp 0x0000:0x8000

disk_error:
    mov si, msg
.hang:
    lodsb
    test al, al
    jz .halt
    mov ah, 0x0E
    mov bh, 0
    int 0x10
    jmp .hang
.halt:
    cli
    hlt
    jmp .halt

boot_drive: db 0
msg: db 'DISK ERR',0

dap:
    times 16 db 0

times 510-($-$$) db 0
dw 0xAA55

