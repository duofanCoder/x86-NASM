    jmp near start 

mytext:
    db 'd',0x07,'o',0x07,'u',0x07,'f',0x07,'a',0x07,'n',0x07, ':',0x07
number:
    db 0,0,0,0,0

start:
    ; 设置数据段 基地址
    mov ax,0x7c0
    mov ds,ax

    ; 设置附加段基地址
    mov ax,0xb800
    mov es,ax

    ; 复制内存区域

    ; 清0正向复制   std置1反向复制
    cld         
    mov si,mytext
    mov di,0
    mov cx,(number-mytext)/2
    rep movsw

    mov ax,number

    ;计算各个位
    mov bx,ax
    mov cx,5            ; 循环次数
    mov si,10
digit:
    xor dx,dx
    div si
    mov [bx],dl
    inc bx              ; bx 自增1
    loop digit


    mov bx,number
    mov si,4

show:
    mov al,[bx+si]
    add al,0x30
    mov ah,0x04
    mov [es:di],ax
    add di,2
    dec si      ; 自减1
    jns show    

    mov word [es:di],0x0744

    jmp near $      ; $ 代表当前标号

    ; 填充字节
    times 510-($-$$) db 0    ; $$ 代表当前汇编节（段）的起始汇编地址
    db 0x55,0xaa    



