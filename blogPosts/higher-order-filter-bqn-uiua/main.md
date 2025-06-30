# |title|

_|description|_

Concatenative programming languages replace function application with composition.
A similar programming style called _tacit programming_ is common in array programming languages where _verb_ (a.k.a function) semantics have _monadic_ (single) and _dyadic_ (two) cases.
This semantical constraint avoids variable introduction with the help of _modifiers_, which cling onto verbs as _adverbs_ (1-case) or _conjunctions_ (2-case).
For example, the verb _reduce_ can be joined with the adverb _plus_ to produce sum-reduction.
Many modifiers are implementations of _combinators_, which tacit code uses to "Tetris" the arguments to the right places by ordering composition.
Terse expressions arising from this game of combinatory Tetris are called _trains_.
Trains are used to capture common patterns, for equational reasoning, or, e.g., for the vanity of code golf.

Yet a good tacit programmer knows the downside; with a particularly long train, the code inadvertently starts resembling original APL code on punchcards -- _write-once code_.
This downside is addressed in part by [Uiua](https://www.uiua.org/), a recent stack-based array programming language influenced by concatenative languages.
In particular, [APL Wiki on Uiua](https://aplwiki.com/wiki/Uiua) shows Uiua being influenced by [Forth](https://en.wikipedia.org/wiki/Forth_(programming_language)), [BQN](https://mlochbaum.github.io/BQN/), and [J](https://www.jsoftware.com/#/).
Of these, Forth is the concatenative language.
In contrast, BQN and J are array programming languages with a particular focus on tacit programming -- Iverson introduced tacit programming in J, and BQN expanded on J by focusing on functionality.
Further, BQN and J (or array programming languages in general) are not stack-based.
So, what's new with Uiua?

To begin the elaboration, let us consider a piece of Haskell code taken from _[Why Concatenative Programming Matters](https://evincarofautumn.blogspot.com/2012/02/why-concatenative-programming-matters.html)_:

```haskell
countWhere :: (a -> Bool) -> [a] -> Int
countWhere predicate list = length (filter predicate list)
```

The definition can be called as follows, which will return 3:

```haskell
countWhere (>2) [1, 2, 3, 4, 5]
```

In the following sections, we implement `countWhere` in Uiua and BQN.
This is a nifty exercise, as `countWhere` includes a higher-order predicate function and an argument duplication structure.
The argument duplication might require some squinting, but the Haskell code returns a list of elements of type `a` after the predicate.
This means that instead of the apparent array-based solution, which would skip the `[a]` part, we want to remain faithful to the Haskell code for demonstration.
Coincidentally, we get to demonstrate Uiua's stack operations in action.

## Uiua

Uiua (pronounced _wee-wuh_), as a peer of APL, departs from the common feature of symbol _ambivalence_.
This means that, e.g., the minus sign will not mean subtraction dyadically and negation monadically.
Ambivalence exists as a pattern of _economy_, as described by Iverson in _Notation as a Tool of Thought_.
But, for a language that focuses on tacit code, the lack of ambivalence makes trains easier to follow; e.g., your comparator `<` will not suddenly turn into an enclose function when your train gets a bit off the rails.

As a peer of concatenative languages, one to frame Uiua with could be Forth (1970), but we will fare with a more recent example called Joy (2001).
Apparently, (according to an uncited claim on Wikipedia) Joy was the first language to call itself concatenative.
Nevertheless, papers such as _[Joy compared with other functional languages](https://hypercubed.github.io/joy/html/j08cnt.html)_ focus on introducing concatenative concepts implemented with stacks.
Combinatory logic is also well covered in these papers, though without a mention of tacit programming in J (1990).
Was Joy developed without awareness of J?

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
You can [try it](https://www.uiua.org/pad?src=0_12_0-dev_1__Q291bnRXaGVyZSEg4oaQIOKnu-KWvV4hLgpDb3VudFdoZXJlISg-MikgWzEgMiAzIDQgNV0K).

Compare this with the Haskell code:

```haskell
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

Whether Haskell or Uiua won in expressivity is left as an exercise to the reader ([comment on Hacker News](javascript:window.location=%22https://news.ycombinator.com/submitlink?u=%22+encodeURIComponent(document.location)+%22&t=%22+encodeURIComponent(document.title))).

## BQN

[BQN](https://mlochbaum.github.io/BQN/) (Big Questions Notation) is one of the languages that influenced Uiua.
BQN supports higher-order functions hence has a level of combinatorial expressivity that lends itself to equational reasoning in a way that Uiua cannot.
BQN is generally more formal: e.g., it has a [specification](https://mlochbaum.github.io/BQN/spec/index.html) and several implementations in different languages.
As a general feature, it retains ambivalence.

With ambivalence ahoy, concepts in array programming languages that resemble the grammar of natural languages follows: a _noun_ (many non-English languages call this a _substantive_) defines a constituent such as an array or its element, _verbs_ are functions, and modifiers are _adverbs_ in monadic form and _conjunctions_ in dyadic form.

Under the terminology above, in `countWhere` the predicate is a modifier.
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

```haskell
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

## Summa summarum and related work

In the sections above, we compared Uiua and BQN to implement some rudimentary Haskell code with the help of combinators.
Uiua used stack operations and unambivalent functions for terse code.
BQN, on the other hand, had arguably a bit more systematic approach to using combinators, but for the uninitiated it may seem more complex than Uiua.
Yet despite these differences, combinators were used as a shared approach in both.

Personally, I see why people find the learning curve of Uiua easy; without ambivalence the combinator juggle and code in general become _easier to explain_.
This might partially explain why Uiua has found a particularly young following online, as grokking the language requires less familiarity with APL and J.
I think Uiua is certainly worth taking a look at, at least as a new kind of experimentation with array programming languages.

Coincidentally, Uiua still grounds itself with tacit programming, which seems to becoming a form of _[squiggol](https://www.cs.ox.ac.uk/people/jeremy.gibbons/publications/squiggol-history.pdf)_ language across array programming languages.
Relevantly, the [ArrayCast](https://www.arraycast.com/) host @code_report, whose [YouTube channel](https://www.youtube.com/codereport) focuses on array programming languages, wrote a topical review on [Combinatory Logic and Combinators in Array Languages](https://raw.githubusercontent.com/codereport/Content/main/Publications/Combinatory_Logic_and_Combinators_in_Array_Languages.pdf) for PLDI Array 2022, although the paper preceeds Uiua.
It seems some sources cite it as the "birdwatching" paper (see [To Mock a Mockinbird](https://en.wikipedia.org/wiki/To_Mock_a_Mockingbird) for influence), which has induced pages such as [BQN for birdwatchers](https://mlochbaum.github.io/BQN/doc/birds.html) and [Uiua - Combinators](https://www.uiua.org/docs/combinators).
And regarding Joy, there is _[The Theory of Concatenative Combinators](http://tunes.org/~iepos/joy.html)_.

Finally, shouldn't looking at code of function trains be rather called _trainspotting_?