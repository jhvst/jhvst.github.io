#import "acmart.typ": acmart

#let abs = [
  Under is a two-parameter (_dyadic_) combinator in array programming languages that utilizes inverse functions.
  The BQN language implements _structural_ and _computational_ cases of Under.
  In this work, we showcase how the lens properties of structural Under can be used to model parallel programming on GPUs.
  In particular, we showcase Under's connectivity to performance optimizations as envisioned by the FISh programming language.
]

#show: doc => acmart(
    doc,
    title: "On Structural Under and GPUs",
    abstract: abs,
    review: false,
)

#outline()

= Introduction

Most programming languages run forwards, but what about backwards?
Natural languages which do this require some extra _patience_: you must reorder words you hear by re-interpreting sentences by going _backwards_ to parse the meaning.
Sometimes, the semantics of some particular word is positional.
E.g., in Finnish, the same word might have a different meaning depending on the words around it; "taju kankaalla kankaalla" means "passed out on a field", because "kankaalla" means "on a field", but "passed out" when it has "taju" immediately on either side of it.
Another example is "tuo", which means either "that" or "bring".
When conjoined with the word hammer "vasara", "tuo vasara" could mean "that hammer" or "bring hammer", but it would be foolish to think "tuo tuo vasara", would be redundant repetition rather than "bring that hammer".
Interestingly, some new array programming languages have a similar formal pattern: operations denoted with the same symbol and parsed "back and forth," causing a different effect.

This work elaborates on inverse operations in array programming languages, code that undos actions, and bidirectional patterns doing different things depending on the context.
The motivation for this study is to realize the performance benefits of shapely programs as envisioned in the FISh language @ProgrammingInJayC1999.
The FISh paper outlined how a rank polymorphic language with a functional core could be statically checked, which in turn allows new kinds of program optimizations.
The paper defines three beneficial properties of such a shaped language:
1. polymorphism
2. static analysis
3. program optimizations

Since the paper was written in 1999, many of the same visions of FISh have been tackled in adjacent works.
While the development of FISh itself has stagnated, the ideas live on.

Polymorphism and static analysis have been combined in the static rank polymorphism research topic.
Various works @AnArrayOrientSlepak2014 @AplicativeProgGibbon2017 @GettingToThePaszke2021 have modeled static rank polymorphism with dependent types.
In general, existing dependently typed languages can used to capture the denotational semantics required for shapely types.
The benefit is a correctness guarantee: the composition of array operations uses type-level information to verify that operation implementations exist for the ranks of given arrays.
This avoids runtime code failing for shape mismatch.
But, as a historical account of APL details @AplSince1978HuiR2020, dependently typed APL remains a research novelty.

The lack of stronger typing in array programming languages is partly because of the lack of rigorous functionality of the mainstream implementations.
This is in contrast with FISh, which was also a proponent of functionality.
However, new array languages have emerged recently with a more functional core similar to the FISh vision.
Of these languages, notable mentions are BQN (2020) and Uiua (2023).
While neither uses dependent types, the languages have made point-free programming with combinators a common and well-regarded approach to array programming.
As such, the work is tangential towards formalization in general.
A good review on combinators and tacit programming is presented in @CombinatoryLogHoekst2022.

The directions in performance optimizations of shapely and array programming languages remain scattered.
*What has changed* in reflection on computing paradigms in 1999 is that parallel programming has become the primary way to gain performance given the prevalence of multi-core CPUs and accelerators like GPUs.
Yet, while multi-core processing, like general-purpose computing on GPU and multi-core CPUs, was introduced at the start of the 2000s, programming multi-core systems remains challenging.
This could be said in large part to be caused by most computation environments becoming heterogenic in nature.
This means there now exists computers with widely variable core counts and types (with CPUs; P for "performance" or E for "economy", with GPUs; different queue family capabilities), making compiling a one-fits-all logic into programs complicated.
In addition, the performance bottleneck with computers has become memory latency rather than clock frequency.
The memory has become hierarchical, with low-latency shared memory access requiring SIMD instructions.
The SIMD group operations that read and write to these registers vary between processor models on CPUs.
With GPUs, the SIMD operations work in the context of a subgroup, which could be considered a set of adjacent cores.
So, on the one hand, high-performance computing requires low-level memory instructions, but on the other hand, writing code that uses these instructions is, in general, cumbersome as it requires unfolding the memory hierarchies that exist on the hardware.
*How the changes have been addressed:* array programming languages started to take note of GPUs on a bit of lag -- Aaron Hsu's co-dfns @ADataParallelAaron2019 pioneered and raised awareness of making APL on GPUs a reality.
co-dfns is often considered a feat in the parsing and compilation department, showing how the array programming approach can be translated into this new paradigm of GPUs by even having the compiler on the GPU.
Besides APL, various works on exhaustive search-based optimizing compilers, or super optimizers as they are also called, have been developed in the context of array languages.
Mostly centered around constraint solvers, these show how integer solvers can address the lower-level heterogeneity of the hardware by using shape analysis to fit workloads to be assigned to tasks that fit the given compute environment nicely @MappingParalleMogers2022.
Optimizations using shape analysis tend to be written for a specific set of devices, such as for TPUs with Dex and JAX @GettingToThePaszke2021, and machine learning libraries, which often require certain programs to be run on specific models (mostly Nvidia) GPUs.
In academic circles, largely distinct but more theoretical work on patterns that yield language semantics better equipped to handle compiler passes on shape analysis has been done in the works of Accelerate and SaC.
Relevantly, SaC was shown in @OnMappingNDiJansse2021 to control data mappings bidirectionally, in an effort to create a denotational framework that yields itself well for practical means to apply compiler passes that fit data onto accelerators.
SaC relies on the programmer to manually do these fittings in the presented state.
However, such semantics could pave the way for more general-purpose superoptimizing compilers to manage this task.

Altogether, this leaves some of the envisioned performance improvements of shapely languages yet open: what would be required to automatically promote the task of doing data mappings by a solver over a set of heterogenic accelerators, assuming the context of a functional array programming language?

The following chapters elaborate on how combinators are used to achieve tacit programming, which we then use as the basis to explain a combinator construct called Under.
A useful version of Under called _structural_ Under has already been built into the newer functional array programming languages.
We leverage Under's property of being a _rank polymorphic inverse combinator_ as a bridge-builder to address program optimizers' challenges in terms of data mappings.
Thus, the thesis is that a language built to use Under to manage memory would have the inherent property required for an automated approach to allow for low-level vector instructions to be used effectively in the context of array programming languages.
Coincidentally, the bidirectionality of the operator allows us to represent memory as a flat array.
In the later chapter, we explain what Under is, categorically speaking, and how it is currently used.
Finally, we end with a discussion of how proof-of-concept code in BQN is used under the semantics of SPIR-V language for GPU compute shaders.
This work is based on the not so well known duality of structural Under corresponding to the concept lenses from bidirectional programming.
As a limitation, the approach remains manual.
However, we hint at how the second variant of Under, called _computational Under_, makes the process automatic.

= Tacit Programming with Combinators

Concatenative programming languages replace function application with composition.
A similar programming style called _tacit programming_ is common in array programming languages where _verb_ (a.k.a function) semantics have _monadic_ (single) and _dyadic_ (two) cases.
This semantical constraint avoids variable introduction with the help of _modifiers_, which cling onto verbs as _adverbs_ (1-case) or _conjunctions_ (2-case).
For example, the verb _reduce_ can be joined with the adverb _plus_ to produce sum-reduction.
Many modifiers are implementations of _combinators_, which tacit code uses to "Tetris" the arguments to the right places by ordering composition.
Terse expressions arising from this game of combinatory Tetris are called _trains_.
Trains are used to capture common patterns, for equational reasoning, or, e.g., for the vanity of code golf.

Yet a good tacit programmer knows the downside; with a particularly long train, the code inadvertently starts resembling original APL code on punchcards -- _write-once code_.
This downside is addressed in part by Uiua#footnote[https://www.uiua.org/], a recent stack-based array programming language influenced by concatenative languages.
In particular, APL Wiki on Uiua shows Uiua being influenced by Forth, BQN, and J.
Of these, Forth is the concatenative language.
In contrast, BQN and J are array programming languages with a particular focus on tacit programming -- Iverson introduced tacit programming in J, and BQN expanded on J by focusing on functionality.
Further, BQN and J (or array programming languages in general) are not stack-based.
So, what's new with Uiua?

To begin the elaboration, let us consider a piece of Haskell code taken from _Why Concatenative Programming Matters_ #footnote[https://evincarofautumn.blogspot.com/2012/02/why-concatenative-programming-matters.html]:

```Haskell
countWhere :: (a -> Bool) -> [a] -> Int
countWhere predicate list = length (filter predicate list)
```

The definition can be called as follows, which will return 3:

```Haskell
countWhere (>2) [1, 2, 3, 4, 5]
```

In the following sections, we implement `countWhere` in Uiua and BQN.
This is a nifty exercise, as `countWhere` includes a higher-order predicate function and an argument duplication structure.
The argument duplication might require some squinting, but the Haskell code returns a list of elements of type `a`' after the predicate.
This means that instead of the apparent array-based solution, which would skip the `[a]` part, we want to remain faithful to the Haskell code for demonstration.
Coincidentally, we get to demonstrate Uiua's stack operations in action.

== Uiua

Uiua (pronounced _wee-wuh_), as a peer of APL, departs from the common feature of symbol _ambivalence_.
This means that, e.g., the minus sign will not mean subtraction dyadically and negation monadically.
Ambivalence exists as a pattern of _economy_, as described by Iverson in _Notation as a Tool of Thought_.
But, for a language that focuses on tacit code, the lack of ambivalence makes trains easier to follow; e.g., your comparator `<` will not suddenly turn into an enclose function when your train gets a bit off the rails.

As a peer of concatenative languages, one to frame Uiua with could be Forth (1970), but we will fare with a more recent example called Joy (2001).
Apparently, (according to an uncited claim on Wikipedia) Joy was the first language to call itself concatenative.
Nevertheless, papers such as _Joy compared with other functional languages_ #footnote[https://hypercubed.github.io/joy/html/j08cnt.html] focus on introducing concatenative concepts implemented with stacks.
Combinatory logic is also well covered in these papers, though without a mention of tacit programming in J (1990).

In Joy, multiplication can be done as follows:

```Joy
* 2 3 === (* 2) 3
```

In Uiua, each line below pushes `6` onto the stack:

```uiua
× 2 3
(× 2) 3
```

As we can see, Uiua follows Polish-notation.
Next up are combinators: the W-combinator `(W f) x = (f x) x` can be used in Uiua to calculate the square using `duplicate`, which when formatted gets turned into punctuation `.`:

```uiua
× . 3
```

Here, `duplicate` is a stack operator acting on `3`: the noun `3` implicitly pushes itself to the stack, and the verb `duplicate` makes a copy of the top value in the stack.
When the stack `3 3` runs into multiply, a dyadic verb, it consumes the two values from the stack and pushes in a `9`.
The following are thus equivalent:

```uiua
× . 3
(× 3) 3
```

Again, the parenthesis is redundant and only highlights the correspondence to the W-combinator.

Things get slightly more interesting once we start utilizing rank polymorphism.
This foundational array language feature constructs an implicit map function when `duplicate` is applied to a vector:

```uiua
× . [1 2 3]
```

Oh, no stinking loops, what a Joy!
But, unfortunately, Joy requires explicit maps to act on vectors, whereas Uiua does not.

With Joy won over, we continue to reimplement the `countWhere` Haskell code:

```uiua
>2 [1 2 3 4 5]
```

Which prints `[0 0 1 1 1]`.
To run a filter over this view vector, we can use the dyadic `keep` (symbol `▽` ) with `duplicate` (symbol `.`):

```uiua
▽ (>2 .) [1 2 3 4 5]
```

Which prints `[3 4 5]`.
What happens is that `duplicate` makes a copy of the original `[1 2 3 4 5]` and adds it to the stack.
The stack thus looks as `[1 2 3 4 5] [1 2 3 4 5]`.
Then, `>2` consumes the first value in the stack to produce `[0 0 1 1 1]`.
Stack looks like `[0 0 1 1 1] [1 2 3 4 5]` now.
Then, the dyadic `keep` consumes the first two elements from the stack, using the first value as a view vector.
`[3 4 5]` remains the stack's sole value.
Length (keyword `length`, symbol `⧻`) can be used on this directly:

```uiua
⧻ ▽ (>2 .) [1 2 3 4 5]
```

Printing us `3` like the Haskell code.
If we translate the symbols back to their keywords, the code above reads: `length keep (greater than 2 duplicate) [1 2 3 4 5]`.
But, we should still refactor this into a function.

Functions in Uiua follow the same principle as in BQN, where assignments that start with an uppercase letter become functions.
However, unlike BQN, Uiua does not support higher-order functions.
Instead, there is a macro system where function declarations and calls are prefixed with bangs.
As many functions as you have as inputs, as many bangs you add to your name and calls.
In the function body, you must then have the same number of _placeholders_, denoted with `^!`, as you have bangs in the name.
A demonstration helps:

```uiua
CountWhere! ← ⧻▽^!.
CountWhere!(>2) [1 2 3 4 5]
```

This completes the definition of `countWhere` in Uiua.

Compare this with the Haskell code:

```Haskell
countWhere :: (a -> Bool) -> [a] -> Int
countWhere predicate list = length (filter predicate list)
countWhere (>2) [1, 2, 3, 4, 5]
```

Some remarks: in the Uiua code, the comparator needs parenthesis to indicate that it is passed as a _modifier_ to the function.
Thus, we hit the only precedence rule in the language with this example.
Another remark is that the Haskell implementation takes in two arguments, whereas the Uiua macro has a placeholder only for a single argument.
It still works because "overflowing" arguments are "appended" to the function call.
For this reason, there is no need to open up this abstraction unless we expect the second argument to also be a function (which is not the case with the Haskell code).
But if you like bangs, here is the definition:

```uiua
CountWhere‼ ← ⧻▽^!.^!
CountWhere‼(>2) [1 2 3 4 5]
```

== BQN

BQN#footnote[https://mlochbaum.github.io/BQN/] (Big Questions Notation) is one of the languages that influenced Uiua.
BQN supports higher-order functions hence has a level of combinatorial expressivity that lends itself to equational reasoning in a way that Uiua cannot.
BQN is generally more formal: e.g., it has a specification #footnote[https://mlochbaum.github.io/BQN/spec/index.html] and several implementations in different languages.
As a general feature, it retains ambivalence.

In this chapter, we lend naming in array programming languages that resemble the grammar of natural languages (as it is in J) as follows: a _noun_ (many non-English languages call this a _substantive_) defines a constituent such as an array or its element, _verbs_ are functions, and modifiers are _adverbs_ in monadic form and _conjunctions_ in dyadic form.

Under the terminology above, in `countWhere` the predicate is an adverb.
A tacit implementation of the predicate is a function train `⊣ > 2∘⊢`, where the circle is called _Atop_ and corresponds to the B-combinator.
The B-combinator is just plain composition.

Although, trains of the form `⊣ 𝔽 𝔾∘⊢` are D-combinators, represented with After: `𝔽 ⟜ 𝔾`.
Thus, `⊣ > 2∘⊢` can be simplified to `> ⟜ 2`.
A partial implementation of `countWhere` might thus be defined as:

```bqn
Predicate ← >⟜2
CountWhere ← {/𝕎𝕩}
predicate CountWhere 1‿2‿3‿4‿5
```

Like with Uiua, `Predicate` and `CountWhere` denote function definitions as seen from the capital first letter.
`Predicate` can be passed as a function to `CountWhere` by using it as a _subject_: this is done by calling it in lowercase.
Meanwhile, the `CountWhere` is defined in a so-called block style (a.k.a _[dfn](https://aplwiki.com/wiki/Dfn)_).
In block style code, arguments have keywords such as `𝕎` (left argument as a verb) and `𝕩` (right argument as a noun) which can be placed in arbitrary locations of the expression.
With this in mind, here is the Haskell code again:

```Haskell
countWhere :: (a -> Bool) -> [a] -> Int
countWhere predicate list = length (filter predicate list)
countWhere (>2) [1, 2, 3, 4, 5]
```

To retain semantical familiarity with Haskell, we can refactor the predicate function into a `CountWhere` modifier by substituting `𝕎` with the D-combinator `𝔽⟜𝕨`.
This _binds_ `>` into `𝔽` and `2` into `𝕨`.
Denoting that the function takes in a modifier is done by adding an underscore to the function name:

```bqn
_CountWhere ← {/𝔽⟜𝕨𝕩}
2> _CountWhere 1‿2‿3‿4‿5
```

So, the underscore collects the left-hand side verb as an adverb `𝔽`.
Coincidentally, it means that `_CountWhere` is now a _1-modifier_.
This sets the noun `2` to become available as a separate argument `𝕨`, which we can arbitrarily place within the function block.

This serves as an introduction how function blocks work, but the implementation does not type-check the Haskell one.
This is because the result contains indices, not argument array values.
To fix this, the filter function `/` has to be moved to the start of the `_CountWhere` definition.
Concretely, what we need we need is:

```bqn
0‿0‿1‿1‿1 / 1‿2‿3‿4‿5
```

While we currently have:

```bqn
/ (0‿0‿1‿1‿1)
```

We must duplicate `𝕩` to both sides of the filter function `/` to implement the fix.
Concretely, we need: `{(𝕩𝔽𝕨)/𝕩}`.

But can we eliminate the repetition of `𝕩` using combinators?
Like the Uiua solution, we need a notion of duplication.
BQN does not have a stack, but the same can be achieved with the Σ-combinator, which is the monadic version of Before `𝔽 ⊸ 𝔾`: `(𝔽𝕩) 𝔾 𝕩`.
In other words, Before applies left-hand side precedence by passing a copy of the original argument `𝕩` also to `𝔽`.
Let us start rewriting from this expression without functions or variables:

```bqn
(1‿2‿3‿4‿5 > 2) / 1‿2‿3‿4‿5
```

First, we can make this into a block by substituting the array with an `𝕩`:

```bqn
a ← (1‿2‿3‿4‿5 > 2) / 1‿2‿3‿4‿5
b ← {(𝕩>2)/𝕩} 1‿2‿3‿4‿5
a ≡ b # Equivalence check
```

The Before combinator `(𝔽𝕩) 𝔾 𝕩` requires the verb `𝔽` to have a right-hand side argument `𝕩`.
Yet, in the code block above our `𝔽𝕩` looks like `𝕩>2`.
To move the `𝕩` to the right side of the expression, we can use After as a _bind_.
From the definition of After `𝕩 𝔽 (𝔾𝕩)` we see that the `𝕩` is moved to the left side of `𝔽`, just like we want.
This Tetris move is required because the verb `>` acts as a merge function if it does not have a left-hand side argument.
Only when it has two arguments (here, `𝕩` and `(𝔾𝕩)`) is it a comparator.
Let us focus only on the comparator part, namely: `x>2`:

```bqn
a ← {(𝕩>2)} 1‿2‿3‿4‿5
# Definition of After: 𝕩 𝔽 (𝔾𝕩)
b ← {𝕩>(2˙𝕩)} 1‿2‿3‿4‿5
# Applying After
c ← {>⟜2𝕩} 1‿2‿3‿4‿5
# Function abstraction
d ← >⟜2 {𝔽𝕩} 1‿2‿3‿4‿5

⍷ a‿b‿c‿d # Deduplicate results
```

With only a single unique result, we see the expressions above are equivalent.
Further, we now have the `𝕩` on the right side of the comparator function.

Before moving to Before, we address the definition `c` from above: what does `> ⟜ 2 1‿2‿5‿4‿5` mean?
In `b`, if we apply the arguments, we get `1‿2‿5‿4‿5 > (2 1‿2‿5‿4‿5)`.
So, `2` is `𝔾`; it is not a noun but a (constant) function returning `2`.
Thus, `> ⟜ 2 1‿2‿5‿4‿5 = 1‿2‿5‿4‿5 > 2`.
This is why the spelled-out definition of `b` requires a constant sign `˙` to evaluate.
But, when the noun is part of a combinator, it is interpreted automatically as a constant verb instead because the combinators only take functions as arguments.

We can now apply Before to the function body with the filter `/`:

```bqn
a ← {(𝕩>2)/𝕩} 1‿2‿3‿4‿5
# Steps from the After
# Notice this corresponds to Before: (𝔽𝕩) 𝔾 𝕩
b ← >⟜2 {(𝔽𝕩)/𝕩} 1‿2‿3‿4‿5
# Apply Before
c ← >⟜2 {𝔽⊸/𝕩} 1‿2‿3‿4‿5

⍷ a‿b‿c
```

Expanding `𝔽`:

```bqn
a ← >⟜2 {𝔽⊸/𝕩} 1‿2‿3‿4‿5
b ← 2> {𝔽⟜𝕨⊸/𝕩} 1‿2‿3‿4‿5

⍷ a‿b
```

We can now put this back into a function and add `≠` to compute the length.
This gets us a modifier that we can call with `2> _CountWhere 1‿2‿5‿4‿5`:

```bqn
_CountWhere ← {≠𝔽⟜𝕨⊸/𝕩}
2> _CountWhere 1‿2‿4‿4‿5
```

Reiteration: here `𝔽` is `>`, `𝕨` is a noun `2`, which gets tacitly promoted to a function, and `𝕩` is the input argument.
This completes the implementation of the Haskell code.

However, I wonder if bqnauts would write such code.
Something I like more is:

```bqn
≠/2>˜ 1‿2‿5‿4‿5
```

Yet this is not a faithful implementation, but at least reads quite well: `length filter 2> swap 1‿2‿5‿4‿5`.

== Related work

In the sections above, we compared Uiua and BQN to implement some rudimentary Haskell code with the help of combinators.
Uiua used stack operations and unambivalent functions for terse code.
BQN, on the other hand, had arguably a bit more systematic approach to using combinators, but for the uninitiated it may seem more complex than Uiua.
Yet despite these differences, combinators were used as a shared approach in both.

A panel of domain experts said to find #footnote[https://www.arraycast.com/episodes/episode87-iversonsession] the learning curve of Uiua easier than BQN; without ambivalence the combinator juggle and code in general become _easier to explain_.
This might partially explain why Uiua has found a particularly young following online, as grokking the language requires less familiarity with APL and J.
As such, Uiua at very least, is certainly worth taking a look at as a experimentation of syntax of array programming languages.

Coincidentally, Uiua still grounds itself with tacit programming, which seems to becoming a form of _squiggol_ @TheSchoolOfSGibbon2020 language across array programming languages.
A recent review on _Combinatory Logic and Combinators in Array Languages_ @CombinatoryLogHoekst2022 also exists, but the paper preceeds Uiua.
Nevertheless, BQN #footnote[https://mlochbaum.github.io/BQN/doc/birds.html] and Uiua #footnote[https://www.uiua.org/docs/combinators] have a dedicated documentation page for combinators.
And regarding Joy, there is _The Theory of Concatenative Combinators_ #footnote[http://tunes.org/~iepos/joy.html].

= Beyond combinators is bidirectionality

Array programming languages BQN and Uiua focus on tacit programming and combinators.
The languages use combinators differently; BQN to rule application precedence and Uiua to handle the stack.
Despite this difference, the combinators form a shared language to realize functional (or _concatenative_) array programming.

In addition to combinators, the languages have operations that capture mathematical and structural _inverses_.
The inverse functions are implemented as the 1-case _Undo_ and the 2-case _Under_.
The operations are a bit of an oddity: they are not plain combinators like all the others but discovered (and rather useful!) programming patterns.

The point onwards is to pinpoint their correspondence with a more abstract notion of _bidirectional transformations_.
In general, bidirectional transformations are a topic in programming language research focusing on invertible patterns.
Moreover, invertible patterns are much more common than one might think; in BQN, every variable assignment can be thought of as a structural inverse.
Further, this structural inverse, called structural _Under_, exhibits the concept of a _profunctor_.
We later implement a profunctor in Uiua, and detail how Under implements the same functionality but ergonomically.
This gives us a nice language that runs forwards, and then backwards to parse out the meaning.

The motivation of this chapter is to contribute an alternative description to Under and raise awareness of array programming languages as a bidirectional transformation tool, especially when considering structural Under as a lens.

== Background

This section briefly reviews bidirectional transformations, focusing on lenses, and then explains how inverse operations came to APL and its descendants.

=== Bidirectional Transformations

Programming languages that run backwards are either bidirectional or bijective.
Bijective ones are defined by backwards code that is formed of injective functions.
You could think these as the "undo" operations when you run them backwards, or more generally multiplayer games where actors take turns "my turn", "your turn".

The group of injective functions is rather limited, but a more general structural case also exists.
These bidirectional definitions only apply inverse transformations to the _structure_ of the parameters.
Bidirectional transformations typically take two arguments: an updated output as well as the original input.
It weaves the parameters together, yielding a new input where the information contained in the output has been propagated, and the discarded information from the input has been restored.
Bidirectional programs are typically required to obey "round-tripping" laws, ensuring that each direction's transformation maintains information.
This is exemplified by our 2-case Under, which is used by languages such as BQN to reassign variables; one of the parameters is an existing variable, and the other is the atoms that you would like to be put in its place.

In this sense, bidirectional transformations are proof-bearing; they can be seen as a mechanism for maintaining the consistency of two (or more) related sources of information.
The most obvious pattern of this kind is a lens: a data accessor for the particular subfield of some data structure.
An example is a database view: you join two tables, possibly by selecting only a subset of all fields.
When you update this view, the changes will propagate back to the original tables.
If so, the view is an input in the outward direction when you update the fields and an output in the forward direction.
If the lens fulfills three laws of `PutGet`, `GetPut`, and `PutPut`,  it is considered _lawful_.
Notably, a lawful lens composes, making it a useful specification for programs dealing with hierarchical structures by making it _heterarchical_.
To elaborate, one could imagine a case with database views where you combine datasets from multiple nodes.
The first view (hierarchy 1) joins the table within a single node, and the second view (hierarchy 2) combines the views from each node.
When you update the cojoined view (of hierarchy 2, the view of two tables of two nodes) on some specific row, the diffset will propagate to each node (hierarchy 1, the view of two tables).
Each node would use the diffset to figure out what tables need updating, propagating the information onto concrete tables (hierarchy 0, concrete representation of a table).
The idea is that if getting and putting data is _well-behaved_, the programmer looking at the data on the highest hierarchy does not need to consider the particularities of what happens on lower levels of abstraction.

=== Inverse combinators in APLs

A monadic inverse has always existed in APL, but a dyadic one has not.
The following sections cover both in three generations: the 80-year-old 1-modifier Undo and the 40- and 5-year-old 2-modifier variants of Under.
Of these, the 5-year-old _structural_ Under is particularly interesting for bidirectional transformations as it can represent a lawful lens.
The code sections in this section will default to BQN.

==== Undo

The 1-modifier _Undo_ (semantics: `𝕨 𝔽⁼ 𝕩`) was already implemented in the initial version of APL.
Denoted in BQN with `⁼`, Undo leverages built-in inverse definitions of the constrained set of array functions in the "standard library" of the languages.
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

This code gives us three because it is the root of nine.
The important takeaway is that there are cases in which applying a function and its inverse does not always return the identity of the argument but rather the "computational" result of an intermediate value.
BQN documentation describes this as follows:
> Undo doesn't always satisfy `𝕩 ≡ 𝔽⁼ 𝔽 𝕩`, but it does obey `𝕩 ≡ 𝔽 𝔽⁼ 𝕩`. That is, it gives one possible argument that could have been passed to `𝔽`, just not necessarily the one that actually was.

Besides this rather weird example using an idiom for power and an effect for negative values, Undo does what you would usually expect, as listed in the specification#footnote[https://mlochbaum.github.io/BQN/spec/inferred.html#required-functions].

==== Under

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
But, a case we will revisit is one in which it is handy is the generation of values up to a bound:

```bqn
↕∘⌈⌾((4+3×⊢)⁼) 20
```

In this example, the `𝔾` function is run backwards first, which causes `20` to become `5.33...` on the left side of Under `(20-4)/3` which is first ceiled to `6`, which is passed to `iota` to generate `0..=5`.
Then, each element in the array is multiplied by `3`, and then a `4` is added.
Conceptually, this is interesting because information is, in a sense, created (well, it exists in 20, but six elements look like more information than one).
One application area is programs dealing with corecursion, i.e., programs that recursively generate new values on which some other parts of the program do some computation.

This contrasts with a more common version of Under called a _structural_ Under, which often selects parts of the input with `𝔾` that it modifies according to a function `𝔽`.
Structural Under was presented in BQN (2020), which expanded `𝔾` of computational Under to work for a class of structural functions.
With structural Under, `𝔾` becomes _shapely_ @ProgrammingInJayC1999: the shape of the result is determined by the shapes of the inputs.
Bidirectional transformations over a shape are much more common than the conjugacy classes of computational Under.
This is largely due to the constraint existing only for `𝔾`: structural Under relaxes `𝔽` to an _update_ or a _set_ function.
The above notion is important for BQN because structural Under is how BQN achieves variable immutability.
This abstraction promotes a rather functional approach to mutation.
The same concept is known as a _lens_ for category theorists and functional programmers.
For demonstration, consider the following code which streams values in an arbitrary format in `𝕨` to a structure given with `𝕩`:

```bqn
⟨" ab", "cde", "fg" ⟩ ⊣⌾∾ ⟨" ---", "----" ⟩
```

Despite the slight difference in computational and structural Under, BQN implemented it as a single donut glyph ⊚.
This conjoined implementation has been a topic "~~arg~~discussion" #footnote[https://www.dyalog.com/blog/2023/01/structural-vs-mathematical-under/].
However, as of the time of writing, the conjoined version has taken hold of other array languages, including Kap, Uiua, and J.
BQN achieved this using a unification principle `(𝔾 𝕨𝔽⌾𝔾𝕩) ≡ 𝕨𝔽○𝔾𝕩`, where ○ is a combinator called _Over_.
Over is defined as `{(Gw)FGx}`, corresponding to the Bluebird combinator with one argument and the Ψ-Combinator with two arguments.
The expression is arguably easier to parse letting `z←𝕨𝔽⌾𝔾𝕩` and `v←𝕨𝔽○𝔾𝕩`.
The unification principle then condenses to `v≡𝔾z`.
Here, 𝒗 is well-defined if one accepts the axioms of combinatory logic.
Next, 𝔾 and 𝒛 are used to select the right case of Under:

- Invertible Under: If 𝔾 is uniquely invertible on 𝒗, that is, 𝒗≡𝔾𝒛 has a unique solution for 𝒛, then the result of Under is that solution.
- Structural Under: If 𝔾 is a structural function and 𝒗 is compatible with 𝔾 on 𝕩, then the result is obtained by inserting 𝒗 back into 𝕩.
- Computational Under: If 𝔾 is provably not a structural function, then the result is 𝔾⁼𝒛 if it is defined, where ${=}$ is Undo.

The implementation details are exhaustively documented #footnote[https://mlochbaum.github.io/BQN/spec/inferred.html#Under] but are out of the scope of this post.

== Reinventing Under

The last section described the inverse operations of array programming languages.
This section reimplements bidirectionality of structural Under without using structural Under.
Here, the dual pattern we show is a higher-order function construction called a profunctor.
The duality between lenses and profunctors has been previously shown in @ProfunctorOptiPicker.
We will use Uiua for code demonstrations.

=== APL: A Profunctor Language

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
The dimap is covariant in what it produces but contravariant in what it consumes (sometimes, this is known as the "robustness principle").
In Haskell, dimap is used to describe a _projective functor_, i.e., a profunctor.

It turns out that implementing the flow of a profunctor gives us the semantics of Under.
For demonstration, let us implement a dimap in Uiua.
First, consider the following Haskell code (taken from #footnote[https://typeclasses.com/profunctors]):

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
This is because macros in Uiua are not pure higher-order functions.
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
These are used in the `WithPhraseAsWord!` macro, which takes in an additional "trailing" function that acts on the type "in the middle" of the conversions.
The trailing function argument 𝒉, which acts on boxed arrays, acts _under_ the bidirectional transformation functions 𝒇 and 𝒈.
With our knowledge of the semantics of structural Under `𝔽⊚𝔾`, we can see that the trailing function is the `𝔽` and the fixed function arguments correspond to the `𝔾` in its forward and backwards application.

The `Words` and `Unwords` required have a lot of information in them which Under can abstract.
Consider the following functionally equivalent code for `CapPhrase`:

```uiua
⍜⊜⊢⌵⊸≠@ "here are some words"
```

Printing us `"Here Are Some Words```.
We can see this definition joining the uppercase operation `⌵` from `CapBox` with structural inverse of `Words`.
Because Under is able to leverage the built-in inverse definitions of structural functions in the language, it renders itself as an ergonomic operation to abstract the projections of `𝔾`.
This, in turn, makes structural Under an interesting operation for working with applications of bidirectional transformations, and BQN and Uiua are interesting languages for such.

= Discussion & future work

The examples above and the connectivity to profunctors might sound abstract.
But lenses are frequent once you know what to look for.

One such finding is to see memory partitioning as a lens.
Consider that we have a 10GB blob of memory on a GPU.
To get most of the performance out of this blob, we need to map it into small regions of threads where the SIMD group operations can be used.
However, we always need a backwards propagation in our application code whenever we model this memory hierarchy because the operations are shapely.
In other words, as the shape controls the memory partitioning, and the shape _of the data we are interested in_ changes between operations, then the parameters for the partitioning logic also vary.
Instead, we can destruct the partitioning after each operation, such that we always restart from a one-dimensional representation of memory.
An operation like Under abstracts away this bidirectional transformation, allowing the programmer to focus mainly on the compute operation at hand.
We can thus start modeling parallel language semantics like SPIR-V in the same sense that APL was modeling IBM/360 semantics, but now with a twist that uses the bidirectional approach from @OnMappingNDiJansse2021.
Consider the following, which uses the semantics of SPIR-V to do a sum scan:

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
_PolyPhase ← {(1>˜(⊑∘≢∘‿4⥊⊢))◶⟨Subgroup1 _Phase_ 𝕗, SubgroupLeader _Phase_ 𝕗⟩ 𝕩}

input ← ↕16
# Runs fold on each subgroup and moves the last value to the first subgroup
•Show a ← (+`) _PolyPhase input
# Writes to registers
•Show a Move input
# Runs fold on the first subgroup
•Show b ← (+`) _PolyPhase 4↑a
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

The code uses two different versions to produce `4x4` matrix sum reduction over the _iota_ of 16 values, with the result being: `⟨ 6 28 66 120 4 9 15 22 8 17 27 38 12 25 39 54 ⟩`.
Importantly, it shows how it is possible to encode certain SIMD instruction _scopes_ (or views), here, `SubgroupLeader` and `Subgroup1` by using array functions that use computational Under to generate the source indices.
When such a view is constructed, the `_Run` modifier takes in a higher-order function parameter like sum reduction and executes the function over the built view using structural Under.
A' Move' function can be used to write these values onto the "registers".
The `Move` function is further abstracted to a given view with the `_MoveTo` modifier, which takes in a view.
As such, a _phase_ of computation, which encodes the rudimentary pattern of divide-and-conquer algorithms of _computing_ and _communication_, can be represented as 2-modifier `_Phase_` function which uses `_Run`'s and `_MoveTo`s values within a certain view scope.
We can further simplify this by inspecting the rank of the parameter by creating a 1-modifier `_PolyPhase` function, which applies a different view depending on the hierarchy of the current computation step.
In other words, the `_PolyPhase` is a rank polymorphic SIMD operation.
The interesting part of the approach above is that the original input shape is always preserved after each operation, despite the fact that the SIMD selectors (dual to thread assignments to memory) generate different shapes for execution functions.
This automatic reshaping is done automatically by Under.

The program above has some constant values encoded in, namely, four to represent the SIMD widths.
However, the four can as well be a variable, should our SIMD lane width be four times of that:

```
# GPU SIMD modeling

# Generates subgroup local indices, 𝔽 can be used to filter certain IDs, 𝔾 to create a stepping function
# note: Computational Under which generates these up to a bound of 𝕩
_Subgroup_ ← {𝔽↕∘⌈⌾(𝔾⁼)}
# Runs function 𝔽 in the scope of given subgroup context
# note: Structural Under, where 𝕩 is the source and 𝔽 is the view
_Run ← {𝔽˘⌾((≢↑‿16⥊⊢)⥊⊢)}
# Uses 𝕨 to overwrite values, akin to load and store
# note: Structural Under, where 𝕩 are the targets and 𝕨 are the values which are written
Move ← ⊣⌾((↕16)⊸⊏)
# MoveTo is abstracted Move, where 𝔽 is an invocation selector (see below) to which values are written
_MoveTo ← {((𝔽≠𝕩)/𝕩) Move 𝕩}
# Subgroup selector which selects the last element of each subgroup
# note: the subgroup leader is often the first subgroup
SubgroupLeader ← {3=(16|⊢ _Subgroup_ ⊢ 𝕩)}
# Subgroup selector which selects the first subgroup using global invocation ID
Subgroup1 ← {16> ⊢ _Subgroup_ ⊢ 𝕩}
# Runs operation 𝔾 on 𝕩 and moves values to locations 𝔽
_Phase_ ← {𝔽 _MoveTo 𝔾 _Run}
# Uses shape to choose which subgroup operation should be used
_PolyPhase ← {(1>˜(⊑∘≢∘‿16⥊⊢))◶⟨Subgroup1 _Phase_ 𝕗, SubgroupLeader _Phase_ 𝕗⟩ 𝕩}

input ← ↕16
# Runs fold on each subgroup and moves the last value to the first subgroup
•Show a ← (+`) _PolyPhase input
# Writes to registers
•Show a Move input
```

Which yields: `⟨ 0 1 3 6 10 15 21 28 36 45 55 66 78 91 105 120 ⟩`, where the sums of each four values are found not in the first four values, but on the index of every fourth value.

The subgroup length comes from a hardware constant, which, interestingly, has also been shown to be a lens in the context of Linux systems.
This duality arises from another application of lenses, which is bidirectional transformation between data formats of, e.g., text files.
A Red Hat project called Augeas @augeas was the first to note this connectivity with lenses.
The takeaway of Augeas is that Linux configuration depends on various text file formats put into the right location on a filesystem or a disk image.
Augeas uses a higher-level source language, Boomerang, that compiles multiple text file formats and puts them in the right place on the filesystem.
However, Augeas only partially found prolific general use, but a more recent project called Nix succeeded, whereas Augeas did not.
Nix started as an artifact product of a PhD thesis @ThePurelyFuncDolstr2006 to reproducibly package software.
Nix does this by handling inputs, including text file formats and software built with the given text files, to build an input-addressed hash tree of the compositions.
Eventually, this led to NixOS, which is able to take inputs in Nix to produce complete operating system images for Linux.
In the context of the SIMD specializations, Nix allows us to specify the device drivers such that those drivers also produce their capabilities into the hash tree.
The output of a hash tree, derivation, can then be queried as an input to a program, effectively inserting hardware properties like the SIMD widths into the compute kernel sources specific to that hardware configuration.
This makes it possible to simplify the variation of SIMD properties by homogenizing hardware configurations.

Naturally, even NixOS configurations are composed, as they, too, are lenses.
An abstraction of the composition of different Linux configurations is called a _flake_ in NixOS, which allows a set of NixOS configurations to be considered as a source, such that a view can be used to mechanize the configuration of a set of NixOS configurations.
The output of this composition is then coincidentally a set of cross-integrated boot images, but also a readable output in Nix language.
In the context of the memory management of GPUs, it expands our ability to think about blobs of memory but in a networked setting: the source is not anymore a single node with a GPU but instead, a _flake_ that configures a set of nodes which GPUs.
For practical use, the flake can query, e.g., which GPU driver is installed on a given NixOS host, thus providing a set of constraints under which clustered scheduling can happen.

This motivates the example above; the `Move` functions could also move memory between GPUs and networks.
This would, however, require more formalization to how the computational Under selects the sources from which it reads memory.

= Conclusion

We reflected on visions of a shapely programming language, FISh, and detailed what performance optimizations could be achieved with shape analysis.
We elaborated on how bidirectional transformations can be used to address challenges that exist when dealing with memory latency.
We then explained how a bidirectional transformation called lens already exists in newer array programming languages within the combinator called Under.
We showed how the Under works by reimplementing the spirit of it as a profunctor.
We then used Under to motivate its use for memory management by showing proof-of-concept code that uses the SPIR-V parallel semantics.

#bibliography("lib.bib")
