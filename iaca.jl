macro iaca(x)
    begin_tag = if isa(x, Expr) && (x.head in (:for, :while))
        :iaca_begin_loop
    else
        :iaca_begin
    end
    Expr(:block, Expr(:meta, begin_tag), esc(x), Expr(:meta, :iaca_end))
end

llvmcall_asm(s) = Expr(:call, Base.llvmcall, "call void asm sideeffect \"$s\",\"\"()\nret void", Void, Tuple{})
const IACA_BEGIN = ".byte 0x0F, 0x0B\nmovl \$\$111, %ebx\n.byte 0x64, 0x67, 0x90"
const IACA_END = "movl \$\$222, %ebx\n.byte 0x64, 0x67, 0x90\n.byte 0x0F, 0x0B"
const ARCH_NAMES = [:haswell => "HSW",
                    :ivy_bridge => "IVB",
                    :sandy_bridge => "SNB",
                    :westmere => "WSM",
                    :nehalem => "NHM"]
const ANALYSIS_TYPE = [:latency => "LATENCY",
                       :throughput => "THROUGHPUT"]
function analyze(f, args::Type; arch = :haswell, analysis = :throughput, iaca_path = "iaca.sh")
    m = which(f, args)
    li = m.func.code
    ast = deepcopy(Base.uncompressed_ast(li))
    body = ast.args[3].args
    next_label = false
    pc = 1
    # for loops, move the begin tag to after the next label
    # the tags should not enclose the first test
    while pc <= length(body)
        stmt = body[pc]
        if isa(stmt, Expr) && stmt.head === :meta && stmt.args[1] === :iaca_begin_loop
            next_label = true
            deleteat!(body, pc)
            continue
        end
        if isa(stmt, LabelNode) && next_label
            insert!(body, pc+1, Expr(:meta, :iaca_begin))
            pc += 1
            next_label = false
        end
        pc += 1
    end
    map!(body) do stmt
        if isa(stmt,Expr) && stmt.head === :meta
            if stmt.args[1] === :iaca_begin
                return llvmcall_asm(IACA_BEGIN)
            elseif stmt.args[1] === :iaca_end
                return llvmcall_asm(IACA_END)
            end
        end
        stmt
    end

    # deepcopy f
    io = IOBuffer()
    serialize(io, f)
    seekstart(io)
    dummy = deserialize(io)
    k = which(dummy, args).func
    k.code.ast = ast
    
    #=@show code_typed(dummy, args)
    @show code_llvm(dummy, args)
    @show code_native(dummy, args)=#
    
    llvmf = ccall(:jl_get_llvmf, Ptr{Void}, (Any,Any,Int32), dummy, args, 0)
    asm = ccall(:jl_dump_function_asm, Any, (Ptr{Void},Cint), llvmf, 1)
    name, io = mktemp()
    write(io, asm)
    close(io)
    if haskey(ENV, "IACA_PATH")
        iaca_path = ENV["IACA_PATH"]
    end
    readall(`$iaca_path -$WORD_SIZE -arch $(ARCH_NAMES[arch]) -analysis $(ANALYSIS_TYPE[analysis]) $name`)
end

function f(y::Float64)
    x = 0.0
    @iaca for i=1:100
        x += 2*y*i
    end
    x
end
function g(y::Float64)
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
