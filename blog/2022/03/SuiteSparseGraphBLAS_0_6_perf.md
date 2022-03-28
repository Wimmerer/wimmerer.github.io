@def title = "SuiteSparseGraphBLAS.jl Performance in v0.6"
@def authors = "Will Kimmerer"
@def published = "March 23 2022"

Check out [Introduction to SuiteSparseGraphBLAS v0.6](/blog/2022/03/SuiteSparseGraphBLAS_introduction.md) if you are new to SuiteSparseGraphBLAS.jl, or want to see the new functionality in v0.6.

As always, benchmark things yourself! Most operations will be **much** faster in SSGrB.jl, especially when the matrices are large enough that it starts multithreading. A Julia package like `SparseArrays.jl` might (for now) be faster for functions not built into SSGrB.jl. Also check out the ***PERFORMANCE TIPS LINKS HERE, BOTH DOCS AND Dr. Davis PDF***

# Show Me the Numbers!



## Sparse * Dense

We need:
- SparseMatrixCSC * Matrix
- GBMatrixC (Sparse) * GBMatrixC (Dense)
- GBMatrixR (Sparse) * GBMatrixR (Dense)
- GBMatrixC (Sparse) * GBMatrixR (Dense)
- GBMatrixR (Sparse) * GBMatrixC (Dense)
- Investigate Juthos stuff, ThreadedSparseArrays.jl, ThreadedSparseCSC.jl

## Dense * Sparse

We need:
- Matrix * SparseMatrixCSC
- GBMatrixC (Dense) * GBMatrixC (Sparse)
- GBMatrixR (Dense) * GBMatrixR (Sparse)
- GBMatrixC (Dense) * GBMatrixR (Sparse)
- GBMatrixR (Dense) * GBMatrixC (Sparse)
- Investigate Juthos stuff, ThreadedSparseArrays.jl, ThreadedSparseCSC.jl

## Sparse * Sparse

We need:
- SparseMatrixCSC * SparseMatrixCSC
- GBMatrixC * GBMatrixC
- GBMatrixR * GBMatrixC
- GBMatrixC * GBMatrixR
- GBMatrixR * GBMatrixR

## Subassign

We need:
- SparseMatrixCSC <- SparseMatrixCSC
- GBMatrix <- GBMatrix

## Hypersparsity Numbers

## One or two examples, implemented using algebraic semiring

