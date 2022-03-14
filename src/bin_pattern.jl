"""
    bin_sparse_matrix!(M::AbstractArray, M_id::AbstractSparseMatrixCSC, max_num_bins::Integer)

Compute a Binning pattern in `M_id` from the sparsity pattern in `M_id`.

`M_id` is SparseMatrixCSC{Int64, Int64} with the same shape as `M`, 
when handed over it contains only 0 and 1. After usage it contains an Integer 
corresponding to a bin or 0. According to the Binning Pattern, 
similar valued entries can be considered the same.

`M` is the matrix whose entries are used for binning. `max_num_bins` is the maximum 
number of bins and must be non-negativ, if `max_num_bins == 0`, no binning is
performed and only the sparsity pattern in `M_id` is used then.

See also: [`ssa_compute`](@ref), [`p_norm_sparsity_matrix`](@ref).

# Examples
```jldoctest
julia> bin_sparse_matrix!([4 1 4.01; 0.1 17.1 17; 0.2 4 29], sparse([1 0 1; 0 1 1; 0 0 1]), 200)
3×3 SparseMatrixCSC{Int64, Int64} with 5 stored entries:
 1  ⋅  1
 ⋅  2  2
 ⋅  ⋅  3
```
"""
function bin_sparse_matrix!(M::AbstractArray{T}, M_id::AbstractSparseMatrixCSC, max_num_bins::Integer) where {T}
    m, n = size(M_id)
    M_i, M_j = findnz(M_id)
    M_pat_nnz = count(!iszero, M_id)

    separated_at = zero(T)

    if max_num_bins == 0
        data = Vector(1:M_pat_nnz)
        M_id[:, :] = sparse(M_i, M_j, data, m, n)
    else
        nz_M = zeros(M_pat_nnz)

        for k in 1:M_pat_nnz
            nz_M[k] = M[M_i[k], M_j[k]]
        end
        min_left, max_left, min_right, max_right = separated_min_max(nz_M, separated_at)
        bin_ids = binned_with_separated_min_max(nz_M, max_num_bins, min_left, max_left, min_right, max_right, separated_at)
        new_ids = bin_mapping(bin_ids)
        M_id[:, :] = sparse(M_i, M_j, new_ids, m, n)
    end
    return M_id
end

_extrema(v) = isempty(v) ? (Inf, -Inf) : extrema(v)

function separated_min_max(v::AbstractVector{T}, separated_at::T) where {T<:Real} 
    min_left, max_left = _extrema(v[v .<= separated_at])
    min_right, max_right = _extrema(v[v .>= separated_at])

    return min_left, max_left, min_right, max_right
end


function binned_with_separated_min_max(v::AbstractVector{T}, max_num_bins::Integer,
    min_left::Real, max_left::Real, min_right::Real, max_right::Real, separated_at::Real) where{T}
    n = length(v)

    if max_left == min_right
        loc_max_num_left_right_bins = max_num_bins - 1
    else
        loc_max_num_left_right_bins = max_num_bins
    end

    if separated_at > min_left
        left_dist = separated_at - min_left
    else
        left_dist = 0
    end

    if max_right > separated_at
        right_dist = max_right - separated_at
    else
        right_dist = 0
    end

    total_dist = left_dist + right_dist

    if total_dist != 0
        max_n_left_bins = floor(Int, (loc_max_num_left_right_bins * left_dist) / total_dist)
        max_n_right_bins = floor(Int, (loc_max_num_left_right_bins * right_dist) / total_dist)
    else
        max_n_left_bins = Inf
        max_n_right_bins = Inf
    end
    @assert max_n_left_bins + max_n_right_bins <= loc_max_num_left_right_bins

    inv_h_l = max_n_left_bins / left_dist
    inv_h_r = max_n_right_bins / right_dist

    fuzz = 1E2  # magic constant from matlab

    left_tol = fuzz * eps(T) * left_dist
    right_tol = fuzz * eps(T) * right_dist

    bin_ids = -ones(Int, n)

    middle_id = max_n_left_bins + max_n_right_bins

    for i in 1:n
        if v[i] == separated_at
            b = middle_id
        elseif v[i] < separated_at
            if separated_at - v[i] <= left_tol
                b = middle_id
            else
                b = floor(Int, (v[i] - min_left) * inv_h_l)
            end
        else  # if (separated_at < v[i])
            if v[i] - separated_at <= right_tol
                b = middle_id
            else
                b = floor(Int, (max_right - v[i]) * inv_h_r) + max_n_left_bins
            end
        end
        bin_ids[i] = b
    end
    return bin_ids
end

function bin_mapping(bin_ids::AbstractVector{<:Integer})

    min_id, max_id = _extrema(bin_ids)
    impossible_id = typemin(Int)

    num_bins = max_id - min_id + 1
    work_array = impossible_id * ones(Int, num_bins)
    n_unique_vals = 0

    n = length(bin_ids)

    for i in 1:n
        id = work_array[bin_ids[i] - min_id + 1]

        if id == impossible_id
            n_unique_vals = n_unique_vals + 1
            work_array[bin_ids[i] - min_id + 1] = n_unique_vals
        end
    end
    new_bin_ids = copy(bin_ids)
    for i in 1:n
        new_bin_ids[i] = work_array[bin_ids[i] - min_id + 1]
    end
    return new_bin_ids
end
