using SubspacePreservingSparsification
using SubspacePreservingSparsification: near_zero_row_col
using MAT
using DelimitedFiles
using LinearAlgebra

sq = "square10"

function default_ssa_compute_bin_no_null(M)
    M = sparsify(M, 0.4, 2, 50)
    return M
end


function default_ssa_compute_no_bin_no_null(M)
    M = sparsify(M, 0.4, 2, 0)
    return M
end


function my_default_ssa_compute_bin_null(M)
    M = sparsify(M, 0.4, 2, 50, true)
    return M
end


function my_default_compute_sparse_pattern(M)
    _, rnull, lnull = pinv_qr(M)

    # sparsity pattern
    num_near_zero_rows, num_near_zero_cols = near_zero_row_col(M)
    min_per_row = max(0, min(size(rnull)[2] - num_near_zero_cols, size(M)[2]))
    min_per_col = max(0, min(size(lnull)[2] - num_near_zero_rows, size(M)[1]))
    M = sparsity_pattern(M, 0.4, 2, min_per_row, min_per_col)
    return M
end


function my_default_compute_bin_pattern(M)
    _, rnull, lnull = pinv_qr(M)

    # sparsity pattern
    num_near_zero_rows, num_near_zero_cols = near_zero_row_col(M)
    min_per_row = max(0, min(size(rnull)[2] - num_near_zero_cols, size(M)[2]))
    min_per_col = max(0, min(size(lnull)[2] - num_near_zero_rows, size(M)[1]))
    M_pat = sparsity_pattern(M, 0.4, 2, min_per_row, min_per_col)
    M = bin_sparse_matrix!(M, M_pat, 50)
    return M
end


function init_script()
    ROOT_DIR = realpath(dirname(@__FILE__) * "/..")
    cd(ROOT_DIR)
end

init_script()

trans_names = readdlm(joinpath("test", "test_data", sq, "trans_names.txt"))


transformations = Dict(
    "pinv_rrqr" => pinv_qr,
    "default_ssa_compute_bin_no_null" => default_ssa_compute_bin_no_null,
    "default_ssa_compute_no_bin_no_null" => default_ssa_compute_no_bin_no_null,
    "default_ssa_compute_bin_null" => my_default_ssa_compute_bin_null,
    "sparse_pattern" => my_default_compute_sparse_pattern,
    "bin_pattern" => my_default_compute_bin_pattern,
)

# load untransformed matrix
file = matopen(joinpath("test", "test_data", sq, "untransformed_matrices", "with_nullspace.mat"))
A = read(file, "A")
close(file)

for j_trans_name in trans_names
    trans = transformations[j_trans_name]
    trans_A = @inferred trans(A)
    if typeof(trans_A) <: Tuple{Any, Any, Any}
        trans_A = trans_A[1]
    end
    if typeof(trans_A) != Matrix{Float64}
        trans_A = Matrix{Float64}(trans_A)
    end
    local file = matopen(joinpath("test", "test_data", sq,
    "transformed_matrices", "matlab", "with_nullspace", j_trans_name*".mat"))
    trans_A_mat = read(file, "trans_A")  # TODO: no sparse matrix
    close(file)
    @test trans_A ≈ trans_A_mat
end
