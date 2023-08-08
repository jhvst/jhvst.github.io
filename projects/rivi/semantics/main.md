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

Capturing ill-defined definitions is called _static rank polymorphism_ in the literature, and there exists various projects which capture this with the use of dependent types, for example, [Remora](https://arxiv.org/abs/1912.13451)[@IntroductionToShiver2019], [Dex](https://arxiv.org/abs/2104.05372), and in increasing capacity [Futhark](https://futhark-lang.org/blog/2023-05-12-size-type-challenges.html#supporting-arbitrary-size-expressions). In effect, what dependent types provides in this context is a form of denotational semantics to various array operations, answering to _what_ it means to execute some array operation in terms of transformation over the shape type.

We can model this in Idris as follows:

```idris
Reduce : Shape q (MkDim (S r) (S n)) -> Phase
Reduce {q=FZ} o = MkPhase Slash o
Reduce {q=FS(FZ)} {n} o = MkPhase Slash SomeScalar
Reduce {q=FS(FS(FZ))} {r} {n} o = MkPhase Slash (SomeVect (S n))
```

Where `q` is defined as the rank of the array. A reduce on a scalar is always of the same shape, with a vector it transforms the vector into _SomeScalar_, whereas with a matrix the resulting vector is a _SomeVect_ of the length of the matrices' row length. This is made possible by modeling the _Shape_ type to be a matrix in all cases:

```idris
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

 presented an approach of modeling types in a similar fashion to a spreadsheet: given a row and a column, the cell in the intersection is a type which is dependent on the _header_ row and column. Conor also made the point of thinking this as a cube of sorts, in which ever higher dimensions could depend on arbitrary amount of these headers.

## A primer to SPIR-V

This work attempts to model SPIR-V, which is a single static assignment language for parallel hardware. We use SPIR-V because it is heterogenious over GPUs, meaning it works with various GPU manufacturers and operating systems. Heteoregenuity also makes SPIR-V a tricky language to target because the language allows varying hardware implementations for its operations. Our goal is to simplify the mental burden caused by this variability by employing dependent type systems.

SPIR-V is a derivation of LLVM's intermediate representation as a shader language. Shader languages are programmed from the viewpoint of a single coordinate in a three dimensional _grid_ of threads. Thinking about this in two dimensions first is easier -- the coordinates are cells on a spreadsheet. In shader languages the program source code defines the actions taken by each cell of the spreadsheet, instead of the program describing how to modify the spreadsheet as a collection of cells. This programming model arguably suits graphics computing better than general-purpose computing, because it is much easier to wrap one's head around to control pixels on a screen rather than spreadsheet cells. To elaborate, in a graphical program neighboring pixels often share some inherent context together by the basis of their location on the screen, but with general-purpose programs indicies much more rarely have strong relation to neigboring values in an arrays other dimension. By the basis of this, we propose to copy the approach detailed in [@TypeSystemsFoMcbrid2022] to use the header and column indices as types for each of the cells.

The grid that holds thread coordinates comes in various levels. This hierarchical structure provides a single cell various mechanisms to communicate between different cells. There also exists a level called _subgroup_ on which cells are able to also operate together. Here, a local subset of active threads are capable of executing operations using each other's values without hardware communication overhead. This in turn makes subgroups the most performant level of abstraction to do computing on.

Subgroups have a length $\bar{s}$ determined by the hardware, which can be queried using an API. $\bar{s}$ is often some power of two:

```
  2⋆↕8
⟨ 1 2 4 8 16 32 64 128 ⟩
```

$\bar{s}$ defines the number of cells that a single subgroup $s$ may _at most_ contain. Each cell $c$ in a subgroup has an index within that subgroup $c_i$ such that $i \lt \bar{s}$. For demonstration, suppose $\bar{s} = 8$ and a set of subgroups $S = \{s_0, s_1, s_2, s_3\}$. We can view this as a matrix of indices $c_{\langle row,col \rangle}$:

```
  (↕4) ≍⌜ ↕8
┌─
╵ ⟨ 0 0 ⟩ ⟨ 0 1 ⟩ ⟨ 0 2 ⟩ ⟨ 0 3 ⟩ ⟨ 0 4 ⟩ ⟨ 0 5 ⟩ ⟨ 0 6 ⟩ ⟨ 0 7 ⟩
  ⟨ 1 0 ⟩ ⟨ 1 1 ⟩ ⟨ 1 2 ⟩ ⟨ 1 3 ⟩ ⟨ 1 4 ⟩ ⟨ 1 5 ⟩ ⟨ 1 6 ⟩ ⟨ 1 7 ⟩
  ⟨ 2 0 ⟩ ⟨ 2 1 ⟩ ⟨ 2 2 ⟩ ⟨ 2 3 ⟩ ⟨ 2 4 ⟩ ⟨ 2 5 ⟩ ⟨ 2 6 ⟩ ⟨ 2 7 ⟩
  ⟨ 3 0 ⟩ ⟨ 3 1 ⟩ ⟨ 3 2 ⟩ ⟨ 3 3 ⟩ ⟨ 3 4 ⟩ ⟨ 3 5 ⟩ ⟨ 3 6 ⟩ ⟨ 3 7 ⟩
                                                                  ┘
```

The row index corresponds to SPIR-V `SubgroupId` and the column index to `SubgroupLocalInvocationId`. Some operations operate on these indices, such as `OpGroupNonUniformElect` which returns `true` if the `SubgroupLocalInvocationId` is zero. We could model calling this instructions as follows:

```
  {0 = 1⊑𝕩}¨subgroups
┌─
╵ 1 0 0 0 0 0 0 0
  1 0 0 0 0 0 0 0
  1 0 0 0 0 0 0 0
  1 0 0 0 0 0 0 0
                  ┘
```

That is to say, all instructions over subgroups operate on a set of indices of subgroups. A more interesting example that operates on the values of the cells is a sum operation. A sum operation corresponds to a select function which takes a set of cells such that $c_{\langle r, col \lt \bar{s}}$. The expansion over the $\bar{s}$ is done automatically. To say we want to operate on the second row is to say:

```
  1 ⊏ idx
⟨ ⟨ 1 0 ⟩ ⟨ 1 1 ⟩ ⟨ 1 2 ⟩ ⟨ 1 3 ⟩ ⟨ 1 4 ⟩ ⟨ 1 5 ⟩ ⟨ 1 6 ⟩ ⟨ 1 7 ⟩ ⟩
```

Suppose the values of the cells would all be 10. Now:

```
  10¨idx
┌─
╵ 10 10 10 10 10 10 10 10
  10 10 10 10 10 10 10 10
  10 10 10 10 10 10 10 10
  10 10 10 10 10 10 10 10
                          ┘
```

A sum reduction would be:

```
  {≠⥊+´}⌾(1⊏⊢) 10¨idx
┌─
╵ 10 10 10 10 10 10 10 10
  80 80 80 80 80 80 80 80
  10 10 10 10 10 10 10 10
  10 10 10 10 10 10 10 10
                          ┘
```

To see affected values we could do:

```
  sum ≠ 10¨idx
┌─
╵ 0 0 0 0 0 0 0 0
  1 1 1 1 1 1 1 1
  0 0 0 0 0 0 0 0
  0 0 0 0 0 0 0 0
                  ┘
```

To return some changed value, we could say that we want to select the leader of the subgroup:

```
  {⌊´1‿0 = 𝕩}¨idx
┌─
╵ 0 0 0 0 0 0 0 0
  1 0 0 0 0 0 0 0
  0 0 0 0 0 0 0 0
  0 0 0 0 0 0 0 0
                  ┘
```

The sum of these values is then

```
  leader + a
┌─
╵ 0 0 0 0 0 0 0 0
  2 1 1 1 1 1 1 1
  0 0 0 0 0 0 0 0
  0 0 0 0 0 0 0 0
                  ┘
```

We can then find the cell which we want to read twice as such:

```
  b = 2
┌─
╵ 0 0 0 0 0 0 0 0
  1 0 0 0 0 0 0 0
  0 0 0 0 0 0 0 0
  0 0 0 0 0 0 0 0
                  ┘
```

Which is equivalent of saying to return the value we have read the most:

```
  b = ⌈´⥊b
┌─
╵ 0 0 0 0 0 0 0 0
  1 0 0 0 0 0 0 0
  0 0 0 0 0 0 0 0
  0 0 0 0 0 0 0 0
                  ┘
```

We can then do a filter on the flattened array:

```
  (⥊(b=2)) / (⥊sum)
⟨ 80 ⟩
```

The motivation to do the selection over the values that we have accessed the most comes from the fact that this allows us to tie a multiplicity into the array values, and only return the ones that we are interested in.

Following this, suppose a sum reduction of the whole matrix:

```
  # sum reduce row-vise
  eachRow ← 1¨idx

barrier
  # read leader values
  leaders ← ({⌈´↑‿0 = 𝕩}¨idx)

barrier
  # zero values from first row
  zeroing ← ({⌈´0‿↓ = 𝕩}¨idx)

barrier
  # write leader values to first row
  move ← 4‿8⥊⍉leaders

barrier
  # sum first row values
  sum2 ← ({⌈´0‿↓ = 𝕩}¨idx)

barrier
  # return first value
  first ← ({∧´0‿0 = 𝕩}¨idx)

  # count accesses
  strat1 ← eachRow + leaders + zeroing + move + sum2 + first
┌─
╵ 6 4 4 4 3 3 3 3
  2 1 1 1 1 1 1 1
  2 1 1 1 1 1 1 1
  2 1 1 1 1 1 1 1
                  ┘
  # count accesses
  +´⥊strat1
57
5 barriers
```

How can we type check this? We can say that if the type of the sum reduction is a single element, then we the number of elements with the value 5 should equal to the dependent type signature.

Where this comes interesting is to think about the work laid in [@TypeSystemsFoMcbrid2022], in which the row and column headers were set as types. Our motivation is to work our way "back" from the representation using the list lengths of the header and cell as lifetimes. The idea being that operations "deconstruct" the spreadsheet structure by checking if the linear "use-by" counts permit it. This way, we can model various parallel algorithms before actual implementation.

Something that we also note is that even in an array programming language the sum reduction of a matrix is a fold applied twice:

```
  +´ +´ ˘ 4‿8 ⥊ 1
32
```

The same is happening in our example: the existance of multiple accesses in the first row show that we have at some point come down a level of abstraction. See:

```
  {≠⥊+´}˘ 4‿8 ⥊ 1
┌─
╵ 8 8 8 8 8 8 8 8
  8 8 8 8 8 8 8 8
  8 8 8 8 8 8 8 8
  8 8 8 8 8 8 8 8
                  ┘
```

```
  (⥊leaders) / (⥊fold)
⟨ 8 8 8 8 ⟩
```

```
  4‿8⥊ (⥊fold)-⌾((¬⥊4‿8⥊⍉leaders)⊸/) (⥊fold)
┌─
╵ 8 8 8 8 0 0 0 0
  0 0 0 0 0 0 0 0
  0 0 0 0 0 0 0 0
  0 0 0 0 0 0 0 0
                  ┘
```

```
  {≠⥊+´}˘ swap
┌─
╵ 32 32 32 32 32 32 32 32
   0  0  0  0  0  0  0  0
   0  0  0  0  0  0  0  0
   0  0  0  0  0  0  0  0
                          ┘
```

```
  ⊑fold_x
32
```

The semantics of one dimensional computation become relevant as we start doing computation on the values on the swap phase.

An input buffer[^1] `buf` on the GPU is always a one dimensional vector indexed by its length: `buf = Vect n a` where `n` is of type `N` and `a` is of type `Q`. Now, `buf 32 0` would retrieve us the value in the given location.

[^1]: The input is called a buffer because the Vulkan API runtime creates I/O resources in the RAM of the computer which support a variety of streaming interfaces with different control granularities and scheduling schemes between the CPU RAM and the GPU RAM. This makes it possible to have a synchronous access between various RAM regions which have read/write access by both the CPU and RAM. This coincidentally implies that changes to the buffer are not directly observed by either one of the hardware devices. However, these semantics are considered _stem of stone brambles_ that should we should not get attached at this time.

We can make this a bit more explicit first. Suppose the matrix above is called $subgroups$. We can then compute the index of cell in the global context as follows:

```
  {+´(8‿1)×⊢}¨subgroups
┌─
╵  0  1  2  3  4  5  6  7
   8  9 10 11 12 13 14 15
  16 17 18 19 20 21 22 23
  24 25 26 27 28 29 30 31
                          ┘
```

Now we have a view to the x-dimension of a global context. A global view `global` is thus of type `global: [buf] -> X x Y x Z`. A global context is not an index into the underlying buffer -- it is triple which shows which thread is assigned to control whichever cell. The global context is constructed from a cuboid of dimension $(x,y,z)$ where $\{x,y,z\} \in 1..1024$.

One way to do the swap is to launch a thread group with the dimensions that correspond to the subgroup length $\{8,1,1\}$:

```
  ⍉⍉(↕8‿1‿1) ˘ subgroups
┌─
┆ ⟨ 0 0 0 ⟩ ⟨ 1 0 0 ⟩ ⟨ 2 0 0 ⟩ ⟨ 3 0 0 ⟩ ⟨ 4 0 0 ⟩ ⟨ 5 0 0 ⟩ ⟨ 6 0 0 ⟩ ⟨ 7 0 0 ⟩
  ⟨ 0 0 0 ⟩ ⟨ 1 0 0 ⟩ ⟨ 2 0 0 ⟩ ⟨ 3 0 0 ⟩ ⟨ 4 0 0 ⟩ ⟨ 5 0 0 ⟩ ⟨ 6 0 0 ⟩ ⟨ 7 0 0 ⟩
  ⟨ 0 0 0 ⟩ ⟨ 1 0 0 ⟩ ⟨ 2 0 0 ⟩ ⟨ 3 0 0 ⟩ ⟨ 4 0 0 ⟩ ⟨ 5 0 0 ⟩ ⟨ 6 0 0 ⟩ ⟨ 7 0 0 ⟩
  ⟨ 0 0 0 ⟩ ⟨ 1 0 0 ⟩ ⟨ 2 0 0 ⟩ ⟨ 3 0 0 ⟩ ⟨ 4 0 0 ⟩ ⟨ 5 0 0 ⟩ ⟨ 6 0 0 ⟩ ⟨ 7 0 0 ⟩
                                                                                  ┘
```

The swap can now be programmed in various ways:

- use the global $\langle0,0,0\rangle$ to do the swaps using the subgroup row number, hence moving every $\langle 0,0,0 \rangle$ to cell $c_{row,0} \to c_{0, row}$ and then doing a subgroup sum
- use a read _offset_ of 4 in `buf` to effectively cause a transpose effect in which the values assigned to the first subgroup now include every 4th element, thus allowing us to run the subgroup sum operation once again

Both implementations give us the same number 32 in the end, of which the first option is modeled above. The latter would look like this:

```
  # first sum reduction
  1¨idx
┌─
╵ 1 1 1 1 1 1 1 1
  1 1 1 1 1 1 1 1
  1 1 1 1 1 1 1 1
  1 1 1 1 1 1 1 1
                  ┘

barrier
  # read every 8th value
  4‿8⥊0=8|↕32
┌─
╵ 1 0 0 0 0 0 0 0
  1 0 0 0 0 0 0 0
  1 0 0 0 0 0 0 0
  1 0 0 0 0 0 0 0
                  ┘
  # zero every 8th value
  4‿8⥊4=8|↕32
┌─
╵ 0 0 0 0 1 0 0 0
  0 0 0 0 1 0 0 0
  0 0 0 0 1 0 0 0
  0 0 0 0 1 0 0 0
                  ┘
barrier
  # sum reduce using offset
  4‿8⥊0=4|↕32
┌─
╵ 1 0 0 0 1 0 0 0
  1 0 0 0 1 0 0 0
  1 0 0 0 1 0 0 0
  1 0 0 0 1 0 0 0
                  ┘

barrier
  # return first value
  ({∧´0‿0 = 𝕩}¨idx)
┌─
╵ 1 0 0 0 0 0 0 0
  0 0 0 0 0 0 0 0
  0 0 0 0 0 0 0 0
  0 0 0 0 0 0 0 0
                  ┘

  # count accesses
  eachRow + fourth + nfourth + ofourth + first
┌─
╵ 4 1 1 1 4 1 1 1
  3 1 1 1 4 1 1 1
  3 1 1 1 4 1 1 1
  3 1 1 1 4 1 1 1
                  ┘
  # sum accesses
49
3 barriers
```

This means that `buf 32 0` denotes the thread which is computing the value to the cell. In this case, it is thread `0 0 0`. This means that if we do an operation $F$ on each of the first element of a row, we have to control it using thread indexed by `0 0 0`. Suppose that we would want to add `1` to the value in the buffer's cell, we would write: `if (thread 0 0 0) then buf 32 X += 1`. Similarly, we could climb back a level to the level of subgroups to do a group operation `fold`: `if (thread 0 0 0) then (buf 32 X) = fold (subgroup s 0)`. The semantics of fold are contrived: the `s` is automatically expanded into the current subgroup. This means that `fold (subgroup s 0) = (subgroup 0 0) + (subgroup 1 0) + (subgroup 2 0) + ...` up to the length of the subgroup $\bar{s}$. Moreover, the write happens on each cell $c^i$ of the subgroup automatically. For example, if we call `fold` on the _cell_ `0 0 0`, then it is the same as doing the following:

```
  buffer ← ↑‿8 ⥊ •rand.Deal 32
┌─
╵ 15 26 29  4  8  6 11  7
  20 30 16 24 17  9 25  1
  12 10 14 18 27 21 23 13
  22  3 31  2  5  0 28 19
                          ┘
  0 ⊏ buffer
⟨ 15 26 29 4 8 6 11 7 ⟩

  {≠⥊+´}⌾⊢(0 ⊏ buffer)
⟨ 106 106 106 106 106 106 106 106 ⟩

  {≠⥊+´}⌾⊏ buffer
┌─
╵ 106 106 106 106 106 106 106 106
   20  30  16  24  17   9  25   1
   12  10  14  18  27  21  23  13
   22   3  31   2   5   0  28  19
                                  ┘
```

As we can see, `fold` result applies automatically each cell of which the subgroup contains. However, translating these array language operational semantics to SPIR-V requires us to use the indices extensively. If we would want to sum values from each row, we could instead of using cell at `0 0 0` use the subgroups in which the index is `0 0 0`. This would sum each row for us instead.

The reason for modeling with types comes a bit more clear when we think of different kind of global contexts. Suppose `8 1 2`:

```
  G ← {⍉⍉(↕8‿1‿2) ˘ 𝕩}
  ↑‿8 ⥊ 32↑ ⍷⥊ G subgroups

┌─
╵ ⟨ 0 0 0 ⟩ ⟨ 1 0 0 ⟩ ⟨ 2 0 0 ⟩ ⟨ 3 0 0 ⟩ ⟨ 4 0 0 ⟩ ⟨ 5 0 0 ⟩ ⟨ 6 0 0 ⟩ ⟨ 7 0 0 ⟩
  ⟨ 0 0 1 ⟩ ⟨ 1 0 1 ⟩ ⟨ 2 0 1 ⟩ ⟨ 3 0 1 ⟩ ⟨ 4 0 1 ⟩ ⟨ 5 0 1 ⟩ ⟨ 6 0 1 ⟩ ⟨ 7 0 1 ⟩
  ⟨ 0 0 0 ⟩ ⟨ 0 0 0 ⟩ ⟨ 0 0 0 ⟩ ⟨ 0 0 0 ⟩ ⟨ 0 0 0 ⟩ ⟨ 0 0 0 ⟩ ⟨ 0 0 0 ⟩ ⟨ 0 0 0 ⟩
  ⟨ 0 0 0 ⟩ ⟨ 0 0 0 ⟩ ⟨ 0 0 0 ⟩ ⟨ 0 0 0 ⟩ ⟨ 0 0 0 ⟩ ⟨ 0 0 0 ⟩ ⟨ 0 0 0 ⟩ ⟨ 0 0 0 ⟩
                                                                                  ┘
```

This means that if we were to launch a threads in the $Z$ dimensions in addition to eight in the $X$ dimension, then the thread assignment would look as above. The cells which have `0 0 0` assigned means that these would be taken over in some random order after the operations by the previous ones are done. This shows that depending on the amount of threads we spawn, we cannot rely on the cell's index alone -- we actually have to use the subgroups's index, which in contrast to the global thread index does _not_ change.

The next step in the hierarchy is the subgroup, which resembles a single SIMD lane. The lane has a hardware-defined length, which are often powers of two:

This is called `SubgroupSize` and is often some value between 4 and 64 and can be checked by querying the Vulkan API. For simplicity, let us assume it is 4. A `SubgroupLocalInvocationId` is then a iota of `SubgroupSize`. The number of subgroups is bounded by 32 bit integer: `2147483648`. We would now have:

```
  gid \[ ↕16
  ss \[ 4¨↕16
⟨ 0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 ⟩
⟨ 4 4 4 4 4 4 4 4 4 4 4 4 4 4 4 4 ⟩
```

