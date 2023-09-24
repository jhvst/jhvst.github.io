
# |title|

_|description|_

Despite the networked nature of computer systems, programming languages that are networked remain a gimmick.
Distributed programming as a term could imply a programmer interfacing with system of networked nodes which collaboratively and heterarchically decide where computation happens.
The prevalent reality is often quite the opposite: the programmer must use heurestics to split data into pieces and control which node receives what work.
In other words, distributed programming often entails coding not only _what_ but also _how_ the computation happens.
The question whether the how, a.k.a _scheduling_, can be mechanized over heterogeneous nodes and arbitrary network size seems rather profound question of how programming languages are designed.
As such, what this essay describes is some prevalent approaches to system and language design which seem capable of pushing distributed programming more towards the more ideal description above.

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
