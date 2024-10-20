#import "acmart.typ": acmart

#let abs = [
]

#show: doc => acmart(
    doc,
    title: "indeKSI: data-mapping with corecursive combinators",
    review: false,
)

#outline()

= Introduction

Post-Moore programming on multi-core computers revolves around using parallelism efficiently.
A particularly interesting space in multi-core programming is general-purpose computing on GPU (GPGPU) environments.
In addition to its significance in current-day machine learning and data science research, the GPGPU environment contains programming constraints that do not generally exist in the CPU space.
Such constraints include: 1) lack of dynamic heap allocation, 2) intermediate representations and domain-specific languages that are written from the perspective of a single thread instead of the computer as a whole, and 3) esoteric memory models where fast memory exists only in consecutive threads making programming harder and applications memory- rather than compute-bound.
In this work, we address the second and third issues by looking at how array programming languages can abstract memory hierarchy with inverse operations.
Using inverse operations for memory management has been shown previously in @OnMappingNDiJansse2021, but our approach leverages the rather new BQN language with a 2-case inverse combinator called Under.
Specifically, we use Under to study the recursive patterns in divide-and-conquer algorithms, which are a necessary programming approach on the GPU.
The approach models the semantics of SPIR-V, a parallel GPU intermediate representation.

We show how Under, which has two contextual cases of generating and overwriting values, is used recursively in a turn-based manner to abstract group operations on memory registers.
As a rank polymorphic language, we retain these polymorphic properties.
Thus, the motivation is to show how an intermediate representation language like SPIR-V can be modeled with a high-order array programming language.
We suggest calling this approach indeKSI, an index manipulation language with combinators.

In the next section, we describe some background on corecursion and invertible combinators.
We then detail the SPIR-V language semantics and how it uses indices for computation.
In the subsequent section, we detail the underlying pattern of index generation using combinators.
Finally, we finish off with discussion and conclusion.

= Background

== Corecursion

Corecursion is a dual to recursion.
Many proofs about corecursion are _coinductive_, meaning that the proof includes a form of induction that allows some form of reasoning concerning sets that are not well-founded.
The relation in coinduction is called a _bisimulation_, which abstracts the idea of associating systems that behave similarly in that one system simulates the other and vice-versa.

An example of bisimulation is fold and unfold: fold consumes values while unfold generates new ones @ProofMethodsFGibbon2005.
A paper that studies the categorization of recursive functions is detailed in @FantasticMorphYang2022.
The paper details how the generalization of folds is known as catamorphism, whereas the list-producing unfolds are known as anamorphism.
When catamorphism is composed with anamorphism, you have _metamorphism_ and _hylomorphism_ the other way around.


== Invertible combinators

The array programming language we use is BQN.
The implementation leverages the Under construction, denoted as $circle.nested$.
Under is a combinator that takes two functions 𝔽 and 𝔾, alongside parameters 𝕩 to 𝔾 and an optional parameter 𝕨 to 𝔽.
As BQN is read from right to left, the usage looks as follows: 𝕨 𝔽 $circle.nested$ 𝔾 𝕩.

Under comes in two forms, _computational_ and _structural_.
The structural Under is dual to a lens: the 𝔾 applies a _view_ to the given rank polymorphic 𝕩 such that the function defined in 𝔽 is applied _under_ the transformation.
Once 𝔽 returns, the _inverse_ of 𝔾 is applied to the return value.
This gives a fundamental building block to stream polymorphic array structures into some function, such that the original structure of the array is preserved.
The computational version can be seen as a generative function up to a bound, as shown later.
When the data is always kept in the same one-dimensional format, writing our generative functions over this shape becomes easier.

The details for Under and BQN are better covered in our other term paper, and as such, the following sections make little effort to reiterate these details.

= Tutorial of GPU semantics on SPIR-V

#let sampo = symbol(
  "⌘",
)

#let cube = rotate(
  180deg,
  [$angle.spatial$]
)

#let wg = sym.angle.right.rev

#let sg = rotate(
  90deg,
  [$angle.right$]
)

#let opphi = symbol(
  "⩕"
)

GPU programming is done with _host_ and _device_ code.
Host code runs on the CPU which calls a GPU API such as Vulkan via system calls (_syscalls_).
Device code runs on the GPU as an intermediate language like SPIR-V.
A GPU _program_ is a composition of host and device code.
The most common pattern involves memory initiation on the host, followed by the compute part on the device, and then host code that transfers memory back to the CPU.

In the following sections, we introduce a GPU language extension to BQN.
The motivation is a homage to @AFormalDescriFalkof1964 in which APL was used to describe the modular IBM System/360 as a form of hardware abstraction layer.

Our approach introduces new notation to BQN.
The notation models Vulkan host operations on the CPU and SPIR-V device operations on the GPU.
The notation is divided into upcoming sections and categorized as follows:

#figure(
table(
  columns: 5,
  table.header(
  [], [ *op* ], [ *side* ], [ *reference* ], [ *arities* ],
  ),
  [Device], [ $sampo$ ], [ host ], [ @device ], [ 0, 1 ],
  [Queue family], [ $parallel.circle$ ], [host], [ @qf ], [ 0, 1, 2],
  [Queue], [ ∿ ], [ host], [@q], [ 1, 2],
  [Buffer create], [ ↤ ], [host], [ @maps ], [ 2 ],
  [Buffer in], [ ⥢ ], [ host], [ @harpoon ], [ 2 ],
  [Buffer out], [ ⥤ ], [ host], [ @harpoon ], [ 2],
  [GPU fence], [ ⥽ ], [ host ], [ @tail ], [ 1],
  [CPU fence], [ ⥼ ], [ host ], [ @tail ] , [ 1 ],
  [Decoration], [ $lozenge$ ], [device], [ @deco], [ 1 ],
  [Push constant], [ ≜ ], [ host], [ @push], [ 1 ],
  [Divergence], [ ∇], [ device], [ @exec ], [ 2],
  [SSA Phi], [ #opphi], [device], [@exec], [0],
  [Thread grid], [ $cube$], [both], [ @cube], [ 0, 1],
  [Workgroup], [ $wg$], [both], [ @mat], [0],
  [Subgroup], [ $sg$], [both], [@vec], [0, 1, 2],
  [Invocation], [ $square$], [device], [@scalar], [0],
),
caption: [ Extra notation introduced to BQN. ],
) <notation>

Throughout the sections, we define semantics that use a form of typing convention from bqncrate#footnote[https://mlochbaum.github.io/bqncrate/].
This approach distinguishes the ranks of arrays (unit, list, and tab) and expected element types as follows:

#figure(
table(
  columns: 2,
  rows: 4,
  table.header(
    [ *symbol* ],[ *type* ],
  ),
    [ `x,y,z`],[ any],
  [ `m,n`], [ num ],
  [ `i,j,k`], [ int ],
  [ `a,b` ], [ bool],
  [ `c,d` ], [ char],
  [ `f,g,h`], [ fn],
  [ `0`], [unit],
  [ `1`], [list],
  [`2`], [tab],
),
 caption: [Typing convention used by bqncrate.],
) <typing>

For example, a vector of booleans is denoted as `a1`.
We also use the convention in our code examples. The examples also follow the convention set by APL for separating input and output: the input code is indented, and the output is not.
A visual cue via #highlight([highlighting]) separates the host and #highlight[device] code.

== Device <device>
A _device_ represents hardware and software-implemented accelerators that run #highlight([device]) code.
Devices are accessed with a two-case host operation $sampo$:

/ Niladic (host): { $sampo$ } : `i1`

Niladic case uses a syscall to return the indices of all devices available on the host.

/ Monadic (host): { $sampo$ `i1` } $equiv$ { `i1` ⊏ $sampo$ } : `j1`

Monadic case provides a convenience function that first uses a syscall to return the indices of all devices, followed by a select function ⊏ provided by BQN that picks indices `i1` retrieved from the niladic case.

/ Example:

Suppose we have a computer with two devices.
Now:

#grid(
  columns: (3em, 1fr),
  [], [$sampo$ ],
  [ ⟨ 0 1 ⟩ ], [],
)

#grid(
  columns: (3em, 1fr),
  [], [ $sampo$ ⟨ 1 ⟩ ],
  [ ⟨ 1 ⟩ ], [],
)

#grid(
  columns: (3em, 1fr),
  [], [ $sampo$ ⟨ 2 ⟩ ],
  [ ⟨ ⟩ ], [],
)

The available total memory on each device determines the ordering.
The device with the most memory is listed first.
If two devices have equal memory, the ordering uses an underlying device identifier provided by Vulkan.
If a GPU program does not include a reference to $sampo$, the first device in the list will be automatically used.

== Queue families <qf>
Each device exposes several queue families, each with one or more queues.
Queue families are used for data transfer operations between the device and the host.

A single queue family has a list of _capabilities_ from a Vulkan syscall bitmask function $f : { "graphics", "compute", "transfer"} -> { 2^n | n in NN_0 }$ such that $f("graphics") &= 2^0 = 1$, $f("compute") &= 2^1 = 2$, and $f("transfer") =& 2^2 = 4$.
Queue family with a transfer capability has a lower cost model for data transfer, although every queue family can always do data transfer.
All queues (@q) in a queue family support the same operations.

Queue family operations are denoted with $parallel.circle$, which implements three host cases:

/ Niladic (host): { $parallel.circle$ } $equiv$ { $parallel.circle sampo$ } : `i2`

Niladic case returns queue families of each device.

/ Monadic (host): { $parallel.circle$ `i1` } $equiv$ { $parallel.circle sampo$ `i1` } : `j2`

Monadic case returns queue families of device indices `i1`.

/ Dyadic (host): { `i1` $parallel.circle$ `j1` } : `k1`

Dyadic case is more complicated, but necessarily so to allow further composition.
For each device index `j` in `j1`, $parallel.circle$ selects a queue family with the capability of `i` for each `i1`.
Each selected queue family is used to pick a queue index `k` from that queue family, which is concatenated to a list of queue indices `k1`.
The queue indices `k1` contain the indices of the queue(s) relative to the queues of all devices.
Which `k` is picked depends on an underlying _queue priority_ syscall.

/ Example:

Suppose we have a computer with two devices that have slightly different queue family structures.
This is common when a computer has both discrete and integrated GPUs -- discrete devices tend to have a transfer-only queue family, whereas integrated ones do not#footnote[This is because integrated GPUs often share the RAM with the CPU, so the data is already in-memory hence there is nothing to optimize for data transfers.].
Now:

#grid(
  rows: (auto, auto),
  row-gutter: .5em,
  [ #h(1cm) $parallel.circle$ ],
  [ $angle.l space angle.l 1 space 2 angle.r space angle.l 1 space 2 angle.r space angle.l 4 angle.r space angle.r$ ],
  [ $angle.l space angle.l 1 space 2 angle.r space angle.l 1 space 2 angle.r space angle.l 1 space 2 angle.r space angle.r$ ],
)

#grid(
  rows: (auto, auto),
  row-gutter: .5em,
  [ #h(1cm) $parallel.circle$ [0] ],
  [ $angle.l space angle.l 1 space 2 angle.r space angle.l 1 space 2 angle.r space angle.l 4 angle.r space angle.r$ ],
)

#grid(
  rows: (auto, auto),
  row-gutter: .5em,
  [ #h(1cm) [2, 4] $parallel.circle$ [0]],
  [ $angle.l space 8 space 18 space angle.r$],
)

After seeing the monadic case example in @q, the final example is easier to understand.

== Queue <q>

To reiterate, a queue is a child of a queue family.
A queue family's only function is to describe what can be done with its children.
A queue is an abstraction that implements data transfer functions to the device and acts as a worker unit as a part of a form of thread pool.
An analogy could be that a queue family is a network interface that may have many ports -- a queue is a single port in that interface.
The queue operator is denoted with ∿ and is a two-case host operation:

/ Monadic (host): { ∿ `i1` } : `j2`

Monadic case returns queues of device indices `i1` in a table `j2`.

/ Dyadic (host): { `x1` ∿ `i1` } : `j1`

Dyadic case uses queue indices `i1` and data `x1` to schedule a memory transfer between the host and the device.
It returns a list `j1` alternating between queue indices `i1` with `x1`.

/ Example:

Suppose we have a device which returns the following for queue families:

#grid(
  rows: (auto, auto),
  row-gutter: .5em,
  [ #h(1cm) $parallel.circle$ [0] ],
  [ $angle.l space angle.l 1 space 2 angle.r space angle.l 1 space 2 angle.r space angle.l 4 angle.r space angle.r$ ],
)

Now, a sensible return for queue operations might be:

#grid(
  rows: (auto, auto),
  row-gutter: .5em,
  [ #h(1cm) ∿ [0] ],
  [ ⟨ ⟨ 0 1 2 3 4 5 6 7 8 ⟩ ⟨ 9 10 11 12 13 14 15 16 17 ⟩ ⟨ 18 ⟩ ⟩],
)

#grid(
  rows: (auto, auto),
  row-gutter: .5em,
  [ #h(1cm) ↕4 ∿ [0, 18]],
  [ ⟨ 0 ⟨ 0 1 2 3 ⟩ 18 ⟨ 0 1 2 3 ⟩ ⟩],
)

The first example shows how the first two queue families with capabilities graphics and compute each has 8 queues, while the transfer queue family only has a single queue.

The second example shows how a data transfer pipeline is being created by the dyadic queue operation using queues with index 0 and 18 (the first queue of the compute queue family and the only transfer queue of the transfer queue family).
The ↕4 is iota (or _range_, as it is called in BQN) which in BQN starts from 0.

The queue on the left-hand side (in this case, 0) is called a termination queue because it is the last queue that is used.
That is, the queue transfers happen by reading the composition from right to left.

== Buffer initation <maps>

The previous sections only described the required operations to queue memory transfers between the host and device.
We first need semantics to do static memory allocations on the host to transfer data that can be mapped between the two.
We call this memory allocation a _buffer_ initiation to suggest the transferable nature of the memory mapping between the host and the device.
The buffer initiation is denoted as a dyadic host operation ↤.

/ Dyadic: { `name` ↤ `m1` } : syscall

/ Example:

#grid(
  rows: (auto, auto),
  row-gutter: .5em,
  [ #h(1cm) i ↤ ↕16],
)

The return value is not displayed for being a syscall pointer.
The pointer would have data of iota 16 allocated on the host.
Creating this pointer is a precondition for moving a mappable buffer onto the device.

== Buffer transfers <harpoon>

Device memory allocation happens by moving a host buffer to the device.
We denote moving the data _in_ with a left-harpoon ⥢ and moving the data _out_ with a right harpoon ⥤.
These operations happen on the host side, compared to ← those that run on the device.

/ Dyadic: { `name` ⥢ `i1` } : syscall

/ Dyadic: { `name` ⥤ `i1` } : syscall

/ Example:

Suppose the queue with index 0 is from a compute queue family and the queue with index 1 is some queue _capable_ of transfer capability.

#grid(
  rows: (auto, auto),
  row-gutter: .5em,
  [ #h(1cm) i ↤ ↕2],
  [ #h(1cm) j ⥢ [0 i]],
  [ #h(1cm) j ⥤ [1 i]],
)

The first line allocates iota 2 on the CPU.
The second line moves these values over the queue with index 0 to the GPU.
The third line moves the data back from the GPU to the CPU, using the queue with index 1.

The termination queue in the inwards direction ⥢ must always be from a queue family with a compute capability.
The termination queue in the outward direction ⥤ may be any queue because all queue families must support at least transfer capability.

Further, because the memory allocation of i and j are related, j cannot return more values than what i allocated.

/ Example:

Suppose the queue index 0 is a high-cost queue from a compute queue family and the queue index 1 is a low-cost queue from a transfer queue family.
We can optimize the memory transfer as follows:

#grid(
  rows: (auto, auto),
  row-gutter: .5em,
  [ #h(1cm) i ↤ ↕2],
  [ #h(1cm) j ⥢ [0 i, 1 i]],
  [ #h(1cm) j ⥤ [1 i]],
)

This creates a memory transfer pipeline which has a lower cost model than the the previous example, despite the pipeline having more commands.
The reasoning is a combination of details in the Vulkan specification, but courtesy of our own empirical findings:

/ Vulkan implementation detail: Mixing different queue families requires buffers to be created with "shared mode" with `VkBufferCreateInfo` #footnote[https://www.khronos.org/registry/vulkan/specs/1.3-extensions/man/html/VkBufferCreateInfo.html]. This means that memory transfer operations that correspond to updates of _descriptor set bindings_ #footnote[https://www.khronos.org/registry/vulkan/specs/1.3-extensions/man/html/vkUpdateDescriptorSets.html] are done with a low-cost transfer queue family, whereas the _dispatch operation_ #footnote[https://www.khronos.org/registry/vulkan/specs/1.3-extensions/man/html/vkCmdDispatch.html] is done by high-cost compute queue family.

In the previous examples, no #highlight([device]) computation has happened yet.
For that, we need a construct called a _fence_.

== Fences <tail>

Fences synchronize memory by using a syscall that raises a flag when the host or device program terminates.
Fences are different from execution and memory barriers, which synchronize memory only on the device without communication with the host.
Assume for now that execution and memory barriers are automatically created while fences are not.

There must exist two fences per GPU program: one when a device program ends to synchronize its end status with the host and one on the host to signify the end of (all #footnote[@push shows usage program that runs on multiple devices]) memory copies.

We denote fences with fish tails ⥽ and ⥼.
The informal idea is that at least one harpoon must eventually catch a fish tail.
Fish tails are monadic functions, but their operational semantics are slightly different.
The fish tails are similar to BQN's Out command in the sense that both write a value from a program to an I/O interface.

/ Monadic (host): { ⥽ `i1` } : syscall

The right fish tail ⥽ waits for a device program to terminate.
For a productive GPU program, there must exist a left harpoon { 𝕨#sub(size: 1em, [i]) ⥢ 𝕩 } where i is the user-defined name of the buffer, such that there exists a corresponding right fish tail { ⥽ 𝕨#sub(size: 1em, [j]) } where j either equals i, or#footnote[TODO: Eventually section 4 would cover how Under would instead be used] is a device variable k which is at some point derived from i.

/ Monadic (host): { ⥼ `i1` } : x1

Denotationally the same as above, but operationally the left fish tail ⥼ waits for a data copy to finish on _all_ devices that are scheduled.
This is the marshaling step of moving the buffers from a device to a readable format on the host.
The existance of this fence is important when a same program is launched on two different devices, which might complete at different times.
It returns the result from the GPU program.

/ Example:

#grid(
  rows: (auto, auto),
  row-gutter: .5em,

[#h(1cm) i ↤ [21]],

[#h(1cm) j1 ⥢ [0 i]],

[#h(1cm) j2 ⥢ [0 i] ],

[#h(1cm) #highlight([k ← j1 + j2]) ],

[#h(1cm) ⥽ k],

[#h(1cm) k ⥤ [0 i]],

[#h(1cm) ⥼ i],

[ ⟨ 42 ⟩]

)

== Decorations <deco>

As denoted by the semantics in @harpoon, memory is always a vector type.
To support partitioning using device code, a _view_ may be constructed with _decorations_ #footnote[https://registry.khronos.org/SPIR-V/specs/unified1/SPIRV.html#decoration].
Decorations are created with a lozenge $lozenge$.
The operation takes function parameters _stride_ and _offset_ alongside data `i1`.
Setting _stride_ to $1$ maps memory to be read continuously by active invocations.
Setting _offset_ to a non-zero value $n$ allows skipping $n$ values from the buffer's start.

/ Dyadic (device): { `f` $lozenge$ `g` `i1` } : `x`

Stride is fixed to `f` and offset to `g`, which then controls how values in `i1` are read.
Like in BQN, the functions `f` and `g` can be constant values, which the language will implicitly lift to constant functions.
When using constant values, it is suggested that the values be enclosed in brackets to avoid user errors arising from tacit code.
If tacit code is used, BQN's constant operation  ̇ (small uptick dot) should be used.

/ Example:

#grid(
  rows: (auto, auto),
  row-gutter: .5em,


[#h(1cm)  i ↤ [0 1] ],

[#h(1cm)  j ⥢ [0 i] ],

[#h(1cm)  #highlight([ k ← 4 + {1} ◊ {1} j ]) ],

[#h(1cm)  ⥽ k ],

[#h(1cm) k ⥤ [0 i] ],

[#h(1cm) ⥼ i ],

[ ⟨ 0 5 ⟩],
)

Here, the definition of k skips one value before adding a 4 to the position where the reading starts.
We will see more useful examples of $lozenge$ in @push and @exec, which use multiple devices and threads.

== Push Constants <push>

Push Constants pass host-side variables to device programs without recompiling the device code -- push constants work as "holes" in the device code which get filled at runtime.
Push Constants are useful for heterogeneous environments, where accelerators might have varying physical properties, such as SIMD lane widths (see: @vec), because these variables can be passed to device code.

Push Constants are denoted with equal-triangle ≜ and exist as a dyadic host-side code:

/ Dyadic (host): { `name` ≜ `x` } : syscall

Dyadic case is uses a syscall to tie a variable to the device program source code.
It is the only host-side command that affects the compilation of the device code.
The variable is left as a program hole that gets filled at runtime.

/ Example:

The following GPU program creates a consensus object from two devices by racing them to write to x.
That is, there is a purposefully made data-race on the middle element of the input array x to see which device was first: the one whose index appears _the least_ number of times "wins".
The program is classified as _anonymous consensus algorithm_ because it does not explicitly set identities of the devices that run it.
The program is also _symmetric_ because the program compiles to the same code and each thread runs the same set of instructions (we will see the opposite case of _divergence_ in @exec).
The symmetry is made possible by a Push Constant called id.
The value of id is bound to the current GPU index that will be either 0 or 1.
In other words, Push Constants can be considered a keyword for "this" scope.

Assume we have two GPUs on indices [0, 1] and both have a transfer- and compute queue family, and sys.GPU is a host-side variable which gets passed to the GPU program on queue creation.
Now:

#grid(
  rows: (auto, auto),
  row-gutter: .5em,

[#h(1cm) i ↤ ↕3],

[#h(1cm) j ⥢ i ∿ [2, 4] #sym.parallel.circle ⌘ [0, 1] ],

[#h(1cm) id ≜ sys.GPU ],

[#h(1cm) #highlight([ j[id, id+1] = sys.GPU ]) ],

[#h(1cm) ⥽ j ],

[#h(1cm) j ⥤ i ∿ [4] #sym.parallel.circle ⌘ [0, 1] ],

[#h(1cm) ⥼ i ],

[ ⟨ 0 0 1 ⟩ OR ⟨ 0 1 1 ⟩ ]
)

First, we note how this example now does not use fixed queue indices to copy values.
Instead, the operations introduced in previous sections are composed together to create a dynamic program schedule.

We say OR in the output, because it is non-deterministic: it might return either option depending on the moment's runtime factors.

An application of symmetric anonymous consensus objects is locks.
This one is a particularly expensive one, but it is nonetheless a lock.
It also has a bug, but to fix it we must be able to do atomic group operations first.
We learn about atomic group operations with _subgroups_ in @vec.

== Execution model <exec>

@deco defined the ◊ operation to mutate how we view data on the device.
The operation also takes in function parameters, but the examples insofar have only used constants.
This section provides device code operations for dynamic control of different hierarchies of views.
Related work presents this hierarchy in the context of Nvidia GPUs @FireironHagedo2020, but we use the terminology from SPIR-V.
In SPIR-V terminology, the hierarchies are:

0. invocation
1. subgroup
2. workgroup
3. thread grid

The indices are significant: invocation is like a scalar set of threads, subgroups are vectors, workgroups are matrices, and thread grids are cubes.

Together, these hierarchies form a projector:

#let projector = grid(
  columns: 4,
  [subgroup], [], [], [thread grid],
  [], [ #rotate(90deg, [$angle.right$]) ], [#rotate(180deg, [$angle.spatial$]) ], [],
  [], [ $square$ ], [ $angle.right.rev$ ], [],
  [ invocation ], [], [], [ workgroup],
)

#figure(projector,
caption: [ Invocations are projections. ],
) <figprojector>

Here, the thread grid $cube$ instantiates the length of the dimensions in $x, y, z$ directions.
Then, workgroup $wg$ reads the dimensions horizontally.
Subgroup $sg$ reads the dimensions vertically.
Invocations $square$ is a single thread that is projected using different accessors.

An important use of these accessors is _thread divergence_.
Thread divergence is the opposite of a symmetric program: a symmetric program runs the same instructions on every thread, but a divergent function does not.
Divergence is important in divide-and-conquer algorithms.
In the context of GPU programs, dividing means partitioning threads using a $lozenge$ and conquer means diverging on some subset of threads to move memory.
Examples will follow in subsequent sections.
What suffices now is that we denote thread divergence with a nabla ∇, which is a dyadic.

/ Dyadic (device): { `f` ∇ `g` }

Dyadic case runs `g` which must return a boolean unit.
If the result of `g` is 0, it returns.
If the result of `g` is 1, it runs `f`.
∇ can be seen as a case of the 2-modifier Choose#footnote[https://mlochbaum.github.io/BQN/doc/choose.html] in BQN.

/ Example:

Suppose we have a single GPU with a device index 0.
The following GPU program checks if the index equals to 1, and if so, it multiplies the vector with 10.

#grid(
  rows: (auto, auto),
  row-gutter: .5em,

[#h(1cm) i ↤ ↕4],

[#h(1cm) j ⥢ [0, i]],

[#h(1cm) id ≜ sys.GPU ],

[#h(1cm) #highlight([ { j × 10 } ∇ { 1=id } ]) ],

[#h(1cm) j ⥤ [0, i]  ],

[#h(1cm) ⥼ i ],

[ ⟨ 0 1 2 3  ⟩ ]
)

The result is unchanged from the static allocation because the `g` function to ∇ failed.

Any ∇ expression can optionally be followed on the next line by operation denoted as $opphi$, which is the SSA Phi function (ϕ is already taken by BQN).
$opphi$ returns the value of `g` of the preceding ∇ expression.
In other words, the value of $opphi$ thus corresponds to the "route" that the divergence took.
It also explicitly marks where the divergence ends.

/ Niladic: { $opphi$ } : `a0`

/ Example:

Suppose we have a single GPU with device index 0.
Let buffer `i` be [ 0 ].
The GPU program then checks if the index of the device is 0, and if so, runs an empty function.
Then, #opphi is used to check if the empty function was run and the boolean result is fixed to `k`.
The boolean value `k` is then summed to `j`, which is returned.

#grid(
  rows: (auto, auto),
  row-gutter: .5em,

[#h(1cm) i ↤ [0] ],

[#h(1cm) j ⥢ [0, i]],

[#h(1cm) id ≜ sys.GPU ],

[#h(1cm) #highlight([ { } ∇ { 0=id } ]) ],

[#h(1cm) #highlight([ k ← #opphi ]) ],

[#h(1cm) #highlight([ j + k ]) ],

[#h(1cm) j ⥤ [0, i]  ],

[#h(1cm) ⥼ i ],

[ ⟨ 1  ⟩ ]
)

GPU program returns 1 because it ran the empty function.

=== Thread grid <cube>
Thread grid is a two-case operation that can be called both from host and device code.
On the host, it is a monadic operation that creates a set of threads in $x,y,z$ dimensions that are passed onto the device code as a syscall.
On the device, it is a niladic operation that returns the current $cube$ dimensions as a three-valued vector of that thread. The created set of threads can be modeled in BQN using the range command ↕:

/ Abstract model:

#grid(
  rows: (auto, auto),
  row-gutter: .5em,
  [ #h(1cm) `↕ 2‿2‿1`],
  [
```┌─
╎ ⟨ 0 0 0 ⟩
  ⟨ 0 1 0 ⟩

  ⟨ 1 0 0 ⟩
  ⟨ 1 1 0 ⟩
            ┘
```
          ],
)

The abstract model returns an iota _index list_.

/ Monadic (host): { $cube$ `i1` } : syscall

The monadic host case prepares `vkCmdDispatch`#footnote[https://registry.khronos.org/vulkan/specs/1.3-extensions/man/html/vkCmdDispatch.html] call with the given $x,y,z$ arguments picked from `i1`.
`i1` must have three non-zero integer elements.
If a GPU program does not have a host-side $cube$ call, it defaults to ⟨ 1 1 1 ⟩.
Every GPU program must call this syscall either implicitly or explicitly.

/ Niladic (device): { $cube$ } : `i0`

The niladic device case returns a three-valued variable with the grid dimensions of the active thread.
See the abstract model above for the values which would be returned when $cube$ is set to [ 2 2 1 ] on the host-side.

/ Example:

The following example is a contrived way to count the total number of invocations created by some `i1` given to the host-side $cube$ dimensions:

#grid(
  rows: (auto, auto),
  row-gutter: .5em,

[#h(1cm) $cube$ 2 2 1],

[#h(1cm) i ↤ [0, 0, 0] ],

[#h(1cm) j ⥢ [0, i] ],

[#h(1cm) k $arrow.l$ $cube$ ],

[#h(1cm) #highlight([ j + k ]) ],

[#h(1cm) ⥽ j ],

[#h(1cm) j ⥤ [0, i] ],

[#h(1cm) ⥼ i ],

[ ⟨ 2 2 0 ⟩ ]
)

Sum-reducing the result gives us 4, which corresponds to the number of lines shown in the abstract model.

=== Workgroup <mat>
A workgroup partitions a set of threads in the "vertical direction".
Workgroup is denoted with $wg$ to suggest that it counts threads "down to a floor".
It is a two-case operation that on the host returns the length of a _local_ workgroup.
On the device, it returns the threads current local workgroup.

When two invocations are located within the same workgroup, they are said to belong to a _local_ workgroup.
The set of disjoint workgroups is called the global workgroup.
The global workgroup partitions the multiply-scan result of the $cube$ parameters into chunks of $wg$ length.

/ Niladic (host): { $wg$ } : `i0`

Niladic case runs a `syscall` on the host and returns an integer specifying the maximum compute workgroup size, which is often 1024#footnote[https://vulkan.gpuinfo.org/displaydevicelimit.php?name=maxComputeWorkGroupSize[0]&platform=all].

/ Niladic (device): { $wg$ } : `i0`

Monadic case returns the workgroup identifier of the active thread.
An individual thread can use it to determine which workgroup it belongs to.
The identifier can be used, e.g., with folds that contain elements more than the maximum size of the local workgroup.

/ Example:

Suppose we instantiate a cube with 1024 threads in the $x$ direction, and our local workgroup max size is also 1024.

#grid(
  rows: (auto, auto),
  row-gutter: .5em,

[#h(1cm) $cube$ 1024 1 1],

[#h(1cm) i ↤ [0] ],

[#h(1cm) j ⥢ [0, i] ],

[#h(1cm) #highlight([ j + $wg$ ]) ],

[#h(1cm) ⥽ j ],

[#h(1cm) j ⥤ [0, i] ],

[#h(1cm) ⥼ i ],

[ ⟨ 0 ⟩ ]
)

The device code adds the $wg$ value to j, but because all threads belong to the same local workgroup of 0, the return value is also 0.

=== Subgroup <vec>
A subgroup partitions threads in the "horizontal direction".
Subgroup is denoted with $sg$ to suggest that it counts threads in the "up to a boundary on the left".
It is a niladic operation that on the host returns the length of a _local_ subgroup.
On the device, it returns subgroup indices of the active thread.

Subgroups are a special kind of thread partitions which allow a set of _non-uniform group operations_ to be performed.
These operations correspond to the notion of single-instruction, multi-data (SIMD) instructions that exist on modern computer architectures.

The indexing that of subgroups can be modeled in BQN using Cartesian product (`≍` for enclose, `⌜` for table -- i.e., in this case, return a 4x4 matrix with tuples of iota 4) by using the range ↕ command.
Suppose we want to model how a dataset of 16 elements (4x4 gets us 16 distinct pairs) gets split across subgroups:

/ Abstract model:

```
(↕4) ≍⌜ ↕4
┌─
╵ ⟨ 0 0 ⟩ ⟨ 0 1 ⟩ ⟨ 0 2 ⟩ ⟨ 0 3 ⟩
  ⟨ 1 0 ⟩ ⟨ 1 1 ⟩ ⟨ 1 2 ⟩ ⟨ 1 3 ⟩
  ⟨ 2 0 ⟩ ⟨ 2 1 ⟩ ⟨ 2 2 ⟩ ⟨ 2 3 ⟩
  ⟨ 3 0 ⟩ ⟨ 3 1 ⟩ ⟨ 3 2 ⟩ ⟨ 3 3 ⟩
                                  ┘
```

Each row signifies a different subgroup, where each tuple in a cell shows the subgroup identity, followed by the local subgroup index.


/ Monadic (host): { $sg$ `i1` } : `j1`

Niladic host case uses a syscall to read the devices' physical properties to fetch the subgroup length of that device.
The length of the subgroup tends to be a multiple of two.

/ Niladic (device): {  $sg$ } : `i1`

The niladic device case returns a two-valued vector where the first element is the subgroup identity and the second element is the subgroup local index of the active thread.
See the abstract model above for the values which would be returned when $cube$ is set to e.g. [ 16 1 1 ] on the host-side and subgroup length is 4.

/ Dyadic (device): { `x` `f` $sg$ `i1` } : `x1`

Dyadic case runs the operating `f` with the parameter `x` as an atomic group operation using `i1` as the right-hand variable to `f`. #footnote[Formally specifying which operations are supported for `f` remains for future work.]
It executes in the context of the active thread, which means the dyadic cas should not be called unless it called inside of a function `f` which is passed to a ∇.

/ Example:

In @push, we hinted that the example had a bug.
The bug arises from the fact that the variable assignment in the example is not necessarily atomic.
With subgroups, this can be fixed, as subgroups can be considered a form of MRMW (multi-reader, multi-writer) objects capable of $n$-assignment, where $n$ is the length of the subgroup.
Suppose subgroup length is 2.
Now:

#grid(
  rows: (auto, auto),
  row-gutter: .5em,

[#h(1cm) i ↤ [1,1,1] ],

[#h(1cm) j ⥢ i ∿ [2, 4] #sym.parallel.circle ⌘ [0, 1] ],

[#h(1cm) gpu_id ≜ sys.GPU ],
[#h(1cm) #highlight([ sg_local_index ← 1 ⊑ $sg$ ]) ],
[#h(1cm) #highlight([ f ← { 1 + $sg$ (1◊gpu_id 𝕩) } ]) ],
[#h(1cm) #highlight([ {f j} ∇ {0=sg_local_index} ]) ],

[#h(1cm) ⥽ j ],

[#h(1cm) j ⥤ i ∿ [4] #sym.parallel.circle ⌘ [0, 1] ],

[#h(1cm) ⥼ i ],

[ ⟨ 0 0 1 ⟩ OR ⟨ 0 1 1 ⟩ ]
)

(Note: $sg$ is not highlighted because of some a Typst problem)

The sg_local_index reads the subgroup local index from $sg$ and saves it as a variable.
Then, a function f is created which sums 1 using a SIMD operation while offsetting reads on 𝕩 by gpu_id.
This means that the first GPU reads
The last device code line uses ∇ as a guard to only run the function on the subgroup leader invocation: this means the subgroup which has a local index of 0.
Coincidentally on the last device code line, j is passed to f as an input.



/ Example:

Sum scan 4x4 matrix when assuming subgroup length of 4:

#grid(
  rows: (auto, auto),
  row-gutter: .5em,

[#h(1cm) i ↤ ↕16 ],

[#h(1cm) j ⥢ [0, i] ],

[#h(1cm) #highlight([ f ← { +\` $sg$ (1◊$square$ 𝕩) } ]) ],
[#h(1cm) #highlight([ {f j} ∇ {0=(1 ⊑ $sg$)} ]) ],

[#h(1cm) ⥽ j ],

[#h(1cm) j ⥤ [0, i] ],

[#h(1cm) ⥼ i ],

[ ⟨ 0 1 3 6 4 9 15 22 8 17 27 38 12 25 39 54 ⟩],
)


Like above, we use a group operation via the dyadic $sg$ operation, but function `f` instructs a sum-scan.
Because the subgroup length is four, the active thread where subgroup local index is 0 will act on the all values of the whole subgroup.

=== Invocation <scalar>
An invocation partitions threads to a single element using a global unique thread index.
An invocation is denoted with $square$ to suggest it targets a single invocation within the thread cube (recall: @figprojector).
The idea is that the invocation index is a source of a projection.
The $square$ is a niladic device operation that returns the index of the active thread in the global context.
The generated global invocation identifiers can be modeled in BQN given a parameter of the $cube$ to the following function:

/ Abstract model:

```
GlobalInvocationIDs ← ↕(×´∘≢↕)
GlobalInvocationIDs 2‿2‿1
⟨ 0 1 2 3 ⟩
```

That is, it uses the same approach as the abstract model in @cube, but it now uses the shape `≢` operator followed by multiply-scan to count the elements in the table, which it then uses as a parameter to range.

/ Niladic (device): { $square$ } : `i0`

Niladic case uses a builtin function in SPIR-V which returns the global invocation identifier.

/ Example:

We can reimplement a parallel iota generator using global invocation identifier as follows:

#grid(
  rows: (auto, auto),
  row-gutter: .5em,

[#h(1cm) $cube$ [4, 1, 1] ],

[#h(1cm) i ↤ [0,0,0,0] ],

[#h(1cm) j ⥢ [2, i] ],

[#h(1cm) #highlight([ j[$square$] = $square$  ]) ],

[#h(1cm) ⥽ j ],

[#h(1cm) j ⥤ [2, i] ],

[#h(1cm) ⥼ i ],

[ ⟨ 0 1 2 3 ⟩ ]
)

/ Example:

GPU programs often use $square$ to map memory from the invocation's memory to a memory buffer.

That is, oftentimes operations are done in the context of a subgroup, since those are the only constructs able to do memory sharing, but the result needs to be placed into the buffer using the GlobalInvocationID.

= indeKSI, mapping with combinators

The hierarchical structure of the memory management of GPUs corresponds to a form of recursive pattern similar to divide-and-conquer strategies.
As explained in the previous section, the moving part happens via indices.
Depending on the depth of recursion, the indices may change; from the index of the GPU, to queue family indicies, and then onto workgroups, subgroups, and to individual invocations.
In this section, we show how we can abstract subgroup operations using Under.

What follows is a demonstration of a proof-of-concept code that models the memory hierarchies as documented in SPIR-V.
However, we use a high-level array programming language, BQN, to model it.
Specifically, we focus on the operation of subgroups, as these act as SIMD-esque vector instructions over a set of invocations.
The point we want to display is that this yields a form of _primitive recursion_, corresponding to an _apomorphism_.
The coalgebra of an apomorphism generates a layer of f -structure in each step, but for substructures, it either generates a new seed of type c for corecursion as in anamorphisms or a complete structure of ν f and stops the corecursion there.
The shape of the array creates the termination boundary, and the substructures correspond to either a catamorphic index generation function within a given scope or a catamorphic mapping function.

We will use BQN for the demonstration code.
We note that in BQN, catamorphic and anamorphic structures are both inhibited in the Under construction's two forms: the _computational_ Under which can be made catamorphic, and the lens structure embedded in _structural_ Under which folds a functor over a subset of the initial values.
There is a duality to recursion schemes to be considered: either the lens structure starts with the initial values and reaches a terminal object of a single element, or the index generator starts from a single value and reaches the shape of the input.


== Computational Under as anamorphism

In BQN, the Under operation can generate values up to a bound using a generative function.
A 2-modifier function of this sort looks as follows:

```
{𝔽↕∘⌈⌾(𝔾⁼)}
```

The semantics of this unfolding function is read as follows: run the inverse function of `𝔾` and then use a function `𝔽` to generate values.
Then, the inverse of the inverse `𝔾` is run to yield the result.
It sounds complicated, but in the end, this is just an iota function with combinators controlling how many values and how the value generation happens.
Below are two examples: in the first we only modify the `𝔽`, and in the second we also control `𝔾`.

Suppose we want to generate subgroup indices when our subgroup length is `4`.
We can fix `𝔽 ≡ {4|⊢}` and `𝔾 ≡ ⊢` where `⊢` means the right identity.
When the function is passed an integer value denoting the length of the initial input, such as `16`, what happens is that `𝔾` keeps the value untouched.
Then, the left-hand side of Under first ceils the value (still returning `16`) after which it is composed with iota to generate values `0..=15`.
Onto this array, we then run the function `𝔽`.
Fixing `𝔽 ≡ {4|⊢}` then each value is modulo `4`, printing us `⟨ 0 1 2 3 0 1 2 3 0 1 2 3 0 1 2 3 ⟩`.
If we want to, say choose the last invocation of each subgroup, we can redefine `𝔽 ≡ {3=4|⊢}` to yield a view vector `⟨ 0 0 0 1 0 0 0 1 0 0 0 1 0 0 0 1 ⟩`.
This is dual to the method we used to look at the subgroup views in the previous section but is now retained in a one-dimensional format.

As an aside, if we would instead want only the indices of each of the four values, we can fix `𝔾 {4×⊢}` and `𝔽 {3+⊢}`.
This causes the input value to be divided by `4` first, which yields `0..=3` on the left side of Under.
When the `𝔾` is run in inverse, we get `⟨ 3 7 11 15 ⟩`.
That is, the program code is `{3+⊢} {𝔽↕∘⌈⌾(𝔾⁼)} {4×⊢} 16`.
This is to showcase that by using the Under combinator, the `𝔾` can be used to control the number of elements we want in relation to `𝕩`.

== Structural Under for context

We can run a function in a subgroup context by using structural Under.
Structural Under is a lens structure that uses the function `𝔾` to reformat the data in some way, to which it then runs `𝔽`, then runs the reformat in reverse.
We already saw in the previous section how we could reformat data to be viewed in a subgroup context, but now we add a modifier function `𝔽`, which corresponds to an operation we want to do.
Effectively, this returns the initial shape of `𝕩` while allowing us to run a function `𝔽` on "multiple threads".
This is similar to how in SPIR-V, using subgroup operations yields values into the memory of the subgroup, but this has not yet persisted to a buffer.
Suppose our subgroup length is still four, we can run plus-scan in the context of a subgroup with:

```
{+`} {𝔽˘⌾((≢↑‿4⥊⊢)⥊⊢)} ↕16
```

Which prints us `⟨ 0 1 3 6 4 9 15 22 8 17 27 38 12 25 39 54 ⟩`.
To persist these changes to our input, we need to select the indices of the values that we want to save.
This is where the view vector created by the unfold in the previous subsection becomes handy.
We will cover this in the next subsection.

== Top-to-bottom approach

When thinking of computing by indices, we have several options.
The top-to-bottom approach starts with an initial task that is divided into smaller pieces where an intermediate result is computed.
A top-to-bottom uses an _apomorphic_ structure, which composes catamorphisms with anamorphisms until we arrive at a single value.
The catamorphism happens over the set of active invocations.
The anamorphism is the index generation.
This kind of approach works for reductions.

For example, to sum scan iota 16, we imagine an approach in which we run the scan on the context of a `SubgroupLeader`, then on `Subgroup1`, and finally copy the value out of `GlobalInvocationID` of 3.
After each phase, the question is, what indices should the result be sent, and from what level of memory abstraction does that index come?
Here, we can reuse the lens structure: the lens destructs whatever hierarchy the programmer chooses to use for the catamorphism by reverting back to the initial shape of the program.
The motivation to use a lens to standardize the mapping to work on a single, initially known shape so we can more easily _generate_ indices to which the results should be mapped.
This effectively allows us to operate on, e.g., a subgroup level but map using global invocation identifiers.
Now, the way the identifiers on a different scope are generated boils down to an anamorphism: it takes a seed value, such as the shape of the input, with some statically known constants such as the subgroup length, which it then uses to generate global invocation IDs.

A tacit structural Under `⊣⌾((↕4)⊸⊏)` overwrites values `𝕩` with `𝕨` on indices ↕4, i.e., `0..=3`.
Suppose that code is called `Move`.
An abstracted version of `Move`, which uses the view vector to place the values into the right places, would be `{((𝔽≠𝕩)/𝕩) Move 𝕩}`.
To demonstrate:

```
_Unfold_ ← {𝔽↕∘⌈⌾(𝔾⁼)}
SubgroupLeader ← {3=4|⊢} _Unfold_ {⊢}
Subgroup1 ← { {4> ⊢} _Unfold_ {⊢} 𝕩}
Move ← ⊣⌾((↕4)⊸⊏)
_MoveTo ← {((𝔽≠𝕩)/𝕩) Move 𝕩}
_Run ← {𝔽˘⌾((≢↑‿4⥊⊢)⥊⊢)}
_Phase_ ← {𝔽 _MoveTo 𝔾 _Run}

move0 ← ↕16
phase0 ← SubgroupLeader _Phase_ (+`) move0
move1 ← phase0 Move move0

phase1 ← Subgroup1 _Phase_ (+`) 4↑move1
move2 ← phase1 Move phase0
```

Produces us `⟨ 6 28 66 120 4 9 15 22 8 17 27 38 12 25 39 54 ⟩`.
Here, we have made the previous code into functions in the header.
In `phase0`, we use the subgroup context to run a sum-scan, after which it uses the generative function `SubgroupLeader` to choose values.
Then, `move1` moves the selected values from `SubgroupLeader` into the first four values in our buffer.
Then, we use the first subgroup to run another sum scan in `phase1`.
Then, we move those values into the our buffer in `move2`.
That is, the code runs an operation in a given context, then uses index generation to mark which values we want to move, which it then saves.

== Bottom-to-up approach

However, we also note that an alternative approach exists.
Instead of an apomorphic structure, another alternative is a bottom-up approach, which uses a composition of anamorphisms until a termination bound is reached, after which the list of lists of anamorphisms is fed onto the catamorphic lenses.
This works exactly in the inverse direction and shows the usefulness of index-based thinking.
When the programmer merely decides on what memory locations should be mapped, we can alternatively create a program that starts from a single element and builds up to the shape of the input.
To elaborate, to prefix scan a matrix, we can start from the global invocation register `3`, then build up to `Subgroup1` to expand the indices from a single element to four on range `0..=3`, then use `SubgroupLeader` to select indices `[3, 7, 11, 15]`, and then expand each element to cover the whole subgroup to get `[[0..=3], [4..=7], [8..=11], [12..=15]]`.
At that point, the length of activated invocations equals the input shape, and the anamorphism terminates and feeds the steps onto the catamorphism, where the actual computation happens.
From this representation, it might be clearer that the indices can be computed statically before the GPU kernel is run.
This approach works also for other programs than reductions because the initial return indices do not necessarily have to be a single value.

= Discussion

In the previous section, we showed how subgroup operations can be used to model parallel algorithms using SPIR-V semantics.
Future work should focus on generative functions that compute the indices for workgroups, thread grids, queue families, and the generation of indices with offsets and array strides.
Implementing more generators corresponds to creating more cases in which the computational Under is used.
Here, Under standardizes the index generation to always happen on a flat array, which corresponds to how the SPIR-V specifies memory buffers.
Compared to related work such as @OnMappingNDiJansse2021, which used manual inverse function definitions, our approach leverages BQN's Under to automatically find the solutions.

The point of using the recursive definitions of the functions boils down to the remarks made in previous work such as @MappingParalleMogers2022 @doctoral_thesis_mogers.
Here, an SMT solver to find rewriting rules to optimize an array language to produce GPU kernels.
In these works, the SMT solver finds memory mappings automatically.
The findings show how the solver spends much time finding correct compute kernels.
A more formal structure, especially in the index generation phase in which we use unfold, would give such a solver more post-conditions.
That is, when the solver has more information about the problem, such as starting from an initial value and somehow applying index generators to eventually arrive at using all values at least once, a solver should be able to reduce the number of search paths.
This is useful in the way the GPU firmware works: the SPIR-V specification merely tells what can be done, not what should be done.
As a sort of black box, it is hard to say without empirical evaluation how communication latencies differ when, e.g., copying memory between far-between invocations and, e.g., those directly next to each other.
Such empirical evaluation is not in our interest, but having a system that is easily amendable to experiment with is essential.

Using a more holistic approach, we can consider the GPU firmware as a constraint model.
The informal description we provided in section [] describes the informal constraints mentioned in the Vulkan and SPIR-V specifications.
The one with which we worked the most is the subgroup size, but additional constraints also exist, such as the memory size, which was not considered in this study.
Should we abstract away the subgroup sizes from our methods, we can imagine a system in which we have multiple GPUs, and now either the programmer has to decide which to use or the language could decide for us.

= Conclusion

In this work, we looked into how recursion schemes could be used to abstract memory hierarchies on a GPU.
We used the BQN array programming language with its Under combinator to do catamorphisms with the structural Under and anamorphisms with computational Under.
We provided a proof-of-concept code that models the SPIR-V assembly language for index-based programming.

#bibliography("lib.bib")
