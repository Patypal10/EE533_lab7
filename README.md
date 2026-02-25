# EE533_lab7
EE533 Lab 7 SP26

CUDA Kernel Support:
- int16 add
- int16 sub
- bf16 mult
- bf16 mac
- bf16 relu

PTX Assembly to Support:
- .reg .pred, .b16, .b32 (used for thread idx), .b64 (used for store addr), .f32 (RELU)
- ld.param.u64, ld.param.s16, ld.global.u16
- mov.u32, mov.b16, mov.b32
- cvt.s32.s16, cvt.u64.u32, cvt.rz.f32.s32, cvt.rm.f32.s32, cvt.rn.bf16.f32
- cvta.to.global.u64
- setp.ge.s32, setp.neu.f32     **Are these instr independant of setp as well?
- @%p1 bra label
- shl.b64
- shr.s64
- add.s64, add.s16
- sub.s16
- st.global.u16
- ret
- fma.rn.bf16
- or.b32
- selp.f32
- mul.wide.s32
- max.bf16

- // begin inline asm {}, // end inline asm
- %tid.x

Notes:
- Trying to use only 16 bit registers:
    - parameter addresses are compiled as 64 bit bc expected GPU memory space is 2^64 ig
        - parameter (.param) types can be treated as special memory space or registers but any ops related to calculating with address is same size (64 bit)
        - will have to simply parse into 16 bit registers but will have to program with that in mind | **GPU device memory is MAX 2^16 bits for now 2^10 -> enough space for matrix op with 2 18x18 matrices

- 
