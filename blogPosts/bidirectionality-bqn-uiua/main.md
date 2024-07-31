
# Beyond combinators is bidirectionality

A common design direction in both BQN and Uiua could be said to be an increased focus on tacit programming using modifiers, compared to their predecessors.
It is apparent that the core of the languages arise from implementation of different combinators which are then used to pass around adverbs and conjuncations around.

However, the languages also reach beyond combinators with _inverses_.
The implementation of inverses leverage another semantical constraint of array languages, which is the finite set of verbs that form the "standard library" of the langauges.
Every verb in has language-defined inverse definition.

The inverse definitions are used to implement two modifiers that are not combinators: the 1-modifier _Undo_, and the 2-modifier _Under_. And while both of these exist in other array languages, a special case of Under called _structural Under_ makes Uiua and BQN interesting languages to implement various _bidirectional transformations_.

The connectivity to bidirectional transformation arises from the categorical classification of Under: the computational Under is a _conjugation_ and the structural Under is a _lawful lens_.
Because the array languages implement these structures in an ergonomic manner, BQN and Uiua happen to turn into interesting languages for applications.
Of these applications, we next focus on the lens for its relevance to a topical relevance to accelerator compilation.

## APL: A Profunctor Language

To understand the categorical underpinnings of Under, we start by explaining contravariance.
Consider the following composition which checks if the length of an array is less than 21:

```uiua
<21 ⧻ ⇡20
```

Here, the function application corresponds to `f g h = f (g h)`.
If we would like to abstract this pattern to a three-argument composition function, we can do so with Uiua macros:

```
Comp‼! ← ^!^!^!
Comp‼! <21 ⧻ ⇡20
```

Something worth noting is that there is no distinction of a noun and a verb here. So, the above definition of `Comp` applies both for composition and a map.
Further, the whole definition is redundant: while the macro expects three arguments, as signified by the three bangs, any additional argument would get concatenated to the right and applied as such.
In other words, the Haskell `(.)` is always redundant in Uiua.

To  make the function application contravariant, we can reverse the function composition using macros again but now with a stack modifier flip `^:` as follows:

```uiua
# f g h = g (f h)
Contra‼! ← ^!^!^:^!
Contra‼!⧻ (<21) ⇡20
```

The macro reads as follows: `f g flip h = g f h = g (f h)`.

We can next consider implementing the following Haskell code in Uiua:

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

Implementing a profunctor is redundant because of rank polymorphism.
What suffices instead is implementing dimap: `dimap f g h = g . h . f`.

However, dimap cannot be implemented using the stack modifiers.
This is because the macros are indeed macros, not pure higher order functions.
Given the current set of stack modifiers in Uiua, it is not possible to reorder function arguments as required by dimap:

```
.   duplicate   Duplicates the top value of the stack
,   over        Duplicate the second-top value of the stack
:   flip        Swap the top two values of the stack
◌   pop         Discard the top value of the stack
∘   identity    Do nothing with one value
```

In specific, when Uiua runs into the macro _placeholder_ `^`, where the next token is either one of the above stack modifiers, or a function call `!`, the argument gets evaluated.
In other words, it is not possible to postpone evaluation.

However, there is one more trick in the book, which is called array macros.
Array macros puts the operands in an array, which can then be manipulated arbitrarily using normal array code.
This works as a form of preprocessing: the expression first reorders arguments, after which all functions are run using normal composition order.
Semantically:

```
Macro =^ (preprocessing)
```

This turns out to be very powerful way to control function application.
Also, the bangs are still needed, because this captures the arguments that the preprocessing block operates on.

Now, consider the dimap definition `dimap f g h = g . h . f` again.
We can see that this corresponds to `rotate 1`: `rotate 1 [f g h] = [g f h]`.

The functions in the resulting array do not need separate deconstruction.
As such, we can now implement the Haskell code above as such:

```
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

Definition. Dimap is a three-bang array macro of rotate 1: `dimap f g h = Dimap‼! ←^ ↻1 = Dimap!!! g h f`

However, bidirectional transformations like the profunctor can be simplified by using Under, which abstracts away the lens structure.
Consider the following code for `CapPhrase`:

```uiua
⍜⊜⊢⌵⊸≠@  "here are some words"
```

Prining us `"Here Are Some Words"`.
This is made possible because Uiua is able to find the inverse definition of the `Words` function automatically for us.
In specific, this is structural Under in action, as the shape of the input array is preserved.
The structural Under concerns bidirectionality in the _shape_ of the input.
This is in contrast with _computational Under_ which requires mathmetical invertibility of the function, and is, as such, much more rare.

### Defining Under

The definition of Under uses the 2-modifier _Over_: `F○G`.
The Over in the unified representation is BQN is `{(Gw)FGx}`, which corresponds to the Bluebird combinator with one argument, and the Ψ Combinator with two arguments.

While structural and computational Under are implemented in different ways, they are compatible using a single glyph because of a unification principle `(𝔾 𝕨𝔽⌾𝔾𝕩) ≡ 𝕨𝔽○𝔾𝕩`.
The expression is arguably easier to parse when setting `z←𝕨𝔽⌾𝔾𝕩`, it now corresponds to `(𝕨𝔽○𝔾𝕩) ≡ 𝔾z`.
Further, let `v←𝕨𝔽○𝔾𝕩`, then `v≡𝔾z`.
Here, `v`'s well-definess comes from combinatory logic, so the task is to use `G` and `z` to distinguish the applicable definition from the following cases:

- Invertible Under: If 𝔾 is uniquely invertible on v, that is, v≡𝔾z has a unique solution for z, then the result of Under is that solution.
- Structural Under: If 𝔾 is a structural function (to be defined below) and v is compatible with 𝔾 on 𝕩, then the result is obtained by inserting v back into 𝕩.
- Computational Under: If 𝔾 is provably not a structural function, then the result is 𝔾⁼v if it is defined, where $^=$ is Undo.

While the full list of inverse definitions is [exhaustively documented](https://mlochbaum.github.io/BQN/spec/inferred.html), what we note here is that colloquially structural Under is defined with a constraint of not discarding argument elements.
In a dependetly typed setting, if our input argument x is of form `List 4 Int`, then the result of Under should match this initial type.
Thus, for structural Under to be applied, the constraint above must be satisfied.
Else, G must be exactly invertible in a mathematical sense.
Otherwise, Under cannot be applied, and a runtime error is raised.

Classi

