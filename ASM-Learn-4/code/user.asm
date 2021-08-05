;  用户程序
; 在屏幕显示success

SECTION hear vstart=0
    program_length dd program_end      ; [0x00]
    
    ; 用户程序入口
    code_entry dw start                 ; [0x04]
    dd section.code.start               ; [0x06]

    realloc_tbl_len dw (header_end-code_segment)/4    ; [0x0a]

    ; 段重定位表
    code_segment dd section.code.start  ; [0x0c]

    header_end:                         ; [0x10]

SECTION code align=16 vstart=0
    msg0_start: db 'd',0x07,'o',0x07,'u',0x07,'f',0x07,'a',0x07,'n',0x07, ':',0x07,'O',0x04,'K',0x04
    msg0_end:

    start:
        mov ax,[code_segment]
        mov ds,ax
         
        mov ax,0xb800
        mov es,ax

        cld
        mov si,msg0_start
        mov di,0
        mov cx,(msg0_end-msg0_start)/2
        rep movsw
        

        jmp near $

program_end: