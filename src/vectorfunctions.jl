#===================================================================================================
  Vector Operations
===================================================================================================#

#==========================================================================
  Scalar Product Function (unweighted)
==========================================================================#

# Scalar product of vectors x and y
function scprod{T<:FloatingPoint}(x::Array{T}, y::Array{T})
    (n = length(x)) == length(y) || throw(ArgumentError("Dimensions do not conform."))
    c = zero(T)
    @inbounds @simd for i = 1:n
        c += x[i]*y[i]
    end
    c
end

# Partial derivative of the scalar product of vectors x and y
scprod_dx{T<:FloatingPoint}(x::Array{T}, y::Array{T}) = copy(y)
scprod_dy{T<:FloatingPoint}(x::Array{T}, y::Array{T}) = copy(x)

# Calculate the gramian (element-wise dot products)
#    trans == 'N' -> G = XXᵀ (X is a design matrix)
#          == 'T' -> G = XᵀX (X is a transposed design matrix)
function scprodmatrix{T<:FloatingPoint}(X::Matrix{T}, trans::Char = 'N', uplo::Char = 'U', sym::Bool = true)
    G = BLAS.syrk(uplo, trans, one(T), X)
    sym ? (uplo == 'U' ? syml!(G) : symu!(G)) : G
end

# Returns the upper right corner of the gramian matrix of [Xᵀ Yᵀ]ᵀ or [X Y]
#   trans == 'N' -> G = XYᵀ (X and Y are design matrices)
#         == 'T' -> G = XᵀY (X and Y are transposed design matrices)
function scprodmatrix{T<:FloatingPoint}(X::Matrix{T}, Y::Matrix{T}, trans::Char = 'N')
    G::Array{T} = BLAS.gemm(trans, trans == 'N' ? 'T' : 'N', X, Y)
end


#==========================================================================
  Scalar Product Function (weighted)
==========================================================================#

# Weighted scalar product of x and y
function scprod{T<:FloatingPoint}(x::Array{T}, y::Array{T}, w::Array{T})
    (n = length(x)) == length(y) == length(w) || throw(ArgumentError("Dimensions do not conform."))
    c = zero(T)
    @inbounds @simd for i = 1:n
        c += x[i]*y[i]*w[i]
    end
    c
end

function scprod_dx!{T<:FloatingPoint}(x::Array{T}, y::Array{T}, w::Array{T})
    (n = length(x)) == length(y) == length(w) || throw(ArgumentError("Dimensions do not conform."))
    @inbounds @simd for i = 1:n
        x[i] = y[i]*w[i]
    end
    x
end

scprod_dy!{T<:FloatingPoint}(x::Array{T}, y::Array{T}, w::Array{T}) = scprod_dx!(y, x, w)
scprod_dw!{T<:FloatingPoint}(x::Array{T}, y::Array{T}, w::Array{T}) = scprod_dx!(w, x, y)

scprod_dx{T<:FloatingPoint}(x::Array{T}, y::Array{T}, w::Array{T}) = scprod_dx!(similar(x), y, w)
scprod_dy{T<:FloatingPoint}(x::Array{T}, y::Array{T}, w::Array{T}) = scprod_dy!(x, similar(y), w)
scprod_dw{T<:FloatingPoint}(x::Array{T}, y::Array{T}, w::Array{T}) = scprod_dy!(x, y, similar(w))


#==========================================================================
  Squared Distance Function (unweighted)
==========================================================================#
 
# Squared distance between vectors x and y
function sqdist{T<:FloatingPoint}(x::Array{T}, y::Array{T})
    (n = length(x)) == length(y) || throw(ArgumentError("Dimensions do not conform."))
    c = zero(T)
    @inbounds @simd for i = 1:n
        v = x[i] - y[i]
        c += v*v
    end
    c
end

sqdist_dx{T<:FloatingPoint}(x::Array{T}, y::Array{T}) = scale!(2, x - y)
sqdist_dy{T<:FloatingPoint}(x::Array{T}, y::Array{T}) = scale!(2, y - x)


# Calculates G such that Gij is the dot product of the difference of row i and j of matrix X
#    trans == 'N' -> X is a design matrix
#          == 'T' -> X is a transposed design matrix
function sqdistmatrix{T<:FloatingPoint}(X::Matrix{T}, trans::Char = 'N', uplo::Char = 'U', sym::Bool = true)
    G = scprodmatrix(X, trans, uplo, false)
    n = size(X, trans == 'N' ? 1 : 2)
    xᵀx = copy(vec(diag(G)))
    @inbounds for j = 1:n
        for i = uplo == 'U' ? (1:j) : (j:n)
            G[i,j] = xᵀx[i] - convert(T, 2) * G[i,j] + xᵀx[j]
        end
    end
    sym ? (uplo == 'U' ? syml!(G) : symu!(G)) : G
end

# Calculates the upper right corner G of the squared distance matrix of matrix [Xᵀ Yᵀ]ᵀ
#   trans == 'N' -> X and Y are design matrices
#         == 'T' -> X and Y are transposed design matrices
function sqdistmatrix{T<:FloatingPoint}(X::Matrix{T}, Y::Matrix{T}, trans::Char = 'N')
    n = size(X, trans == 'N' ? 1 : 2)
    m = size(Y, trans == 'N' ? 1 : 2)
    xᵀx = trans == 'N' ? dot_rows(X) : dot_columns(X)
    yᵀy = trans == 'N' ? dot_rows(Y) : dot_columns(Y)
    G = scprodmatrix(X, Y, trans)
    @inbounds for j = 1:m
        for i = 1:n
            G[i,j] = xᵀx[i] - convert(T, 2) * G[i,j] + yᵀy[j]
        end
    end
    G
end

# scprodmatrix_dx: Difference each coordinate in X by each observation in Y
#     trans == 'N' -> Each row in X and Y is a coordinate
#              'T' -> Each column in X and Y is a coordinate
#     block_X == true  -> Every [:,:,i] block in the returned matrix is X differenced by the ith coordinate in Y
#             == false -> Every [:,:,i] block in the returned matrix is the ith coordinate of X differenced by Y
function sqdistmatrix_dx{T<:FloatingPoint}(a::T, X::Matrix{T}, Y::Matrix{T}, trans::Char = 'N', block_X::Bool = true)
    is_trans = trans == 'T'  # True if columns are observations
    n = size(X, is_trans ? 2 : 1)
    m = size(Y, is_trans ? 2 : 1)
    if (d = size(X, is_trans ? 1 : 2)) != size(Y, is_trans ? 1 : 2)
        throw(ArgumentError("X and Y do not have the same number of " * is_trans ? "rows." : "columns."))
    end
    a = 2 * a
    if block_X  # Every [:,:,i] block is X differenced by ith coordinate in Y
        A = Array(T, d, n, m)
        if trans == 'N'
            @inbounds for j = 1:m
                for i = 1:n
                    for k = 1:d
                        A[k, i, j] = a*(X[i,k] - Y[j,k])
                    end
                end
            end
        else
            @inbounds for j = 1:m
                for i = 1:n
                    for k = 1:d
                        A[k, i, j] = a*(X[k,i] - Y[k,j])
                    end
                end
            end
        end
        return A
    else  # Every [:,:,i] block is the ith coordinate of X differenced by Y
        A = Array(T, d, m, n)
        if trans == 'N'
            @inbounds for j = 1:m
                for i = 1:n
                    for k = 1:d
                        A[k, j, i] = a*(X[i,k] - Y[j,k])
                    end
                end
            end
        else
            @inbounds for j = 1:m
                for i = 1:n
                    for k = 1:d
                        A[k, j, i] = a*(X[k,i] - Y[k,j])
                    end
                end
            end
        end
        return A
    end
end
#sqdistmatrix_dy{T<:FloatingPoint}(a::T, X::Matrix{T}, Y::Matrix{T}, trans::Char = 'N', block_Y::Bool = true) = sqdistmatrix_dx(-a

#==========================================================================
  Squared Distance Function (weighted)
==========================================================================#

# Weighted squared distance function between vectors x and y
function sqdist{T<:FloatingPoint}(x::Array{T}, y::Array{T}, w::Array{T})
    (n = length(x)) == length(y) == length(w) || throw(ArgumentError("Dimensions do not conform."))
    c = zero(T)
    @inbounds @simd for i = 1:n
        v = (x[i] - y[i]) * w[i]
        c += v*v
    end
    c
end

function sqdist_dx!{T<:FloatingPoint}(x::Array{T}, y::Array{T}, w::Array{T})
    (n = length(x)) == length(y) == length(w) || throw(ArgumentError("Dimensions do not conform."))
    @inbounds @simd for i = 1:n
        x[i] = 2(x[i] - y[i]) * w[i]^2
    end
    x
end

sqdist_dy!{T<:FloatingPoint}(x::Array{T}, y::Array{T}, w::Array{T}) = sqdist_dx!(y, x, w)

function sqdist_dw!{T<:FloatingPoint}(x::Array{T}, y::Array{T}, w::Array{T})
    (n = length(x)) == length(y) == length(w) || throw(ArgumentError("Dimensions do not conform."))
    @inbounds @simd for i = 1:n
        w[i] = 2(x[i] - y[i])^2 * w[i]
    end
    w
end

sqdist_dx{T<:FloatingPoint}(x::Array{T}, y::Array{T}, w::Array{T}) = sqdist_dx!(copy(x), y, w)
sqdist_dy{T<:FloatingPoint}(x::Array{T}, y::Array{T}, w::Array{T}) = sqdist_dy!(x, copy(y), w)
sqdist_dw{T<:FloatingPoint}(x::Array{T}, y::Array{T}, w::Array{T}) = sqdist_dw!(x, y, copy(w))