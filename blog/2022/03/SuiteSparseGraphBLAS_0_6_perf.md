@def title = "SuiteSparseGraphBLAS.jl: An Introduction"
@def authors = "Will Kimmerer"
@def published = "March 23 2022"


# SuiteSparseGraphBLAS.jl: An Introduction

This blog post serves a couple purposes. The first is to introduce Julia users to [GraphBLAS](https://graphblas.org/), and the features and performance of the [`SuiteSparseGraphBLAS.jl`](https://github.com/JuliaSparse/SuiteSparseGraphBLAS.jl) package. The second is an update on new features in versions 0.6 and 0.7 as well as a roadmap for the near future. That's a lot for one blogpost so let's dive right in!

## What is SuiteSparseGraphBLAS.jl

[`SuiteSparseGraphBLAS.jl`](https://github.com/JuliaSparse/SuiteSparseGraphBLAS.jl) is a sparse linear algebra library with some special features oriented to graph algorithms. The headline feature is taking the matrix multiplication function, and turning it into a higher order function. Instead of the normal arithmetic operations `+` and `*` a user could substitute other binary operators, like `max` or `&&`.

When we multiply two matrices `A` and `B` as normal we use the following index expression:

$$ C_{ik} = \sum\limits_{j=1}^{n}{A_{ij} \times B_{jk}} $$

This expression uses the arithmetic [semiring](https://en.wikipedia.org/wiki/Semiring) $(+, \times)$. A semiring is an abstract algebra structure consisting of two binary operators that interact in a particular way. 

There are plenty of other interesting semirings to choose from, and no reason to limit ourselves to the arithmetic one! We could, for instance, use the max-plus semiring $(\max, +)$ (one of the [tropical semirings](https://en.wikipedia.org/wiki/Tropical_semiring)). Then our index expression above looks like:

$$ C_{ik} = \max\limits_{j=1}^{n}{(A_{ij} + B_{jk})} $$

This semiring has many applications to dynamic programming and graphs, but to wrap up this short intro, GraphBLAS lets you perform  this operation, particularly on sparse matrices:

$$ C_{ik} = \bigoplus\limits_{j=1}^{n}{(A_{ij} \otimes B_{jk})} $$

where $\oplus$ is some binary operator (a monoid in particular) which takes the place of the $\sum$ reduction, and $\otimes$ is some binary operator which takes the place of $\times$ in typical arithmetic.

## Let's see some code!!

What does a simple operation look like? The equivalence between a matrix-vector multiplication and breadth-first search is a key component of linear algebraic graph algorithms.

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

This looks exactly like a matrix-vector multiplication with any other array type in Julia.
Where possible, `SuiteSparseGraphBLAS.jl` will behave exactly as any other array type in Julia. 
But there are some places where `SuiteSparseGraphBLAS.jl` has significant extra functionality. 
I'll illustrate that here by finding the number of triangles in the graph above.

For those that haven't seen triangle counting before, a triangle in a graph is a set of three vertices whose edges form a triangle. We'll pretend like the graph is undirected, and then you can see two triangles: $(2, 5, 7)$ and $(3, 4, 7)$.

```julia
julia> using SuiteSparseGraphBLAS: pair

julia> function cohen(A)
         U = triu(A)
         L = tril(A)
         return reduce(+, *(L, U, (+, pair); mask=A)) ÷ 2
       end
cohen (generic function with 1 method)

julia> function sandia(A)
         L = tril(A)
         return reduce(+, *(L, L, (+, pair); mask=L))
       end
sandia (generic function with 1 method)

julia> M = eadd(A, A', +) #Make undirected/symmetric
7x7 GraphBLAS int64_t matrix, bitmap by row
  20 entries, memory: 832 bytes

    (1,2)   1
    (1,4)   8
    (2,1)   1
    (2,5)   3
    (2,7)   4
    (3,4)   7
    (3,6)   14
    (3,7)   10
    (4,1)   8
    (4,3)   7
    (4,7)   11
    (5,2)   3
    (5,6)   8
    (5,7)   12
    (6,3)   14
    (6,5)   8
    (7,2)   4
    (7,3)   10
    (7,4)   11
    (7,5)   12

julia> cohen(M)
2

julia> sandia(M)
2
```

There are a couple unique features of `SuiteSparseGraphBLAS.jl` used in the two methods, `cohen` and `sandia` above.

The first is the `pair` function. This function returns `1` whenever both arguments `x` and `y` are explicit stored values, otherwise it returns nothing (an implicit zero). To illustrate:

```julia
julia> using SuiteSparseGraphBLAS

julia> u = GBVector([2,4,5], [4,5,6])
5x1 GraphBLAS int64_t matrix, bitmap by col
  3 entries, memory: 328 bytes

    (2,1)   4
    (4,1)   5
    (5,1)   6

julia> v = GBVector([1,3,5], [1,2,3])
5x1 GraphBLAS int64_t matrix, bitmap by col
  3 entries, memory: 328 bytes

    (1,1)   1
    (3,1)   2
    (5,1)   3

julia> SuiteSparseGraphBLAS.pair.(u, v)
5x1 GraphBLAS int64_t matrix, bitmap by col
  1 entry, memory: 272 bytes
  iso value:   1

    (5,1)   1
```

This function is primarily a performance enhancement. In an algorithm like triangle counting we don't care about the weight of a particular edge, just that it exists. `pair` lets us avoid a costly multiplication by just checking that `x` is a stored value in `u` *and* `y` is a stored value in `v`.

The second feature is the semirings discussed in [What is SuiteSparseGraphBLAS.jl](#what_is_suitesparsegraphblasjl) above.
The tuple `(+, pair)` in `*(L, U, (+, pair); mask=A)` indicates the the `*` function is using the `+`-`pair` semiring:

$$ C_{ik} = \sum\limits_{j=1}^{n}{\text{pair}(A_{ij}, B_{jk})} $$

Finally, `*(L, U, (+, pair); mask=A)` uses `A` as a mask. The mask prevents values from being placed in the result where the mask is false (or true if complemented). This is a powerful algorithmic and performance tool.

## Summary of Primary Functions

The complete documentation of supported operations can be found in [Operations](https://graphblas.juliasparse.org/stable/operations/).
GraphBLAS operations are, where possible, methods of existing Julia functions listed in the third column.

| GraphBLAS           | Operation                                                      | Julia                                      |
|:--------------------|:--------------------------------------------------------------:|-------------------------------------------:|
|`mxm`, `mxv`, `vxm`  |$\bf C \langle M \rangle = C \odot AB$                          |`mul!` or `*`                               |
|`eWiseMult`          |$\bf C \langle M \rangle = C \odot (A \otimes B)$               |`emul[!]` or `.` broadcasting               |
|`eWiseAdd`           |$\bf C \langle M \rangle = C \odot (A \oplus  B)$               |`eadd[!]`                                   |
|`extract`            |$\bf C \langle M \rangle = C \odot A(I,J)$                      |`extract[!]`, `getindex`                    |
|`subassign`          |$\bf C (I,J) \langle M \rangle = C(I,J) \odot A$                |`subassign[!]` or `setindex!`               |
|`assign`             |$\bf C \langle M \rangle (I,J) = C(I,J) \odot A$                |`assign[!]`                                 |
|`apply`              |${\bf C \langle M \rangle = C \odot} f{\bf (A)}$                |`apply[!]`, `map[!]` or `.` broadcasting    |
|                     |${\bf C \langle M \rangle = C \odot} f({\bf A},y)$              |                                            |
|                     |${\bf C \langle M \rangle = C \odot} f(x,{\bf A})$              |                                            |
|`select`             |${\bf C \langle M \rangle = C \odot} f({\bf A},k)$              |`select[!]`                                 |
|`reduce`             |${\bf w \langle m \rangle = w \odot} [{\oplus}_j {\bf A}(:,j)]$ |`reduce[!]`                                 |
|                     |$s = s \odot [{\oplus}_{ij}  {\bf A}(i,j)]$                     |                                            |
|`transpose`          |$\bf C \langle M \rangle = C \odot A^{\sf T}$                   |`gbtranspose[!]`, lazy: `transpose`, `'`    |
|`kronecker`          |$\bf C \langle M \rangle = C \odot \text{kron}(A, B)$           |`kron[!]`                                   |

where $\bf M$ is a `GBArray` mask, $\odot$ is a binary operator for accumulating into $\bf C$, and $\otimes$ and $\oplus$ are a binary operation and commutative monoid respectively. $f$ is either a unary or binary operator.

# Show Me the Numbers!

`SuiteSparseGraphBLAS.jl` has loads of extensions to normal sparse linear algebra, but it's also *fast* and multithreaded. Let's look at some numbers!

As always, benchmark things yourself. Most operations will be faster in `SuiteSparseGraphBLAS.jl`, particularly when the matrices are large enough that multithreading kicks in. 

However, maintaining good performance can be tricky in any numerical package, and there's plenty of ways to accidentally reduce performance. For instance, below you'll notice that when `A` is stored in `RowMajor` format it can be quite a bit faster than operations where `A` is stored in `ColMajor` format. This isn't always the case, some operations favor column orientation. 

Always feel free to ask for performance tips in the [#graphblas Julia Slack channel](https://julialang.slack.com/archives/C023B0WGMHR) or open an issue on GitHub. And check out the [SuiteSparse:GraphBLAS User Guide](https://raw.githubusercontent.com/DrTimothyAldenDavis/GraphBLAS/stable/Doc/GraphBLAS_UserGuide.pdf), especially the section on performance.

The performance is [discussed](#discussion) briefly after the plots below.

## Sparse Matrix $\cdot$ Dense Vector

\figenv{}{/assets/plots/densevec.svg}{width:100%}

## Sparse Matrix $\cdot$ (n $\times$ 2) Dense Matrix

\figenv{}{/assets/plots/denseby2.svg}{width:100%}

## Sparse Matrix $\cdot$ (n $\times$ 32) Dense Matrix

\figenv{}{/assets/plots/denseby32.svg}{width:100%}

## Transpose

\figenv{}{/assets/plots/transpose.svg}{width:100%}

## Discussion

When the dense matrix is low-dimensional and only a single thread is used Julia compares very favorably with, and often beats, `SuiteSparseGraphBLAS.jl`. When 2 threads are available and the sparse matrix is stored in row-major orientation `SuiteSparseGraphBLAS.jl` begins to pull ahead significantly. Once a full 16 threads are used `SuiteSparseGraphBLAS.jl` is between 10 and 15 times faster on all tested matrices. 

`SuiteSparse:GraphBLAS` uses well over a dozen subalgorithms for matrix multiplication internally to achieve this performance. In particular when `A` is a sparse row-oriented matrix, and `B` is a dense column oriented matrix `SuiteSparse:GraphBLAS` will switch to a highly optimized dot-product algorithm, which is often much faster than the saxpy based algorithm used when `A` is column oriented.

# A New Version of SuiteSparseGraphBLAS.jl

Versions 0.6 and 0.7 of `SuiteSparseGraphBLAS.jl` brought with them several new features.

# New Features/Changes

These new versions contained a *many* changes under the hood to support faster development in the future and otherwise clean up the codebase. The type system was completely overhauled to enable new matrix types with special extensions, the low level wrapper was scrubbed of any human-written contamination, and the operator/user-defined-function system was rewritten.

Despite the focus on internals there are several new complete features as well as some experimental ones.

### User Defined Fill Value

The default `GBMatrix` returns `nothing` when indexing into an "implicit-zero" or non-stored value. This better matches the GraphBLAS method of attaching the implicit values to *operators* like `max` and `*`. It also is more natural for graphs, where there is a semantic difference between a stored zero (an edge with weight zero), and an implicit zero (no edge).

Users may now directly set the fill value best suited to their application. This can be done in 3 ways:

1. On construction: a new keyword argument for constructors, `fill`.
2. `setfill!`: a new mutating function which can be used to change the fill value. This function may only change the fill value to another value within the same domain as the original fill value to maintain type stability.
3. `setfill`: a new non-mutating function which returns a new `GBMatrix` which aliases the original, but with a new fill value. This new value may be of any type.

These changes allow the `GBMatrix` to be seamlessly used for general scientific applications that expect implicit zeros *to be zero*, while still adhering to the original design intended for graph algorithms.

### `mmread` Function

Previously reading Matrix Market files was supported only by first reading into a `SparseArrays.SparseMatrixCSC` before converting, which was slow and memory intensive. We now have a native `SuiteSparseGraphBLAS.mmread` function. It remains unexported to avoid clashes with other packages. In the future it will likely be superseded (but not replaced) by some function which can automatically detect and read from a number of formats.

### Serialization

Using the `Serialization` Julia standard library users can now easily serialize and deserialize a GraphBLAS data structures. The serialized array is compressed using LZ4 making both read and write operations much faster than operating on a Matrix Market file.

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

## Iteration

Recent versions of `SuiteSparse:GraphBLAS` have added the ability to iterate the stored values of a row or column. This functionality takes advantage of that, and is particularly useful to iterate over neighbors when implementing the `Graphs.jl` interface.

## Automatic Differentiation

Automatic Differentiation support continues to improve, with additional constructor rules, and rules for the `second` and `first` families of semirings. The biggest remaining missing pieces are the tropical semirings, and potentially user-defined functions.

# Roadmap

There's lots of upcoming features, extensions, and JuliaLab Compiler Trickery™ on the horizon but here's a few important updates to look out for:

## SuiteSparse Support

Supporting the SuiteSparse solvers is 1st on the list, and support will be released sometime in April 2022. This is a relatively simple addition, but involves quite a bit of duplicated code from `SuiteSparse.jl` which assumes the use of `SparseMatrixCSC`.

## GBPirate.jl Full Release

`GBPirate.jl` allows users of `SparseArrays.jl` to pirate certain methods of that package to use the more performant ones found in `SuiteSparseGraphBLAS.jl`. Because this involves copying on output it is not always faster, and the remaining development involves finding a heuristic for when this is beneficial.

## User Defined Types

User defined types are not currently part of the public interface of `SuiteSparseGraphBLAS.jl` while the interface is improved. This feature will enable users to use any statically sized `isbits` type, like dual-numbers, colors,  as elements of a `GBMatrix`. Release is planned for late April 2022.

## GBGraphs.jl

A new `Graphs.jl` backend built on `SuiteSparseGraphBLAS.jl` will allow users access to the full `Graphs.jl` ecosystem, while letting them develop fast algorithms in the language of linear algebra!

# Conclusion

