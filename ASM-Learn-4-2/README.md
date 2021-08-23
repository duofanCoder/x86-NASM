> 基于上篇加载了应到程序后，这一篇对用户程序内容进行增加，有屏幕显示多行内容，并实现超出屏幕，滚动屏幕，光标移动等。

# 引言
简单介绍本次实践，需要用的知识点。

#### 屏幕光标控制
索引寄存器的端口号是 0x3d4，可以向它写入一个值，用来指定内部的某个寄存器。比如，
两个 8 位的光标寄存器，其索引值分别是 14（0x0e）和 15（0x0f），分别用于提供光标位置的高 8 位和低 8 位。
指定了寄存器之后，要对它进行读写，这可以通过数据端口 0x3d5 来进行。
高八位 和第八位里保存这光标的位置，显卡文本模式显示标准是25x80，这样算来，当光标在屏幕右下角时，该值为 25×80－1=1999

#### mul指令
第一种执行 8 位操作数与 AL 寄存器的乘法；
第二种执行 16 位操作数与 AX 寄存器的乘法；
下述语句实现 AL 乘以 BL，乘积存放在 AX 中。由于 AH（乘积的高半部分）等于零，因此进位标志位被清除（CF=0）：
mov al, 5h
mov bl, 10h
mul bl                    ; AX = 0050h, CF = 0
如果 DX 不等于零，则进位标志位置 1，这就意味着隐含的目的操作数的低半部分容纳不了整个乘积。

#### resb指令
伪指令 resb（REServe Byte）的意思是从当前位置开始，保留指定数量的字节，但不初始化它们的值。在源程序编译时，编译器会保留一段内存区域，用来存放编译后的内容。当它看到这条伪指令时，它仅仅是跳过指定数量的字节，而不管里面的原始内容是什么。内存是反复使用的，谁也无法知道以前的使用者在这里留下了什么。也就是说，跳过的这段空间，每个字节的值是不确定的。

		resb 256  ;使用
#### retf指令
        ; retf 相当于执行了两次pop,CPU将执行CS:IP的指令
        ; POP IP
        ; POP CS

#### 回车和换行
回车换行在ASCII码表内是两个码分别是0x0d，0x0a
回车的功能就是光标移动到行首，换行就是到下一行。
在显卡文本模式下25x80，换行就是+80，移动到行首就是
除以80取商再乘以80

# 疑问
#### 汇编有函数吗？
一下是我的理解，有如果错误欢迎批评指正。
万不能把标号下的内容当作一个函数，这只是一个程序的开始地址，当一个标号下的内容运行结束后，不会返回到调用那，需要使用ret，或retf来返回，
这个指令会返回到调用call那。
由于错把标号当作一个函数的缘故，导致我在写这段程序没有注意到顺序，
将.put_other和.set_cursor的标号里的内容调换了位置，结果程序在运行了put_other标号下最后一条指令会执行start标号的内容，导致错误。
所以必须明确汇编在运行的时候没有遇到转移指令，call和ret或retf的时候都是一步一步向下执行的。
![正确操作](https://img-blog.csdnimg.cn/476cd3d390934978b835561abcbf270f.png?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_10,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3dlaXhpbl80NDU4MDk3Nw==,size_16,color_FFFFFF,t_70)

# 程序环境
NASM 编译器版本 :nasm-2.07
IDE ：vs code
虚拟机： oracle vm virtualBox 最新版 
写入工具：fixvhdwr.exe
# 程序逻辑
![程序运行流程图](https://img-blog.csdnimg.cn/a6af5d05901f44d2ae94e2fcbbcb573d.png?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_10,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3dlaXhpbl80NDU4MDk3Nw==,size_16,color_FFFFFF,t_70)

# 代码

#### 引导程序  user2.asm

```bash
; 用户程序，
; 封装打印函数,
; 多次调用
; 移动屏幕光标


SECTION header vstart=0
    program_length dd program_end

    code_entry dw start
    dd section.code_1.start

    realloc_tbl_len dw (header_end-code_1_segment)/4

    ; 段重定位表
    code_1_segment dd section.code_1.start
    code_2_segment dd section.code_2.start
    data_1_segment dd section.data_1.start
    data_2_segment dd section.data_2.start
    stack_segment dd section.stack.start

    header_end:


SECTION code_1 align=16 vstart=0
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
    ; 参数(光标位置:bx,打印字符:cl)




   
    start:
        mov ax,[stack_segment]
        mov ss,ax
        mov sp,stack_end

        mov ax,[data_1_segment]
        mov ds,ax
        
        mov bx,msg0
        call put_string
        push word [es:code_2_segment]
        mov ax,begin
        push ax
        ; retf 相当于执行了两次pop,CPU将执行CS:IP的指令
        ; POP IP
        ; POP CS
        retf

    continue:
        mov ax,[es:data_2_segment]
        mov ds,ax
        mov bx,msg1
        call put_string
        jmp  $

SECTION code_2 align=16 vstart=0
    begin:
        push word [es:code_1_segment]
        mov ax,continue
        push ax
        
        retf
SECTION data_1 align=16 vstart=0
    msg0 db '  This is NASM - the famous Netwide Assembler. '
            db 'Back at SourceForge and in intensive development! '
            db 'Get the current versions from http://www.nasm.us/.'
            db 0x0d,0x0a,0x0d,0x0a
            db '  Example code for calculate 1+2+...+1000:',0x0d,0x0a,0x0d,0x0a
            db '     xor dx,dx',0x0d,0x0a
            db '     xor ax,ax',0x0d,0x0a
            db '     xor cx,cx',0x0d,0x0a
            db '  @@:',0x0d,0x0a
            db '     inc cx',0x0d,0x0a
            db '     add ax,cx',0x0d,0x0a
            db '     adc dx,0',0x0d,0x0a
            db '     inc cx',0x0d,0x0a
            db '     cmp cx,1000',0x0d,0x0a
            db '     jle @@',0x0d,0x0a
            db '     ... ...(Some other codes)',0x0d,0x0a,0x0d,0x0a
            db 0

SECTION data_2 align=16 vstart=0
    msg1 db '  The above contents is written by LeeChung. '
        db '2011-05-06'
        db 0


SECTION stack align=16 vstart=0
    resb 256
    stack_end:

SECTION trail align=16
    program_end:
```
# 实践结果
	nasm.exe -f bin  .\mbr.ASM -o  mbr.bin
	nasm.exe -f bin  .\user2.ASM -o  use2r.bin
	编译代码，生成二进制文件。
	分别写入到虚拟机的vhd的0号位，和100号位。运行虚拟机显示如下
![运行结果](https://img-blog.csdnimg.cn/04e8984ee8ed4d51842a3966032ee947.png?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_10,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3dlaXhpbl80NDU4MDk3Nw==,size_16,color_FFFFFF,t_70)

# 资源

汇编代码及二进制文件：https://github.com/duofanCoder/x86-NASM/tree/master/ASM-Learn-4-2/code

虚拟机固定大小硬盘vhd文件：https://github.com/duofanCoder/x86-NASM/tree/master/ASM-Learn-4-2

vhd写入工具：https://github.com/duofanCoder/x86-NASM/tree/master/tools
