.arm

.macro call func
    ldr r6, =\func
    blx r6
.endm

.equ base_addr,     0xA3E800
.equ mount_sdmc,    0x291BE0
.equ IFile_Init,    0x12A2F4
.equ IFile_Open,    0x12A21C
.equ IFile_Exists,  0x873DA8
.equ IFile_GetSize, 0x1182CC
.equ IFile_Read,    0x13EEBC
.equ IFile_Close,   0x12A360
.equ strcat,        0x1003F0
.equ strcpy,        0x2FEB40
.equ strlen,        0x2FEA94
.equ liballoc,      0x157780
.equ libdealloc,    0x167058
.equ memcpy,        0x300680
.equ crit_this,      0x11DAA4
.equ crc,           0x6F47A4

test:
     ldrh r1, [r0]
     sub sp, sp, #0x14
     mov r2, r0
     
     push {r0-r6,lr}
         ldr r2, storage
         call crit_this
         ldr r3, =0x161F30 @nn::os::CriticalSection::Initialize()
         blx r3
         
         ldr r0, sdmc_on
         ldr r0, [r0]
         cmp r0, #0x0
         bne skip_sdmc_mount
         ldr r0, =sdmc+base_addr
         call mount_sdmc
         ldr r0, sdmc_on
         mov r1, #0x1
         str r1, [r0]
         
skip_sdmc_mount:
     pop  {r0-r6,lr}
     
     push {r0-r8,lr}
         ldr r0, storage
         str r2, [r0, #0x28]
         
         ldr r0, =0x404
         call liballoc
         mov r8, r0
         add r7, r8, #0x20
         
         ldr r0, =mod_path+base_addr
         call strlen
         add r7, r7, r0
         
         ldr r0, storage
         ldr r1, [r0, #0x28]
         mov r0, r7
         sub r0, r0, #0x4
         ldr r3, =0x181850 @lib::Resource::path_str(char* out, Resource* res)
         blx r3
         
         push {r0-r6,lr}
            mov r0, r7
            call crc
            mov r6, r0
            ldr r0, cache
            ldr r0, [r0]
            cmp r0, #0x0
            beq alloc_cache
begin_crc_check:
            ldr r3, [r0, #0x0] @number of crcs
            ldr r4, =0xF00FF00F
            cmp r3, r4
            beq end_loop_success
            mov r4, #0x1 @count
loop:
            cmp r4, r3
            bgt end_loop
            lsl r2, r4, #0x2
            ldr r1, [r0, r2]
            cmp r6, r1
            beq end_loop_success
            add r4, r4, #0x1
            b loop
end_loop:
            mov r0, #0x0
            ldr r1, cache
            str r0, [r1, #0x4]
            b exit_crc
end_loop_success:
            mov r0, #0x1
            ldr r1, cache
            str r0, [r1, #0x4]
            b exit_crc
alloc_cache:
            ldr r0, =0x8000
            call liballoc
            ldr r1, cache
            str r0, [r1]
            mov r0, r8
            call IFile_Init
             
            mov r0, r8
            ldr r1, =cache_bin+base_addr
            mov r2, #0x1
            call IFile_Open
            cmp r0, #0x0
            beq empty_cache
            mov r0, r8
            call IFile_GetSize
             
            ldr r1, cache
            ldr r1, [r1] @dst
            mov r2, r0 @len
            ldr r3, storage
            add r3, r3, #0x14 @bytes_read
            mov r0, r8 @file
            call IFile_Read
            mov r0, r8
            call IFile_Close 
            b begin_crc_check
            
empty_cache:            
            ldr r1, cache
            ldr r0, [r1]
            ldr r1, =0xF00FF00F
            str r1, [r0]
            b begin_crc_check
exit_crc:
         pop  {r0-r6,lr}
         ldr r0, cache
         ldr r0, [r0, #0x4]
         cmp r0, #0x0
         beq close 
         
         add r7, r8, #0x20
         
         ldr r0, =mod_path+base_addr
         call strlen
         mov r2, r0
         mov r0, r7
         ldr r1, =mod_path+base_addr
         call memcpy
   
         mov r0, r8
         call IFile_Init
         
         mov r0, r8
         mov r1, r7
         mov r2, #0x1
         call IFile_Exists
         cmp r0, #0x0
         beq close_and_end @ SD file doesn't exist, exit and pretend it never happened.
         mov r0, r8
         call IFile_Close 
         mov r0, r8  
         call libdealloc 
     pop  {r0-r8,lr}   
exit:
     mov r0, #0x1
     ldr lr, =0x159F0C
     bx lr
     
close_and_end:
        mov r0, r8
        call IFile_Close     
close:
         mov r0, r8  
         call libdealloc
     pop  {r0-r8,lr}
continue:   
     mov r0, #0x0  
     
     ldr lr, =0x159EC8
     bx lr
    
.pool

storage: .long 0xC7CD00
cache:     .long 0xC7CD84
sdmc_on:     .long 0xC7CD80
something_resource_lock: .long 0xC6A6B0

.align 4
cache_bin:   .asciz "sdmc:/saltysd/smash/cache.bin"
sdmc:       .asciz "sdmc:"
mod_path:   .asciz "sdmc:/saltysd/smash/"
