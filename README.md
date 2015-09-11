### rough work in progress

### steps
- use a version of Julia at least as new as 7897a9131bf
- install IACA <https://software.intel.com/en-us/articles/intel-architecture-code-analyzer-download>
- add `@iaca` macro around a loop or straight code
- run `analyze(f, sig)`

### options
- `analyze(..., iaca_path = "/path/to/iaca.sh")`
- `analyze(..., arch = :haswell | :ivy_bridge | :sandy_bridge | :westmere | :nehalem)`
- `analyze(..., analysis = :throughput | :latency)`

```julia
julia> using IACA

julia> function f(y::Float64)
    x = 0.0
    @iaca for i=1:100
        x += 2*y*i
    end
    x
end

julia> function g(y::Float64)
    x1 = x2 = x3 = x4 = x5 = x6 = x7 = 0.0
    @iaca for i=1:7:100
        x1 += 2*y*i
        x2 += 2*y*(i+1)
        x3 += 2*y*(i+2)
        x4 += 2*y*(i+3)
        x5 += 2*y*(i+4)
        x6 += 2*y*(i+5)
        x7 += 2*y*(i+6)
    end
    x1 + x2 + x3 + x4 + x5 + x6 + x7
end

julia> println(analyze(f, Tuple{Float64}))
Intel(R) Architecture Code Analyzer Version - 2.1
Analyzed File - /tmp/tmplWkO5l
Binary Format - 64Bit
Architecture  - HSW
Analysis Type - Throughput

Throughput Analysis Report
--------------------------
Block Throughput: 12.00 Cycles       Throughput Bottleneck: InterIteration

Port Binding In Cycles Per Iteration:
---------------------------------------------------------------------------------------
|  Port  |  0   -  DV  |  1   |  2   -  D   |  3   -  D   |  4   |  5   |  6   |  7   |
---------------------------------------------------------------------------------------
| Cycles | 1.0    0.0  | 2.0  | 0.0    0.0  | 0.0    0.0  | 0.0  | 1.0  | 2.0  | 0.0  |
---------------------------------------------------------------------------------------

N - port number or number of cycles resource conflict caused delay, DV - Divider pipe (on port 0)
D - Data fetch pipe (on ports 2 and 3), CP - on a critical path
F - Macro Fusion with the previous instruction occurred
* - instruction micro-ops not bound to a port
^ - Micro Fusion happened
# - ESP Tracking sync uop was issued
@ - SSE instruction followed an AVX256 instruction, dozens of cycles penalty is expected
! - instruction not supported, was not accounted in Analysis

| Num Of |                    Ports pressure in cycles                     |    |
|  Uops  |  0  - DV  |  1  |  2  -  D  |  3  -  D  |  4  |  5  |  6  |  7  |    |
---------------------------------------------------------------------------------
|   2    |           | 1.0 |           |           |     | 1.0 |     |     | CP | vcvtsi2sd xmm2, xmm0, rax
|   1    |           |     |           |           |     |     | 1.0 |     |    | add rax, 0x1
|   1    | 1.0       |     |           |           |     |     |     |     | CP | vmulsd xmm2, xmm1, xmm2
|   1    |           | 1.0 |           |           |     |     |     |     | CP | vaddsd xmm0, xmm0, xmm2
|   1    |           |     |           |           |     |     | 1.0 |     |    | cmp rax, 0x65
|   0F   |           |     |           |           |     |     |     |     |    | jnz 0xffffffffffffffe1
Total Num Of Uops: 6

julia> println(analyze(g, Tuple{Float64}))
Intel(R) Architecture Code Analyzer Version - 2.1
Analyzed File - /tmp/tmpLPZdgg
Binary Format - 64Bit
Architecture  - HSW
Analysis Type - Throughput

Throughput Analysis Report
--------------------------
Block Throughput: 14.00 Cycles       Throughput Bottleneck: Port1, Port5

Port Binding In Cycles Per Iteration:
---------------------------------------------------------------------------------------
|  Port  |  0   -  DV  |  1   |  2   -  D   |  3   -  D   |  4   |  5   |  6   |  7   |
---------------------------------------------------------------------------------------
| Cycles | 7.0    0.0  | 14.0 | 0.0    0.0  | 0.0    0.0  | 0.0  | 14.0 | 2.0  | 0.0  |
---------------------------------------------------------------------------------------

N - port number or number of cycles resource conflict caused delay, DV - Divider pipe (on port 0)
D - Data fetch pipe (on ports 2 and 3), CP - on a critical path
F - Macro Fusion with the previous instruction occurred
* - instruction micro-ops not bound to a port
^ - Micro Fusion happened
# - ESP Tracking sync uop was issued
@ - SSE instruction followed an AVX256 instruction, dozens of cycles penalty is expected
! - instruction not supported, was not accounted in Analysis

| Num Of |                    Ports pressure in cycles                     |    |
|  Uops  |  0  - DV  |  1  |  2  -  D  |  3  -  D  |  4  |  5  |  6  |  7  |    |
---------------------------------------------------------------------------------
|   0*   |           |     |           |           |     |     |     |     |    | vxorps xmm0, xmm0, xmm0
|   2    |           | 1.0 |           |           |     | 1.0 |     |     | CP | vcvtsi2sd xmm0, xmm0, rcx
|   1    | 1.0       |     |           |           |     |     |     |     |    | vmulsd xmm0, xmm7, xmm0
|   1    |           | 1.0 |           |           |     |     |     |     | CP | vaddsd xmm8, xmm8, xmm0
|   1    |           |     |           |           |     | 1.0 |     |     | CP | lea rdx, ptr [rcx+0x1]
|   0*   |           |     |           |           |     |     |     |     |    | vxorps xmm0, xmm0, xmm0
|   2    |           | 1.0 |           |           |     | 1.0 |     |     | CP | vcvtsi2sd xmm0, xmm0, rdx
|   1    | 1.0       |     |           |           |     |     |     |     |    | vmulsd xmm0, xmm7, xmm0
|   1    |           | 1.0 |           |           |     |     |     |     | CP | vaddsd xmm1, xmm1, xmm0
|   1    |           |     |           |           |     | 1.0 |     |     | CP | lea rdx, ptr [rcx+0x2]
|   0*   |           |     |           |           |     |     |     |     |    | vxorps xmm0, xmm0, xmm0
|   2    |           | 1.0 |           |           |     | 1.0 |     |     | CP | vcvtsi2sd xmm0, xmm0, rdx
|   1    | 1.0       |     |           |           |     |     |     |     |    | vmulsd xmm0, xmm7, xmm0
|   1    |           | 1.0 |           |           |     |     |     |     | CP | vaddsd xmm2, xmm2, xmm0
|   1    |           |     |           |           |     | 1.0 |     |     | CP | lea rdx, ptr [rcx+0x3]
|   0*   |           |     |           |           |     |     |     |     |    | vxorps xmm0, xmm0, xmm0
|   2    |           | 1.0 |           |           |     | 1.0 |     |     | CP | vcvtsi2sd xmm0, xmm0, rdx
|   1    | 1.0       |     |           |           |     |     |     |     |    | vmulsd xmm0, xmm7, xmm0
|   1    |           | 1.0 |           |           |     |     |     |     | CP | vaddsd xmm3, xmm3, xmm0
|   1    |           |     |           |           |     | 1.0 |     |     | CP | lea rdx, ptr [rcx+0x4]
|   0*   |           |     |           |           |     |     |     |     |    | vxorps xmm0, xmm0, xmm0
|   2    |           | 1.0 |           |           |     | 1.0 |     |     | CP | vcvtsi2sd xmm0, xmm0, rdx
|   1    | 1.0       |     |           |           |     |     |     |     |    | vmulsd xmm0, xmm7, xmm0
|   1    |           | 1.0 |           |           |     |     |     |     | CP | vaddsd xmm4, xmm4, xmm0
|   1    |           |     |           |           |     | 1.0 |     |     | CP | lea rdx, ptr [rcx+0x5]
|   0*   |           |     |           |           |     |     |     |     |    | vxorps xmm0, xmm0, xmm0
|   2    |           | 1.0 |           |           |     | 1.0 |     |     | CP | vcvtsi2sd xmm0, xmm0, rdx
|   1    | 1.0       |     |           |           |     |     |     |     |    | vmulsd xmm0, xmm7, xmm0
|   1    |           | 1.0 |           |           |     |     |     |     | CP | vaddsd xmm5, xmm5, xmm0
|   1    |           |     |           |           |     | 1.0 |     |     | CP | lea rdx, ptr [rcx+0x6]
|   0*   |           |     |           |           |     |     |     |     |    | vxorps xmm0, xmm0, xmm0
|   2    |           | 1.0 |           |           |     | 1.0 |     |     | CP | vcvtsi2sd xmm0, xmm0, rdx
|   1    | 1.0       |     |           |           |     |     |     |     |    | vmulsd xmm0, xmm7, xmm0
|   1    |           | 1.0 |           |           |     |     |     |     | CP | vaddsd xmm6, xmm6, xmm0
|   1    |           |     |           |           |     |     | 1.0 |     |    | cmp rcx, rax
|   1    |           |     |           |           |     | 1.0 |     |     | CP | lea rcx, ptr [rcx+0x7]
|   1    |           |     |           |           |     |     | 1.0 |     |    | jnz 0xffffffffffffff60
Total Num Of Uops: 37
```
