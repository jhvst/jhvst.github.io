
# |title|

_|description|_

Despite the networked nature of computer systems, programming languages that are networked remain a gimmick.
Distributed programming as a term could imply a programmer interfacing with system of networked nodes which collaboratively and heterarchically decide where computation happens.
The prevalent reality is often quite the opposite: the programmer must use heurestics to split data into pieces and control which node receives what work.
In other words, distributed programming often entails coding not only _what_ but also _how_ the computation happens.
The question whether the how, a.k.a _scheduling_, can be mechanized over heterogeneous nodes and arbitrary network size seems rather profound question of how programming language schedulers are designed.
What this essay explores are some prevalent approaches in system and language design which include distributed schedulers in the language compiler.
Common to all is that such languages are domain-specific to array computation -- either as a library such as NumPy, or in some cases complete languages such as APL.
Our findings suggests that novel static type systems of array programming languages can aid in the compiler enough in the understanding of the operational semantics of the language to make execution distribution possible.
Given this, we also explore some properties of the said type systems in aiding the schedulers to also achieve static scheduling schemes rather than runtime ones.

## Introduction

The profiliration of different hardware architectures has caused a lot of computing systems to consist of nodes that are different in their physical properties.
For example, a cloud computing environment might include nodes which are partially x86, ARM, and then include separate accelerators such as GPUs and TPUs.
To use such heterogeneous networks efficiently is a complicated task because most programming languages expose APIs which concern primarily the local resources of the computer.
With the prevalence of machine learning tasks and other big data tasks which do not easily fit into a single computers memory anymore, various programming language libraries and designs have started to focus on distributed scheduling as a built-in feature of the langauge.
However, designing such language does not come without its limits: for one, the compiler of the language needs to be know much about the semantics of the language to be able to decide whether some expression can be divided and offloaded to a separate accelerator.
This calls for languages which are rather constrained in their domain and which by default deal with data structures that can be split up into smaller pieces.

The design of a constrained programming language starts from the semantics.
When defining a programming language, one way to think about them is as a categorical object in space.
Formal semantics and type systems help defining this object by establishing boundaries on the shape of the object.
In this sense, research in type systems could be said to focus on defining the object meticulously.
The properties that these definitions then give arise are called static properties, because the properties can be inspected in the form of proofs from the "shape" of the object before programs are run.
As the propreties cane be inspected prior to execution, a scheduler can take a look at the expression to infer whether segments of the expression could be split.
In other words, static properties given by type systems could be thought to describe information that can be inferred from the expression of programming language prior executing the program.

In many cases, the inferred information has to do with correctness guarantees of various expression within the language.
This is because if the program can be analyzed prior to execution to satisfy properties, a compiler could check whether it violates various contracts between the types or in some cases, Hoare-triples expressed with predicate logic.
However, we reiterate that this essay only explores exeuction optimization.
So, we are not as focused on how the object is defined, but by how certain static properties in the language could be leveraged in novel ways to make mechanized decision about parallel or distributed execution.

### The Constraints of a constrained language

To make a programming language with a distributed scheduler, we need to first constraint the source language under certain parameters.
One constraint is that "viewing the object in space" is only possible if the state space of the object is finite.
Otherwise, it would be impossible to "step out of it" as the act of viewing might cause infinite continuation of the object.
What we thus need is a source language which is Turing-incomplete in nature.
A Turing-incomplete language forbids the language to contain user-defined recursion and randomness.

Otherwise, the best effort is to use bounded model checking to restrict the possible state spaces to a finite subset.
But, bounded model checking is mainly relevant in checking security properties of the language.
This is because bounded model cheking may only establish an incomplete representation of the language: it uses programmer or domain-expert instructed specification to model the language.
As such, the verification of possibly infinite state spaces created by a language are only as good as the specifications created by the programmer.
Here, the hard parts of bounded model checking are often related to non-determinism and loop boundaries: unless these can be resolved, the shape of the object might be inifite, thus the viewing of the programming language is impossible.
Consider just a simple for loop defined by a programmer: it suffices that the loop _may_ be infinite to make it possibly impossible for an exhaustive search to be done, because the solver visiting the state spaces might run into eternal loop thus make the solver to time out in its search of an objective.

What is interesting is that languages which establish loop boundaries in itself limit the state spaces to a finite subset.
Examples of such languages are e.g. array programming languages, in which the loop boundaries are created by the language using the shape of a rank polymorphic language.
In specific, an array programming languages with dependent types and their quantitative extensions can establish finite search spaces for SMT solvers statically.
This means that an array programming languages which static rank polymorphism are indeed objects with provably finite state spaces, hence when the type checking works, then the program is known to terminate.
What the rest of this essay now introduces are some background information in SMT solvers, how they are often used nowadays, but then disposing how the SMT solvers can be used to view or "chunk" the programming language into smaller parts that may be executed in parallel on multiple accelerators.
The originality of the research is that the idea of using SMT solvers to create automatically parallelizable execution of a programming language seems novel: to our knowledge, there are no languages which are Turing-incomplete and use exhaustive search to optimize the execution for heterogeneous hardware.
The mechanized decision procedure to find such pieces from a language stems from the static properties of the language, which in itself motivates the research into advanced type systems such as dependent and quantitative type systems.

## Background

### Model checking

Model checking in programming languages can be roughly divided into two categories: the ones which have it built-in, and which do not.
Another categorization is whether the model checker is used for operational or denotational semantics.
What this essay explores is one in which the model checking is built-in to the language, but is primarily used for operational semantics.

### Bounded model checking

The most classical way to employ model checkers for verification purposes is to use SMT solvers posthumously.
Here, there exists some source language $S$ which is then being checked using separate specification language.
Examples of such languages include e.g. PROMELA which is used e.g. in the Spin language, which combines C with PROMELA to verify fragments of C programs using an SMT solver.
In this case, the model checker is mainly used to verify constraints introduced as temporal logic to aid in concurrent processes.

In more contemporary setting, various smart contract languages in blockchain applications have also been used with bounded verification.
For example, a company named Certora uses a language called Certora Verification Language (CVL) as the specification language to verify properties in the Solidity smart contract language.
This is used to find bugs in a loosely typed language such as Solidity by finding counterexamples which violate various safety properties.
A rudimentary example is a "token" transfer: given some account $A$ and $B$ and the balance $A_b$ and $B_b$, a rule could be that the given some arbitrary transfer $T$, the overall token balance in $A$ and $B$ should not exceed the sum of $A_b + B_b$.

Similar to both PROMELA and CVL, the source language has no awareness of the verification language.
Instead, it is up to the specification language to be able to faitfully model thus integrate with the underlying language properly.
This means that the formal semantics of the source language have to be posthumously defined by verification experts.
It also means that the modeling might not be complete -- it is dependent on the verification experts to understand enough of the source language for the verificaiton process to be useful.
These approaches scale well when the programs modeled are somewhat limited in their scope, such as token transfers -- bigger programs might create too large state spaces which might cause the solver to time out in their search of verification conditions or simply take an extraordinary amount of time.
For example, the state space search might prove intractable e.g. for functions which are not linear or use data types such as floats.
In such cases, approximations of the datatypes might be needed, which in turn might not always completelely represent the semantics of the source language properly.

Nevertheless, bounded model checking might in practice be a useful approach to give further guarantees of programs without introducing extra semantics in the source language.
This way, the verification step can be considered optional to the programmer and/or done posthumously.

#### Refinement types

To the author's anecdotal experience, the most common misconception between the proposal to use SMT solvers as a language property to aid in execution performance stems from confusing such objective with refinement types.
Languages such as Liquid Haskell and Dafny use SMT solvers (and the Microsoft Z3 solver to be precise) to establish annotations based on predicate logic within the source language of the program.
In these contexts, the type system allows "refinements" to be added as a way to prove correctness of algorithms using the type system.
In some sense, these languages are more user-friendly version of the so-called B-method, which is a programming approach in which the program is a set of specifications with ever more precise refinements of the most abstract version.

In more concerte terms, and as an example, in Dafny expressions such as the following can be written in a function definition: `forall k: int :: 0 <= k < a.Length ==> 0 < a[k]`.
Such expression verify that the indexing within an array `a` is safe for all values of `k`.
In more general terms, these expressions are often combined as a set of Hoare-triples to represent proofs about program fragments.

The general limitation with the refinement types, while more fundamental property of the language than with simple bounded model checking, is that it is incomplete verification of the algorithms.
That is, the proven parts of the algorithm is only proved to the extent that the programmer is able to produce specifications.
To know what is relevant to prove is hence up to the programmer to come up with the cases that are deemed important.

### SMT-guided compiler superoptimizations

With the aforementioned description of using model checking for correctness purposes, we can visit the topic of using them for performance optimization.
Some existing projects have looked into _superoptimizations_ of programming languages using SMT solvers.
In this context, superoptimizations means an exhaustive search using an SMT solver to fulfill objectives that align with some performance charasteristic.
This research is arguably more closely to our effort.
The idea is that when the source programming language is formally defined, then the boundaries to which the state spaces in the program are limited from the get-go.

This branch of research has little to do with the correctness of the programs in the source language.
Instead, the idea is to use the already-provided semantics of the source language to establish a finite set of states to visit using an SMT solver.

As an example, in ? the author used the ?? as the source language to then apply SMT-based _superoptimizations_ to look for ways to execute the programs faster on a different set of hardware architectures.
These approaches often address the question of performance optimization on heterogeneous hardware, which means a set of accelerators that vary in their physical properties.
An example of heterogeneous hardware could be a CPU with varying amount of cores and cache sizes, but more often nowadays is the example of GPUs of varying manufacturers and RAM sizes.
A common objective for an SMT solver could be, for example, which GPU from a set of GPUs should be used for a given computation, or how should the expression and its data be split such that the workload fits into the memory of both of the GPUs.
Solving this has a practical upside of avoiding running out of memory during execution, which is commonplace with various machine learning tasks.
Similarly, given that the amount of RAM and the required number of operations over the data can be inferred statically, one could receive an estimate on the "wall-time" of the expression to be run.
A blue sky vision of the approach could thus be an estimate e.g. that how long some prompt execution would take to complete in the context of large langauge models.

## Related research

Next, we look at some previous practical examples in the research direction to see how alternative approaches have tackled the problem of distributed execution.
A commonality is that the approaches tend to use some for of array orientated domain-specific language to limit the source language to a language fragment from which the inferration of distribution can be resolved mechanically.
The most common array language fragment is Python's NumPy, but alternatives also exist for Haskell and APL.

### NumPy

NumPy is a popular Python library used for performing array- based numerical computations.
The canonical implementation of NumPy used by most programmers runs on a single CPU core and only a few operations are parallelized across cores.
This restriction to single-node CPU-only execution limits both the size of data that can be processed and the speed with which problems can be solved.

Despite these limitatons, the programming interface provided by NumPy is often the basis of many of other distributed computing libraries.
Somewhat of a limiting factor with NumPy is its lack of strict type system.
This becomes apparent when doing distributed computing over arrays: the static information flow between phases of computation has to be done on another level.
In practice, this means that NumPy cannot often be directly overloaded, but instead each library has to implement a correspondence to the NumPy interfaces to make the distributed computing intrinsics work.

#### Dask

Dask is a flexible library for parallel computing in Python.
Dask.distributed is a lightweight library for distributed computing in Python. It extends both the concurrent.futures and dask APIs to moderate sized clusters.
Dask.distributed is a centrally managed, distributed, dynamic task scheduler.
The central dask scheduler process coordinates the actions of several dask worker processes spread across multiple machines and the concurrent requests of several clients.

#### Legate

Legate, a programming system that transparently accelerates and distributes NumPy programs to machines of any scale and capability typically by changing a single module import statement.
Legate achieves this by translating the NumPy application interface into the Legion programming model and leveraging the performance and scalability of the Legion runtime.

Legion is a data-driven task-based runtime system [2] designed to support scalable parallel execution of programs while retaining their apparent sequential semantics. All long-lived data is organized in logical regions, a tabular abstraction with rows named by multi- dimensional coordinate indices and fields of arbitrary types along the columns (see Figure 3). Logical regions organize data indepen- dently from the physical layout of that data in memory, and Legion supports a rich set of operations for dynamically and hierarchically partitioning logical regions [27, 28]. The Legion data model is thus ideally suited for programming models such as NumPy which must manipulate collections of multi-dimensional arrays and support creation of arbitrary views onto those arrays at runtime.

Legate leverages support for dynamic control replication in the Legion runtime. As a result of efficient translation to Legion, effective mapping strate- gies, and control replication, our Legate implementation enables developers to weak-scale problems out to hundreds of GPUs with- out code rewrites.

#### JAX

We describe JAX, a domain-specific tracing JIT compiler for gen- erating high-performance accelerator code from pure Python and Numpy machine learning programs.
JAX uses the XLA compiler infrastructure to generate optimized code for the program subrou- tines that are most favorable for acceleration, and these optimized subroutines can be called and orchestrated by arbitrary Python.
Because the system is fully compatible with Autograd, it allows forward- and reverse-mode automatic differentiation of Python functions to arbitrary order.

What’s new is that JAX uses XLA to compile and run your NumPy programs on GPUs and TPUs. Compilation happens under the hood by default, with library calls getting just-in-time compiled and executed. But JAX also lets you just-in-time compile your own Python functions into XLA-optimized kernels using a one-function API, jit. Compilation and automatic differentiation can be composed arbitrarily, so you can express sophisticated algorithms and get maximal performance without leaving Python. You can even program multiple GPUs or TPU cores at once using pmap, and differentiate through the whole thing.

#### Cloud Haskell

We present Cloud Haskell, a domain-specific language for devel- oping programs for a distributed computing environment. Imple- mented as a shallow embedding in Haskell, it provides a message- passing communication model, inspired by Erlang, without intro- ducing incompatibility with Haskell’s established shared-memory concurrency. A key contribution is a method for serializing func- tion closures for transmission across the network. Cloud Haskell has been implemented; we present example code and some prelim- inary performance measurements.

Cloud Haskell is a domain-specific language for cloud computing, implemented as a shallow embedding in Haskell. It presents the programmer with a computational model strongly based on the message-passing model of Erlang, but with additional advantages that stem from Haskell’s purity, types, and monads.

#### co-dfns

Co-dfns development historically focused on the core compiler, and not parsing, code generation, or the runtime. The associated Ph.D. thesis and famous 17 lines figure refer to this section, which transforms the abstract syntax tree (AST) of a program to a lower-level form, and resolves lexical scoping by linking variables to their definitions.

The core Co-dfns compiler is based on manipulating the syntax tree, which is mostly stored as parent and sibling vectors—that is, lists of indices of other nodes in the tree.

## Problem statement

Suppose a simple program of sum reduction over a matrix with $r$ rows. Given some set of nodes $N$, the question is how to split the $r$'s onto $N$.

A heurestics based approach could divide the rows evenly, but if the $n \in N$ are heterogeneous, then the optimal solution might not be an even split.
To support heterogeneous splits, there has to be a read function over the computational capabilities of each $n$.

Next, some static information about the program is useful.
The first property is some indicator of the cost of the computation.
Oftentimes, the shape of the input data is a good way to quantify this.
A language capable of generalized shape analysis is one in which data is often structured as an array.
Here, array programming languages and dependent types help a lot.
Dependent types allows static infer of sub-expressions in the program where the shapes can be computed ahead of execution.
This capability essentially allows a complete program expression to be split into individual phases of execution which are well typed or not.
Hence, phasing of expressions effectively provides a skeleton for parallel operations using type information.

The set of well-typed phases of the program can then be considered for analysis of data-independent parts.
If the nodes doing the computation cannot be assumed to share shared memory during execution, then grouping of sub-expressions becomes tricky.
Consider a case where a sum reduction of the rows of an matrix is followed by the sum reduction of the resulting value.
Now, whether to split the initial sum reduction over different nodes is really a question of whether the row lengths are larger than the amount of rows.
We could:
1. Split the data and have the nodes operate in parallel, but synchronize after the first reduction (optimize for throughput)
2. Put all the data into a single node and have it do all the work, but no synchronization is needed (optimize for latency)
On modern hardware, the second option is likely the fastest, because the cost of synchronization is often much more than cost of computation.

For analyzing needed synchronization between different phases more static information is needed.
Here, quantified types help.
Quantified types allow individual shapes of data to be embedded with the extra information on the number of times some bit of information was used.
That is, even though the shapes of the sub-expressions remain the same in the cases 1 and 2, the second case causes less reads and writes because of the lack of synchronization.
In fact, this is useful for

## Related Work

The cats around this hot porridge come from various background

## Scheduling schemes

Prevalent in many scheduling schemes is the amount of information that can be accessed by the compiler to apply optimizations.

## Prevalent directions

Computation is moving towards heterogeneous infrastructures.
Here, a computation cluster consists of multiple nodes which may have different hardware properties.

Oftencase, languages and other distributed schedulers make an assumption the underlying hardware.
Usually, this assumption is that the hardware is homogeneous.
For example, supercomputers are often build with uniformity in hardware accelerators while abstracts the multi-node hardware to the software as a single computation node.
Similar approach is taken by current AI accelerators, such as the Nvidia DGX H100.

Challenges in distribution arise when the nodes are not exactly the same anymore.
It is thus much harder to make use of networked datacenters which might mix-and-match accelerators.

To address situations in which the hardware is heterogeneous the compiler of the language would have to be aware of the operational semantics of the language.
The language also has to be aware of the network of such nodes.
One approach to look at this is as a constraint problem.
A constraint model is created with predicate logic.
Consider a rudimentary example of splitting a computation to two GPUs.
Suppose two GPUs $A$ and $B$ with memory $A_m$ and $B_m$.
If the computation can be computed to take, say $200MB$, one could create a constraint model that the memory used by each node has to be achieved to maximized, but to the bound of $200MB$.
