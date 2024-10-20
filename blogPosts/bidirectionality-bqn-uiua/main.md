
Most programming languages run forwards, but what about backwards?
Some natural languages do the same: languages that lack strict word ordering require a larger context to parse the meaning.
I like to joke that in my native tongue Finnish, this is the reason why people do not interrupt each other; there is no set word order in the grammar.
"A quick fox jumps over a lazy dog" can be as easily said as "A quick fox, over a lazy dog, jumps".
We need _patience_: collect words until you hear the verb, and then use agglutination to reorder them in the only way that makes any sense.
That is, you hear words, and then you have to reorder, or go _backwards_ to parse it.
Somewhat surprising fact is that this works even with semantical equivalences between different words: "taju kankaalla kankaalla" means "passed out on a field", where "kankaalla" means "on a field", but "passed out", only when "kankaalla" is surrounded with "taju" on either side.
I have learned that this grammartical structure is very important when doing _real work_ -- it is a grave error to think that people just redundantly repeat themselves; "tuo", which means either "that" or "bring" cojoined with hammer "vasara" could mean either "that hammer" or "bring hammer", but upon hearing "tuo tuo vasara", you would be foolish to not think this means "bring that hammer".
If you instead reply, "Yeah, what about it?" you get looks that could kill, much moreso when you supposedly study languages.

You can imagine my excitement when I learned there are formal languages that also do real work!
And just like with Finnish, you need some patience to get the whole picture.

In CB Jays FIsh language, various benefits of shaped programming are introduced.
The paper outlines how a rank polymorphic language with a functional core could be statically checked, which in turn allows new kinds of program optimizations.
The paper defines three properties for a shaped language:
1. polymorphism
2. static analysis
3. program optimizations

Since the paper was written in 2007, many of the same visions of FIsh have been tackled in adjacent works.
While the development of FIsh itself has stagnated, the ideas live on.

Polymorphism and static analysis have been combined in the static rank polymorphism research topic.
Various works [][][] have modeled static rank polymorphism with dependent types.
In general, existing dependently typed languages such as Idris can used to capture the denotational semantics around operations that require specific array shapes in parameters.
The main benefit is correctness guarantees: composition of array operations uses intermediate program phases to check that an array operation implementations exist for the ranks of given arrays.

Fish is also a proponent of functionality.
New array languages have recently emerged with a more functional core than that of APL.
Of these languages, notable mentions are BQN (2020) and Uiua (2023).
While neither uses dependent types, the languages have made point-free programming with combinators a common and well-regarded approach to array programming.
As such, the work is tangential towards formalization in general.
A good review on the topic is presented in [ref paper Hoekstra].

The directions in performance optimizations of shapely and array programming languages remain much more scattered.
__What has changed__ is that, reflecting on computing in 2007, parallel programming has become the primary way to gain performance given the prevalence of multi-core CPUs and accelerators like GPUs.
Yet, while GPGPU was introduced in a paper from 2008 [], the programming of software utilizing multi-core systems remains challenging to date.
This could be said in large part be caused by most computation environments becoming heterogenic in nature.
This means there now exists computers with widely variable core counts and types (with CPUs; P for "performance" or E for "economy", with GPUs; different queue family capabilities), making compiling a one-fits-all logic into programs complicated.
In addition, the performance bottleneck with computers has become memory latency rather than clock frequency.
The memory has become hierarchical, with low-latency shared memory access requiring SIMD instructions.
The SIMD group operations that read and write to these registers vary between processor models on CPUs.
With GPUs, the SIMD operations work in the context of a subgroup, which could be considered a set of adjacent cores.
Similarly to CPUs, the length of a subgroup varies between GPU models on GPUs.
So, on the one hand, high-performance computing requires low-level memory instructions, but on the other hand, writing code that uses these instructions is, in general, complicated.

__How the changes have been addressed:__
Array programming languages started to take note of GPUs on a bit of lag: Aaron Hsu's co-dfns pioneered and raised awareness of making APL on GPUs a reality.
co-dfns is often considered a feat in the parsing and compilation department, showing how array programming approach can be translated into this new paradigm of GPUs.
Besides APL, various works on exhaustive search-based optimizing compilers, or super optimizers as they are also called, have been developed in the context of array languages.
Mostly centered around constraint solvers, these show how integer solvers can be used to address the lower-level heterogeneity of the hardware by using shape analysis to fit workloads to be assigned to tasks that fit the given compute environment nicely.
Optimizations using shape analysis tend to be written for a specific set of devices, such as for TPUs in Dex and JAX, and machine learning libraries, which require certain programs to be run on specific models (mostly Nvidia) GPUs.
In academic circles, largely distinct but more theoretical work on patterns that yield language semantics better equipped to handle compiler passes on shape analysis has been done in the works of Accelerate and SaC.
Relevantly, SaC showed in [] how the concept of thinking of data mappings bidirectionally creates a denotational framework that yields itself well for practical means to apply compiler passes that fit data onto accelerators.
In the presented state, SaC relies on the programmer doing these fittings manually.
However, one could see such semantics paving the way to a more general-purpose superoptimizing compilers to manage this task.
This leaves a rather niche gap in research: what would be required to promote the task of doing data mappings automatically by a solver over a set of heterogenic accelerators in the context of a functional array programming language?

As such, the following chapters elaborate on a combinator construct called Under that is already built into the newer functional array programming languages as a bridge-builder and addresses the challenges that program optimizers have had in terms of data mappings.
Thus, the thesis is that a language built to use Under to manage memory would have the inherent property required for an automated approach to allow for low-level vector instructions to be used effectively in the context of array programming languages.
Next, we explain what Under is categorically speaking, how it is currently used, and finally, end on a proof-of-concept code in BQN that shows it being used under the semantics of SPIR-V language for GPU compute shaders.
This is all done using the variant of Under called _structural Under_, which is dual to the concept lenses from bidirectional programming.
As a limitation, the approach remains manual, but we give hints along the way how the second variant of Under, called _computational Under_ has a role towards making the process automatic.

# Beyond combinators is bidirectionality

Array programming languages BQN and Uiua focus on tacit programming and combinators.
The languages use combinators differently; BQN to rule application precedence and Uiua to handle the stack.
Despite this difference, the combinators form a shared language to realize functional (or _concatenative_) array programming.

In addition to combinators, the languages have operations that capture mathematical and structural _inverses_.
The inverse functions are implemented as the 1-case _Undo_ and the 2-case _Under_.
The operations are a bit of an oddity: they are not plain combinators like all the others, but discovered (and rather useful!) programming patterns.

The point onwards is to pinpoint their correspondence with a more abstract notion of _bidirectional transformations_.
In general, bidirectional transformations are a topic in programming language research focusing on invertible patterns.
Moreover, invertible patterns are much more common than one might think; in BQN, every variable assignment can be thought of as a structural inverse.
Further, this structural inverse, called structural _Under_, exhibits the concept of a _profunctor_.
We later implement a profunctor in Uiua, and detail how Under implements the same functionality but ergonomically.
This gives us a nice language that runs forwards, and then backwards to parse out the meaning.

The motivation is to contribute an alternative description to Under and raise awareness of array programming languages as a bidirectional transformation tool, especially when considering structural Under as a lens.

## Background

This section briefly reviews BX, focusing on lenses, and then explains how inverse operations came to APL and its descendants.

### Bidirectional Transformations

Luckily, formal languages are much more rigorous about semantics than natural languages.
Programming languages that run backwards are either bidirectional or bijective.
Bijective ones are defined by backwards code that are formed of injective functions.
You could think these of as the "undo" operations when you run them backwards, or more generally multiplayer games where actors take turns "my turn", "your turn".
For example, when I enter the insert mode in vim and write bunch of text, I can undo my actions by pressing the `u` button on normal mode.
Similarly, in a game of life one can "undo" an iteration by inspecting the neighbors of each cell and figuring out what was must have been the rule applied to get into that state.

The group of injective functions is rather limited, so a more lax definition is the bidirectional case.
Bidirectional definitions only apply inverse transformations to the _structure_ of the parameters.
Bidirectional transformations typically take two arguments: an updated output as well as the original input.
It weaves the parameters together, yielding a new input where the information contained in the output has been propagated, and the discarded information from the input has been restored.
Bidirectional programs are typically required to obey "round-tripping" laws, ensuring that each direction's transformation maintains information.
This is exemplified by our 2-case Under, which is used by languages such as BQN to reassign variables; one of the parameters is an existing variable, and the other is the atoms that you would like to be put in its place.

In this sense, bidirectional transformations are proof-bearing; they can be seen as a mechanism for maintaining the consistency of two (or more) related sources of information.
The most obvious pattern of this kind is a lens: a data accessor for the particular subfield of some data structure.
An example is a database view: you join two tables, possibly by selecting only a subset of all fields.
When you update this view, the changes would also propagate back to the original tables.
If so, the view is an input in the outward direction when you update the fields and an output in the forward direction.
If the lens fulfills three laws of `PutGet`, `GetPut`, and `PutPut`,  it is considered _lawful_.
A lawful lens composes, making it a very useful specification (ha! see, category theory is useful!) for your programs dealing with hierarchical structures by making it seem _heterarchical_.
To elaborate, one could imagine a case with database views where you combine datasets from multiple nodes.
The first view (hierarchy 1) joins the table within a single node, and the second view (hierarchy 2) combines the views from each node.
When you update the cojoined view (of hierarchy 2, the view of two tables of two nodes) on some specific row, the diffset would propagate to each node (hierarchy 1, the view of two tables).
Each node would use the diffset to figure out what tables need updating, propagating the information onto concrete tables (hierarchy 0, concrete representation of a table).
The idea is that if getting and putting data is _well-behaved_, the programmer looking at the data on the highest hierarchy does not need to consider the particularities of what happens on lower levels of abstraction.

### Inverse combinators in APLs

A monadic inverse has always existed in APL, but a dyadic one has not.
The following sections cover both in three generations: the 80-year-old 1-modifier Undo and the 40- and 5-year-old 2-modifier variants of Under.
Of these, the 5-year-old _structural_ Under is particularly interesting for bidirectional transformations as it can represent a lawful lens.
The code sections in this section will default to BQN.

#### Undo

The 1-modifier _Undo_ (semantics: `𝕨 𝔽⁼ 𝕩`) was already implemented in the initial version of APL.
It is denoted in BQN with `⁼`, Undo leverages built-in inverse definitions of the constrained set of array functions in the "standard library" of the languages.
As such, Undo applies the mathematical inverse of a function, defined classically as a right inverse such that `𝕩 ≡ 𝕨 𝔽 𝕨 𝔽⁼ 𝕩` (where 𝕨 is an optional parameter).
This shows the relatively constrained nature of Undo: running the function back and forth must yield the right-hand parameter.

The BQN documentation displays a great foot gun about Undo:

```bqn
×˜ ¯3
```

Here, applying negative three to both sides (`˜`) of a multiplication `×` gives us nine, which is an alternative way to describe the power of two.
The example then proceeds to run it backwards:

```bqn
×˜⁼ ×˜ ¯3
```

While the forward application uses multiply, the Undo pass applies a root rather than a division, as one might think from the symbols alone.

#### Under

Under is the big brother of Undo.
It was introduced in SHARP APL (1983) as a 2-modifier inverse operation (`𝔽⌾𝔾` in BQN semantics).
This initial form of Under, now called _computational_ or _mathematical Under_ captures the notion of _conjugacy classes_ from group theory.
It is implemented as a relation such that `𝔾⁼∘𝔽○𝔾` where `○ = {(𝔾𝕨)𝔽𝔾𝕩}`, that is, `x = 𝔾⁼𝔽𝔾` (read right-to-left).
Semantically speaking, in `𝔽⌾𝔾`, the effect _under_ transformation is placed onto the left side of the donut, and the `𝔾` is run back and forth, with the backward direction applying the inverse function.
Under is said to distill a computation or proof by first translating the input domain (first application of `𝔾`), then applying a function `𝔽` under the transformation, and then performing the inverse transformation `𝔾⁼` on the result of `𝔽`.
For the sake of demonstration, consider a naive Ceasar cipher with a positive offset of 7.
The `𝕩` is an already encrypted message, `𝔾` is the transformation to plaintext, `𝔽` joins a plaintext message to the now decrypted message:

```bqn
("abba"∾⊢)⌾(7+⁼⊢) "m"‿"v"‿"y"‿"l"‿"c"‿"l"‿"y"
```

Now, your guilty pleasure of listening to Dancing Queen will remain under disguise.

However, even with the added relation, a computational Under remains a niche operation, arguably even more than Undo.
Anecdotally, one example in which it is handy is the generation of values up to a bound:

```bqn
↕∘⌈⌾((4+3×⊢)⁼) 20
```

In this example, the `𝔾` function is run backwards first, which causes `20` to become `5.33...` on the left side of Under `(20-4)/3` which is first ceiled to `6`, which is passed to `iota` to generate `0..=5`.
Then, each element in the array is multiplied by `3`, and then a `4` is added.
Conceptually, this is interesting because information is, in a sense, created (well, it exists in 20, but six elements look like more information than one).
One application area is programs dealing with corecursion, i.e., programs that recursively generate new values on which some other parts of the program do some computation.

A vastly more common version of Under also exists as _structural_ Under.
Structural Under was presented in BQN (2020), which expanded `𝔾` part of Under to work for a class of structural functions.
With structural Under, `𝔾` becomes _shapely_ [@ProgrammingInJayC1999]: the shape of the result is determined by the shapes of the inputs.
Bidirectional transformations over a shape are much more common than the conjugacy classes of computational Under.
This is largely due to the constraint existing only for `𝔾`: structural Under relaxes `𝔽` to an _update_ or a _set_ function.
The above notion is important for BQN because structural Under is how BQN achieves variable immutability.
This abstraction promotes a rather functional approach to mutation.
The same concept is known as a _lens_ for category theorists and some functional programmers.
For demonstration, consider the following code which streams values in an arbitrary format in `𝕨` to a structure given with `𝕩`:

```bqn
⟨"ab", "cde", "fg"⟩ ⊣⌾∾ ⟨"---", "----"⟩
```

Despite the slight difference in computational and structural Under, BQN implemented it as a single donut glyph ⊚.
This conjoined implementation has been a topic "~~arg~~discussion" (see: [Structural vs. Mathematical "Under"](https://www.dyalog.com/blog/2023/01/structural-vs-mathematical-under/)).
However, as of the time of writing, the conjoined version has taken hold of other array languages, including Kap, Uiua, and J.
BQN achieved this using a unification principle `(𝔾 𝕨𝔽⌾𝔾𝕩) ≡ 𝕨𝔽○𝔾𝕩`, where ○ is a combinator called _Over_.
Over is defined as `{(Gw)FGx}`, which corresponds to the Bluebird combinator with one argument, and the Ψ-Combinator with two arguments.
The expression is arguably easier to parse letting `z←𝕨𝔽⌾𝔾𝕩` and `v←𝕨𝔽○𝔾𝕩`.
The unification principle then condenses to `v≡𝔾z`.
Here, 𝒗 is well-defined if one accepts the axioms of combinatory logic.
Next, 𝔾 and 𝒛 are used to select the right case of Under:

- Invertible Under: If 𝔾 is uniquely invertible on 𝒗, that is, 𝒗≡𝔾𝒛 has a unique solution for 𝒛, then the result of Under is that solution.
- Structural Under: If 𝔾 is a structural function and 𝒗 is compatible with 𝔾 on 𝕩, then the result is obtained by inserting 𝒗 back into 𝕩.
- Computational Under: If 𝔾 is provably not a structural function, then the result is 𝔾⁼𝒛 if it is defined, where $^=$ is Undo.

The implementation details are [exhaustively documented](https://mlochbaum.github.io/BQN/spec/inferred.html#Under) but are out of the scope of this post.

## Reinventing Under

The last section described the inverse operations of array programming languages.
This section reimplements bidirectionality of structural Under without using structural Under.
Here, the dual pattern we show is a higher-order function construction called a profunctor.
The duality between lenses and profunctors have been previously shown in [].
We will use Uiua for code demonstrations.

### APL: A Profunctor Language

To understand the categorical underpinnings of Under, we start by explaining _contravariance_.

First, consider the following Uiua composition which is _covariant_.
It checks if the length of an array is less than 21:

```uiua
<21 ⧻ ⇡20
```

Covariance is concatenation in "the correct order": `f g h = f (g h)`.
This is even more obvious if we create a redundant macro for it:

```uiua
Comp‼! ← ^!^!^!
Comp‼! <21 ⧻ ⇡20
```

Because the placeholder calls `^!` do not apply any combinators for rearrangement, the application must be covariant.

Contravariance is achieved by flipping composition order at some point.
Uiua macros include a stack modifier _flip_ `^:` which can be used to implement contravariance:

```uiua
# f g flip h = g f h = g (f h)
Contra‼! ← ^!^!^:^!
Contra‼!⧻ (<21) ⇡20
```

Because of rank polymorphism, contracomposition and contramap are the same definition.

Next, consider contravariance of `dimap f g h = g h f`.
The dimap is covariant in what it produces, but contravariant in what it consumes (sometimes, this is known as the "robustness principle").
In Haskell, dimap is used to describe a _projective functor_, i.e., a profunctor.

It turns out that implementing the flow of a profunctor gives us the semantics of Under.
For demonstration, let us implement a dimap in Uiua.
First, consider the following Haskell code (taken from [Understanding profunctors](https://typeclasses.com/profunctors)):

```Haskell
withPhraseAsWords :: Profunctor f
  => f [Word] [Word] -> f Phrase Phrase
withPhraseAsWords = dimap words unwords

capPhrase :: Phrase -> Phrase
capPhrase = withPhraseAsWords (fmap capWord)

takeTwoWords :: Phrase -> Phrase
takeTwoWords = withPhraseAsWords (take 2)
```

Usage:

```
λ> capPhrase "one two three"
"One Two Three"

λ> takeTwoWords "one two three"
"one two"
it :: Phrase
```

To implement a profunctor in Uiua, we need to create a higher-order function `dimap f g h = g h f`.
However, this cannot be implemented using stack combinators.
This is because macros in Uiua are not pure higher order functions.
That is, given the current set of stack modifiers in Uiua, it is not possible to reorder function arguments as required by dimap:

```
.   duplicate   Duplicates the top value of the stack
,   over        Duplicate the second-top value of the stack
:   flip        Swap the top two values of the stack
◌   pop         Discard the top value of the stack
∘   identity    Do nothing with one value
```

When Uiua runs into the macro placeholder `^`, where the next token is either a stack modifier like flip `:` or a function call `!`, the argument gets evaluated.
In other words, postponing evaluation is impossible with stack modifiers.

However, a language feature called array macros puts the parameters in an array, which can be manipulated arbitrarily using regular Uiua code.
This works as a form of composition preprocessing: the expression first mangles with the arguments as an array somehow, after which the expressions are evaluated from right to left.
This is a compelling way to control function application, as dimap can be defined as `rotate 1` over three arguments: `rotate 1 [f g h] = [g h f]`.

The functions in the resulting array do not need separate deconstruction for the application to commence.
As such, we can now implement the Haskell code above as such:

```uiua
# Words : String => Boxed Array
Words ← ⊜□ ≠@ .
# Unwords : Boxed Array => String
Unwords ← /◇(⊂⊂:@ )
# CapBox : Boxed Array => Boxed Array
CapBox ← ⍚(⊂⌵⊃↙↘1)

# f g h = g h f
Dimap‼! ←^ ↻1

WithPhraseAsWord! ← Dimap‼!Words Unwords ^!
CapPhrase ← WithPhraseAsWord!(CapBox)
TakeTwoWords ← WithPhraseAsWord!(↙2)

CapPhrase "foo bar bizz"
TakeTwoWords "foo bar bizz"
```

Printing us:

```
"Foo Bar Bizz"
"foo bar"
```

The `Words` and `Unwords` functions show how the type conversions from strings to a _boxed array_ show the similarity with the categorical projection.
These are used in the `WithPhraseAsWord!` macro, which takes in an additional "trailing" function which acts on the type "in the middle" of the conversions.
The trailing function argument 𝒉, which acts on boxed arrays, acts _under_ the bidirectional transformation functions 𝒇 and 𝒈.
With our knowledge of the semantics of structural Under `𝔽⊚𝔾`, we can see that the trailing function is the `𝔽` and the fixed function arguments correspond to the `𝔾` in its forward and backwards application.

The `Words` and `Unwords` required have a lot of information in them which Under can abstract.
Consider the following functionally equivalent code for `CapPhrase`:

```uiua
⍜⊜⊢⌵⊸≠@  "here are some words"
```

Printing us `"Here Are Some Words"`.

## Discussion: Seeing through lenses

The examples above and the connectivity to profunctors might sound abstract.
But lenses are frequent once you know what to look for.

One of such finding is to see memory partitioning as a lens.
Consider we have 10GB blob of memory on a GPU.
To get most of the performance out of this blob, we need to map it into small regions of threads where the SIMD group operations can be used.
However, whenever we model this memory hierarchy, we always need a backwards propagation in our application code because the operations are shapely.
In other words, as the shape controls the memory partitioning, and the shape changes between operations, then the same partitioning logic cannot be assumed for each operation.
Instead, what we can do is to destruct the partitioning after each operation, such that we always restart from a one-dimensional representation of memory.
An operation like Under abstracts away this bidirectional transformation allowing the programmer to focus mainly on compute operation at hand.
Consider the following which uses the semantics of SPIR-V to do a sum scan in a contrived way:
We can thus start modeling parallel language semantics like SPIR-V in the same sense that APL was modeling IBM/360 semantics, but now with a twist that uses the bidirectional approach from [].

```bqn
# GPU SIMD modeling

# Generates subgroup local indices, 𝔽 can be used to filter certain IDs, 𝔾 to create a stepping function
# note: Computational Under which generates these up to a bound of 𝕩
_Subgroup_ ← {𝔽↕∘⌈⌾(𝔾⁼)}
# Runs function 𝔽 in the scope of given subgroup context
# note: Structural Under, where 𝕩 is the source and 𝔽 is the view
_Run ← {𝔽˘⌾((≢↑‿4⥊⊢)⥊⊢)}
# Uses 𝕨 to overwrite values, akin to load and store
# note: Structural Under, where 𝕩 are the targets and 𝕨 are the values which are written
Move ← ⊣⌾((↕4)⊸⊏)
# MoveTo is abstracted Move, where 𝔽 is an invocation selector (see below) to which values are written
_MoveTo ← {((𝔽≠𝕩)/𝕩) Move 𝕩}
# Subgroup selector which selects the last element of each subgroup
# note: the subgroup leader is often the first subgroup
SubgroupLeader ← {3=(4|⊢ _Subgroup_ ⊢ 𝕩)}
# Subgroup selector which selects the first subgroup using global invocation ID
Subgroup1 ← {4> ⊢ _Subgroup_ ⊢ 𝕩}
# Runs operation 𝔾 on 𝕩 and moves values to locations 𝔽
_Phase_ ← {𝔽 _MoveTo 𝔾 _Run}
# Uses shape to choose which subgroup operation should be used
_Foo ← {(1>˜(⊑∘≢∘‿4⥊⊢))◶⟨Subgroup1 _Phase_ 𝕗, SubgroupLeader _Phase_ 𝕗⟩ 𝕩}

input ← ↕16
# Runs fold on each subgroup and moves the last value to the first subgroup
•Show a ← (+`) _Foo input
# Writes to registers
•Show a Move input
# Runs fold on the first subgroup
•Show b ← (+`) _Foo 4↑a
# Moves b's to the start of a
•Show res ← b Move a

# More verbose version of above
cpu ← ↕16
mat ← SubgroupLeader _Phase_ (+`) cpu
mat Move cpu
vec ← Subgroup1 _Phase_ (+`) 4↑mat
res2 ← vec Move mat

res ≡ res2
```

The ability to query driver constraints becomes interesting in memory management when the driver capabilities is considered as a source to a GPU program also known as a compute shader or kernel.
When one of the compute shader inputs is a subgroup length, we can start considering a general solution for letting such a thing be a variable.

One of the examples is HTML templating, showcased in my previous blog post.
We go to great lengths to eventually arrive at a single Under operation that ties together all the pieces.
The barbell package uses a set of files ending in .bar as the sources of a lens, which get composed in a parent file such as this HTML file.
The HTML file becomes a lens that composes a set of source files into a single unified view.
Coincidentally, the output is then readable -- just run the command in the footer to reproduce this web page!

Another relevant topic in the context of working with heterogenic hardware is operating system configurations.
A Red Hat project called Augeas was the first to note this connectivity with lenses.
Linux configuration mostly depends on various text file formats put into the right location on a filesystem or a disk image.
So, just like HTML templating, which took a set of `.bar` files to produce an HTML page, Augeas uses a higher-level source language that compiles multiple text file formats, putting them in the right place on the filesystem.
Augeas uses the Boomerang language to work with lenses.
However, Augeas only partially found proliferency to be of general use.
Instead, a project called Nix succeeded, whereas Augeas did not.
Nix was the product of a PhD thesis to reproducably package software, by essentially handling inputs, which include text file formats and software that was built with the given text files, as a hash to produce a hash tree reprsentations of compositions of software.
Eventually, this led to NixOS, which is able to take inputs in Nix to produce complete operating system images for Linux.
An abstraction of the composition of different Linux configurations is called a _flake_ in NixOS, which allows a set of NixOS configurations to be considered as a source, such that a view can be used to mechanize the configuration of a set of NixOS configurations, just like with a lens.
The output of this composition is then coincidentally a set of cross-integrated boot images, but also a readable output in Nix language.
In the context of the memory management of GPUs, NixOS is interesting because it provides tools to manage the splitting of memory in a networked setting: the source is not anymore a single node with a GPU but instead a _flake_ that configures a set of nodes which GPUs.
For a practical use, the flake can query e.g. which GPU driver is installed on a given NixOS host, thus provide a set of constraints under which clustered scheduling can happen.

## Conclusion

We reflected on visions of a shapely programming language called FIsh, and detailed what kind of performance optimiziations could be achieved with shape analysis.
We elaborated how bidirectional transformations can be used to address challenges that exist with dealing memory latency.
We then explained how a specific kind of bidirectional transformation called lens already exists in newer array programming language within the combinator called Under.
We showed how the Under works by reimplementing the spirit of it as a profunctor.
We then used Under to motivate its use for memory management, by showing some proof-of-concept code that uses the SPIR-V parallel semantics.

## Whats next?

The pipedream is done one direction; lenses reduce information by surjection.
A mechnanized solution still needs directions.
Something which creates information was referred to above -- a mathematical Under.
Will mathematical Under direct the communication paths for lenses?

