doc"`GaussianKernel(α)` = exp(-α⋅‖x-y‖²)"
function GaussianKernel{T<:AbstractFloat}(α::T = 1.0)
    KernelComposition(ExponentialClass(α, one(T)), SquaredDistanceKernel(one(T)))
end
SquaredExponentialKernel = GaussianKernel
RadialBasisKernel = GaussianKernel

doc"`LaplacianKernel(α)` = exp(α⋅‖x-y‖)"
function LaplacianKernel{T<:AbstractFloat}(α::T = 1.0)
    KernelComposition(ExponentialClass(α, one(T)/2), SquaredDistanceKernel(one(T)))
end

doc"`PeriodicKernel(α,p)` = exp(-α⋅Σᵢsin²(p(xᵢ-yᵢ)))"
function PeriodicKernel{T<:AbstractFloat}(α::T = 1.0, p::T = convert(T, π))
    KernelComposition(ExponentialClass(α, one(T)), SineSquaredKernel(p, one(T)))
end

doc"'RationalQuadraticKernel(α,β)` = (1 + α⋅‖x-y‖²)⁻ᵝ"
function RationalQuadraticKernel{T<:AbstractFloat}(α::T = 1.0, β::T = one(T), γ::T = one(T))
    KernelComposition(RationalQuadraticClass(α, β), SquaredDistanceKernel(one(T)))
end

doc"`MatérnKernel(ν,θ)` = 2ᵛ⁻¹(√(2ν)‖x-y‖²/θ)ᵛKᵥ(√(2ν)‖x-y‖²/θ)/Γ(ν)"
function MaternKernel{T<:AbstractFloat}(ν::T = 1.0, θ::T = one(T))
    KernelComposition(RationalQuadraticClass(α, β), SquaredDistanceKernel(one(T)))
end
MatérnKernel = MaternKernel

doc"`PolynomialKernel(a,c,d)` = (a⋅xᵀy + c)ᵈ"
function PolynomialKernel{T<:AbstractFloat}(a::T = 1.0, c = one(T), d = 3one(T))
    KernelComposition(PolynomialClass(a, c, d), ScalarProductKernel{T}())
end

doc"`LinearKernel(α,c,d)` = α⋅xᵀy + c"
function LinearKernel{T<:AbstractFloat}(α::T = 1.0, c = one(T))
    KernelComposition(TranslationScaleClass(α, c), ScalarProductKernel{T}())
end

doc"`SigmoidKernel(α,c)` = tanh(α⋅xᵀy + c)"
function SigmoidKernel{T<:AbstractFloat}(α::T = 1.0, c::T = one(T))
    KernelComposition(SigmoidClass(α, c), ScalarProductKernel{T}())
end
