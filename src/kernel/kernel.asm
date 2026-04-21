[bits 64]
[org 0x00100000]
default rel

VGA_TEXT_BASE equ 0xB8000

COM1_BASE equ 0x3F8

_start:
    cli
    cld
    mov rsp, stack_top
    call ui_init

    call serial_init

    call idt_init
    call pic_init
    call pit_init
    call kbd_init
    sti

    call shell

.halt:
    cli
    hlt
    jmp .halt

port_outb:
    mov dx, di
    mov al, sil
    out dx, al
    ret

port_inb:
    mov dx, di
    in al, dx
    movzx rax, al
    ret

serial_init:
    mov rdi, COM1_BASE + 1
    mov rsi, 0x00
    call port_outb

    mov rdi, COM1_BASE + 3
    mov rsi, 0x80
    call port_outb

    mov rdi, COM1_BASE + 0
    mov rsi, 0x01
    call port_outb
    mov rdi, COM1_BASE + 1
    mov rsi, 0x00
    call port_outb

    mov rdi, COM1_BASE + 3
    mov rsi, 0x03
    call port_outb

    mov rdi, COM1_BASE + 2
    mov rsi, 0xC7
    call port_outb

    mov rdi, COM1_BASE + 4
    mov rsi, 0x0B
    call port_outb
    ret

serial_putc:
    cmp dil, 10
    jne .go
    mov rdi, 13
    call serial_putc
.go:
    mov rdx, COM1_BASE
.wait:
    mov rdi, COM1_BASE + 5
    call port_inb
    test al, 0x20
    jz .wait
    mov al, dil
    out dx, al
    ret

vga_clear:
    call ui_init
    ret

vga_put_at:
    mov rax, rdi
    imul rax, rax, 80
    add rax, rsi
    shl rax, 1
    add rax, VGA_TEXT_BASE
    mov byte [rax], dl
    mov byte [rax+1], cl
    ret

vga_fill_row:
    mov r8, rdi
    xor rsi, rsi
.loop:
    cmp rsi, 80
    jae .out
    mov rdi, r8
    mov dl, ' '
    call vga_put_at
    inc rsi
    jmp .loop
.out:
    ret

ui_init:
    mov dword [cursor_row], 2
    mov dword [cursor_col], 0
    mov byte [attr_current], 0x07

    mov rdi, VGA_TEXT_BASE
    mov rcx, 80*25
    mov ax, 0x0720
    rep stosw

    mov rdi, 0
    mov cl, 0x1F
    call vga_fill_row
    mov rdi, 0
    mov rsi, 2
    lea rdx, [ui_title]
    mov rcx, 0x1F
    call ui_write_cstr_at

    mov rdi, 1
    mov cl, 0x70
    call vga_fill_row
    call ui_update_status

    call console_clear
    ret

ui_write_cstr_at:
    mov r8, rdi
    mov r9, rsi
    mov r10, rdx
.l:
    mov al, [r10]
    test al, al
    jz .o
    mov rdi, r8
    mov rsi, r9
    mov dl, al
    mov cl, cl
    call vga_put_at
    inc r10
    inc r9
    jmp .l
.o:
    ret

ui_write_hex64_at:
    mov r8, rdi
    mov r9, rsi
    mov r10, rcx
    mov rcx, 16
.hx:
    rol rax, 4
    mov dl, al
    and dl, 0x0F
    cmp dl, 9
    jbe .num
    add dl, 'A' - 10
    jmp .emit
.num:
    add dl, '0'
.emit:
    mov rdi, r8
    mov rsi, r9
    mov cl, r10b
    call vga_put_at
    inc r9
    loop .hx
    ret

ui_update_status:
    mov rdi, 1
    mov cl, 0x70
    call vga_fill_row

    mov rdi, 1
    mov rsi, 2
    lea rdx, [ui_status_ticks]
    mov rcx, 0x70
    call ui_write_cstr_at

    mov rax, [ticks]
    mov rdi, 1
    mov rsi, 12
    mov rcx, 0x70
    call ui_write_hex64_at

    mov rdi, 1
    mov rsi, 32
    lea rdx, [ui_status_fs]
    mov rcx, 0x70
    call ui_write_cstr_at

    mov eax, [fs_mounted]
    cmp eax, 1
    jne .fsno
    mov rdi, 1
    mov rsi, 40
    lea rdx, [ui_yes]
    mov rcx, 0x70
    call ui_write_cstr_at
    jmp .next
.fsno:
    mov rdi, 1
    mov rsi, 40
    lea rdx, [ui_no]
    mov rcx, 0x70
    call ui_write_cstr_at
.next:
    mov rdi, 1
    mov rsi, 48
    lea rdx, [ui_status_next]
    mov rcx, 0x70
    call ui_write_cstr_at

    mov eax, [fs_next_free]
    movzx rax, eax
    mov rdi, 1
    mov rsi, 58
    mov rcx, 0x70
    call ui_write_hex64_at
    ret

vga_putc:
    call console_putc
    ret

vga_print:
    mov rsi, rdi
.loop:
    mov al, [rsi]
    test al, al
    jz .out
    movzx rdi, al
    call vga_putc
    inc rsi
    jmp .loop
.out:
    ret

vga_print_nl:
    mov rdi, 10
    call vga_putc
    ret

console_clear:
    mov r8d, 2
.row:
    cmp r8d, 25
    jae .done
    mov rdi, r8
    mov cl, 0x07
    call vga_fill_row
    inc r8d
    jmp .row
.done:
    mov dword [cursor_row], 2
    mov dword [cursor_col], 0
    ret

console_scroll:
    mov rdi, VGA_TEXT_BASE
    mov rsi, VGA_TEXT_BASE
    add rdi, 2*160
    add rsi, 3*160
    mov rcx, (22*80)
    rep movsw

    mov rdi, 24
    mov cl, 0x07
    call vga_fill_row
    ret

console_newline:
    mov eax, [cursor_row]
    inc eax
    mov [cursor_row], eax
    mov dword [cursor_col], 0
    cmp eax, 25
    jb .ok
    call console_scroll
    mov dword [cursor_row], 24
.ok:
    ret

console_backspace:
    mov eax, [cursor_col]
    test eax, eax
    jz .out
    dec eax
    mov [cursor_col], eax
    mov edx, eax
    mov eax, [cursor_row]
    movzx rdi, eax
    movzx rsi, edx
    mov dl, ' '
    mov cl, [attr_current]
    call vga_put_at
.out:
    ret

console_putc:
    cmp dil, 0x0D
    je .out

    push rdi
    call serial_putc
    pop rdi

    cmp dil, 0x0A
    je console_newline

    mov eax, [cursor_row]
    mov edx, [cursor_col]
    movzx rdi, eax
    movzx rsi, edx
    mov dl, dil
    mov cl, [attr_current]
    call vga_put_at

    inc dword [cursor_col]
    mov eax, [cursor_col]
    cmp eax, 80
    jb .out
    call console_newline
.out:
    ret

pic_init:
    mov rdi, 0x20
    mov rsi, 0x11
    call port_outb
    mov rdi, 0xA0
    mov rsi, 0x11
    call port_outb

    mov rdi, 0x21
    mov rsi, 0x20
    call port_outb
    mov rdi, 0xA1
    mov rsi, 0x28
    call port_outb

    mov rdi, 0x21
    mov rsi, 0x04
    call port_outb
    mov rdi, 0xA1
    mov rsi, 0x02
    call port_outb

    mov rdi, 0x21
    mov rsi, 0x01
    call port_outb
    mov rdi, 0xA1
    mov rsi, 0x01
    call port_outb

    mov rdi, 0x21
    mov rsi, 0xFC
    call port_outb
    mov rdi, 0xA1
    mov rsi, 0xFF
    call port_outb
    ret

pic_eoi:
    mov rdi, 0x20
    mov rsi, 0x20
    call port_outb
    ret

pic_eoi_slave:
    mov rdi, 0xA0
    mov rsi, 0x20
    call port_outb
    mov rdi, 0x20
    mov rsi, 0x20
    call port_outb
    ret

pit_init:
    mov rdi, 0x43
    mov rsi, 0x36
    call port_outb

    mov eax, 1193182
    mov ecx, 100
    xor edx, edx
    div ecx
    mov bx, ax

    mov rdi, 0x40
    mov rsi, rbx
    and rsi, 0xFF
    call port_outb
    mov rdi, 0x40
    mov rsi, rbx
    shr rsi, 8
    and rsi, 0xFF
    call port_outb

    mov rdi, 0x21
    call port_inb
    and al, 0xFE
    mov rdi, 0x21
    mov rsi, rax
    call port_outb
    ret

kbd_init:
    mov rdi, 0x21
    call port_inb
    and al, 0xFD
    mov rdi, 0x21
    mov rsi, rax
    call port_outb
    ret

idt_init:
    lea rax, [idt]
    mov qword [idtr+2], rax
    mov word [idtr], idt_end - idt - 1

    lea rbx, [isr_stub_table]
    xor ecx, ecx
.loop:
    movzx rdi, ecx
    mov rsi, [rbx + rcx*8]
    call idt_set_gate
    inc ecx
    cmp ecx, 256
    jne .loop

    lidt [idtr]
    ret

idt_set_gate:
    mov rdx, rsi
    mov rcx, rdi
    shl rcx, 4
    lea rbx, [idt + rcx]

    mov word [rbx + 0], dx
    mov word [rbx + 2], 0x08
    mov byte [rbx + 4], 0
    mov byte [rbx + 5], 0x8E
    shr rdx, 16
    mov word [rbx + 6], dx
    shr rdx, 16
    mov dword [rbx + 8], edx
    mov dword [rbx + 12], 0
    ret

%macro ISR_NOERR 1
isr_stub_%1:
    push 0
    push %1
    jmp isr_common
%endmacro

%macro ISR_ERR 1
isr_stub_%1:
    push %1
    jmp isr_common
%endmacro

%assign i 0
%rep 256
%if i=8 || i=10 || i=11 || i=12 || i=13 || i=14 || i=17 || i=21 || i=29 || i=30
    ISR_ERR i
%else
    ISR_NOERR i
%endif
%assign i i+1
%endrep

isr_stub_table:
%assign i 0
%rep 256
    dq isr_stub_%+i
%assign i i+1
%endrep

isr_common:
    push r15
    push r14
    push r13
    push r12
    push r11
    push r10
    push r9
    push r8
    push rbp
    push rdi
    push rsi
    push rdx
    push rcx
    push rbx
    push rax

    mov rdi, [rsp + 15*8 + 0]
    mov rsi, [rsp + 15*8 + 8]
    call interrupt_dispatch

    pop rax
    pop rbx
    pop rcx
    pop rdx
    pop rsi
    pop rdi
    pop rbp
    pop r8
    pop r9
    pop r10
    pop r11
    pop r12
    pop r13
    pop r14
    pop r15

    add rsp, 16
    iretq

interrupt_dispatch:
    cmp edi, 32
    jb exception_handler

    cmp edi, 32
    je pit_handler
    cmp edi, 33
    je kbd_handler
    cmp edi, 39
    je irq7_spurious
    cmp edi, 47
    je irq15_spurious
    ret

exception_handler:
    cli
    mov rdi, msg_exc
    call vga_print
    mov rdi, msg_exc_vec
    call vga_print
    movzx rax, edi
    call vga_print_hex64
    mov rdi, msg_exc_err
    call vga_print
    mov rax, rsi
    call vga_print_hex64
    call vga_print_nl
.h:
    hlt
    jmp .h

irq7_spurious:
    call pic_eoi
    ret

irq15_spurious:
    call pic_eoi_slave
    ret

pit_handler:
    inc qword [ticks]
    mov rax, [ticks]
    test al, 0x0F
    jne .skip
    call ui_update_status
.skip:
    call pic_eoi
    ret

kbd_handler:
    mov rdi, 0x60
    call port_inb
    mov bl, al

    mov eax, [kbd_head]
    mov ecx, eax
    inc ecx
    and ecx, (KBD_BUF_SIZE-1)
    cmp ecx, [kbd_tail]
    je .eoi
    mov [kbd_buf + rax], bl
    mov [kbd_head], ecx
.eoi:
    call pic_eoi
    ret

    ret

kbd_get_scancode:
.wait:
    mov eax, [kbd_tail]
    cmp eax, [kbd_head]
    je .wait
    mov bl, [kbd_buf + rax]
    inc eax
    and eax, (KBD_BUF_SIZE-1)
    mov [kbd_tail], eax
    movzx rax, bl
    ret

scancode_to_ascii:
    cmp dil, 0x80
    jae .none
    movzx rax, byte [scancode_map + rdi]
    ret
.none:
    xor eax, eax
    ret

shell:
    call fs_try_mount
    call ui_update_status
    mov rdi, prompt
    call vga_print
    xor ecx, ecx

.read:
    call kbd_get_scancode
    mov dil, al
    call scancode_to_ascii
    test al, al
    jz .read
    cmp al, 0x08
    jne .not_bs
    test ecx, ecx
    jz .read
    dec ecx
    call console_backspace
    jmp .read

.not_bs:
    cmp al, 0x0A
    je .line
    cmp ecx, CMD_BUF_SIZE-1
    jae .read
    mov [cmd_buf + rcx], al
    inc ecx
    mov rdi, rax
    call vga_putc
    jmp .read

.line:
    mov byte [cmd_buf + rcx], 0
    call vga_print_nl
    lea rdi, [cmd_buf]
    call shell_exec
    mov rdi, prompt
    call vga_print
    xor ecx, ecx
    jmp .read

shell_exec:
    call str_skip_spaces

    mov rbx, rdi

    mov rsi, cmd_mkfs
    call str_eq
    test eax, eax
    jnz .mkfs

    mov rsi, cmd_ls
    call str_eq
    test eax, eax
    jnz .ls

    mov rsi, cmd_cat
    call str_eq
    test eax, eax
    jnz .cat

    mov rsi, cmd_write
    call str_eq
    test eax, eax
    jnz .write

    mov rsi, cmd_rm
    call str_eq
    test eax, eax
    jnz .rm
    mov rsi, cmd_help
    call str_eq
    test eax, eax
    jnz .help


    mov rsi, cmd_clear
    call str_eq
    test eax, eax
    jnz .clear

    mov rsi, cmd_ticks
    call str_eq
    test eax, eax
    jnz .ticks

    mov rsi, cmd_halt
    call str_eq
    test eax, eax
    jnz .halt

    mov rsi, cmd_reboot
    call str_eq
    test eax, eax
    jnz .reboot

    mov rdi, msg_unknown
    call vga_print
    call vga_print_nl
    ret

.help:
    mov rdi, msg_help
    call vga_print
    call vga_print_nl
    ret

.clear:
    call vga_clear
    ret

.ticks:
    mov rdi, msg_ticks
    call vga_print
    mov rax, [ticks]
    call vga_print_hex64
    call vga_print_nl
    ret

.halt:
    cli
.h:
    hlt
    jmp .h

.reboot:
    mov rdi, 0x64
    mov rsi, 0xFE
    call port_outb
    ret

.mkfs:
    call fs_format
    call ui_update_status
    ret

.ls:
    call fs_list
    ret

.cat:
    mov rdi, rbx
    call arg1_ptr
    test rax, rax
    jz .need_arg
    mov rdi, rax
    call fs_cat
    ret

.write:
    mov rdi, rbx
    call arg1_ptr
    test rax, rax
    jz .need_arg
    mov r12, rax
    mov rdi, rbx
    call arg2_ptr
    test rax, rax
    jz .need_arg
    mov r13, rax
    mov rdi, r13
    call strlen
    mov rdx, rax
    mov rdi, r12
    mov rsi, r13
    call fs_write
    call ui_update_status
    ret

.rm:
    mov rdi, rbx
    call arg1_ptr
    test rax, rax
    jz .need_arg
    mov rdi, rax
    call fs_rm
    call ui_update_status
    ret

.need_arg:
    mov rdi, msg_need_arg
    call vga_print
    call vga_print_nl
    ret

str_skip_spaces:
    mov rax, rdi
.s:
    mov bl, [rax]
    cmp bl, ' '
    jne .out
    inc rax
    jmp .s
.out:
    mov rdi, rax
    ret

str_eq:
    push rdi
    push rsi
    xor eax, eax
.loop2:
    mov bl, [rdi]
    mov dl, [rsi]
    cmp dl, 0
    je .endpat
    cmp bl, dl
    jne .no
    inc rdi
    inc rsi
    jmp .loop2
.endpat:
    mov bl, [rdi]
    cmp bl, 0
    je .yes
    cmp bl, ' '
    je .yes
.no:
    xor eax, eax
    pop rsi
    pop rdi
    ret
.yes:
    mov eax, 1
    pop rsi
    pop rdi
    ret

vga_print_hex64:
    mov rcx, 16
.hx:
    rol rax, 4
    mov bl, al
    and bl, 0x0F
    cmp bl, 9
    jbe .num
    add bl, 'A' - 10
    jmp .emit
.num:
    add bl, '0'
.emit:
    movzx rdi, bl
    call vga_putc
    loop .hx
    ret

strlen:
    xor eax, eax
.l:
    mov bl, [rdi + rax]
    test bl, bl
    jz .o
    inc eax
    jmp .l
.o:
    ret

arg1_ptr:
    call str_skip_spaces
    mov rax, rdi
.s1:
    mov bl, [rax]
    test bl, bl
    jz .none
    cmp bl, ' '
    je .after
    inc rax
    jmp .s1
.after:
    inc rax
.skip:
    mov bl, [rax]
    test bl, bl
    jz .none
    cmp bl, ' '
    jne .ok
    inc rax
    jmp .skip
.ok:
    ret
.none:
    xor eax, eax
    ret

arg2_ptr:
    call arg1_ptr
    test rax, rax
    jz .none
    mov rdi, rax
    mov rax, rdi
.s2:
    mov bl, [rax]
    test bl, bl
    jz .none
    cmp bl, ' '
    je .after
    inc rax
    jmp .s2
.after:
    inc rax
.skip:
    mov bl, [rax]
    test bl, bl
    jz .none
    cmp bl, ' '
    jne .ok
    inc rax
    jmp .skip
.ok:
    ret
.none:
    xor eax, eax
    ret

ata_delay:
    mov rdi, 0x3F6
    call port_inb
    mov rdi, 0x3F6
    call port_inb
    mov rdi, 0x3F6
    call port_inb
    mov rdi, 0x3F6
    call port_inb
    ret

ata_wait_not_busy:
    mov rdi, 0x1F7
.w:
    call port_inb
    test al, 0x80
    jnz .w
    ret

ata_wait_drq:
    mov rdi, 0x1F7
.w:
    call port_inb
    test al, 0x08
    jnz .ok
    test al, 0x01
    jnz .err
    jmp .w
.ok:
    xor eax, eax
    ret
.err:
    mov eax, 1
    ret

disk_read_sector:
    push rbx
    push r12
    mov r12, rdi
    mov ebx, eax
    call ata_wait_not_busy
    mov rdi, 0x1F6
    mov eax, ebx
    shr eax, 24
    and eax, 0x0F
    or eax, 0xE0
    mov rsi, rax
    call port_outb
    call ata_delay

    mov rdi, 0x1F2
    mov rsi, 1
    call port_outb

    mov rdi, 0x1F3
    mov eax, ebx
    and eax, 0xFF
    mov rsi, rax
    call port_outb

    mov rdi, 0x1F4
    mov eax, ebx
    shr eax, 8
    and eax, 0xFF
    mov rsi, rax
    call port_outb

    mov rdi, 0x1F5
    mov eax, ebx
    shr eax, 16
    and eax, 0xFF
    mov rsi, rax
    call port_outb

    mov rdi, 0x1F7
    mov rsi, 0x20
    call port_outb

    call ata_wait_drq
    test eax, eax
    jnz .err
    mov rdi, r12
    mov dx, 0x1F0
    mov rcx, 256
    rep insw
    xor eax, eax
    pop r12
    pop rbx
    ret
.err:
    mov eax, 1
    pop r12
    pop rbx
    ret

disk_write_sector:
    push rbx
    push r12
    mov r12, rsi
    mov ebx, eax
    call ata_wait_not_busy
    mov rdi, 0x1F6
    mov eax, ebx
    shr eax, 24
    and eax, 0x0F
    or eax, 0xE0
    mov rsi, rax
    call port_outb
    call ata_delay

    mov rdi, 0x1F2
    mov rsi, 1
    call port_outb

    mov rdi, 0x1F3
    mov eax, ebx
    and eax, 0xFF
    mov rsi, rax
    call port_outb

    mov rdi, 0x1F4
    mov eax, ebx
    shr eax, 8
    and eax, 0xFF
    mov rsi, rax
    call port_outb

    mov rdi, 0x1F5
    mov eax, ebx
    shr eax, 16
    and eax, 0xFF
    mov rsi, rax
    call port_outb

    mov rdi, 0x1F7
    mov rsi, 0x30
    call port_outb

    call ata_wait_drq
    test eax, eax
    jnz .err
    mov rsi, r12
    mov dx, 0x1F0
    mov rcx, 256
    rep outsw

    mov rdi, 0x1F7
.f:
    call port_inb
    test al, 0x80
    jnz .f
    xor eax, eax
    pop r12
    pop rbx
    ret
.err:
    mov eax, 1
    pop r12
    pop rbx
    ret

FS_LBA_BASE equ 2048
FS_DIR_LBA equ (FS_LBA_BASE + 1)
FS_DIR_SECTORS equ 8
FS_DATA_LBA equ (FS_DIR_LBA + FS_DIR_SECTORS)

fs_try_mount:
    cmp dword [fs_mounted], 1
    je .ok
    lea rdi, [sector_buf]
    mov eax, FS_LBA_BASE
    call disk_read_sector
    test eax, eax
    jnz .no
    mov eax, dword [sector_buf + 0]
    cmp eax, 0x53465A46
    jne .no
    mov eax, dword [sector_buf + 4]
    cmp eax, 1
    jne .no
    mov eax, dword [sector_buf + 8]
    mov [fs_next_free], eax
    mov eax, 1
    mov [fs_mounted], eax
.ok:
    mov eax, 1
    ret
.no:
    xor eax, eax
    ret

fs_format:
    lea rdi, [sector_buf]
    mov rcx, 512/8
    xor rax, rax
    rep stosq
    mov dword [sector_buf + 0], 0x53465A46
    mov dword [sector_buf + 4], 1
    mov dword [sector_buf + 8], 0
    mov dword [sector_buf + 12], FS_DIR_LBA
    mov dword [sector_buf + 16], FS_DATA_LBA
    lea rsi, [sector_buf]
    mov eax, FS_LBA_BASE
    call disk_write_sector
    test eax, eax
    jnz .ioerr

    lea rdi, [sector_buf]
    mov rcx, 512/8
    xor rax, rax
    rep stosq
    mov r10d, FS_DIR_LBA
    mov ecx, FS_DIR_SECTORS
.d:
    push rcx
    lea rsi, [sector_buf]
    mov eax, r10d
    call disk_write_sector
    pop rcx
    test eax, eax
    jnz .ioerr
    inc r10d
    dec ecx
    jnz .d
    mov dword [fs_next_free], 0
    mov dword [fs_mounted], 1
    mov rdi, msg_ok
    call vga_print
    call vga_print_nl
    ret
.ioerr:
    mov rdi, msg_disk_fail
    call vga_print
    call vga_print_nl
    ret

fs_load_dir:
    mov r10d, FS_DIR_LBA
    xor ebx, ebx
.l:
    cmp ebx, FS_DIR_SECTORS
    jae .ok
    lea rdi, [dir_buf + rbx*512]
    mov eax, r10d
    call disk_read_sector
    test eax, eax
    jnz .ioerr
    inc r10d
    inc ebx
    jmp .l
.ok:
    xor eax, eax
    ret
.ioerr:
    mov eax, 1
    ret

fs_store_dir:
    mov r10d, FS_DIR_LBA
    xor ebx, ebx
.l:
    cmp ebx, FS_DIR_SECTORS
    jae .ok
    lea rsi, [dir_buf + rbx*512]
    mov eax, r10d
    call disk_write_sector
    test eax, eax
    jnz .ioerr
    inc r10d
    inc ebx
    jmp .l
.ok:
    xor eax, eax
    ret
.ioerr:
    mov eax, 1
    ret

fs_find:
    mov r12, rdi
    xor ebx, ebx
.loop:
    cmp ebx, 128
    jae .none
    lea rsi, [dir_buf + rbx*32]
    mov al, [rsi]
    test al, al
    jz .next
    mov rdi, r12
    mov rdx, rsi
    call name_eq16
    test eax, eax
    jnz .hit
.next:
    inc ebx
    jmp .loop
.hit:
    mov eax, ebx
    ret
.none:
    mov eax, 0xFFFFFFFF
    ret

name_eq16:
    xor ecx, ecx
.c:
    cmp ecx, 16
    jae .yes
    mov al, [rdi + rcx]
    mov bl, [rdx + rcx]
    cmp bl, 0
    je .endb
    cmp al, bl
    jne .no
    inc ecx
    jmp .c
.endb:
    cmp al, 0
    je .yes
    cmp al, ' '
    je .yes
    jmp .no
.yes:
    mov eax, 1
    ret
.no:
    xor eax, eax
    ret

name_copy16:
    xor ecx, ecx
.c:
    cmp ecx, 16
    jae .z
    mov al, [rsi + rcx]
    cmp al, 0
    je .z
    mov [rdi + rcx], al
    inc ecx
    jmp .c
.z:
    mov byte [rdi + ecx], 0
    ret

fs_list:
    call fs_try_mount
    test eax, eax
    jnz .mounted
    mov rdi, msg_no_fs
    call vga_print
    call vga_print_nl
    ret
.mounted:
    call fs_load_dir
    test eax, eax
    jz .ok
    mov rdi, msg_disk_fail
    call vga_print
    call vga_print_nl
    ret
.ok:
    mov rdi, msg_files
    call vga_print
    call vga_print_nl
    xor ebx, ebx
.ent:
    cmp ebx, 128
    jae .done
    lea rsi, [dir_buf + rbx*32]
    mov al, [rsi]
    test al, al
    jz .next
    mov rdi, rsi
    call vga_print
    mov rdi, msg_sp
    call vga_print
    mov eax, dword [rsi + 20]
    movzx rax, eax
    call vga_print_hex64
    call vga_print_nl
.next:
    inc ebx
    jmp .ent
.done:
    ret

fs_cat:
    mov r12, rdi
    call fs_try_mount
    test eax, eax
    jnz .mounted
    mov rdi, msg_no_fs
    call vga_print
    call vga_print_nl
    ret
.mounted:
    call fs_load_dir
    test eax, eax
    jz .ok
    mov rdi, msg_disk_fail
    call vga_print
    call vga_print_nl
    ret
.ok:
    mov rdi, r12
    call fs_find
    cmp eax, 0xFFFFFFFF
    jne .found
    mov rdi, msg_not_found
    call vga_print
    call vga_print_nl
    ret
.found:
    mov ebx, eax
    lea rsi, [dir_buf + rbx*32]
    mov eax, dword [rsi + 16]
    mov r8d, eax
    mov eax, dword [rsi + 20]
    mov r9d, eax
    mov eax, r9d
    add eax, 511
    mov ecx, 512
    xor edx, edx
    div ecx
    mov r10d, eax

    mov r11d, r9d
    xor ebx, ebx
.rl:
    cmp ebx, r10d
    jae .done
    lea rdi, [sector_buf]
    mov eax, r8d
    add eax, FS_DATA_LBA
    add eax, ebx
    call disk_read_sector
    test eax, eax
    jnz .io

    mov ecx, 512
    cmp r11d, 512
    jae .pr
    mov ecx, r11d
.pr:
    xor edx, edx
.p:
    cmp edx, ecx
    jae .next
    mov al, [sector_buf + rdx]
    movzx rdi, al
    call vga_putc
    inc edx
    jmp .p
.next:
    sub r11d, ecx
    inc ebx
    jmp .rl
.done:
    call vga_print_nl
    ret

.io:
    mov rdi, msg_disk_fail
    call vga_print
    call vga_print_nl
    ret

fs_rm:
    mov r12, rdi
    call fs_try_mount
    test eax, eax
    jnz .mounted
    mov rdi, msg_no_fs
    call vga_print
    call vga_print_nl
    ret
.mounted:
    call fs_load_dir
    test eax, eax
    jz .ok
    mov rdi, msg_disk_fail
    call vga_print
    call vga_print_nl
    ret
.ok:
    mov rdi, r12
    call fs_find
    cmp eax, 0xFFFFFFFF
    jne .found
    mov rdi, msg_not_found
    call vga_print
    call vga_print_nl
    ret
.found:
    mov ebx, eax
    lea rdi, [dir_buf + rbx*32]
    mov byte [rdi], 0
    call fs_store_dir
    test eax, eax
    jz .ok2
    mov rdi, msg_disk_fail
    call vga_print
    call vga_print_nl
    ret
.ok2:
    mov rdi, msg_ok
    call vga_print
    call vga_print_nl
    ret

fs_write:
    mov r12, rdi
    mov r13, rsi
    mov r14, rdx
    call fs_try_mount
    test eax, eax
    jnz .mounted
    mov rdi, msg_no_fs
    call vga_print
    call vga_print_nl
    ret
.mounted:
    call fs_load_dir
    test eax, eax
    jz .ok
    mov rdi, msg_disk_fail
    call vga_print
    call vga_print_nl
    ret
.ok:
    mov eax, r14d
    add eax, 511
    mov ecx, 512
    xor edx, edx
    div ecx
    mov r15d, eax
    cmp r15d, 0
    jne .cont
    mov rdi, msg_need_arg
    call vga_print
    call vga_print_nl
    ret
.cont:
    mov eax, dword [fs_next_free]
    mov r8d, eax

    mov rdi, r12
    call fs_find
    mov r10d, eax
    cmp r10d, 0xFFFFFFFF
    jne .have_idx
    xor ebx, ebx
.free:
    cmp ebx, 128
    jae .nodir
    lea rsi, [dir_buf + rbx*32]
    mov al, [rsi]
    test al, al
    jz .use
    inc ebx
    jmp .free
.use:
    mov r10d, ebx
.have_idx:

    xor ebx, ebx
    xor r9d, r9d
.wloop:
    cmp ebx, r15d
    jae .dir
    lea rdi, [sector_buf]
    mov rcx, 512/8
    xor rax, rax
    rep stosq
    xor ecx, ecx
.fill:
    cmp r9d, r14d
    jae .do
    cmp ecx, 512
    jae .do
    mov al, [r13 + r9]
    mov [sector_buf + rcx], al
    inc ecx
    inc r9d
    jmp .fill
.do:
    lea rsi, [sector_buf]
    mov eax, r8d
    add eax, FS_DATA_LBA
    add eax, ebx
    call disk_write_sector
    test eax, eax
    jnz .ioerr
    inc ebx
    jmp .wloop

.dir:
    lea rdi, [dir_buf + r10*32]
    mov rsi, r12
    call name_copy16
    mov dword [rdi + 16], r8d
    mov dword [rdi + 20], r14d
    mov dword [rdi + 24], 1
    call fs_store_dir
    test eax, eax
    jnz .ioerr

    mov eax, r8d
    add eax, r15d
    mov [fs_next_free], eax
    lea rdi, [sector_buf]
    mov rcx, 512/8
    xor rax, rax
    rep stosq
    mov dword [sector_buf + 0], 0x53465A46
    mov dword [sector_buf + 4], 1
    mov eax, [fs_next_free]
    mov dword [sector_buf + 8], eax
    mov dword [sector_buf + 12], FS_DIR_LBA
    mov dword [sector_buf + 16], FS_DATA_LBA
    lea rsi, [sector_buf]
    mov eax, FS_LBA_BASE
    call disk_write_sector
    test eax, eax
    jnz .ioerr
    mov rdi, msg_ok
    call vga_print
    call vga_print_nl
    ret

.nodir:
    mov rdi, msg_no_dir
    call vga_print
    call vga_print_nl
    ret
.ioerr:
    mov rdi, msg_disk_fail
    call vga_print
    call vga_print_nl
    ret

ui_title: db 'Fazer OS  |  help: commandes  |  mkfs: formater  |  write/cat/ls/rm',0
ui_status_ticks: db 'TICKS=0x',0
ui_status_fs: db 'FS:',0
ui_status_next: db 'NEXT=0x',0
ui_yes: db 'OK',0
ui_no: db 'NO',0

banner: db 'Fazer OS (prototype) - 64-bit kernel',10,0
prompt: db '> ',0
msg_unknown: db 'Commande inconnue. Tapez help.',0
msg_ticks: db 'ticks=0x',0
msg_help: db 'Commandes: help clear ticks halt reboot mkfs ls cat write rm',0
msg_need_arg: db 'Argument manquant',0
msg_no_fs: db 'Aucun FS. Lancez mkfs.',0
msg_disk_fail: db 'Erreur disque',0
msg_ok: db 'OK',0
msg_not_found: db 'Introuvable',0
msg_files: db 'Fichiers:',0
msg_no_dir: db 'Repertoire plein',0
msg_sp: db ' size=0x',0
msg_exc: db 'EXCEPTION ',0
msg_exc_vec: db 'vec=0x',0
msg_exc_err: db ' err=0x',0

cmd_help: db 'help',0
cmd_clear: db 'clear',0
cmd_ticks: db 'ticks',0
cmd_halt: db 'halt',0
cmd_reboot: db 'reboot',0
cmd_mkfs: db 'mkfs',0
cmd_ls: db 'ls',0
cmd_cat: db 'cat',0
cmd_write: db 'write',0
cmd_rm: db 'rm',0

scancode_map:
    db 0
    db 0
    db '1','2','3','4','5','6','7','8','9','0','-','='
    db 8
    db 0
    db 'q','w','e','r','t','y','u','i','o','p','[',']'
    db 10
    db 0
    db 'a','s','d','f','g','h','j','k','l',';'
    db 0x27
    db 0x60
    db 0
    db 0x5C
    db 'z','x','c','v','b','n','m',',','.','/'
    db 0
    db 0
    db 0
    db ' '
    times 128-($-scancode_map) db 0

align 16
stack: resb 16384
stack_top:

cursor_row: resd 1
cursor_col: resd 1
attr_current: resb 1
align 8
ticks: resq 1

KBD_BUF_SIZE equ 256
kbd_buf: resb KBD_BUF_SIZE
kbd_head: resd 1
kbd_tail: resd 1

CMD_BUF_SIZE equ 128
cmd_buf: resb CMD_BUF_SIZE

fs_mounted: resd 1
fs_next_free: resd 1

align 16
sector_buf: resb 512

align 16
dir_buf: resb (FS_DIR_SECTORS*512)

align 16
idtr: dw 0
      dq 0

align 16
idt: times 256 dq 0,0
idt_end:

