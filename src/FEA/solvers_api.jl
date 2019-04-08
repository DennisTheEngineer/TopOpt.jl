abstract type SolverResult end
abstract type SolverType end
abstract type SolverSubtype end

struct Displacement <: SolverResult end

struct Direct <: SolverType end
struct CG  <: SolverType end

struct MatrixFree <: SolverSubtype end
struct Assembly <: SolverSubtype end

Utilities.getpenalty(solver::AbstractFEASolver) = solver.penalty
function Utilities.setpenalty!(solver::AbstractFEASolver, p)
    solver.prev_penalty = solver.penalty
    penalty = solver.penalty
    solver.penalty = @set penalty.p = p
    solver
end
Utilities.getprevpenalty(solver::AbstractFEASolver) = solver.prev_penalty

function FEASolver(::Type{Displacement}, ::Type{Direct}, problem; kwargs...)
    DirectDisplacementSolver(problem; kwargs...)
end

function FEASolver(::Type{Displacement}, ::Type{CG}, problem; kwargs...)
    FEASolver(Displacement, CG, MatrixFree, problem; kwargs...)
end

function FEASolver(::Type{Displacement}, ::Type{CG}, ::Type{MatrixFree}, problem; kwargs...)
    StaticMatrixFreeDisplacementSolver(problem; kwargs...)
end

function FEASolver(::Type{Displacement}, ::Type{CG}, ::Type{Assembly}, problem; kwargs...)
    PCGDisplacementSolver(problem; kwargs...)
end

function default_quad_order(problem)
    if TopOptProblems.getdim(problem) == 2 && TopOptProblems.nnodespercell(problem) == 3 || TopOptProblems.getdim(problem) == 3 && TopOptProblems.nnodespercell(problem) == 4
        return 3
    end
    if TopOptProblems.getgeomorder(problem) == 2
        return 6
    else
        return 4
    end
end
