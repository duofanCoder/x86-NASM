;  用户程序
; 显示时间实时更新

SECTION hear vstart=0
    program_length dd program_end      ; [0x00]
    
    ; 用户程序入口
    code_entry  dw start                 ; [0x04]
                dd section.code.start               ; [0x06]

    realloc_tbl_len dw (header_end-realloc_begin)/4    ; [0x0a]

    realloc_begin:
    ; 段重定位表
    code_segment dd section.code.start  ; [0x0c]
    data_segment dd section.data.start
    stack_segment dd section.stack.start

    header_end:                         ; [0x10]

SECTION code align=16 vstart=0

new_int_0x70:
    push ax
    push bx
    push cx
    push dx
    push es

.w0:
    mov al,0x0a
    or al,0x80
    out 0x70,al
    in al,0x71
    test al,0x80
    jnz .w0

    xor al,al
    or al,0x80
    out 0x70,al
    in al,0x71          ;读RTC当前时间秒
    push ax
    mov al,2

    mov al,2
    or al,0x80
    out 0x70,al         ;读RTC当前时间分
    in al,0x71
    push ax

    mov al,4
    or al,0x80
    out 0x70,al         ;读当前时间时
    in al,0x71
    push ax

    mov al,0x0c         ;寄存器C的索引。 开发NMI
    out 0x70,al
    in al,0x71          ;读RTC的寄存器C，否则只发生一次中断
                        ;此处不考虑闹钟和周期性中断的情况


    mov ax,0xb800
    mov es,ax

    pop ax
    call bcd_to_ascii
    mov bx,12*160+36*2
    
    mov [es:bx],ah
    mov [es:bx+2],al

    mov al,':'
    mov [es:bx+4],al
    not byte [es:bx+5]

    pop ax
    call bcd_to_ascii
    mov [es:bx+6],ah
    mov [es:bx+8],al

    mov al,':'
    mov [es:bx+10],al
    not byte[es:bx+11]

    pop ax
    call bcd_to_ascii
    mov [es:bx+12],ah
    mov [es:bx+14],al

    mov al,0x20     ;中断结束命令EOI
    out 0xa0,al     ;向从片发送
    out 0x20,al     ;向主片发送

    pop es
    pop dx
    pop cx
    pop bx
    pop ax

    iret

bcd_to_ascii:               ;BCD码转ASCII
                            ;输入： AL=bcd码
                            ;输入:  AX=ascii
    mov ah,al
    and al,0x0f
    add al,0x30


    shr ah,4
    and ah,0x0f
    add ah,0x30

    ret


start:
    ; 初始化
    mov ax,[stack_segment]
    mov ss,ax
    mov sp,ss_pointer
    mov ax,[data_segment]
    mov ds,ax

    mov bx,init_msg
    call put_string

    mov bx,inst_msg
    call put_string

    ; 计算0x70号中断的偏移
    mov al,0x70
    mov bl,4
    mul bl
    mov bx,ax

    cli

    push es
    mov ax,0x0000
    mov es,ax
    mov word[es:bx],new_int_0x70
    mov word[es:bx+2],cs
    pop es 

    mov al,0x0b     ; RTC寄存器B
    or al,0x80      ; 阻断 NMI
    out 0x70,al

    mov al,0x12     ; 禁止周期中断，开放更新中断
    out 0x71,al     ; BCD码，24小时

    mov al,0x0c
    out 0x70,al
    in al,0x71

    ; 读8259从片的IMR寄存器
    in al,0xa1  
    and al,0xfe     ; 清除bit 0(此位连接RTC,0表示允许，1表示阻断)
    out 0xa1,al

    sti

    mov bx,done_msg
    call put_string

    mov bx,tips_msg
    call put_string

    mov cx,0xb800
    mov ds,cx
    mov byte [12*160+33*2],'@'

.idle:
    hlt     ;使CPU进入低功耗状态
    not byte[12*160+33*2+1]
    jmp .idle

put_string:
    mov cl,[bx]

    ; 影响零标志位,和符号标志位
    ; 结果=0,零标志位为1
    ; 结果为负数,符号标志位为1
    or cl,cl            
    ; jz 零标志位为1,跳转
    ; 0时退出
    jz .exit
    call put_char
    inc bx
    
    jmp put_string
    .exit:
        ret


put_char:
    push ax
    push bx
    push cx
    push dx
    push ds
    push es


    ; 索引寄存器的端口号是 0x3d4，可以向它写入一个值，用来指定内部的某个寄存器。比如，
    ; 两个 8 位的光标寄存器，其索引值分别是 14（0x0e）和 15（0x0f），分别用于提供光标位置的
    ; 高 8 位和低 8 位。
    mov dx,0x3d4
    mov al,0x0e
    out dx,al
    mov dx,0x3d5
    in al,dx
    mov ah,al

    mov dx,0x3d4
    mov al,0x0f
    out dx,al
    mov dx,0x3d5
    in al,dx

    ; bx光标位置
    mov bx,ax

    cmp cl,0x0d     ; 是否是回车符
    jnz .put_0a     ; 不是,看看是不是换行等字符
    mov ax,bx       ; 多余
    mov bl,80
    div bl
    mul bl
    mov bx,ax
    jmp .set_cursor


.put_0a:
    cmp cl,0x0a

    jnz .put_other
    ; 标准VGA文本模式 25x80 
    add bx,80
    jmp .roll_screen
.put_other:
    mov ax,0xb800
    mov es,ax

    ; 一个字符在显存中对应两个字节
    ; 乘以2来得到在显存里光标的偏移地址
    shl bx,1
    mov [es:bx],cl

    ; 光标位置+1
    shr bx,1
    add bx,1

.roll_screen:
    cmp bx,2000
    ; 超出屏幕需要滚屏
    ; 这句如果执行了，将会返回call调用处，下面的滚屏操作将不再执行
    jl .set_cursor

    ; 滚屏操作
    ; 复制内存
    mov ax,0xb800
    mov ds,ax
    mov es,ax
    cld
    mov si,0xa0
    mov di,0x00
    mov cx,1920
    rep movsw

    ; 清楚屏幕最底一行,其开始的偏移地址是1920x2
    mov bx,3840
    mov cx,80
.cls:
    mov word[es:bx],0x0720
    add bx,2
    loop .cls
    mov bx,1920

; 未超出屏幕，
; 参数(光标位置:bx)
.set_cursor:
    ; 修改光标高八位
    mov dx,0x3d4
    mov al,0x0e
    out dx,al
    mov dx,0x3d5
    mov al,bh
    out dx,al
    ; 修改光标高八位
    mov dx,0x3d4
    mov al,0x0f
    out dx,al
    mov dx,0x3d5
    mov al,bl
    out dx,al

    pop es
    pop ds
    pop dx
    pop cx
    pop bx
    pop ax

    ; 返回到call
    ret 


; data segment
SECTION data align=16 vstart=0
    init_msg    db 'Starting...',0x0d,0x0a,0

    inst_msg    db 'Installing a new interrupt 70H...',0

    done_msg    db 'Done.',0x0d,0x0a,0

    tips_msg    db 'Clock is now working.',0

; stack segment
SECTION stack align=16 vstart=0
    resb 256
ss_pointer:

SECTION program_trail
program_end: