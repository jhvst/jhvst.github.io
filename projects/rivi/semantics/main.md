# |title|

Array programming languages like APL and BQN have gained recent interest as a DSL for parallel computing. One reason for this is the constrained programming interface based on rank polymorphic arrays. The upsides are dual: on one hand, dealing with vector data corresponds closely how GPUs deal with flat array structures, and on the other, the program compositions created by the constrained language environment exhibit functional programming paradigm around maps and scans. This is especially useful to avoid so-called _thread divergence_ on GPUs, in which any kind of Von-Neumann style programming essentially stalls the device to a halt, as the GPU program _kernel_ is waiting for single thread to progress.

What the rank polymorphism does is _lifting_ of binary operations onto higher array dimensions. That is, irrespective of the array rank, the languages implicitly create iterators over data structures lengths. This avoids the programmer to write `for` loops regardless of whether the operation is applied with a vector or a matrix. Because of this automatic lifting, the challenge quickly becomes about creating program compositions that remain on higher dimensions. This is arguably the main painpoint with using array programming languages, because it differs conceptually a lot from imperative style of programming -- as we are about to see, it is rather trivial to convince a theorem prover that this makes sense, but whether a programmer can wrap their head around it is another question.

## Denotational semantics: dependent types

The basis of a rank polymorphic language are its _atoms_. Atoms here mean function values and value literals. All atoms share the same single data type, which is a rank polymorphic array. This type carries no visible type signature in traditional implementations like APL, even though there are certain cases in which a type error may occur, such as with product of two matrices, which is defined as Hadamard product hence requires matrix shape symmetry. Some more novel array programming languages like Google Dex implement dependent types to resolve these runtime errors statically.

Function applications are called _monadic_ when taking a single argument and _dyadic_ when taking two. Suppose that $F$ is the set of all functions and $x$ and $w$ as elements of the set of subjects $s$, then the set of monadic functions are ones which are called with $F x$ and dyadics with $w F x$.

In BQN, monadic `=` returns array rank, but dyadic checks for equality:

```
  = 1‿2‿3
1
```

```
  1 = 1‿3‿2
⟨ 1 0 0 ⟩
```

In BQN a user-defined dyadic function can be implemented with pattern matching. First, the expression is wrapped into clauses, and then the cases are separated with a comma:

```
{ 1-case ; 2-case }
```

The point-free a.k.a _tacit_ version can be done with the valence `⊘` function combinator:

```
        {𝕨0⊘1𝕩} 'x'
0

    'w' {𝕨0⊘1𝕩} 'x'
1
```

In other words, `F valence G x` applies $F$ for $x$, whereas `w F valence G x` applies $G$ to $x$ and $w$. Hence, a valence is just a function body of the format `{𝔽𝕩;𝕨𝔾𝕩}`.

Considering type-checking, we can say that each operation in BQN is a transformation over a single _shape_, which we define as a _rank polymorphic array_. It is worth noting that these operations are _well-defined_ in terms of type-checking when the operations are monadic: any operation in BQN _should_ be valid in such case. However, this is not true when the operations are dyadic: an operation might be ill-defined if the shapes do not agree on a shape. For example, a plus operation works similarly to Hadamard products: the dimensions have to match.

Capturing ill-defined definitions is called _static rank polymorphism_ in the literature, and there exists various projects which capture this with the use of dependent types, for example, [Remora](https://arxiv.org/abs/1912.13451), [Dex](https://arxiv.org/abs/2104.05372), and in increasing capacity [Futhark](https://futhark-lang.org/blog/2023-05-12-size-type-challenges.html#supporting-arbitrary-size-expressions). In effect, what dependent types provides in this context is a form of denotational semantics to various array operations, answering to _what_ it means to execute some array operation in terms of transformation over the shape type.

We can model this in Idris as follows:

```c
Reduce : Shape q (MkDim (S r) (S n)) -> Phase
Reduce {q=FZ} o = MkPhase Slash o
Reduce {q=FS(FZ)} {n} o = MkPhase Slash SomeScalar
Reduce {q=FS(FS(FZ))} {r} {n} o = MkPhase Slash (SomeVect (S n))
```

Where `q` is defined as the rank of the array. A reduce on a scalar is always of the same shape, with a vector it transforms the vector into _SomeScalar_, whereas with a matrix the resulting vector is a _SomeVect_ of the length of the matrices' row length. This is made possible by modeling the _Shape_ type to be a matrix in all cases:

```c
data Shape: (rank: Fin 3) -> Dim rows stride len -> Type where
  SomeScalar:
    Shape
      (mkRank 1 1)
      (MkDim 1 1)
  SomeVect:
    (stride: Nat)
    -> {auto NZs : So (stride > 0)}
    -> Shape
        (mkRank stride stride)
        (MkDim 1 stride)
  SomeMat:
    (rows, stride: Nat)
    -> {auto NZs : So (stride > 0)}
    -> {auto NZs : So (rows > 0)}
    -> Shape
        (mkRank (rows * stride) stride)
        (MkDim rows stride)
```

Which says that the _Dim_-ensions of the Shape is always consisting of number or rows, a _stride_, and a lenght. Modeling polymorphic arrays this way is often considered folklore: to support arbitrary ranks, the Dim can be an array of dimensions, but for simplification, this three-rank example should suffice to convince the reader for the basic gist. This allows us to capture mismatching shapes e.g. in the following APL expression:

```
1 2 3 4 + (+/ 3 3 ⍴ ⍳9)
```

Which in APL gives us an error:

```
LENGTH ERROR: Mismatched left and right argument shapes
```

In Idris, we would get:

```html
(input):1:8-54:When checking an application of function Shaped.Sum:
Type mismatch between
    Shape (free_rank (Reduce (SomeMat 3 3)))
          (MkDim (S (free_rows (Reduce (SomeMat 3 3))))
                 (S (free_stride (Reduce (SomeMat 3 3))))) (Type of shape (Reduce (SomeMat 3 3)))
and
    Shape (mkRank 4 4) (MkDim 1 4) (Expected type)

Specifically:
    Type mismatch between
            free_stride (Reduce (SomeMat 3 3))
    and
            3
```

The specifics of this implementation are prior work done in [my University of St Andrews master's thesis](https://juuso.dev/papers/msc-thesis-standrews/msc-thesis-standrews.html). Where this work ends is where this article now continues: operational semantics using quantitative typing.

## Operational semantics: quantitative types

In my other master's thesis, done at INRIA while studying at University of Lorraine, I created [a software artifact for running GPU programs](https://github.com/periferia-labs/rivi-loader) using the Vulkan API. This introduced me to specifics of implementing parallel algorithms in SPIR-V, which is a parallel SSA IR similar to that used in LLVM.

It quickly became apparent that writing GPU kernels by hand is an error-prone endeavior, which left me thinking of better ways to do this. As remarked later in the St Andrews's thesis, the connection to the use of quantitative typing was already established: modeling the hardware memory bank communication could be thought as _channels_ (in the session types way) managing linear resources. This is merely an original thought: mainstream languages like Go already use channels with (optionally) bounded lifetimes to do communication between green-threads, or as Go calls them, goroutines. However, anyone with field experience with Go knows that these lifetimes are runtime values, which means that doing communication with goroutines in a dependable way either requires familiarity with Go's race condition checker or modeling the interaction with formal method tools like TLA+.

To turn this communication method into a static property begs for use the use of quantitative type systems, which are well known to be implemented in Idris 2 and Granule. How to do this in a manner that preserves algebraic properties was then another question -- the point should not be whether it can be done, but whether the resulting construct is generally useful to model parallel algorithms. This point is further amplified as the art of verifying GPU kernels posthumously with model checker is already the topic of [a whole research group](https://multicore.doc.ic.ac.uk/projects/gpuverify/).

In an __IFIP Working Group 2.1__ group meeting in Oxford, Conor McBride presented an approach of modeling types in a similar fashion to a spreadsheet: given a row and a column, the cell in the intersection is a type which is dependent on the _header_ row and column. Conor also made the point of thinking this as a cube of sorts, in which ever higher dimensions could depend on arbitrary amount of these headers.

In various blog posts I have tried to model my practical learnings from the world of SPIR-V, but these quite never struck any abstract notion useful enough to convey the challenge that lies in the GPU kernel. However, with Conor's approach, my presentation can be reiterated:

Each thread in a GPU kernel is a cell in a larger thread cube. At any point within the hardware, the location of the cell has multiple ways to identify itself, with the smallest denomination being the so-called global identifier. Like an element in a vector, the `gid` is the index of the cell in its global context. Given a dataset of say 16 values, the `gids` of each value in the vector could be represented as iota 16 in BQN terms:

```
  ↕16
⟨ 0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 ⟩
```

The next step in the hierarchy is the subgroup, which resembles a single SIMD lane. The lane has a hardware-defined length, which are often powers of two:

```
  2⋆↕16
⟨ 1 2 4 8 16 32 64 128 256 512 1024 2048 4096 8192 16384 32768 ⟩
```

This is called `SubgroupSize` and is often some value between 4 and 64 and can be checked by querying the Vulkan API. For simplicity, let us assume it is 4. A `SubgroupLocalInvocationId` is then a iota of `SubgroupSize`. The number of subgroups is bounded by 32 bit integer: `2147483648`. We would now have:

```
  gid \[ ↕16
  ss \[ 4¨↕16
⟨ 0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 ⟩
⟨ 4 4 4 4 4 4 4 4 4 4 4 4 4 4 4 4 ⟩
```

