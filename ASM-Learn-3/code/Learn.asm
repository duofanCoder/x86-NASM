; 完成1到100累加，并显示在屏幕上


jmp near start

message db "1+2+3+...+100="


start:
    mov ax,0x7c0
    mov ds,ax
    mov ax,0xb800
    mov es,ax

    mov si,message
    mov di,0        ;除了作为通用寄存器使用外，还专门用于和外设之间进行数据传送
    mov cx,start-message

@g:
    mov al,[si]
    mov ah,0x07
    mov [es:di],ax
    inc di
    inc di
    inc si
    loop @g

    xor ax,ax
    mov cx,1

@f:
    add ax,cx
    inc cx
    cmp cx,100
    jle @f

    ; 这里使用栈，ss为栈顶的短地址，sp是相对栈顶的偏移
    ; 当使用  PUSH 指令向栈中压入 1 个字节单元时，SP = SP - 1；即栈顶元素会发生变化；
    ; 而当使用  PUSH 指令向栈中压入  2 个字节的字单元时，SP = SP – 2 ；即栈顶元素也要发生变化；
    ; 当使用  POP 指令从栈中弹出 1 个字节单元时， SP = SP + 1；即栈顶元素会发生变化；
    ; 当使用  POP 指令从栈中弹出 2 个字节单元的字单元时， SP = SP + 2 ；即栈顶元素会发生变化；

    xor cx,cx
    mov ss,cx
    mov sp,cx

    ; div  ，ax被除数、结果商也会存到这，dx余数
    mov bx,10
@d:
    inc cx
    xor dx,dx
    div bx
    ; 这里可以等效 add ，
    ; 原因是  dl的高位都是0，0x30低位是0，所以或操作不会影响al低位的余数
    or dl,0x30      
    push dx
    cmp ax,0
    jne @d    

    ;以下显示各个数位 
@a:
    pop dx
    mov [es:di],dl
    inc di
    mov byte [es:di],0x04
    inc di
    ; 循环直到cx为0
    loop @a


jmp near $

times 510-($-$$)db 0
    db 0x55,0xaa

    

