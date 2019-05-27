mutable struct PrimalData{T, TV1<:AbstractVector{T}, TV2, TM<:AbstractMatrix{T}}
    σ::TV1
    α::TV1 # Lower move limit
    β::TV1 # Upper move limit
    p0::TV1
    q0::TV1
    p::TM
    q::TM
    ρ::TV2
    r::TV2
    r0::T
    x0::TV1
    x::TV1 # Optimal value for x in dual iteration
    x1::TV1 # Optimal value for x in previous outer iteration
    x2::TV1 # Optimal value for x in previous outer iteration
    f_x::T # Function value at current iteration
    f_x_previous::T
    g::TV2 # Inequality values at current iteration
    ∇f_x::TV1 # Function gradient at current iteration
    ∇g::TM # Inequality gradients [var, ineq] at current iteration
end

struct XUpdater{T, TV, TPD<:PrimalData{T, TV}}
    pd::TPD
end
function (xu::XUpdater)(λ::DualSolution{:CPU})
    @unpack x, p0, p, q0, q, σ, x1, α, β, ρ = xu.pd
    λρ = dot(λ.cpu, ρ)
    tmap!(x, 1:length(x)) do j
        λpj = @matdot(λ.cpu, p, j)
        λqj = @matdot(λ.cpu, q, j)
        getxj(λρ, λpj, λqj, j, p0, q0, σ, x1, α, β)
    end
    return
end

function getxj(λρ, λpj, λqj, j, p0, q0, σ, x1, α, β)
    lj1 = p0[j] + λpj + λρ*σ[j]/4
    lj2 = q0[j] + λqj + λρ*σ[j]/4

    αj, βj = α[j], β[j]
    Lj, Uj = minus_plus(x1[j], σ[j])

    Ujαj = Uj - αj
    αjLj = αj - Lj
    ljαj = lj1/Ujαj^2 - lj2/αjLj^2 

    Ujβj = Uj - βj
    βjLj = βj - Lj
    ljβj = lj1/Ujβj^2 - lj2/βjLj^2 

    fpj = sqrt(lj1)
    fqj = sqrt(lj2)
    xj = (fpj * Lj + fqj * Uj) / (fpj + fqj)
    xj = ifelse(ljαj >= 0, αj, ifelse(ljβj <= 0, βj, xj))

    return xj
end

# Primal problem functions
struct ConvexApproxGradUpdater{T, TV, TPD<:PrimalData{T}, TM <: Model{T, TV}}
    pd::TPD
    m::TM
end

function (gu::ConvexApproxGradUpdater{T, TV})() where {T, TV <: AbstractVector}
    @unpack pd, m = gu
    @unpack f_x, g, r, x, σ, x1, p0, q0, ∇f_x, p, q, ρ, ∇g = pd
    n = dim(m)
    r0 = f_x
    r0 -= tmapreduce(+, 1:n, init = zero(T)) do j
        getgradelement(x, σ, x1, p0, q0, ∇f_x, j)
    end
    for i in 1:length(constraints(m))
        r[i] = g[i]
        r[i] -= tmapreduce(+, 1:n, init = zero(T)) do j
            getgradelement(x, σ, p, q, ρ[i], ∇g, (j, i))
        end
    end
    pd.r0 = r0
end

function getgradelement(x::AbstractVector{T}, σ, x1, p0, q0, ∇f_x, j::Int) where {T}
    xj = x[j]
    σj = σ[j]
    Lj, Uj = minus_plus(xj, σj) # x == x1
    ∇fj = ∇f_x[j]
    abs2σj∇fj = abs2(σj)*∇fj
    (p0j, q0j) = ifelse(∇fj > 0, (abs2σj∇fj, zero(T)), (zero(T), -abs2σj∇fj))
    p0[j], q0[j] = p0j, q0j
    return (p0[j] + q0[j])/σj
end
function getgradelement(x::AbstractVector{T}, σ, p, q, ρi, ∇g, ji::Tuple) where {T}
    j, i = ji
    σj = σ[j]
    xj = x[j]
    Lj, Uj = minus_plus(xj, σj) # x == x1
    ∇gj = ∇g[j,i]
    abs2σj∇gj = abs2(σj)*∇gj
    (pji, qji) = ifelse(∇gj > 0, (abs2σj∇gj, zero(T)), (zero(T), -abs2σj∇gj))
    p[j,i], q[j,i] = pji, qji
    Δ = ρi*σj/4
    return (pji + qji + 2Δ)/σj
end

struct VariableBoundsUpdater{T, TV, TPD <: PrimalData{T}, TModel <: Model{T, TV}}
    pd::TPD
    m::TModel
    μ::T
end
function (bu::VariableBoundsUpdater{T, TV})() where {T, TV <: AbstractVector}
    @unpack pd, m, μ = bu
    @unpack α, β, x, σ = pd
    n = dim(m)
    αβ = StructArray{Tuple{T, T}}((α, β))
    tmap!(αβ, 1:n) do j
        xj = x[j]
        Lj, Uj = minus_plus(xj, σ[j]) # x == x1 here
        αj = max(Lj + μ * (xj - Lj), min(m, j))
        βj = min(Uj - μ * (Uj - xj), max(m, j))    
        αj, βj
    end
    return
end

struct AsymptotesUpdater{T, TV <: AbstractVector{T}, TModel <: Model{T}}
    m::TModel
    σ::TV
    x::TV
    x1::TV
    x2::TV
    s_init::T
    s_incr::T
    s_decr::T
end

function (au::AsymptotesUpdater{T, TV})(k::Iteration) where {T, TV <: AbstractVector}
    @unpack σ, m, s_init, x, x1, x2, s_incr, s_decr = au
    if k.i == 1 || k.i == 2
        tmap!(σ, 1:dim(m)) do j
            s_init * (max(m, j) - min(m, j))
        end
    else
        tmap!(σ, 1:dim(m)) do j
            σj = σ[j]
            xj = x[j]
            x1j = x1[j]
            x2j = x2[j]
            d = ifelse((xj == x1j || x1j == x2j), 
                σj, ifelse(xor(xj > x1j, x1j > x2j), 
                σj * s_decr, σj * s_incr))
            diff = max(m, j) - min(m, j)
            _min = T(0.01)*diff
            _max = 10diff
            ifelse(d <= _min, _min, ifelse(d >= _max, _max, d))
        end
    end

    return
end
