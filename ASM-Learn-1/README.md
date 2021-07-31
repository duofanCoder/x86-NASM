
> 这章是学习了x86汇编从实模式到保护模式的初步实践，主要完成
> 1.利用显卡在屏幕上显示文字，
> 2.使用div汇编指令将标号以十进制的方式显示

# 引言
简单介绍本次实践，需要用的知识点。

#### 主引导扇区
指的是处理器加电或者复位后，ROM-BIOS读取启动硬盘的第一个扇区，512字节。该扇区的最后两个字节必须 是0x55 0xaa。

#### 显卡内存地址
0xB8000～0xBFFFF，由显卡来提供，用来显示文本。（所有在个人计算机上使用的显卡，在加电自检之后都会把自己初始化到80×25 的文本模式。在这种模式下，屏幕上可以显示 25 行，每行 80 个字符，每屏总共 2000 个字符）
#### 字符显示
每个字符由两个字节构成，第一个字节是字符ascii码，第二个字节是字符属性，即字符颜色和底色（0x07 可以解释为黑底白字，无闪烁，无加亮）。
![字符属性详细内容](https://img-blog.csdnimg.cn/0052d09a9f8f469d8d66d283af07a4c8.png?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_10,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3dlaXhpbl80NDU4MDk3Nw==,size_16,color_FFFFFF,t_70)
![颜色表](https://img-blog.csdnimg.cn/4509493a1e4048bd9c36f1d47e293c2b.png?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_10,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3dlaXhpbl80NDU4MDk3Nw==,size_16,color_FFFFFF,t_70)![颜色表](https://img-blog.csdnimg.cn/1ce37b006746497ba22cb1665a2a4d60.png?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_10,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3dlaXhpbl80NDU4MDk3Nw==,size_16,color_FFFFFF,t_70)
#### 标号
在 NASM 汇编语言里，每条指令的前面都可以拥有一个标号，以代表和指示该指令的汇编地址（即标号就指的是相对该程序起始位置的偏移地址）。

#### 寄存器
8086中的通用寄存器ax、bx、cx等都是十六位，
al,ah代表的是ax 的低8位和高8位，以此类推bl,bh,cl,ch也成立。
#### div 指令
;div除法汇编指令 
;被除数：除数为8位, 被除数为16位, 默认在AX中存放.
; 　　      除数为16位, 被除数为32位, 在DX或AX中存放. AX存放低16位,DX存放高16位.

;除数：作为div的操作数
;结果： 除数为8位, 则AL存储除法操作的商, AH存放余数
;       除数为16为, 则AX存储除法操作的商, DX存放余数

#### 数据初始化声明
DB 的意思是声明字节（Declare Byte），DW（Declare Word）用于声明字数据，DD（Declare Double Word）用于声明双字（两个字）数据，DQ（Declare Quad Word）

#### xor指令
异或逻辑，相同为0，不同为1，可以用来将内存置0，比mov ax，0更加快，原因是前者占用两个字节，后者3字节，且有立即数0，效率较慢。

# 程序环境
NASM 编译器版本 :nasm-2.07
IDE ：vs code
虚拟机： oracle vm virtualBox 最新版 

##### 虚拟机
创建的虚拟机要使用固定vhd格式硬盘，以模拟启动硬盘，我们将把二进制程序，写入到该硬盘的第一个扇区。

# 程序逻辑
标号的地址是储存5个字节的内存地址，代码 ：number：db 0,0,0,0,0
number 会是一个16位的数据，最大是65535。因此这个地址以十进制显示在屏幕上，需要占5个字符的位置。那么在此之前我们需要分解个十百千万位上的数字，然后加上‘0’ ascii码也就是0x30，后就可以得到对应的数字字符ascii码，之后将其显示到屏幕。举例如下
	
	个位数位5，则 字符5的ascii码= 5+ 0x30 = 0x35 


# 代码

```bash
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
```

# 实践结果
	nasm.exe -f bin  .\Learn.ASM -o  learn.bin
	编译代码，生成二进制文件。
	写入到虚拟机的vhd里。运行虚拟机显示如下
![虚拟机运行结果](https://img-blog.csdnimg.cn/088dcb409e0c4e3c975eab701368736b.png?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_10,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3dlaXhpbl80NDU4MDk3Nw==,size_16,color_FFFFFF,t_70)
	可以得出 number的汇编地址十进制是234，换算16进制是‭0xEA。

#### 验证
‬在vscode 使用hexdump插件查看learn.bin.
![二进制内容](https://img-blog.csdnimg.cn/dbba0b360636497eab2669ea3c15cac6.png?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_10,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3dlaXhpbl80NDU4MDk3Nw==,size_16,color_FFFFFF,t_70)
查看 learn.asm 汇编代码，number标号 处的指令，初始化了5个数据，每个数据一个字节，都是0， 然后循环inif 标号，再然后就是 268个字节的0，
对照二进制可以找到，number标号对应的5个字节0，就是在行 000000e0，offset是0a, e0+0a，可知number 标号是ea与结果吻合。验证了程序的正确。
![鼠标悬浮第一个00也可以得出](https://img-blog.csdnimg.cn/2661f8066397449e885a197f882f085b.png?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_10,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3dlaXhpbl80NDU4MDk3Nw==,size_16,color_FFFFFF,t_70)