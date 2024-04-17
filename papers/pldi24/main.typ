#import "acmart.typ": acmart

#let abs = [
  Under is a dyadic operator in array programming languages that utilizes rank polymorphic function inverses.
  The BQN array language implements _structural_ and _computational_ cases of Under.
  In this work we showcase how the the lens properties of structural Under can be used to model parallel programming on GPUs.
  In particular, we showcase Under's connectivity to static memory allocations in the context of GPUs, and how it may coincidentally promote programming approaches leveraging $n$-assignment register objects.
]

#show: doc => acmart(
    doc,
    title: "On Structural Under and GPUs",
    abstract: abs,
    review: true,
)

= Introduction

The lens properties of structural Under could be used to model GPU programming based on invocation indices.
In @Impl, we describe few examples which show properties of how such modeling could work using global and subgroup indices.
Combining this approach with *constraint solvers* such as in @MappingParalleMogers2022 could pave way to mechnanically find solutions that abstracts the differences in GPU hardware properties for GPU-compiler backends for array programming languages.
I.e., operation like Under, which keep the shape constant across composition and place variables into a single view function $F$ could further help devising solver-aided compilers.
Thematically, the motivation is in part a continuation of an effort (or a homage) to using array programming languages as an abstraction over hardware, but this time to model GPUs.

= Background

*Computational Under* was first presented by Iverson as _Dual_ in @OperatorsAndFKennet1978.
The name comes from the mathematical concept of dualities between functions.
This conjugation structure first applies function $F$ with input $x$, then passes the result to $G$, after which the inverse of $F$ is applied.
E.g., Under can be used to round floats: $F$ changes the domain to integers, then $G$ does the rounding, and then $F^(=)$ denotes the inversion which reverts the domain back to floats.
Semantics-wise, Under is read "back and forth": the result of $F x$ progresses onto the left hand side of the combinator, but then returns on the right hand side by undoing $F$.

*Structural Under* was presented as an extension to computation Under by BQN author Marshall Lochbaum in 2017.
In BQN, Under is denoted with $circle.nested$ and covers both the computational and structural implementations.
BQN leverages structural Under to achieve immutable arrays; changing array values leverages Under as an in-place update.
This also means that structural Under is a lawful lens: $F x$ constructs a _view_ of $x$ to $G$ iff the inverse of $F$ can be used to reconstruct the original shape of $x$.

*Parallel programming* is a form of multi-core programming in which threads run the same program.
This is in comparison to concurrent programming in which programs may differ from thread to thread.
In concurrent programming literature, programs that suite the parallel programming definition are sometimes called symmetric or anonymous programs, especially so if the programs do not assign thread identities at initialization.
Any particularly useful general purpose GPU program (a.k.a. _kernel_ or _compute shader_) is anonymous, because scheduling and synchronization of kernels is a major performance bottleneck with GPU programming.
Instead, GPU kernels map input buffers to invidual _invocations_ of threads at runtime using identities as memory read offsets.
This departure from familiar programming model could be considered one factor which makes GPU programming particularly challenging to grok.

= Implementation <Impl>

To use structural Under for GPU we must leverage _decorations_ of input buffers alongside invocation identities.
These decorations, with invocation identities often as parameters, change how an invidual invocation -- a task done by some thread in the kernel -- reads data to local variables.

_Stride_ creates a stepping function: it determines every $n$th element that should be read by the invocation.
E.g., a stride decoration of of 2 means that when an invocation reads from index 0, it gets 0th element, from 1, it gets 2nd element, from 2, it gets 4th element, and so on.

_Offset_ marks how many values are skipped on initial read.
E.g., an offset decoration of 10 means that when an invocation reads from index 0, it gets 10th element, and so on.

_Invocation identities_ necessite the creation of invocations.
A GPU kernel takes a "grid" dimension arguments $x,y,z$ which generates invocation identifiers.
E.g., given arguments $2,2,2$ we can model this with the range operand BQN (i.e., this creates 8 invocations):

```BQN
  ↕ 2‿2‿2
┌─
╎ ⟨ 0 0 0 ⟩ ⟨ 0 0 1 ⟩
  ⟨ 0 1 0 ⟩ ⟨ 0 1 1 ⟩

  ⟨ 1 0 0 ⟩ ⟨ 1 0 1 ⟩
  ⟨ 1 1 0 ⟩ ⟨ 1 1 1 ⟩
                      ┘
```

At runtime an invocation can determine which thread it is running by reading $text("grid").x, text("grid").y, text("grid").z$ accessors.
For demonstration purposes of the examples, we say that each invocation uniquely determines itself by a global invocation identifier, which is is the invocation's index in the grid.

Suppose there is a _view_ function $V arrow.r "Shape" arrow.r "stride" arrow.r "offset"$, where Shape is Scalar or Vector($n$) where $n$ is bounded to 4.
Let Shape denotes how many elements are read into invocation view using the given stride and offset.
Now, we use this definition of $V$ as the $F$ function to structural Under.
Any parameter $x$ we pass to $V$ will be a flat array.
When $V$ creates the view for the $G$ function, we say that each produced row acts as an independent invocation.
E.g., if $V$ is chosen such that it produces an array of shape $(4,4)$, it means that the GPU runs four invocations which each have four values in its view.
To model safe registers, we disallow any invocation under a view (i.e., on the left side of $circle.nested$) to read values from any other invocation.

Example. Iota.
It is possible to implement the iota operator from APL using the global thread identifier: each element in the array will be taking the identity as value.
1. Let $F = V(text("Scalar"), 1, text("gid"))$
2. Let $G = text("gid")+1$
3. Let $iota = G circle.nested F tack.r$
In other words, $V$ reads a single scalar into each invocation's view.
Suppose that $x$ is a an array of 16 values with each element initialized to 0.
In such case, the view produces a 16x1 matrix on the left side of Under.
This means that it launches 16 invocations which each have a single scalar in their view under $G$, where the value of the scalar is read using a stride of 1 (a continous read) and using the invocations global identity as the read offset.
Next, each invocations assigns its global invocation identity to the scalar value; $x["gid"] = "gid"$.
Finally, the view is undone, which reshapes the input back to a vector of $16$ values.

Example. Sum reduce.
We show a sum reduction over $iota 16$ that uses Under composition and stride to achieve the result.
1. Let $F = V("Vector(4)", 1, "gid" times 4)$
2. Let $F' = V("Vector(4)", 4, "gid" times 4)$
3. Let $G = +´$
4. Let $"sum" = G circle.nested F' space (G circle.nested F space iota 16)$

Here, $F$ does a row-wise sum reduce by creating four invocations using a view of 4x4.
Then, $F'$ does a column-wise sum reduce using four invocations using a stride of 4.

_Tangled_ instructions make a group of invocations in a given context communicate using a single instruction in any member of that group.
An example of such context are *subgroups* come with the following identities: subgroup index, subgroup local index, and subgroup size.
Subgroup index tells which subgroup a given invocation belongs to.
Subgroup local index what is the index of that particular invocation within the subgroup.
The subgroup size is a hardware constant which tells how many invocations belong to a single subgroup.

To account the entanglement of invocations, $G$ should only be ran by the subgroup leader, i.e., the invocation which has subgroup local index of zero.
To model this, we define $(S times V)$ as a product which uses subgroup size to scale $V$ such that it gathers all invocations in a given subgroup to a single line row of the view matrix.
E.g., in the sum reduce example above let $F = (S times V("Scalar", 1, "sid" times "ssize"))$ where sid is subgroup id and ssize is subgroup size.
AMD GPUs have subgroup size is 64.
Suppose input $x = iota 128$.
Here, $F$ would produce a 2x64 view where each row signifies a subgroup leader invocation.
On each row, the 64 values are summed together using a single subgroup instruction.

= Conclusion

We demonstrated examples how anonymous parallel programs can be modeled using structural Under such that the $F$ utilizes thread indices.
In further work, type systems and solver-aided compilers could aid in generalizing this approach for heterogeneous set of GPUs.

#bibliography("lib.bib")
