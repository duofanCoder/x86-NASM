> 如何完成1到100的累加，并把结果显示到屏幕上，
> 使用对战储存数据

# 引言
简单介绍本次实践，需要用的知识点。

#### 堆栈
使用前设置ss堆栈段的寄存器，设置sp栈顶偏移地址，此处都为0，
原因是主引导程序从0x7c00开始，那么两个是不是冲突呢？后每次压栈时，SP 都要依次减 2，即 0x0000－0x0002＝0xFFFE于是与主引导程序是不会冲突的。

	push，  sp-2  
	pop，	sp+2
![栈的生长方向](https://img-blog.csdnimg.cn/0bbedf852faf4cc69c80e3d9d858c58e.png?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_10,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3dlaXhpbl80NDU4MDk3Nw==,size_16,color_FFFFFF,t_70)
#### cmp 
cmp 指令在功能上和 sub 指令相同，唯一不同之处在于，cmp 指令仅仅根据计算的结果设置相应的标志位，而不保留计算结果，因此也就不会改变两个操作数的原有内容。cmp 指令将会影响到CF、OF、SF、ZF、AF 和 PF 标志位。
根据这些标注为的变化我们就可以用条件转移指令了。
![条件转移指令](https://img-blog.csdnimg.cn/bccb99f2fcf840c6a4ce14038f816650.png?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_10,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3dlaXhpbl80NDU4MDk3Nw==,size_16,color_FFFFFF,t_70)
#### or指令
逻辑或，有1则1，没有则0

# 程序环境
NASM 编译器版本 :nasm-2.07
IDE ：vs code
虚拟机： oracle vm virtualBox 最新版 
写入工具：fixvhdwr.exe

# 程序逻辑
循环100次 （这里使用cmp修改标志位，利用转移指令进行循环）累加1到100，结果存入到ax中，div 10 将 余数push到栈中，这里不在是如上篇div 5次了，而是利用cmp 去根据商的结果是否需要继续求余数，如果是0则跳过。求余数结束后，用pop出栈数据，并显示到屏幕上。
	
# 代码

```bash
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


```
# 实践结果
	nasm.exe -f bin  .\Learn.ASM -o  learn.bin
	编译代码，生成二进制文件。
	写入到虚拟机的vhd里。运行虚拟机显示如下
![在这里插入图片描述](https://img-blog.csdnimg.cn/c4bd4846f7ef4dc98611512eb04b2a3f.png?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_10,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3dlaXhpbl80NDU4MDk3Nw==,size_16,color_FFFFFF,t_70)

# 资源

汇编代码及二进制文件：https://github.com/duofanCoder/x86-NASM/tree/master/ASM-Learn-3/code

虚拟机固定大小硬盘vhd文件：https://github.com/duofanCoder/x86-NASM/tree/master/ASM-Learn-3

vhd写入工具：https://github.com/duofanCoder/x86-NASM/tree/master/tools