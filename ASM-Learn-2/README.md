> 上一期的代码使用笨拙的手段，将字符传入到显卡里，如果要增加或减少字符，工作量就会很大，考虑到这点，汇编当然有更好的方式去实现了，那就是循环，这篇文章将详细介绍。	
>会使用到一些新的指令 cld, movsw,rep,inc,loop,dec,jns,$,$$等

# 引言
依然先介绍会使用到的指令。主要是循环，和内存搬运指令。

#### 内存复制指令 
movsb,movsw
这里有两个同样功能的指令区别在于，一次转移内存的大小，movsb 的传送是以字节为单位的，而 movsw 的传送是以字为单位的。
	从ds:si地址复制到es:di,复制字节数由cx指定。

	DS:SI  ->  ES:DI		  

这里会有正向和反向复制。
当正向复制时会从内存低地址到高地址复制，反向相反。
分别通过cld和std指令控制。
正向时si和di加1或者加2（由使用复制字节还是字的指令控制）反向则是减。
每次复制一次，CX 的内容自动减一。
rep 则是使指令不断运行知道cx为0结束。

#### 循环指令
loop 标号
循环指令标号位置指令，直到cx寄存器值为0

#### 条件转移指令
jns 
处理器在执行它的时候要参考标志寄存器的 SF 位。jns 当SF位为0，执行标号处指令。和jmp相似。（结果为负数会触发sf置1）

#### 汇编伪指令
\$$,\$ 

\$代表当前指令的标号，

\$$是NASM编译器提供的另一个标记，代表当前汇编节（段）的起始汇编地址。当前程序没有定义节或段，就默认地自成一个汇编段，而且起始的汇编地址是 0（程序起始处）。

这样，用当前汇编地址减去程序开头的汇编地址（0），就是程序实体的大小。再用 510 减去程序实体的大小，就是需要填充的字节数

# 程序环境
NASM 编译器版本 :nasm-2.07
IDE ：vs code
虚拟机： oracle vm virtualBox 最新版 
写入工具：fixvhdwr.exe
##### 虚拟机
创建的虚拟机要使用固定大小vhd格式硬盘，以模拟启动硬盘，我们将把二进制程序，写入到该硬盘的第一个扇区。


# 代码
```bash
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
```
# 实践结果
	nasm.exe -f bin  .\Learn.ASM -o  learn.bin
	编译代码，生成二进制文件。
	写入到虚拟机的vhd里。运行虚拟机显示如下
![虚拟机显示结果](https://img-blog.csdnimg.cn/19a042941f2743ecae9153d5745ca531.png?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_10,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3dlaXhpbl80NDU4MDk3Nw==,size_16,color_FFFFFF,t_70)



# 资源

汇编代码及二进制文件：https://github.com/duofanCoder/x86-NASM/tree/master/ASM-Learn-2/code

虚拟机固定大小硬盘vhd文件：https://github.com/duofanCoder/x86-NASM/tree/master/ASM-Learn-2

vhd写入工具：https://github.com/duofanCoder/x86-NASM/tree/master/tools