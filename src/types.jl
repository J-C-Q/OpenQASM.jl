module Types

using RBNF
using RBNF: Token

export MainProgram, IfStmt, Opaque, Barrier, RegDecl, Include, GateDecl, Gate, Reset, Measure,
    Instruction, UGate, CXGate, Bit, FnExp, Negative

struct MainProgram
    version::VersionNumber
    prog::Vector{Any}

    MainProgram(version, prog) = new(version, Vector{Any}(prog))
end

struct IfStmt
    left
    right
    body
end

struct Opaque
    name
    cargs::Vector{Any}
    qargs::Vector{Any}

    function Opaque(name, cargs, qargs)
        new(name, _force_any(cargs), _force_any(qargs))
    end
end

struct Barrier
    qargs::Vector{Any}

    function Barrier(qargs)
        new(_force_any(qargs))
    end
end

struct RegDecl
    type
    name
    size
end

struct Include
    file
end

struct GateDecl
    name
    # we remove type annotations for now
    # due to JuliaLang/julia/issues/38091
    cargs::Vector{Any}
    qargs::Vector{Any}
    
    function GateDecl(name, cargs, qargs)
        new(name, _force_any(cargs), _force_any(qargs))
    end
end

struct Gate
    decl::GateDecl
    body::Vector{Any}
end

struct Reset
    qarg
end

struct Measure
    qarg
    carg
end

struct Instruction
    name::String
    cargs::Vector{Any}
    qargs::Vector{Any}

    function Instruction(name, cargs, qargs)
        new(name, _force_any(cargs), _force_any(qargs))
    end
end

struct UGate
    z1
    y
    z2
    qarg
end

struct CXGate
    ctrl
    qarg
end

struct Bit
    name
    address
end

function Bit(name::String, address::Int)
    Bit(Token{:id}(name), Token{:int}(string(address)))
end

Bit(name::String) = Bit(Token{:id}(name), nothing)

struct FnExp
    fn::Symbol
    arg
end

struct Negative
    value
end

Base.show(io::IO, x::MainProgram) = print_qasm(io, x)
Base.show(io::IO, x::Gate) = print_qasm(io, x)

print_kw(io::IO, xs...) = printstyled(io, xs...; color=:light_blue)

function print_list(io::IO, list::Vector)
    for k in eachindex(list)
        print_qasm(io, list[k])

        if k != lastindex(list)
            print(io, ", ")
        end
    end
end

print_list(io::IO, x) = print_qasm(io, x)

print_qasm(ast) = print_qasm(stdout, ast)
print_qasm(io::IO) = x->print_qasm(io, x)
print_qasm(io::IO, ::Nothing) = nothing

print_qasm(io::IO, t::Token) = print(io, t.str)

function print_qasm(io::IO, t::Token{:reserved})
    print_kw(io, t.str)
end

function print_qasm(io::IO, stmt::RBNF.Token{:id})
    printstyled(io, stmt.str; color=:light_cyan)
end

function print_qasm(io::IO, stmt::RBNF.Token{:float64})
    printstyled(io, stmt.str; color=:green)
end

function print_qasm(io::IO, stmt::RBNF.Token{:int})
    printstyled(io, stmt.str; color=:green)
end

# NOTE:
# In order to preserve some line number
# we usually don't annote types to AST

# work around JuliaLang/julia/issues/38091
function _force_any(x)
    if isnothing(x)
        return Any[]
    else
        return Vector{Any}(x)
    end
end

function print_qasm(io::IO, x::MainProgram)
    printstyled(io, "OPENQASM "; bold=true)
    printstyled(io, x.version.major, ".", x.version.minor; color=:yellow)
    println(io)

    for k in 1:length(x.prog)
        stmt = x.prog[k]
        print_qasm(io, stmt)
        
        # print extra line
        # when there is a gate decl
        if stmt isa Gate
            println(io)
        end
        
        if k != length(x.prog)
            println(io)
        end
    end
end
# nested inst list
function print_qasm(io::IO, stmts::Vector{Any})
    for each in stmts
        print_qasm(io, each)
    end
end

function print_qasm(io::IO, stmt::IfStmt)
    print_kw(io, "if ")
    print(io, "(")
    print_qasm(io, stmt.left)
    print(io, " == ")
    print_qasm(io, stmt.right)
    print(io, ") ")
    print_qasm(io, stmt.body)
end

function print_qasm(io::IO, stmt::Opaque)
    print_kw(io, "opaque ")
    if !isempty(stmt.cargs)
        print(io, "(")
        print_list(io, stmt.cargs)
        print(io, ") ")
    end
    print_list(io, stmt.qargs)
    print(io, ";")
end

function print_qasm(io::IO, stmt::Barrier)
    print_kw(io, "barrier ")
    print_list(io, stmt.qargs)
    print(io, ";")
end

function print_qasm(io::IO, stmt::RegDecl)
    print_qasm(io, stmt.type)
    print(io, " ")
    print_qasm(io, stmt.name)
    print(io, "[")
    print_qasm(io, stmt.size)
    print(io, "];")
end

function print_qasm(io::IO, stmt::Include)
    print_kw(io, "include ")
    print_qasm(io, stmt.file)
    print(io, ";")
end

function print_qasm(io::IO, stmt::GateDecl)
    print_kw(io, "gate ")
    print_qasm(io, stmt.name)

    if !isempty(stmt.cargs)
        print(io, "(")
        print_list(io, stmt.cargs)
        print(io, ")")
    end

    print(io, " ")
    print_list(io, stmt.qargs)
    print(io, " {")
end

function print_qasm(io::IO, stmt::Gate)
    print_qasm(io, stmt.decl)
    println(io)
    for k in 1:length(stmt.body)
        print(io, " "^2)
        print_qasm(io, stmt.body[k])
        println(io)
    end
    print(io, "}")
end

function print_qasm(io::IO, stmt::Reset)
    print_kw(io, "reset ")
    print_qasm(io, stmt.qarg)
end

function print_qasm(io::IO, stmt::Measure)
    print_kw(io, "measure ")
    print_qasm(io, stmt.qarg)
    print_kw(io, " -> ")
    print_qasm(io, stmt.carg)
    print(io, ";")
end

function print_qasm(io::IO, stmt::Instruction)
    printstyled(io, stmt.name; color=:light_magenta)

    if !isempty(stmt.cargs)
        print(io, "(")
        print_list(io, stmt.cargs)
        print(io, ")")
    end
    print(io, " ")
    print_list(io, stmt.qargs)
    print(io, ";")
end

function print_qasm(io::IO, stmt::UGate)
    print_kw(io, "U")
    print(io, "(")
    print_qasm(io, stmt.z1)
    print(io, ", ")
    print_qasm(io, stmt.y)
    print(io, ", ")
    print_qasm(io, stmt.z2)
    print(io, ") ")
    print_qasm(io, stmt.qarg)
    print(io, ";")
end

function print_qasm(io::IO, stmt::CXGate)
    print_kw(io, "CX ")
    print_qasm(io, stmt.ctrl)
    print(io, ", ")
    print_qasm(io, stmt.qarg)
    print(io, ";")
end

function print_qasm(io::IO, stmt::Bit)
    print_qasm(io, stmt.name)
    if !isnothing(stmt.address)
        print(io, "[")
        print_qasm(io, stmt.address)
        print(io, "]")
    end
end

function print_qasm(io::IO, stmt::FnExp)
    print_kw(io, stmt.fn)
    print(io, "(")
    print_qasm(io, stmt.arg)
    print(io, ")")
end

function print_qasm(io::IO, stmt::Negative)
    print(io, "-")
    print_qasm(io, stmt.value)
end

# exp
function print_qasm(io::IO, stmt::Tuple)
    if get(io, :parathesis, false)
        print(io, "(")
    end

    foreach(print_qasm(IOContext(io, :parathesis=>true)), stmt)
    
    if get(io, :parathesis, false)
        print(io, ")")
    end
end

end
