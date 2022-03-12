@def title = "SuiteSparseGraphBLAS.jl Update v0.6"
@def authors = "Will Kimmerer"
@def published = "March 7 2022"

# SuiteSparseGraphBLAS.jl Introduction

Update v0.6 is is a pretty major update, that touches every aspect of the package. 
Here, I'll introduce the performance and usage of the package from the point of view of a new user. Then I'll follow with a brief look at a few new features and wrap-up with some features and related packages slated for upcoming versions.

In-depth looks at graph algorithms will be saved for a later blog, for now we'll focus mostly on the linear algebra primitives.

## A very brief summary of GraphBLAS?

`SuiteSparseGraphBLAS.jl` is a sparse linear algebra library with some special features oriented to graph algorithms. It takes operations like matrix multiply, and turns them into higher order functions which replace the normal arithmetic operations `+` and `*` with other binary operators, like `max` or `&&`, which form a semiring. 

What does that mean in practice? When we multiply two matrices `A` and `B` as normal we use the following index expression:

$$ C_{ik} = \sum\limits_{j=1}^{n}{A_{ij} \times B_{jk}} $$

This expression uses the arithmetic semiring `(+, \times)`. There is nothing, however, that forces us to use this semiring, there are plenty of other interesting ones to choose from. We could, for instance, use the max-plus semiring `(max, +)` (one of the tropical semirings). Then our index expression above looks like:

$$ C_{ik} = \max\limits_{j=1}^{n}{(A_{ij} + B_{jk})} $$

This semiring has many applications to dynamic programming and graphs, but to wrap up this egregiously short intro, GraphBLAS lets you calculate this, particularly on sparse matrices:

$$ C_{ik} = \bigoplus\limits_{j=1}^{n}{(A_{ij} \otimes B_{jk})} $$

where $\oplus$ is some binary operator (a monoid in particular) which takes the place of the $\sum$ reduction, and $\otimes$ is some binary operator which takes the place of $\times$ in typical arithmetic.

## Let's see some code!!

```julia
a = 10
@show a
```
\show{./code/intro1}