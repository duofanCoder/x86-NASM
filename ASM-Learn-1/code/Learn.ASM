mov ax,0xb800   ;3B  0xb800 扇区程序被加载到该地址
mov es,ax       ;2B
mov byte[es:0x00],'D'   ;7B
mov byte[es:0x01],0x07   ;7B
mov byte[es:0x02],'O'
mov byte[es:0x03],0x07
mov byte[es:0x04],'U'
mov byte[es:0x05],0x07
mov byte[es:0x06],' '
mov byte[es:0x07],0x07
mov byte[es:0x08],'F'
mov byte[es:0x09],0x07
mov byte[es:0x0A],'A'
mov byte[es:0x0B],0x07
mov byte[es:0x0C],'N'
mov byte[es:0x0D],0x07
mov byte[es:0x0E],':'
mov byte[es:0x0F],0x07

;div除法汇编指令 
;被除数：除数为8位, 被除数为16位, 默认在AX中存放.
; 　　   除数为16位, 被除数为32位, 在DX或AX中存放. AX存放低16位,DX存放高16位.

;除数：作为div的操作数
;结果： 除数为8位, 则AL存储除法操作的商, AH存放余数
;       除数为16为, 则AX存储除法操作的商, DX存放余数
mov ax,number   ; 被除数
mov bx,10       ; 除数

xor dx,dx
div bx          ; bx 16位除数
mov [0x7c00+number+0x00],dl     ; 保存个位数

xor dx,dx
div bx
mov [0x7c00+number+0x01],dl     ; 保存十位数

xor dx,dx
div bx
mov [0x7c00+number+0x02],dl     ; 保存百位数

xor dx,dx
div bx
mov [0x7c00+number+0x03],dl     ; 保存千位数

xor dx,dx
div bx
mov [0x7c00+number+0x04],dl     ; 保存万位数

mov al,[0x7c00+number+0x04]
add al,0x30
mov [es:0x10],al
mov byte[es:0x11],0x04


mov al,[0x7c00+number+0x03]
add al,0x30
mov [es:0x12],al
mov byte[es:0x13],0x04


mov al,[0x7c00+number+0x02]
add al,0x30
mov [es:0x14],al
mov byte[es:0x15],0x04


mov al,[0x7c00+number+0x01]
add al,0x30
mov [es:0x16],al
mov byte[es:0x17],0x04


mov al,[0x7c00+number+0x00]
add al,0x30
mov [es:0x18],al
mov byte[es:0x19],0x04

mov byte[es:0x1A],'D'
mov byte[es:0x20],0x07

number:db 0,0,0,0,0     ; 0xb800 +number（偏移地址）刚好是第一个字节的地址

inif:jmp near inif      ; 程序不断在此处循环
times 268 db 0          ; 重复 268 个字节，来凑满512个字节
db 0x55,0xaa        ;  扇区标志