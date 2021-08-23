> 离开主引导扇区之后，前方通常就是操作系统的森林，也就是我们经常听说的 DOS、Windows、Linux、UNIX 等，
本篇要实现的就是通过引导程序加载硬盘上的用户，并执行。
由于内容比较多，用户程序简写了，
下一篇将在此基础上写入带有多段用户程序

# 引言
简单介绍本次实践，需要用的知识点。

#### SECTION
Intel 处理器要求段在内存中的起始物理地址起码是 16 字节对齐的。这句话的意思是，必须是16 的倍数，或者说该物理地址必须能被 16 整除。
所以每个段的定义中都包含了要求 16 字节对齐的子句，所以必须有align=这个设置。align=16那么该段至少是16个字节。

段定义的vstart语句可以让段内的标号，从vstart的值开始，这样就可以解决前几篇标号都要加上0x07c00的问题了。只需要像如下的写就可以解决这个问题
	
	SECTION  mbr align=16 vstart=0x7c00

如果段定义没有vstart=0，那么汇编地址就会从程序开头算起。

#### 用户程序头部定义
约定:在用户程序的开头，包含一些基本的结构信息.而且头部要以一个段的形式出现。

	SECTION header vstart=0

[0x00]程序的大小存储在程序开头的双字，
[0x04]接着使用一个字定义程序入口地址的汇编地址，[0x06]然后是双字的程序入口的段地址。[0x0a]段的数量。[0x0c]段重定位表的开始汇编地址。

#### 加载过程
读取用户程序所在磁盘的扇区，然后加载进内存某个地址，用户程序头部的信息，根据加载的地址修改段重定位表。
问题：为什么要修改重定位表呢？
因为重定位表里初始化时储存的是相对用户程序内代码段数据段等的段地址，这个地址是从用户程序开头计算的，所以我们需要他从我们加载进内存的地址开始计算作为段地址。

我们会预先加载一个扇区，查看用户程序头部的信息内的程序大小，判断是否加载完成。


#### 外围设备访问-磁盘
外围设备和处理器间通信是通过相应的I/O接口的.端口是处理器和外围设备通过 I/O 接口交流的窗口，每个I/O接口可能有好几个端口，端口就相当于寄存器，所以可能是8位或是16位也有32位。
端口在不同计算机有不同实现方式，分别是内存映射和独立编址。x86是端粒编址的。

主硬盘接口分配的端口号是 0x1f0～0x1f7，副硬盘接口分配的端口号是 0x170～0x177。
因为是独立编址不能使用mov，从端口读用in，写入端口用out指令和mov类似。	

##### 步骤
第 1 步，设置要读取的扇区数量。这个数值要写入 0x1f2 端口。这是个 8 位端口，因此每次只能读写 255 个扇区。注意，如果写入的值为 0，则表示要读取 256 个扇区。
第 2 步，设置起始 LBA 扇区号。扇区的读写是连续的，因此只需要给出第一个扇区的编号就可以了。28 位的扇区号太长，需要将其分成 4 段，分别写入端口 0x1f3、0x1f4、0x1f5 和 0x1f6 号端口。其中，0x1f3 号端口存放的是 0～7 位；0x1f4 号端口存放的是 8～15 位；0x1f5 号端口存放的是 16～23 位，最后 4 位在 0x1f6 号端口。
在现行的体系下，每个 PATA/SATA 接口允许挂接两块硬盘，分别是
主盘（Master）和从盘（Slave）。如图 8-11 所示，0x1f6 端口的低 4 位用于存放逻辑扇区号的 24～27位，第 4 位用于指示硬盘号，0 表示主盘，1 表示从盘。高 3 位是“111”，表示 LBA 模式。

![1f6端口含义](https://img-blog.csdnimg.cn/b7f9f1af49264a358285774fb6bd89ae.png?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_10,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3dlaXhpbl80NDU4MDk3Nw==,size_16,color_FFFFFF,t_70)
第 3 步，向端口 0x1f7 写入 0x20，请求硬盘读。
第 4 步，等待读写操作完成。端口 0x1f7 既是命令端口，在它内部操作期间，它将 0x1f7 端口的第 7 位置“1”，表明自己很忙。一旦硬盘系统准备就绪，它再将此位清零，说明自己已经忙完了，同时将第 3 位置“1”，意思是准备好了，请求主机发送或者接收数据
第 5 步，连续取出数据。0x1f0 是硬盘接口的数据端口，而且还是一个 16 位端口。一旦硬盘控制器空闲，且准备就绪，就可以连续从这个端口写入或者读取数据。读取的数据存放到由段寄存器 DS 指定的数据段，偏移地址由寄存器 BX 指定。
0x1f1 端口是错误寄存器，包含硬盘驱动器最后一次执行命令后的状态（错误原因）。


#### call指令
	我们要把经常用户的方法写成C语言的函数那样，就是用来方便调用。
	调用前，我们要把可能会影响到的寄存器值push进堆栈，
	call的指令执行结束后（用ret,或retf），
	在pop到原寄存器内。
![过程调用](https://img-blog.csdnimg.cn/65ecf39835c947e48ac5f56b8ce62b99.png?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_10,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3dlaXhpbl80NDU4MDk3Nw==,size_16,color_FFFFFF,t_70)
有四种调用方式。第一种是 16 位相对近调用（目标在当前代码段内，故操作数只要是16位偏移地址）。第二种是 16 位间接绝对近调用。（间接和第一种不同的就是偏移地址是通过[地址]获取的）。

第三种是 16 位直接绝对远调用。（指令call 0x2000:0x0030）

第四种是 16 位间接绝对远调用。（需要给出段地址和偏移地址，如call far [0x2000]，为什么和第一种操作数相似呢，但是指令里必须有far，那么段地址会在[0x2000]获取，偏移会从[0x2000+2]取）。

#### 逻辑右移指令

用逻辑右移指令 shr（SHift logical Right）将寄存器 AX 中的内容右移 4 位。

逻辑右移指令执行时，会将操作数连续地向右移动指定的次数，每移动一次，
“挤”出来的比特被移到标志寄存器的 CF 位，左边空出来的位置用比特“0”填充。

![指令示意图](https://img-blog.csdnimg.cn/2eecdf8ff4e84a1ebaff1f14fd57dcf4.png?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_10,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3dlaXhpbl80NDU4MDk3Nw==,size_16,color_FFFFFF,t_70)
shr 的配对指令是逻辑左移指令 shl（SHift logical Left），它的指令格式和 shr 相同，只不过它是
向左移动。

ror 的配对指令是循环左移指令 rol（ROtate Left）。ror、rol，循环到了最右边会去到最左边
![指令示意图](https://img-blog.csdnimg.cn/df638277a97d42d0b4dfae69c2163e05.png?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_10,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3dlaXhpbl80NDU4MDk3Nw==,size_16,color_FFFFFF,t_70)

# 程序环境
NASM 编译器版本 :nasm-2.07
IDE ：vs code
虚拟机： oracle vm virtualBox 最新版 
写入工具：fixvhdwr.exe

# 程序逻辑
### 加载程序
8086cpu最大寻址空间是1MB，0x00000到0x0FFFF是引导程序，0xA0000到0xFFFFF是bios程序，因此0x10000到0x9FFFF是空闲的区域。
![内存分配图](https://img-blog.csdnimg.cn/dc5009df48fd46c5b35a77c5db8b2aad.png?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_10,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3dlaXhpbl80NDU4MDk3Nw==,size_16,color_FFFFFF,t_70)
这里我们把程序加载到0x10000物理地址，这个数值16位不够存储，所以分别将该数值的高 16 位和低 16 位传送到寄存器 DX 和 AX。然后除以16或许段地址，（这里必须要说要加载的程序开头也是一个段开头，所以必须要16字节对齐，所以他的最低四位其实必须是0，因此这里除16并未改变加载地址，下面的程序也会在这里有解释）读取第一扇区，加载到这个段地址，然后，根据用户程序头部信息的程序大小除以512获取程序占据的扇区数（这里程序占据扇区是连续的），然后判断是否继续读取，要注意的是我们已经读取了一个扇区。

如果用户程序加载到0x10000处，段地址为0x1000，每次读取一个字节逻辑地址就要+1， 0x0000 开始，一直延伸到最大值 0xffff。再大的话，又绕回到 0x0000，以致于把最开始加载的内容给覆盖掉了，那么过大怎么办？

要解决这个问题最好的办法是，每次往内存中加载一个扇区前，都重新在前面的数据尾部构造一个新的逻辑段，并把要读取的数据加载到这个新段内。如此一来，因为每个段的大小是 512 字节，即，十六进制的 0x200，右移 4 位（相当于除以 16 或者 0x10）后是 0x20，这就是各个段地址之间的差值。每次构造新段时，只需要在前面段地址的基础上增加 0x20 即可得到新段的段地址。

#### 程序重定位
加载完程序后，用户程序里会有不同的段，那么段在内存里的地址就需要从新定位。
用户程序重定位，就需要使用加载的地址和汇编里的汇编地址（也就是偏移地址）相加，计算出实际的物理地址，然后通过移位操作，获取段地址，存入到segment定位表里。

# 问题解决
#### 段地址覆盖问题
有过疑惑 0x0000:0x1000和0x0100:0x0000不就是同一个地址了吗。 没错确实是，所以在使用段地址的时候，逻辑地址最大寻址空间是64kb，段地址从0x0000开始，逻辑地址寻址空间64占满后，段地址+0x20,逻辑地址可以继续寻址64kb的空间。

# 代码

#### 引导程序  mbr.asm

```bash


; 声明程序在扇区的位置，这里假设在第100扇区
app_lba_start equ 100


SECTION  mbr align=16 vstart=0x7c00
    mov ax,0
    mov ss,ax
    mov sp,ax

    ;? 这里cs是否是0
    mov ax,[cs:pyh_base]
    mov dx,[cs:pyh_base+0x02]

    ; 在这里我想32位除法ax是商，dx是余数，不出现商也是32位的情况吗？
    ; 答案是不会的，因为内存从0x00000到0xFFFFF,最大1MB，
    ; 所以这里的地址除以16也就是右移四位，刚好商就算最大也才FFFF。所以这样。
    ; 这里结果就是段地址了。
    mov bx,16           ; 32位除法
    div bx
    mov ds,ax
    mov es,ax

    xor di,di
    mov si,app_lba_start
    xor bx,bx
    ; 读扇区参数有：si扇区位置,es加载程序位置
    call read_hard_disk_0

    ; 判断程序多大,是否需要继续读
    mov dx,[2]
    mov ax,[0]
    mov bx,512
    div bx
    cmp dx,0
    ; 余数不为0,则实际扇区数位商+1,但是这里我们已经读取了一个扇区
    ; 所以商不需要减一
    jnz @1
    ; 反之,余数为0,商需要减一
    dec ax

@1:
    ; 如果程序只有一个扇区的情况
    cmp ax,0
    jz direct

    ; 还需要继续读硬盘的情况
    push ds

    ; 循环读取ax次
    mov cx,ax
@2:
    mov ax,ds
    ; 因为逻辑地址寻址最大64KB,
    ; 而程序可能超过这个大小,
    ; 所以每次读取一个扇区后,段地址加0x20(0x20乘0x10就是512),
    ; 新段的逻辑地址又可以从 0x0000开始了.
    add ax,0x20
    mov ds,ax
    
    xor bx,bx
    ; si 扇区位置
    inc si
    call read_hard_disk_0
    loop @2
    pop ds



; 计算入口地址 ,位用户程序段地址重定位
direct:
    ; 这个程序入口是32的,需要
    mov dx,[0x08]
    mov ax,[0x06]

    ; 参数是dx,ax  32位的用户程序段入口汇编地址
    call calc_segment_base
    mov [0x06],ax

    ; 开始处理段重定位表

    ; 先获取将要重定位段的数量
    mov cx,[0x0a]
    ; 段表开始地址
    mov bx,0x0c

realloc:
    mov dx,[bx+0x02]
    mov ax,[bx]
    call calc_segment_base
    mov [bx],ax
    add bx,4
    loop realloc

    jmp far [0x04]


read_hard_disk_0:
    ; 保存调用前的寄存器内容
    push ax
    push bx
    push cx
    push dx

    ; 设置读取扇区数
    ; 硬盘I/O接口的八位端口
    mov dx,0x1f2
    mov al,1
    out dx,al

    ; 设置读取扇区的编号
    inc dx
    mov ax,si
    out dx,al

    inc dx
    mov al,ah
    out dx,al

    inc dx
    ; 这里mov是否可以省略了
    mov ax,di
    out dx,al

    inc dx
    ;ax的高四位 第 4 位用于指示硬盘号，0 表示主盘，1 表示从盘。
    ; 高 3 位是“111”表示用LAB模式

    mov ax,0xe0    
    ; or al,ah        ; 这行可以省略是吗？
    out dx,al

    inc dx
    ; 开始请求硬盘读
    mov al,0x20
    out dx,al

.waits:
    in al,dx
    ; 第7位表示忙,第3位为1且第七位为0表示准备接受或发送数据.
    and al,0x88
    cmp al,0x08
    jnz .waits
    mov cx,256
    mov dx,0x1f0
.readw:
    in ax,dx
    mov [bx],ax
    add bx,2
    loop .readw

    pop dx
    pop cx
    pop bx
    pop ax

    ret




; 构造出的用户程序地址其实是一个段地址+0x0000
calc_segment_base:
    push dx
    ; 入口地址的低16位偏移地址加用户程序加载的开始物理地址
    add ax,[cs:pyh_base]
    ; adc相加 如果上面add有进位则再加1
    ; 用户程序的相对段地址+物理段地址+加进位
    adc dx,[cs:pyh_base+0x02]

    ; 加载的程序必须是16字节对齐
    ; 所以这里右移4位其实都是0
    
    ; 右移,空出补0
    shr ax,4
    ; 循环右移
    ror dx,4
    and dx,0xf000

    ; 段地址 + [pyh_base]的高四位
    or ax,dx

    ; ax 作为结果传出
    pop dx
    ret 



pyh_base dd 0x10000
times 510-($-$$) db 0
    db 0x55,0xaa
```

#### 用户程序  user.asm

```bash
;  用户程序
; 在屏幕显示duofan:OK

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
```
# 实践结果
	nasm.exe -f bin  .\mbr.ASM -o  mbr.bin
	nasm.exe -f bin  .\user.ASM -o  user.bin
	编译代码，生成二进制文件。
	分别写入到虚拟机的vhd的0号位，和100号位。运行虚拟机显示如下
![运行结果](https://img-blog.csdnimg.cn/431dba5d0008433e9de76b119d770942.png?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_10,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3dlaXhpbl80NDU4MDk3Nw==,size_16,color_FFFFFF,t_70)

# 资源

汇编代码及二进制文件：https://github.com/duofanCoder/x86-NASM/tree/master/ASM-Learn-4/code

虚拟机固定大小硬盘vhd文件：https://github.com/duofanCoder/x86-NASM/tree/master/ASM-Learn-4

vhd写入工具：https://github.com/duofanCoder/x86-NASM/tree/master/tools