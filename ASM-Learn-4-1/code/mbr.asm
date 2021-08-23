

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