

The corridors of PLDI had multiple mentions of [Uiua](https://www.uiua.org/), a stack-based array programming language.
As someone who has mostly been using BQN recently, I decided to give Uiua a quick try.

The relevant [ArrayCast podcast episode](https://www.arraycast.com/episodes/episode63-uiua) covers various details on the background of the language, including few off-hand mentions of _concatenative_ languages.
As the [APL Wiki on Uiua](https://aplwiki.com/wiki/Uiua) shows, Uiua has been influenced by languages called [Forth](https://en.wikipedia.org/wiki/Forth_(programming_language)), BQN, and J.

Some further digging referenced a blog post _[Why Concatenative Programming Matters](https://evincarofautumn.blogspot.com/2012/02/why-concatenative-programming-matters.html)_, which says that:

> Concatenative programming is so called because it __uses function _composition_ instead of function _application___ ...

The blog post then explains why these languages are often implemented as a stack-based languages, which now starts to tie to story to Uiua.

Another pattern that starts appearing are boxes and lines between them.
And indeed, some further digging presents us _[Joy compared with other functional languages](https://hypercubed.github.io/joy/html/j08cnt.html)_ which ties the concatenation of boxes into morphism of category theory.

Hence, notes on parallel compiler arise, which with the orbit of topics starts resembling the [HVM](https://github.com/HigherOrderCO/HVM) spiel which for anyone reading Hacker News is probably more familiar than anything insofar.

So, many interesting points, but what about Uiua again?

The blog post mentions the following piece of Haskell code:

```Haskell
countWhere :: (a -> Bool) -> [a] -> Int
countWhere predicate list = length (filter predicate list)
```

Which is used as such:

```Haskell
countWhere (>2) [1, 2, 3, 4, 5] == 3
```

This example is nice since it is very easy to understand, but coincidentally the predicate represents a higher order function.
Another important detail is to notice that the Haskell code returns a `[a]` after the predicate.
This means that instead the obvious array solution, which would return `[Bool]` on filter, we want to retain the array values before taking the length.

## Uiua

Unlike BQN and most other APLs, Uiua has no double meaning for symbols: your comparator `<` won't suddently turn into a enclose function when you lose the track of your tacit code.

The article on Joy has examples comparing combinatory logic and Joy.
An expression doing multiplications is shown:

```Joy
* 2 3 === (* 2) 3
```

In fact, the same applies in Uiua:

```
multiply 2 3 === (multiply 2) 3
```

Likewise, using the W (Warbler) combinator:

```
 (W f) x   =   (f x) x
```

Is done with Uiua to calculate the square as follows:

```
multiply duplicate 3
```

The duplicate is a Uiua stack operator.
To make it work over a list of numbers:

```
multiply duplicate [1 2 3]
```

Uiua calls this automatic lifting of the operations over a list a _pervasive_ function.
To implement the Haskell code, we can thus simply use:

```
>2 [1 2 3 4 5]
```

Which prints `[0 0 1 1 1]`. To run a filter over this view vector, we can use keep:

```
keep (>2 duplicate) [1 2 3 4 5]
```

Which prints `[3 4 5]`.
The parenthesis are redundant, but it highlights how the predicate with duplicate maps the parameters yielding `[0 0 1 1 1]` to the parenthesis, which keep uses then to select the values to be preserved.

Length can be used on this directly:

```
length keep (>2 duplicate) [1 2 3 4 5]
```

Printing us 3.

```Uiua
CountWhere! ← ⧻▽^!.
CountWhere!(>2) [1 2 3 4 5]
```

[Try it](https://www.uiua.org/pad?src=0_12_0-dev_1__Q291bnRXaGVyZSEg4oaQIOKnu-KWvV4hLgpDb3VudFdoZXJlISg-MikgWzEgMiAzIDQgNV0K)


## BQN

BQN supports higher order functions.

The predicate in BQN can be implemented as a function train `⊣ > 2∘⊢`.
Trains of form `⊣ F G∘⊢` are Dove combinators, which are represented in BQN as After `⟜`: `F ⟜ G`.
Thus:

```
⊣ > 2∘⊢ === > ⟜ 2
```

A coarce implementation of `countWhere` might thus be defined as:

```
Predicate ← >⟜2
CountWhere ← {≠/𝕎𝕩}
predicate CountWhere 1‿2‿3‿4‿5 === 3
```

Semantically `Predicate` is a function, and it can be passed as higher order function to `Where` by passing the lowercase name of it.
The `W` in `Where` denotes that the right hand side argument is passed in as function.

To disharge the comparator from the argument, we need to refactor the function into a 1-modifier.
This is done by adding an underscore to the function name:

```
_CountWhere ← {≠/𝔽⟜𝕨𝕩}
2> _CountWhere 1‿2‿3‿4‿5
```

The `Predicate` function becomes redundant this way.
You can think of the underscore collecting the left hand side function as an argument `F`, to which we pass the value as left hand side parameter `w` using After like previously.

But, this implementation is not faitful to the Haskell implementation because the values before length function have indices, not array values in them.
To fix this, the filter functon has to be moved to the start of the `_CountWhere` function.
Concretely, what we need we need is:

```
0 0 1 1 1 / 1 2 3 4 5
```

While we currently have:

```
/ (0 0 1 1 1)
```

Which outputs `2 3 4`.

To implement the fix, we need to duplicate the `x` argument to both sides of the filter function `/`.
As such, similar to the Uiua solution, we need a notion of duplication in our solution.
BQN does not have a stack, so we do not have stack functions.
But, the same can be achieved with the Violet Starling combinator which is the monadic version of Before `⊸` in BQN:

```
(Fx) G x
```

Let `F = 𝔽 ⟜ 𝕨`.

```
((> ⟜ 2)𝕩) G x
```

Now `G = /` and `x = 1 2 3 4 5`.

```
((> ⟜ 2)[1 2 3 4 5]) / [1 2 3 4 5]
```

The lollipop with one `x` is the same as `x < 0`.
Thus:

```
([1 2 3 4 5] > 2) / [1 2 3 4 5]
```

Calling `2> _CountWhere 1 2 3 4 5` sets the variables:

```BQN
_CountWhere ← {≠𝔽⟜𝕨⊸/𝕩}
2> _CountWhere 1‿2‿4‿4‿5
```

Which is more complicated way to say `≠/2>˜ 1‿2‿5‿4‿5`.

