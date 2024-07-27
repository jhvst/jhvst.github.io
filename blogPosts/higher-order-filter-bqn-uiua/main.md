
# Combinatory Tetris

Concatenative programming is similar to _tacit_ programming in array programming languages, in which functions are composed together in a point-free style without explicitly applying functions.
Tacit programming leverages a typical constraint in array programming languages' _modifier_ semantics having either a single (_monadic_) or two (_dyadic_) arguments (or 0).
Modifiers are almost exclusively implementations of _combinators_, which are used to "Tetris" the parameters to right places by swapping, copying, and applying precendence around functions.
This game of combinatory Tetris is often used to omit variables by those looking for terse implementation of common idioms, or, e.g., code golfing.

Yet a good tacit programmer knows the downside; when the extent of function composition starts resembling a particularly long train, the code inadvertently starts resembling properties of original APL code on punchcards -- write-once code.
This downside is something that [Uiua](https://www.uiua.org/), a recent stack-based array programming language, addresses in part thanks to its concatenative language influece.
In fact, as the [APL Wiki on Uiua](https://aplwiki.com/wiki/Uiua) shows, Uiua has been influenced by languages called [Forth](https://en.wikipedia.org/wiki/Forth_(programming_language)), BQN, and J.
Of these, Forth is a _concatenative_ language which is not often mentioned alongside array programming languages.
Or at least, it was not mentioned before Uiua.
So, compared to BQN which I have mostly been using as of late, I decided to give Uiua a quick try.

To elaborate, we can consider a piece of Haskell code taken from _[Why Concatenative Programming Matters](https://evincarofautumn.blogspot.com/2012/02/why-concatenative-programming-matters.html)_:

```Haskell
countWhere :: (a -> Bool) -> [a] -> Int
countWhere predicate list = length (filter predicate list)
```

The definition above can be called as such:

```Haskell
countWhere (>2) [1, 2, 3, 4, 5]
```

Returning `3`.
In the next sections, we reimplement `countWhere` in Uiua and BQN.
This is a nifty excercise, as `countWhere` includes a higher order predicate function, and a parameter duplication structure.
The latter might be harder to see, but do notice the Haskell code returning a list of elements of type `a` after the predicate.
This means that instead the obvious array-based solution, which would skip the `[a]` part, we want to remain faitful to the Haskell code for demonstration.

## Uiua

Unlike BQN and most other APLs, Uiua has no double meaning for symbols: your comparator `<` won't suddently turn into a enclose function when you lose the track of your tacit code.

A language to frame Uiua (pronounced _wee-wuh_) with would logically be Forth (1970), but a more recent example Joy (2001).
Joy was also the first language to call itself concatenative.
For this reason, various papers such as _[Joy compared with other functional languages](https://hypercubed.github.io/joy/html/j08cnt.html)_ have a focus on introducing the concatenative concepts (and stacks) in the context of combinatory logic.
As combinatory logic is the way that tacit programming was initially achieved in J (1990), as it gave the tools to play the parenthesis Tetris.

In Joy, multiplication can be done as follows:

```Joy
* 2 3 === (* 2) 3
```

The same applies in Uiua:

```uiua
× 2 3
(multiply 2) 3
```

Which both print 6. Likewise, the W (Warbler) combinator `(W f) x = (f x) x` can be used in Uiua to calculate the square using `duplicate`:

```uiua
× . 3
```

Here, `duplicate` is a stack operator acting on `3`: the noun `3` pushes itself to the stack, and the verb `duplicate` copies its argument to the stack. The following are thus equivalent:

```uiua
× . 3
(multiply 3) 3
```

Again, the parenthesis are redundant, and only to highlight the correspondence to the Warbler combinator.

Things get slightly more interesting once we start utilizing rank polymorphism. The array language features of Uiua can be noticed by its implicit map function when `duplicate` is applied to a vector:

```uiua
× . [1 2 3]
```

While Joy needed multiple tricks to act on vectors, rank polymorphism in Uiua handles it automatically.
To start implementing the Haskell code, we can thus simply use:

```uiua
>2 [1 2 3 4 5]
```

Which prints `[0 0 1 1 1]`. To run a filter over this view vector, we can use the dyadic `keep` with `duplicate`:

```uiua
▽ (>2 .) [1 2 3 4 5]
```

Which prints `[3 4 5]`.
Notice that the dyadism now means acting on two values from the stack.
The parenthesis are redundant, but it highlights how the predicate with duplicate maps the parameters yielding `[0 0 1 1 1]` to the parenthesis, which keep uses then to select the values to be preserved.

Length can be used on this directly:

```uiua
⧻ ▽ (>2 .) [1 2 3 4 5]
```

Printing us 3.

```Uiua
CountWhere! ← ⧻▽^!.
CountWhere!(>2) [1 2 3 4 5]
```

[Try it](https://www.uiua.org/pad?src=0_12_0-dev_1__Q291bnRXaGVyZSEg4oaQIOKnu-KWvV4hLgpDb3VudFdoZXJlISg-MikgWzEgMiAzIDQgNV0K)


## BQN

BQN supports higher order functions, which are also called _modifiers_ in the array programming community.
The intuition in the naming follows grammar of natural languages: where a _noun_ (a.k.a _substantive_, compare "name" and "subject to an effect") defines a constituent such as an array or its element, _verbs_ are functions, and modifiers are _adverbs_ in monadic form and _conjunctions_ in dyadic form.

In the example of `countWhere`, the modifier is the predicate of the function.
The predicate can be be implemented tacitly in BQN as a function train `⊣ > 2∘⊢`, where the circle is called _Atop_ which also corresponds to the Bluebird combinator.

Trains of form `⊣ F G∘⊢` are Dove combinators, which are represented in BQN as After `⟜`: `F ⟜ G`.
Thus `⊣ > 2∘⊢` can be simplified to `> ⟜ 2`.
A coarce implementation of `countWhere` might thus be defined as:

```bqn
Predicate ← >⟜2
CountWhere ← {≠/𝕎𝕩}
predicate CountWhere 1‿2‿3‿4‿5
```

Semantically `Predicate` is a function, and it can be passed as higher order function to `Where` by passing the lowercase name of it.
The `W` in `Where` denotes that the right hand side argument is passed in as function.

To separate the comparator verb from the argument, we need to refactor the function into an adverb, that is, a (monadic) 1-modifier.
This is done by adding an underscore to the function name:

```bqn
_CountWhere ← {≠/𝔽⟜𝕨𝕩}
2> _CountWhere 1‿2‿3‿4‿5
```

The `Predicate` function becomes redundant this way.
You can think of the underscore collecting the left hand side function as an argument `F`, to which we pass the value as left hand side parameter `w` using After like previously.
A grammatical description would be that the adverb has a verb `>` with a substantive `2`.

But, this implementation does not typecheck the Haskell implementation because the values before length function have indices, not array values in them.
To fix this, the filter functon has to be moved to the start of the `_CountWhere` function.
Concretely, what we need we need is:

```bqn
0‿0‿1‿1‿1 / 1‿2‿5‿4‿5
```

While we currently have:

```bqn
/ (0‿0‿1‿1‿1)
```

To implement the fix, we need to duplicate the `x` argument to both sides of the filter function `/`.
As such, similar to the Uiua solution, we need a notion of duplication in our solution.
BQN does not have a stack, but the same can be achieved with the Violet Starling or $\Sigma$ combinator which is the monadic version of Before `⊸` in BQN:

```bqn
{(𝔽𝕩) 𝔾 𝕩}
```

Let `F = 𝔽 ⟜ 𝕨`.

```bqn
{((> ⟜ 2)𝕩) 𝔾 𝕩}
```

Now `G = /` and `x = 1 2 3 4 5`.

```bqn
((> ⟜ 2) 1‿2‿5‿4‿5) / 1‿2‿5‿4‿5
```

The lollipop with one `x` is the same as `x < 0`.
Thus:

```bqn
(1‿2‿5‿4‿5 > 2) /  1‿2‿5‿4‿5
```

Calling `2> _CountWhere 1‿2‿5‿4‿5` sets the variables:

```BQN
_CountWhere ← {≠𝔽⟜𝕨⊸/𝕩}
2> _CountWhere 1‿2‿4‿4‿5
```

Which is more complicated way to say `≠/2>˜ 1‿2‿5‿4‿5`.
