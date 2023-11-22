# |title|

## Introduction

Array programming languages have gained newfound interest as the source language for _automatic parallelization_ on modern multi-core hardware.
The foundation of these efforts is based on a constrained data-type called _rank polymorphic array_ which can be considered a _view_ into a multidimensional matrix.
Historically, the view is the flywheel of _notation as a tool of thought_ ideal, in which a set of "_squiggols_" -- well-defined mathematical tensor operations often represented as single characters -- act as high-level operations on the view.
Recently, new developments in programming language type systems allow the formalization of rank polymorphism statically in ways that have not been previously possible.
Insofar efforts in  _static_ rank polymorphism have primarily focused on proving that operations over different input shapes are correct.
Coincidentally to the evolution of type systems, newly discovered programming approaches have allowed array languages to become self-hosted; the compiler is written in the language itself.
The self-hosted implementations do not leverage new type systems but instead focus on compiler design using rank polymorphism.
Here, manual effort is spent on finding ways to map expressions in a vectorized form for multi-core hardware to optimize performance.
However, recent research shows that optimized mappings can be automatically searched using SMT solvers.
Here, SMT solvers exhaustively search constraint models of hardware to discover optimizations automatically.
The literature generally calls optimizations based on exhaustive searches _superoptimizations_.
Yet, the research also shows that superoptimizers would benefit from additional guidance to reduce the search time.
Guiding the search with information derived from a type system sounds viable.
However, superoptimizations have little to gain from dependent type systems used insofar in rank polymorphism: the efforts omit type quantification, which would be the most helpful property to guide data mappings.
This paper thus explores a new type system over _dependent types_ similar to _quantitative types_ to guide an SMT solver in its exhaustive search to find superoptimizations.
The contribution is bridging previous efforts in type system research with properties from which to derive compiler optimizations.
Yet, the point is not to introduce an optimizing compiler by definition but to demonstrate why and how quantification in the type system could preserve useful type information for array programming languages while enabling future avenues and generality to superoptimizers.

In the following chapters, we describe the background relevant to our research and some practical examples to our suggested approach to formalize a superoptimizing compiler for future work.

## Background

This research considers the challenges of static typing of array programming languages and how parallel algorithms for array programming languages can be superoptimized with SMT solvers.
Below, we remark on some relevant previous work in this area of both these research directions.

### Contemporary developments in array languages

Our introduction remarked that array languages have had recent developments with and without types.

The ones that used advanced type systems are academic papers on static rank polymorphism.
These started appearing in the late 2010's.
Common to all is the use of dependent types, and the focus on soundness and completeness of the implementations.
Remora [@IntroductionToShiver2019] formalized a static rank polymorphic language with custom semantics.
In [@AplicativeProgGibbon2017] an alternative approach using dependent Haskell was introduced.
Futhark [@FutharkPurelyHenrik2017] moreso started from a functional array-orientated core, focusing on performance, and then progressing towards advanced type systems to enhance performance.
Google, a company known for indexing HTML pages, introduced language called Dex [@GettingToThePaszke2021] focused on automatic differentation.
In summary, it is possible to represent all data types in an array programming language using a single generic _shape_ which encodes rank polymorphism using dependent types.
With this encoding, dependent types allow the catching of shape errors statically.
In most array language implementations, shape errors can only arise from _dyadic_ function applications.
A dyadic function has two arguments, compared to a _monadic_ function, which only takes one.
In array languages, there are no other possible cases.
As an example in BQN, monadic $\times$ returns sign:

```
  × 1‿2‿3‿4
⟨ 1 1 1 1 ⟩
```

Whereas the dyadic case multiplies:

```
  4 × 1‿2‿3‿4
⟨ 4 8 12 16 ⟩
```

The monadic implementation works for any shape.
With a slight change, the dyadic operation errors:

```
  4‿4 × 1‿2‿3‿4
Error: Mapping: Equal-rank argument shapes don't agree
```

Dependent types provide us _denotational semantics_ to cases like these, answering what it means in terms of types to execute an expression.
For example, type-checking can work by considering every shape to take two arguments: the stride and length of the array.
A matrix is a case where the stride is less than the array's length.
A vector is a shape where the stride and length are equal.
A scalar is a shape in which the stride and length are equal to one.
This allows pattern matching over a shape by using the subtype as the case.
When modeling operations, using implicit arguments from the type parameters in the case matching is also possible.
There could now be a case where $\times$ is only permissible on two vectors when the strides are equal.
Languages with a totality checker can also help by checking that each operation fulfills at least one case of the subtypes.
In terms of practicalities, it is worth mentioning that the overhead of type checking is quite large, and may take more time than running into shape error at runtime -- if your program takes less than a second to complete, then type checking is not likely worth it.
Interestingly, dependently typed array languages do not necessarily need type annotations because input values determine the shapes.
As every data-type is a shape, there is no need to add annotation semantics to the language presented to the user.
This could be useful for teaching about strong type systems.

The other part of contemporary development has focused more on performance and features than semantics.
Relevant to us, these papers do not use advanced type systems to achieve the goals.
Instead, implementing the language's compiler as an array program is a common idea.
The canonical work is called `co-dfns`, which can be found in the dissertation of Aaron Hsu [@ADataParallelAaron2019].
The project is infamous in the array programming community for its terse and continuous presentation of the compiler, but more importantly, for contributing approaches to dealing with tree structures.
However, the project was not a silver bullet -- the performance of the produced GPU code is short of existing alternatives in the Python ecosystem [@UNetCnnInApHsuA2023].
Another self-hosted language is BQN from Michael Lochbaum, which uses approaches learned from `co-dfns` to deal with ASTs.
BQN optimizes performance with instruction vectorization, for which it has its own intermediate representation called [Singeli](https://github.com/mlochbaum/Singeli).
The Futhark team also has papers such as [@AplOnGpusAHenrik2016] and [@CompilingAplTBudde2015] in which an intermediate representation called TAIL is used to target APL on GPUs.
In [@CompilationOnVoette2022] Futhark is used as the source language to create GPU-based compiler for a virtualized RISC-V target.
# In [@UnleashingGpusHaavis2022] APL is used as a modeling language to target SPIR-V for GPUs.
In [@TeilATypeSaRink2019] Coq is used to define an intermediate representation called TeIL which is an imperative tensor language which leverages C's compiler backends to generate superoptimized code.

### SMT-based superoptimizations

Generally speaking, various compiler optimization techniques are common in the industry standard LLVM compiler infrastructure.
LLVM is a target language for various compilers of languages, for which optimizations that happen on LLVM must be generic.
LLVM uses single static assignments (SSAs) as its intermediate format.
Many optimization techniques leverage SSA to implement and reason about performance improvements.
These automatically found optimizations, which are not based on exhaustive searches, are sometimes called _auto-tuning_ in the literature.
Manual optimizations are called _expert optimizations_.
Many compiler optimizations for array programming language are expert optimizations because they are domain-specific and cannot be merged directly into LLVM.
Similarly, the programmer's algebraic reasoning could be considered an expert optimization because the decision procedures are not presented to the compiler.
On the other hand, the auto-tuning that compilers can do are things such as automatic vectorization.
However, even these assume standardization, such as Advanced Vector Extensions (AVX) in the CPU world.
The amount of optimizations that can be done is relatively rigid because the high-level optimizations are considered expert optimizations, hence out of scope for a general compiler.
In contrast, low-level optimizations rely on assumptions given by standardizations.

One solution to rigid optimizations is superoptimizations.
Superoptimizations help in unlucky cases, as with GPUs, which do not have AVX-like instruction standardization.
Understanding why superoptimizations are tricky to implement requires further exposure to intermediate formats compilers use.
Consider Standard Portable Intermediate Representation (SPIR) and its modern version SPIR-V.
SPIR-V is a cross-platform intermediate representation for parallel hardware like GPUs, but more strictly, it is an informal operational specification.
For example, the bit-width of vector instructions is not defined, which controls how many register values an operation computes.
Instead, the bit-width is a device-specific variable.
As a result, open-source compilers cannot apply vectorization in general for GPUs but instead need a superoptimizer that iterates over all possible cases of vector lengths.
In practice, some applications assume certain bit-widths, especially in machine learning, which means that these deep register-level rewrites, which affect the whole program composition, only work on a specific combination of hardware devices and software drivers.
As a result, heterogeneous general-purpose computing on GPUs is relatively slow aside from Nvidia because Nvidia invested early on in device-specific compilers with the CUDA language.
It could be said that Nvidia keeps the operational semantics of parallel operations as a trade secret by embedding a special version of CUDA interpreter into each GPU's firmware.
For this reason, the CUDA language from Nvidia does not work for other manufacturers' GPUs.

So, how viable are superoptimizations?
A recent dissertation experimented with SMT-based superoptimizers using a tensor language [@doctoral_thesis_mogers].
Here, Figure $5.5$ shows that the solver took 88 seconds to outperform manual heuristic-based approach.
It took 95 minutes for the solver to reach peak performance at 450 GFLOPs.
A completely random approach only generated working valid code 1 out of 49,000 generations.
It took a random approach five weeks to reach 450 GFLOPs throughput.
The author notes that the solver spent half its time finding satisfiable mappings.
This overhead must be done with a solver-aided approach before execution can start.
In Chapter $7.3$ _Future Work_, it is mentioned that a form of _informed search_ would help truncate the search space and help the solver find solutions in less time.
The author suggests that _static analysis_ on the AST could be used to derive extra rules.
Under the subheading _Distributed and Heterogenous Platforms_, in the same chapter, the author notes that a solver-guided approach has the benefit that it is not a platform-dependent technique but could also be used to target other hardware platforms in addition to GPUs.

Under this terminology, this research aims to allow compiler superoptimizations without the assumption of operational semantics at compile-time.
Once semantics exist for some function, it is possible to define the device-specific variables, such as the bit-width of vector instructions at runtime. Next, a SMT solver applies symbolic optimizations by rewriting.
The key here is that should the denotational semantics of the source language modeled happen to be a rank polymorphic language, which means that it permits the interpretation of programs to be a set of scalars, vectors, as well as matrices, then symbolic optimizations can be applied on a more general level than usually possible.
That is, including of device-specific variables is "just" changing certain coefficients, which then affect other parts of the expression.
This allows the executed program rewriting to happen in a device-specific manner, but before the expressions arrive at the GPUs firmware.

## System Overview

Operational semantics is a convoluted story.
On one hand, it attempts to model quantitative types similar to [@Idris2QuantiBrady2021] and [@QuantitativePrOrchar2019].
However, because of how parallel group operations tend to work on only a set of cells of a given array, we employ ideas from inverses like demonstrated on [@TypeSystemsFoMcbrid2022] and in [@HowToTakeTheMarsha2022].
Here, the challenge is that group operations work on a partial view of some array.
Because of the lack of memory management on low-level operations, a faithful model of the operations should only update the array such that it preserves the memory allocations properly.
Luckily, BQN has two operations to help us: the inverse $^=$ and _Under_ $\circledcirc$.
Inverse finds structure-preserving function applications for a subset of possible operations automatically, whereas $\circledcirc$ allows to do partial updates by employing the definition of inverse in its contract: $\mathbb{F} \circledcirc \mathbb{G} x$ means that the input $x$ is given a partial view by a selector function $\mathbb{G}$, such as selecting the first row.
Then, that selected items' values are modified per the function $\mathbb{F}$, but iff the resulting structure can be applied back to $x$ by taking the inverse of $\mathbb{G}$.
This way the Under corresponds to a structure-preserving partial map of $x$.
This is rather useful in our effort to model how function applications over the whole input data $x$ work when some low-level group operation $\mathbb{F}$ is applied.
It is worth reiterating the connection to [@TypeSystemsFoMcbrid2022]: the $\mathbb{G}$ can be considered an indexing operation over $x$.
The index selector's capabilities vary depending on the execution scope of the GPU: in a global view, $\mathbb{G}$ is a pair of scalar indexes, such as $c_{\langle0,0\rangle}$.
On a so-called _subgroup_ level the pair is a combination of a scalar and a vector, such as $c_{\langle0 \times \{ 0, 1, 2, 3\}\rangle}$.
This could allow to model the possible operational transformations over $x$ by depending on rank.

## Operational semantics: quantitative types

Note: here, an inane description of cars were preferred because the technical description concerning memory cells is less descriptive.

Many natural languages have words and phrases which denote quantities precisely.
For example, vehicles come with varying numbers of wheels.
It is sometimes helpful to denote vehicles according to the number of wheels one has, such as a two or four-wheeler.
This may allow us to restrict further the possible set of functions that can be applied to such objects.
For example, when winter comes and you want to change your tires on your car, you might call up a car shop to change your tires.
If you tell over the phone that you want to change your car's tires but then roll in with your eight-wheeler, the car shop would need to work twice as much and refuse the operation unexpectedly!
Such runtime exceptions are wasteful for both parties and arise from a set of assumptions made -- I know my car has eight wheels, so I think it is redundant to tell it over the phone.
In contrast, the car repair shop might assume that most people's cars have four wheels because _certainly_ otherwise it would be told over the phone.

One thing that allows specifying of quantities of types in formal languages are dependent types.
We can encode vehicles by the number of wheels and define functions that only permit applications over vehicles with a known number of wheels.
This allows us to create contracts in which exceptions are resolved even before work begins on either end.
This is particularly useful in languages that work with data-types that are indexed by various quantities of elements, such as vectors.

When defining array languages formally or just using them as a new user, one will inadvertently uncover some peculiarities of array language quite quickly.
This peculiarity is the rank polymorphism.
To continue our example, the language would allow you to increment wheels by one size in your eight-wheeler (supposedly to make them bigger) but the moment you want to increment with a list of two sizes (whether the values are the same or not), the languages would refuse to operate.
This is called an error in rank mapping, which is a type of shape error.
But, if you would instead want to increment eight wheels in your eight-wheeler, then the operation would suddenly be permitted!
In other words, there is an implicit assumption in the language about not the size of your wheels, but the number of them.
In fact, all the runtime errors in array languages arise from a mismatch of the number of values, not the values of the number.
Array languages call these dyadic operations.
More formally, this is the dependent function type, or pi-type: $\prod_{n:\mathbb{N}} \text{Vec}(\mathbb{R}, n)$.
In our example, the language implicitly expects the $n$ of the increment to be in the set of $\{1, n\}$ but does not tell us that before we try it out.

These also have an operational difference: if the increment function is called $A$ and your current car $B$, then the $n$ of $A$ when $n=1$ adds $\mathbb{R}$ of $A$ to _each_ $\mathbb{R}$ of $B$, so to say it increments the size of each wheel by the same value.
In the other case where $n=n$, each wheel size is incremented by their corresponding index, resulting in (possibly) each size of your eight-wheeler now having a different wheel size!
However, it is important to note that when talking about denotational semantics, we are only interested in the $n$'s being correct, not what actually happens in the mappings of $\mathbb{R}$'s.
To know which values are being used in the value computation, we also need the quantification of the values, i.e., operational semantics.
It is worth noting that the operations are equal in terms of linearity: in both cases, eight values are increment to eight values, as in the $n=1$ case it can be considered that the $A$ is lifted to a list of eight values first.
In current language implementations, the need for lifting is identified using the rank of $A$.
Yet, quantitative typing gives us more structure for cases where the rank of $A$ and $B$ are the same, but not their length: if $n$ of $B$ mod $n$ of $A = 0$, then we know that $n$ of $A$ can be expanded by $n$ of $B$ div $n$ of $A$ times, giving us the lift rule that is similar to the case $n$ of $A = 1$.
This would allow us to implement the cases where in our example $n$ is also $2$ or $4$, in addition to $1$ or $8$.
To borrow the example again, this would mean that if the list of wheel sizes is two, it would mean that each pair of wheels is increment first by the first value in the list, and the second by the second value in the list, and then duplicate the action until all wheels are replaced.
This is also more precise description of what the operations is all about: it is about replacing all wheels with winter ones, even if the set of sizes is partial (and even in the real world, the back tires are sometimes slightly larger than the front wheels).
This could serve as a motivating example of how a quantitative type system could complement the traditional semantics of array languages, which only match on either length of the same rank or then the rank below the current with lifting.
Dependent types still guide us to have the base cases, but quantification can expand the set of solutions on the type level.

Yet, presenting the algebraic properties still requires answering an another question -- not whether it can be done, but whether the resulting software construct is useful to model parallel algorithms.

## Structure

In the 1960's APL was used to model IBM 3/60 computer system.
This essays explores using a novel array programming language called BQN to model GPUs instead.
In specific, we will demonstrate how BQN's operator combinator called Under has an interesting correspondence between views of rank polymorphic arrays and GPUs runtime memory representation.

Array programming languages have always abstracted nitty-gritty of hardware: the original IBM paper did this for register and types, then Dyalog APL did it for multi-core CPUs, and vectorization has been recently handled in BQN with a separate performance orientated DSL called Singeli.

The unifying idea throughout the years has been to provide the programmer with an abstraction to low-level instruction sets by leveraging a standard library that closely corresponds to mathematical notation.


### The graphics processing unit

__GPU program__ A GPU program in SPIR-V has six different _execution models_.
Two of these are meant for general-purpose computing: the Open Graphics Library (OpenGL) compute shader, and the Open Computing Language (OpenCL) kernel.
The compute shader model is purely GPU orientated, whereas the kernel model targets heterogeneous targets such as FPGAs and CPUs.
For this reason, the functionality in the kernel model is limited to an intersection of hardware capabilities on a varying set of accelerators.
As such, we only focus on the compute shader model, because this shares functionality with GPU execution models rather than different hardware accelerators.

__Invocations__ Invocations specify the amount of threads that a compute kernel has.
The set of invocations $I$ is computed from the dimensions of two cubes: _global_ and _local_ group counts.
Given three integers often denoted as $X$, $Y$, and $Z$ with each having a size $\ge 1$, a set of group counts can be derived using the range command:

```
|workgroup.bqn|
```

A distinction of the global and local work groups is that the global work groups cannot do cross-communication between different invocations, but local workgroup can.
The set of total invocations $I$ is a Cartesian product of local and global work groups.
The number of invocations $\bar{I}$ can thus be computed using the shape of the Cartesian product:

```
|workgroup_product.bqn|
```

Each $i \in I$ has a unique identifier $i_{id}$ which is distinct between global work groups invocations.

__Memory mappings__ The set of $I$ is closely related to _memory mapping_.
Here, the index of some $i \in I$ determines the memory location from which to load values from a given _storage class_.
A storage class is like a variable with initial values but with varying visibility granularity within the GPU.
A SPIR-V program can have multiple storage classes with the complete list described in Section 3.7 in the SPIR-V specification.
Arguably the most useful of these is the _StorageBuffer_, which is _shared externally, readable and writable, visible across all fnctions in all invocations in all work groups_.
_Shared externally_ means that it is a memory mapping that can be accessed by both the GPU and the CPU.
This allows the same buffer to act as input and the output buffer of a compute shader.
This is in contrast to simple _Input_ and _Output_ storage classes, which require that the program copies memory during runtime from the _Input_ to the _Output_ buffer.
In other words, _StorageBuffer_ allows in-place memory management hence enables more strategies to achieve static memory allocation.
_Visible across all functions in all invocations in all work groups_ means that the buffer is an _uniform_ buffer, which means it can be accessed at any location of the program.
This means that _StorageBuffer_ memory class is similar to CPUs _heap_ memory.
StorageBuffer also uniquely enables a special memory access pattern known as a _variable pointer_.
Variable pointers allow a memory region within a StorageBuffer to be selected as a pointer of a result of the following instructions: _OpSelect_, _OpPhi_, _OpFunctionCall_, _OpPtrAccessChain_, _OpLoad_, and _OpConstantNull_.
Hence, it is possible to either compute memory regions needed for subsequent functions using runtime and statically computed memory mappings.

__Subgroups__ As noted, a local work group can share memory between different invocations.
This is done using _subgroups_, which correspond to a SIMD lane of a GPU.
A subgroup $s$ has a length $\bar{s}$ which often is a constant given by an API such as Vulkan.
Often, it is a multiple of $2$, with common values being $8$ for Intel, $32$ for Nvidia and Apple, and $64$ for AMD.
Subgroups allow a set of _non-uniform group operations_ to be performed over invocations.
Suppose our local size of invocations is $128$ and $\bar{s} = 32$.
This will produce a view over the invocations and the data loaded in them such that we have a matrix $4x32$.
We can instruct an integer addition on each row using `OpGroupNonUniformIAdd` with `Reduce` which will act on each invocations value with a single instruction.

__Decorations__ From the viewpoint of a CPU, a _StorageBuffer_ is always a vector data-type.
The view to the compute shader is controlled by _[Decorations](https://registry.khronos.org/SPIR-V/specs/unified1/SPIRV.html#_decoration)_.
Decorations allow two useful primitives to control the view on the GPU, which are _ArrayStride_ and _Offset_.
A single _StorageBuffer_ may have multiple different views using statically computed _ArrayStrides_ and _Offsets_.
For example, setting _ArrayStride_ to $1$ would map each value in the _StorageBuffer_ to each $i \in I$.
Similarly, setting it to $4$ would map each fourth value to _StorageBuffer_ to each $i \in I$.
While accesses to memory regions outside of the length of _StorageBuffer_ results in undefined behavior, it is still useful if the compute shader is instructed to do _thread divergence_.
Here, we can instruct only a subset of $I$'s to act.
Suppose the values in _StorageBuffer_ is $N \times N$ where $N$ equals to the subgroup length of the GPU.
Now, using _ArrayStride_ of $N$ causes a transposition of the array values.
On the other hand, _Offset_ allows skipping $n$ values from _StorageBuffer_ before assigning values to each $i \in $I$.
This instruction may correspond to reading values in the y-axis of the input: suppose the input is $4x6$ and the subgroup length is $4$.
We can instruct some $i \in I$ to first skip $5$ values, and then use _stride_ of $5$ to read every value in the last column in the _StorageBuffer_.


### BQN modeled SPIR-V

APL was initially used to model the IBM 3/60 system. What we present below is using BQN to model SPIR-V.

The highest level of the SPIR-V views is a the global thread index. Suppose we have a an index of

```
|global.bqn|
```

This shows that in the global context each value in the grid acts independently.
One of the downsides of this is that the y-axis needs communication between different indexes to do operations.
In this sense, the global view is rather unuseful.
On one hand, it gives a simplified view to our data, but any computation needs communication between different threads.

To get more useful, we need a different level of grid abstraction which is the subgroup.
A subgrouop of length $\bar{s}$ does the following:

```
|subgroup.bqn|
```

This way, it allows each subgroup to operate on values on that x-axis.
The elements can be identified using the global index as such, but more useful is the subgroup index:

```
|subgroup_local.bqn|
```

Now each row has its own index on which it operates.
We can create a group operations on the subgroup level.

Suppose we introduce a data vector with actual values:

```
|subgroup_data.bqn|
```

We can look how to some subgroup level operation like a prefix sum by using the shape of the subgroup view onto the data:

```
|subgroup_prefix.bqn|
```

Or this how it would look on a CPU. But because on GPU, the subgroup actions are SIMD operations the actual output is actually as follows:

```
|subgroup_prefix_simd.bqn|
```

The problem is that we have calculated prefixes per subgroup, but the information is in different subgroups.
This is where the communication between subgroups start to happen, and in which the complexity increases a lot.

To minimize communication, we should focus on a single subgroup onto which we do communication.
For simplicity, we could focus on the first subgroup, with global thread identifiers $0..3$ (inclusive of $3$).
Coincidentally, focusing on a single subgroup causes _thread divergence_, which means that other threads are sleeping.

One thing to note when the rows length is equal to the subgroup length, one can do a transpose to get the right values on the first row:

```
|subgroup_transpose.bqn|
```

On the GPU, one way to achieve this is to do change the read stride.
Changing the stride to the length of the subgroup causes hence effectively the transpose effect.

This way, we can first lock into the first subgroup, change the read stride, and then prefix scan again:

```
|subgroup_transpose_selected.bqn|
```


We can go back to reading the information from subgroups using the index of the subgroup.
Remind this example:

```
|subgroup_local.bqn|
```

We can use the indexes where we have zero (called a _subgroup leader_, or any other arbitrary index) to create a view vector:

```
|view_vector.bqn|
```

We can use this to read the values:

```
|view_values.bqn|
```

To know where to put these values, we can use the global index:

```
|subgroup.bqn|
```

And count where the index is a modulo of the subgroup length:


### A primer to SPIR-V

Note: Here, the more technical presentation compared to car wheels is given. These examples need revamping: the idea in each is to show how the G in Under can be used to selector on which the values change. The idea is to "carry" the quantification with the type. Suppose that we interpret every program to be the type Shape (Shape (Shape (Shape input)))... then the view matrices which encode the type would be fixed first to the Shape of the initial input, which is then carried over the program View (View (View (View input)))... The combination of Shapes and Views is a map over them. The point is to show that in the semantics of "F Under G input" the F corresponds to Shape, the G to View, and the input to input. For superoptimizations, it is important that the initial structure of input is never destroyed, which is indeed guaranteed by Under since it requires the G to always invert any change on input after F is applied.

The thread grid on a GPU holds thread coordinates in various levels of abstraction. This inherently hierarchical structure provides a single cell various mechanisms to communicate between different cells, to then finally converge on a uniform result. Arguably, the most interesting level happens on _subgroups_ where a small partition of cells are able to also cooperate together. Here, a subset of active threads are capable of executing operations using each other's values with as little hardware communication overhead as possible. This hardware-based constraint thus makes subgroups the most performant hence the most interesting level of abstraction to do computation on.

We now start with examples, which we model in an array programming language called BQN. Subgroups have a length $\bar{s}$ determined by the hardware, which can be queried using an API (we base our work on the Vulkan API for reasons detailed in our previous works ??). $\bar{s}$ is often some power of two:

```bqn
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

The row index in SPIR-V terminology corresponds to $c_{\langle \text{SubgroupId}, \text{SubgroupLocalInvocationId} \rangle}$. Some SPIR-V operations operate over these indices, such as `OpGroupNonUniformElect` which returns `true` for $c_{\langle id, 0 \rangle}$. We could model calling this instructions as follows:

```
  {0 = 1⊑𝕩}¨subgroups
┌─
╵ 1 0 0 0 0 0 0 0
  1 0 0 0 0 0 0 0
  1 0 0 0 0 0 0 0
  1 0 0 0 0 0 0 0
                  ┘
```

It is relevant to note that BQN operation calls `each` `¨` to operate on per row basis. The same applies to SPIR-V instruction on the subgroup level. These semantical _suggestions_ of operational correspondence continue to appear in later examples.

A computational example that operates _on the values_ of the cells is a sum operation. A sum operation corresponds to a select function which takes a set of cells such that $c_{\langle r, col \lt \bar{s} \rangle}$. The index generation on $col$ over the $\bar{s}$ is done automatically by SPIR-V. So, to say we want to operate on the second row is to say:

```
  1 ⊏ idx
⟨ ⟨ 1 0 ⟩ ⟨ 1 1 ⟩ ⟨ 1 2 ⟩ ⟨ 1 3 ⟩ ⟨ 1 4 ⟩ ⟨ 1 5 ⟩ ⟨ 1 6 ⟩ ⟨ 1 7 ⟩ ⟩
```

Suppose each cell has value $10$. Now:

```
  10¨idx
┌─
╵ 10 10 10 10 10 10 10 10
  10 10 10 10 10 10 10 10
  10 10 10 10 10 10 10 10
  10 10 10 10 10 10 10 10
                          ┘
```

A sum reduction using SPIR-V semantics would be:

```
  {≠⥊+´}⌾(1⊏⊢) 10¨idx
┌─
╵ 10 10 10 10 10 10 10 10
  80 80 80 80 80 80 80 80
  10 10 10 10 10 10 10 10
  10 10 10 10 10 10 10 10
                          ┘
```

SPIR-V subgroup operations write the result to each acting cell. The concept is same as SIMD instruction on CPUs. So, a sum does not fold, it ravels the _context_ of the subgroup identity. How the communication exactly happens is not explained in the specification, it is implemented on the hardware level. We can also visualize the identity:

```
  sum ≠ 10¨idx
┌─
╵ 0 0 0 0 0 0 0 0
  1 1 1 1 1 1 1 1
  0 0 0 0 0 0 0 0
  0 0 0 0 0 0 0 0
                  ┘
```

Returning the result can done from arbitrary cell in the context, but it has to be a coded deterministically -- there is no randomness instruction in SPIR-V. In practice it is probably easiest to do using the subgroup leader index:

```
  {⌊´1‿0 = 𝕩}¨idx
┌─
╵ 0 0 0 0 0 0 0 0
  1 0 0 0 0 0 0 0
  0 0 0 0 0 0 0 0
  0 0 0 0 0 0 0 0
                  ┘
```

Now we start our quantitative modeling. We sum identities of acting cells:

```
  leader + a
┌─
╵ 0 0 0 0 0 0 0 0
  2 1 1 1 1 1 1 1
  0 0 0 0 0 0 0 0
  0 0 0 0 0 0 0 0
                  ┘
```

In this case, we find our final value from the cell which we have done two reads, which also happens to be the most used cell. A hypothesis appears: the result of computation is found from a subset of cells, but not necessarily from a proper subset that have been accessed the most. A stronger claim is that cells that have been accessed zero times are redundant. Let us find the subset using our quantified matrix:

```
  b = ⌈´⥊b
┌─
╵ 0 0 0 0 0 0 0 0
  1 0 0 0 0 0 0 0
  0 0 0 0 0 0 0 0
  0 0 0 0 0 0 0 0
                  ┘
```

This _view index_ can be used as a filter on the flattened array:

```
  (⥊(b = ⌈´⥊b)) / (⥊sum)
⟨ 80 ⟩
```

We have now demonstrated the basic idea how we want to use quantified types in our work. To reiterate, we want to encode the times that operations access cells using indexes of each level of context available to us. In the above example, the only level of context we used was the subgroup. Next, we introduce the level below which we call the global context.

Before we continue, we should also introduce barriers. A barrier is a blocking instruction which is paramount for deterministic results. Barriers come in two forms: _control barriers_, and _memory barriers_. A control barrier waits for each context to converge in execution. A memory barrier ensures that accesses to a cell or cells are observed by a user-defined context. For simplification, we say that our barrier does both.

Quantification of barriers is important because of how it can considered a _code-smell_: the more there are barriers, the more time is spent on waiting. A hypothesis is that minimizing barriers lead to faster algorithms.

In our example above, there is a single barrier after the sum reduction. This is because returning the result before the sum operation is done would not give us the result wanted. Now on, we denote a barrier in our code.

We now continue modeling a sum reduction of the whole matrix. This will introduce us to operations on the global context.

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

The interesting part happens on the `move` step on $c_{\langle row,0 \rangle} \to c_{\langle 0, row \rangle}$. We followed this with an extra subgroup sum on $c_{\langle 0, col \rangle}$. The result is found from $c_{\langle 0,0 \rangle}$ which is again the most accessed cell.

We can revisit typing now. We define that each operation produces a vector of binary values $\{0,1\}$ indexed by $n$. We call such array a _view array_. As a corollary, $n$ must match the shape of our denotational semantics for that operation. There exists an initial view array which is always the size of our input _buffer_. The count of $1$s in the last view array must correspond with the final shape defined by our denotational semantics of the algorithm iff the type can be deduced. If the type cannot be deduced, the program must return. Any view array in between the initial and the last one must have shape that depends on the shape of the previous operation. If all these constraints hold, then the algorithm is considered type-correct.

A corollary: the result is a list iff the final type cannot be deduced. An example of this is a value-dependent filter. The only case in which the type cannot be deduced must hence depend on the value of the cell.

In effect, these statements join static rank polymorphism with operational semantics derived from work of [@TypeSystemsFoMcbrid2022], in which the row and column headers were set as types. Our motivation is to work our way "back" from the representations of the final view array using the list lengths of the header and cell as lifetimes. The idea being that operations "deconstruct" the spreadsheet structure by checking if the linear "use-by" counts permit it. This way, we can model various parallel algorithms before actual implementation.

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

Note: The point is here to convey the idea that if the F in under is the Shape that we want, then we may give candidates G how to produce an output of type F under constraints X, then we can use the quantities in G to evaluate with an SMT solver which one of the outputs is the most desirable. The idea is that one which minimizes the total accesses in the final program composition is the fastest. So, F does the computing, and G is being searched for versions over some constraints X (like s bar and various indexing offsets) such that it produces least steps.

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

## Evaluation

??? Is one needed? Do examples suffice?

## Discussion

Discussion would be the remarks of notes in different format

## Conclusion

Under is useful to present dependent type information because it allows dependent types to exist as F, while having quantification exist in G. The fact that the input dimensions is unchanged over the composition of N of these (F under G)'s is the most useful part, because it allows the fusion and rewriting of each part in possibly in ways that the hardware likes more. "What the hardware likes more" is the exhaustive search over such rewrites such that the shape F is preserved while minimizing the sum of Gs values in the final solution.

