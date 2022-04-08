@def title = "SuiteSparseGraphBLAS.jl Performance and v0.6"
@def authors = "Will Kimmerer"
@def published = "March 23 2022"


# A New Version of SuiteSparseGraphBLAS.jl

`SuiteSparseGraphBLAS.jl` (SSGrB) v0.6 just recently released with a lot of changes. The biggest news is that the exported interface should now be considered relatively stable. We're still a while away from v1.0, but most new development will be documentation, entirely new bells and whistles, and convenience functions. Significant new development will also occur in other extension packages in the future.

If you're new to `SuiteSparseGraphBLAS.jl` check out the [docs](https://graphblas.juliasparse.org/stable/)! 

In this post I'll first give a very brief introduction to GraphBLAS, followed by some benchmarks vs. Julia's `SparseArrays.jl` standard library. After that  briefly describe some of the [new features in v0.6](#new_features_in_v06), and finally a [roadmap](#roadmap) for the next couple versions.

# What is SuiteSparseGraphBLAS.jl?

`SuiteSparseGraphBLAS.jl` is a sparse linear algebra library with some special features oriented to graph algorithms. It takes operations like matrix multiply, and turns them into higher order functions which replace the normal arithmetic operations `+` and `*` with other binary operators, like `max` or `&&`.

What does that mean in practice? When we multiply two matrices `A` and `B` as normal we use the following index expression:

$$ C_{ik} = \sum\limits_{j=1}^{n}{A_{ij} \times B_{jk}} $$

This expression uses the arithmetic [semiring](https://en.wikipedia.org/wiki/Semiring) $(+, \times)$, an abstract algebra structure consisting of two binary operators that interact in a particular way. 

There are plenty of other interesting semirings to choose from, and no reason to limit ourselves to the arithmetic one! We could, for instance, use the max-plus semiring $(\max, +)$ (one of the [tropical semirings](https://en.wikipedia.org/wiki/Tropical_semiring)). Then our index expression above looks like:

$$ C_{ik} = \max\limits_{j=1}^{n}{(A_{ij} + B_{jk})} $$

This semiring has many applications to dynamic programming and graphs, but to wrap up this short intro, GraphBLAS lets you perform  this operation, particularly on sparse matrices:

$$ C_{ik} = \bigoplus\limits_{j=1}^{n}{(A_{ij} \otimes B_{jk})} $$

where $\oplus$ is some binary operator (a monoid in particular) which takes the place of the $\sum$ reduction, and $\otimes$ is some binary operator which takes the place of $\times$ in typical arithmetic.

## Let's see some code!!

What does a simple operation look like? The equivalence between a matrix-vector multiplication and breadth-first search is a key component of linear algebraic graph algorithms, so we'll show a simple matvec of the matrix and vector below:

\figenv{Adjacency matrix of a directed graph and a single iteration of BFS}{/assets/AdjacencyBFS.png}{width:100%}


```julia
julia> using SuiteSparseGraphBLAS

julia> A = GBMatrix([1,1,2,2,3,4,4,5,6,7,7,7], [2,4,5,7,6,1,3,6,3,3,4,5], [1:12...])
7x7 GraphBLAS int64_t matrix, bitmap by row
  12 entries, memory: 832 bytes

    (1,2)   1
    (1,4)   2
    (2,5)   3
    (2,7)   4
    (3,6)   5
    (4,1)   6
    (4,3)   7
    (5,6)   8
    (6,3)   9
    (7,3)   10
    (7,4)   11
    (7,5)   12

julia> v = GBVector([4], [10]; nrows = 7)
7x1 GraphBLAS int64_t matrix, bitmap by col
  1 entry, memory: 272 bytes
  iso value:   10

    (4,1)   10

julia> A * v
7x1 GraphBLAS int64_t matrix, bitmap by col
  2 entries, memory: 328 bytes

    (1,1)   20
    (7,1)   110

```

Basic operations should be familiar to any Julia user. But we can do 

# Show Me the Numbers!

`SuiteSparseGraphBLAS.jl` has loads of extensions to normal sparse linear algebra, but it's also *fast* and multithreaded. Let's look at some numbers!

As always, benchmark things yourself. Most operations will be faster in `SuiteSparseGraphBLAS.jl`, particularly when the matrices are large enough that multithreading kicks in. 

However, maintaining good performance can be tricky in any numerical package, and there's plenty of ways to accidentally reduce performance. For instance, below you'll notice that when `A` is stored in `RowMajor` format it can be quite a bit faster than operations where `A` is stored in `ColMajor` format. This isn't always the case, some operations favor column orientation. 

Always feel free to ask for performance tips in the [#graphblas Julia Slack channel](https://julialang.slack.com/archives/C023B0WGMHR) or open an issue on GitHub. And check out the [SuiteSparse:GraphBLAS User Guide](https://raw.githubusercontent.com/DrTimothyAldenDavis/GraphBLAS/stable/Doc/GraphBLAS_UserGuide.pdf), especially the section on performance.

## Sparse Matrix $\cdot$ Dense Vector

\figenv{}{/assets/plots/densevec.svg}{width:100%}

## Sparse Matrix $\cdot$ (n $\times$ 2) Dense Matrix

\figenv{}{/assets/plots/denseby2.svg}{width:100%}

## Sparse Matrix $\cdot$ (n $\times$ 32) Dense Matrix

\figenv{}{/assets/plots/denseby32.svg}{width:100%}

## Transpose

\figenv{}{/assets/plots/transpose.svg}{width:100%}

# New Features/Changes in v0.6

v0.6 contained a *ton* of changes under the hood to support faster development in the future and clean things up. The type system was completely overhauled to enable new matrix types with special extensions, the low level wrapper was scrubbed of any human-written contamination, and the operator/user-defined-function system was rewritten.

Despite the focus on the internals there are several new complete features as well as some experimental ones.

### User Defined Fill Value

The default `GBMatrix` returns `nothing` when indexing into an "implicit-zero" or non-stored value. This better matches the GraphBLAS method of attaching the implicit values to *operators* like `max` and `*`. It also is more natural for graphs, where there is a semantic difference between a stored zero (an edge with weight zero), and an implicit zero (no edge).

Users may now directly set the fill value best suited to their application. This can be done in 3 ways:

1. On construction: a new keyword argument for constructors, `fill`.
2. `setfill!`: a new mutating function which can be used to change the fill value. This function may only change the fill value to another value within the same domain to maintain type stability.
3. `setfill`: a new non-mutating function which returns a new `GBMatrix` which aliases the original, but with a new fill value. This new value may be of any type.

These changes allow the `GBMatrix` to be seamlessly used for general scientific applications that expect implicit zeros *to be* zero while adhering to the original design intended for graph algorithms.

### `mmread` Function

Previously reading Matrix Market files was supported only by first reading into a `SparseArrays.SparseMatrixCSC` before converting, which was slow and memory intensive. We now have a native `SuiteSparseGraphBLAS.mmread` function. It remains unexported to avoid clashes with other packages. In the future it will likely be superseded (but not replaced) by some function which can automatically detect and read from a number of formats.

### Serialization

Using the `Serialization` Julia standard library users can now easily serialize and deserialize a GraphBLAS data structures. The serialized array is compressed using LZ4 and is much faster to both read and write than a Matrix Market file.

### StorageOrders

A new dependency on StorageOrders.jl makes it easier to parametrize new `AbstractGBArray` types, for instance by restricting the orientation to `StorageOrders.RowMajor()` or `StorageOrders.ColMajor()`. The experimental `OrientedGBMatrix` and `GBMatrixC`/`GBMatrixR` subtypes take advantage of this.

Users may now also call `gbset(A, :format, RowMajor())`, instead of `gbset(A, :format, :byrow)` avoiding the use of magic symbols. 

### `apply` and Deprecation of Scalar Argument `map`

The new function `apply[!]` is now the direct wrapper of the `GrB_apply` function. `map` still functions as expected, but no longer accepts a scalar argument. Previously, when `map` was the direct wrapper of `GrB_apply`, `map(+, A, 3)` was legal and equivalent to `A .+ 3`. This caused many (mostly obscure) ambiguities between `map(op::Function, A::GBArray, x)`, `map(op::Function, x, A::GBArray)` and several external methods. 

`apply` now performs this function, althoug the recommended method remains dot-broadcasting. 

### `wait` Function Fully Implemented

To fully support calling SuiteSparseGraphBLAS.jl the `wait` function has been fully implemented

## Experimental Functionality

### `as` Function

The new `as` functions grew out of an internal need to safely and quickly view a `GBMatrix` as a `DenseMatrix`/`SparseMatrixCSC` or vice-versa. 

```julia
julia> A = GBMatrix([[1, 2] [3,4]])
2x2 GraphBLAS int64_t matrix, full by col
  4 entries, memory: 288 bytes

    (1,1)   1
    (2,1)   2
    (1,2)   3
    (2,2)   4

julia> SuiteSparseGraphBLAS.as(Matrix, A) do mat
           display(mat)
           mat .+= 1
           sum(mat)
       end
2×2 Matrix{Int64}:
 1  3
 2  4
14

julia> A
2x2 GraphBLAS int64_t matrix, full by col
  4 entries, memory: 288 bytes

    (1,1)   2
    (2,1)   3
    (1,2)   4
    (2,2)   5
```
Note that this functionality is currently somewhat dangerous. If `mat` escapes the scope of `as` in some way, for instance by returning the `Transpose` of `mat`, the underlying memory may be freed by `SuiteSparseGraphBLAS.jl`. If the user attempts to return `mat` directly the `as` function will gracefully copy the matrix rather than return an array that may be invalidated in the future. 

### `OrientedGBMatrix`, `GBMatrixR` and `GBMatrixC`

Experimental matrix types that do not allow their orientation to be changed.  

### 
# Roadmap
