# |title|

_|description|_

![BQN is an underrated programming language.
I will try to convince you why: it has a built-in In-N-Out function. _Image Source_: In-N-Out](./img/innout.avif)

First, some background: [BQN](https://mlochbaum.github.io/BQN/) is an array programming language like APL but more Haskell-esque.
An interesting combinator implemented by BQN is a so-called ["Under"](https://mlochbaum.github.io/BQN/doc/under.html) a.k.a "Dual".
This operation is represented in the language as $\circledcirc$.
This "donut" and its history in APL was covered in a recent Dyalog blog post titled _[Structural vs. Mathematical "Under"](https://www.dyalog.com/blog/2023/01/structural-vs-mathematical-under/)_.
As that title suggests, Under exists in the forms of _structural_ and _mathematical_.
In BQN, both are implemented behind the same donut [squiggol](https://www.cs.ox.ac.uk/people/jeremy.gibbons/publications/squiggol-history.pdf).

This blog post presents more about this donut, followed by a "fairly simple" program that uses structural under for text templating.
I call that templating program `barbell` (available on [GitHub](https://github.com/jhvst/barbell)).
In fact, even this webpage is generated with it!

A no-code example of Under, which is particularly Finnish of me, is eating salty liquorice.

1. You eat salty liquorice to get a sugar high and high blood pressure (function $\mathbb{G}$) with a bag of Super Salmiakki (parameter $\mathbb{x}$).
2. _Under_ the influence of this newly-found jolt of energy, you complete function $\mathbb{F}$ using $\mathbb{x}$ with an optional additional parameter $\mathbb{w}$.
3. However, when you became under the influence, you entered into an implicit contract, which is completing the _inverse_ function of $\mathbb{G} \mathbb{x}$ eventually.
In this example, it could mean that you manage the sugar crash.
4. Further, as a side-effect of your acts in the second part, you have changed the value of your bag of Super Salmiakki $\mathbb{x}$ in the end (but the overall bag itself is not consumed).

Given this description, the following definition of Under in BQN might be more digestible (do notice that BQN is read right to the left):

$\mathbb{w F} \circledcirc \mathbb{G x}$

Semantics-wise, it is interesting that the action of undoing $\mathbb{G}$ is figured by BQN as of _automagically_.
But there is little actual magic happening.
Instead, BQN leverages its inverse operation $^=$ called [Undo](https://mlochbaum.github.io/BQN/doc/undo.html).
Undo is defined using pre-existing constructs:

$\mathbb{F} \circledcirc \mathbb{G} = \mathbb{G}^= \circ \mathbb{F} \bigcirc \mathbb{G}$

This reads as apply $\mathbb{G}$ over (do $\mathbb{G}$, then pass the result to the next function) $\mathbb{F}$ composed with the inverse of $\mathbb{G}$.

This creates a trick in which the interpretation goes "in and out" of $\circledcirc$.
The out part, the inverse, makes BQN an exciting language to toy with inverses.
Notably, you do not have to use a "side effect" to use the inverse:

```bqn
    2 ⌽ "abcde"
"cdeab"

    2 ⌽⁼ 2 ⌽ "abcde"
"abcde"
```

The expression is indented, and the output is not. This is a [tradition](https://www.youtube.com/watch?v=_DTpQ4Kk2wA) of APL and its derivatives.

More relevantly to templating, when doing [Advent of Code 2022 in BQN](https://mlochbaum.github.io/BQN/community/aoc.html), I found the Under operation fascinating due to its capability to stream array structure.
In particular, this example:

```bqn
  ⟨ "ab", "cde", "fg" ⟩ ⊣⌾∾ ⟨ "---", "----" ⟩
⟨ "abc" "defg" ⟩
```

So, the operation's result is `⟨ "abc" "defg" ⟩`. Here, $\sim$ (join) is $\mathbb{F}$, which turns the dashes into a single long string.
Next, the left identity $\dashv$ ($\mathbb{F}$) replaces the dashes with the left argument $w$ `⟨ "ab", "cde", "fg" ⟩`.
Then, the replaced array gets passed _back_ to $\mathbb{G}$.
The inverse of $\sim$ reshapes the flat string back into the shape of $x$ -- three and four elements -- while preserving the values from $w$.

This makes BQN feel rather magical -- even in Haskell, you don't automatically get inverses of functions.
And frankly, I don't know any other language in which you do.
Similarly, you could ask yourself how often does code "turn back" on a single line?

Does this even make sense?
Seemingly yes -- there is a categorical story to Under.
My DPhil supervisor **Jeremy Gibbons** noted the following:

> That page about "under" is very interesting. The operation is also known as [conjugation](https://en.wikipedia.org/wiki/Conjugacy_class) - specifically when the two transformations are inverses. And it's also the functorial action ("map") of the function type constructor ($→$), a bifunctor:

```haskell
bimap :: (b → b') → (a' → a) → (a → b) → (a' → b')
bimap g f k = g . k . f
```

>(note that ($→$) is contravariant in its left argument, to the type of $f$ above is the opposite of what you might first think). What they call "structural under" is captured by a lens, with a "get" (to extract some component) and a "put" (to store an updated copy of that component). And "mathematical under" and "structural under" are indeed closely related: there's a story about lenses in terms of "profunctors", and ($→$) is the simplest profunctor.

The comment introduces to look at structural under as a [lens](https://ncatlab.org/nlab/show/lens+%28in+computer+science%29#).
A rudimentary example of a lens-in-action is a database view over the `deletedAt` field: choosing data and providing a partial view to it.
There is also the write part.
The mutation finds its way back with the same lens construct that selects a _view_ $v$ from a _source_ $s$.
Say the view is a joined view.
The update returns the changes $v$ to the corresponding (but separate) tables $s$.
This way, the same method to read the information "routes" back also for writes.

The BQN author **Marshall Lochbaum** also rejoiced:

> Oh cool! I knew about conjugation, and I've always assumed (not sure I've seen an explicit reference) that it was a major influence when Iverson designed APL's Dual, which is just the mathematical part. Vaguely aware of lenses; the interesting part with structural Under is that the put is uniquely determined by the get, plus the set of all possible get functions (structural functions here, and I don't know what other sets would allow it).

Iverson refers to the late **[Kenneth Iverson](https://amturing.acm.org/award_winners/iverson_9147499.cfm)**, who designed APL.

_Uniquely determined_ is another way of saying that structural Under is a partial map over the values of $x$ where the $\mathbb{G}$ defines the components that are affected.
The uniqueness comes from the left side of the donut.
That is, there is no way to change _where_ the values will be returned, only _what_.
Further, you get a runtime error if you fail to fulfill the contract to undo $\mathbb{G x}$ back to the original _shape_ of $x$.

Lochbaum continues:

> Come to think of it, Iverson was probably more influenced by the form [$S^{−1}AS$ in linear algebra](https://en.wikipedia.org/wiki/Matrix_similarity), a special case of conjugation.

>Reading up on profunctor optics (and just saw "Our group would like to thank Jeremy Gibbons, **Jules Hedges** and **David Jaz Myers** for helpful discussion on the topic"!). Being able to compose them adds some structure. Seems like something like a lens starting at $T \times T$ that extracts the first component but puts it back in the second position would be possible. So more structure is needed; "lawful optics" sounds promising.

To comment on composition -- an example I came up with is: `((2⥊1↑⊢)⌾(0‿8⊏⥊))⌾∾(3‿2⥊2)‿(3‿2⥊1)`.
This creates two $3x2$ matrices, one with only $2$'s and one with $1$'s.
First, the parameters are joined into a cuboid.
Then, the first Under flattens the array and picks the 0th (first element of the first matrix) and 8th (the third element of the second matrix).
The second Under then copies the first element twice and returns it.
As a result, you get:

```bqn
┌─
· ┌─      ┌─
  ╵ 2 2   ╵ 1 1
    2 2     2 1
    2 2     1 1
        ┘       ┘
                  ┘
```

This is, however, not that of a great example as the expression is functionally equivalent to a composition in the $\mathbb{G}$ `(2⥊1↑⊢)⌾(0‿8⊏⥊∘∾)(3‿2⥊2)‿(3‿2⥊1)`.

Nevertheless, Lochbaum continued:

>Did you ever link [to the spec](https://mlochbaum.github.io/BQN/spec/inferred.html#under) for this by the way? Very dense, but it does have a mathematical definition and proof that it's well defined. We did recently find a gap where functions like `⥊` that automatically enclose an atom don't qualify as structural, but that's not important from the perspective of a language that wouldn't define that sort of thing.

>([Here in Operators and Functions](https://www.jsoftware.com/papers/opfns1.htm#8), which I believe is Iverson's first publication about Dual, he relates it to "the notion of dual functions implicit in deMorgan's law", which is the two-argument case. Nothing here to connect it to conjugation actually.) 

After some quick thinking, Marshall added:

>Okay, relationship of BQN Under to lenses. It's clear that a function $\mathbb{F}$ and its structural inverse taking $s$, $v$ to $v \dot \circledcirc \mathbb{F} s$ satisfy the lens laws where they're defined:
>
```
Law     Math                           BQN
GetPut  put(s, get(s)) = s             s ≡ ⊢⌾F s
PutGet  get(put(s, v)) = v             v ≡ F v˙⌾F s
PutPut  put(put(s, w), v) = put(s, v)  (v˙⌾F s) ≡ v˙⌾F w˙⌾F s
```

These laws are from the [ncat page of a lens](https://ncatlab.org/nlab/show/lens+%28in+computer+science%29).
The page lists the three lens laws above GetPut, PutGet, and PutPut.
Lochbaum was also quick to note the importance of PutPut:

>(Not so obvious why PutPut is important: consider a getter function `F←⊑` that gets the first value in a pair, but a setter function `v¨⍟(v≢⊑)s` that leaves $s$ alone if the first value is $v$ but sets both values to $v$ if not.)

>A lens following these laws is "lawful" or "very well-behaved". I can't find a reference stating exactly this, but it seems like a given getter function can only be part of one lawful lens. There's always an isomorphism that splits a getter argument into the part that gets got and the part that doesn't, at which point you can define the setter to replace the gotten part and undo the isomorphism. But the isomorphism isn't unique so that's not a full proof.

>But Under doesn't actually define a lens because the put function `v˙⌾F s` is partial: not all combinations of values $s$ and $v$ from the domain and range of $\mathbb{F}$ can be used. For example `↕3` is in the domain of `⊏`, but `(↕3)⌾⊏2‿2⥊0` is an error. This is the hard part of the definition, and why I need the concept of a "structural function decomposition": each structure transformation in the decomposition is actually a lens. Still, knowing lens theory seems very useful so I'll keep reading. Will probably put some reference to lenses in the Under documentation when I have a clearer idea of what's going on, in case it helps any Haskell programmer reading.

This is a remark that has connections to dependent types.
Many research languages that have modeled array programming languages' main language feature, _rank polymorphism_ statically, have used dependent types to do so.
Examples of these efforts include [Remora](https://arxiv.org/abs/1912.13451), [Futhark](https://futhark-lang.org/blog/2023-05-12-size-type-challenges.html), Google [Dex](https://github.com/google-research/dex-lang), and a paper from my DPhil advisor [_APLicative Programming with Naperian Functors_](https://www.cs.ox.ac.uk/people/jeremy.gibbons/publications/aplicative.pdf).
In a dependent type setting, such language _could_ permit a partial update by using the shape lengths on $\mathbb{G}$ to figure out which values were actually used and not.
This does not make sense in the context of a lens, since it would break the lens laws, but could make sense when you want to add a vector into another vector with a different length.
In this sense, this also links up the research on _quantitative type theory_, which can model the operational semantics of operations to _precisely_ identify redundant values.
But the rest of the story is for another time.

With this, I thought what a fine motivation to practice using lenses and BQN!
So, I applied it to a pet peeve: HTML templating.
For that, I created a tool I call `barbell`.

## Barbell for HTML templating

Barbell is a simple templating tool that works similarly to [Handlebars](https://handlebarsjs.com).

Templating comes relevant with HTML page generation when you want to have "components" or _[imports](https://web.dev/imports/)_ to avoid redefining your `<head>` and `<footer>` elements on every page. For example:

```HTML
<html>
<head>
  <title>{{ title }}</title>
</head>
<body>
  {{ body }}
</body>
</html>
```

Handlebars would replace `{{ title }}` and `{{ body }}` with data provided by the programmer.
After ten years of programming, I have had my fair share of different templating libraries like Handlebars, EJS of ExpressJS, and Go's `html/template` package.
However, these mainly work for dynamic web applications and are language-specific.
My website is a rather messy collection of static HTML pages created over the years, for which these templating libraries do not work particularly well for.

So, what I wanted to do with `barbell` was something that worked nicely in a shell environment because that _has_ been persistent for me.
Also, I wanted something that plays nicely with Nix, which I use in my current workflow extensively.
Nix, as a package manager, can abstract away the languages and frameworks -- as long as I get the tools to print to the shell, I could use them with `barbell`.
And given the previous description of BQN, I also wanted to do this with BQN.
This introduces the extra convolution of doing the update in-place!

Aside from the in-place update, my approach is relatively standard -- find the tokens in which the key character is, mark those, and then create a valid input to Under.
So, we first recognize we are going to use a lens with Under.
The rest of the program is about preparing the input so that it can be given to Under.
Effectively:

1. `barbell template.html` would first search the current directory for files with a filename ending in `.bar`
2. read `.bar` files and create pairs in which `"{name_of_file}": "contents_of_file"`
3. map the contents to `template.html`
4. print the `template.html` with the values changed

## Implementation

I will skip how `input` and `pairs` work when reading files because this is rather uninteresting, considering how the templating works.
What matters instead is the steps to prepare us to use Under.
Eventually, we want something like the following:

```bqn
    1‿2‿3⊸+⌾(1‿1‿0‿1⊸/) 10‿20‿30‿40
⟨ 11 22 30 43 ⟩
```

Here, BQN applies a transformation to the right argument selectively by using a view vector.
In the cells that are $1$, it applies the argument at the same index as the left argument.

We first define `b` and `e` to correspond to the beginning and end markers of the "bar" tokens we look for.
$\underline{\in}$ is a "find" which returns the indices in which the token is found.
The end token result is shifted to the right to capture the token into the fragment from which it started from (hence, we call the resulting fragment vector `frags`):

```bqn
pairs ← ⟨⟨"name", "Juuso"⟩, ⟨"unmatched", "foobar"⟩⟩
input ← "hello {name} :)"

b ← "{"⍷input
e ← »"}"⍷input

•Show b
•Show e
```

This yields us:

```
⟨ 0 0 0 0 0 0 1 0 0 0 0 0 0 0 0 ⟩
⟨ 0 0 0 0 0 0 0 0 0 0 0 0 1 0 0 ⟩
```

These view vectors shows us the locations in which the tokens `{` and `}` were found, defaulting otherwise to $0$.
Next, we apply a sum scan:

```bqn
pairs ← ⟨⟨"name", "Juuso"⟩, ⟨"unmatched", "foobar"⟩⟩
input ← "hello {name} :)"

b ← "{"⍷input
e ← »"}"⍷input

•Show (+`e+b)
```
Giving us:

```
⟨ 0 0 0 0 0 0 1 1 1 1 1 1 2 2 2 ⟩
```

A sum scan makes sense only if we know about BQNs group operation $\cup$. Given a vector such as the one above, it partitions the input:

```bqn
pairs ← ⟨⟨"name", "Juuso"⟩, ⟨"unmatched", "foobar"⟩⟩
input ← "hello {name} :)"

b ← "{"⍷input
e ← »"}"⍷input

frags ← (+`e+b) ⊸ ⊔ input
•Show frags
```

Returning:

```
⟨ "hello " "{name}" " :)" ⟩
```

This output `frags` is what we want to pass as the right argument to Under.
Next, we need a _mask_ that uses `frags` to find us the indices in `pairs` where we have a matching key (if a key is not found, it should not be replaced).
But first, we have to separate keys and values from `pairs`:

```bqn
pairs ← ⟨⟨"name", "Juuso"⟩, ⟨"unmatched", "foobar"⟩⟩
input ← "hello {name} :)"

b ← "{"⍷input
e ← »"}"⍷input

frags ← (+`e+b) ⊸ ⊔ input
keys ← {⊑𝕩}¨pairs
vals ← {1⊑𝕩}¨pairs

•Show keys
•Show vals
```

These definitions gives us what we want:

```
⟨ "name" "unmatched" ⟩
⟨ "Juuso" "foobar" ⟩
```

What happens here is that `¨` iterates the pairs after which we apply a selection function `⊑`.
The brackets distinguish that the selection operation should happen to the iterator values.
As such, `{⊑𝕩}` defaults to the first cell, and `{1⊑𝕩}` to the second.
If we also mess with the `keys` expression, we can add bars to it: `{∾"{"‿(⊑𝕩)‿"}"}`.
This will wrap each key with the bars, giving this output instead:

```
⟨ "{name}" "{unmatched}" ⟩
⟨ "Juuso" "foobar" ⟩
```

Next is the mask.
I cannot say that I instantly realized this is a single operation:

```bqn
pairs ← ⟨⟨"name", "Juuso"⟩, ⟨"unmatched", "foobar"⟩⟩
input ← "hello {name} :)"

b ← "{"⍷input
e ← »"}"⍷input

frags ← (+`e+b) ⊸ ⊔ input
keys ← {∾"{"‿(⊑𝕩)‿"}"}¨pairs
vals ← {1⊑𝕩}¨pairs
mask ← frags∊keys

•Show mask
```

Giving us:

```
⟨ 0 1 0 ⟩
```

Unwrapped, the definition of `mask` is easier to understand: `⟨ "hello" "{name}" " :)" ⟩ ∊ ⟨ "{name}" "{unmatched}" ⟩`.
So, it says that the corresponding value was found, but does not return its index.
That is, if we would replace `{name}` in the input with `{unmatched}`, we would get the same result.
Instead, we need to use `keys ⊐ frags` to get the indices in `keys`.
This would print us `⟨ 2 0 2 ⟩` -- notice that if the value is not found, it gives an index that is one more than the length of the `keys` vector.
We can use this fact to filter `/` the results by comparing each value against the length of the `keys` or `pairs`: `≠pairs` or alternatively re-using our `mask` variable:

```bqn
pairs ← ⟨⟨"name", "Juuso"⟩, ⟨"unmatched", "foobar"⟩⟩
input ← "hello {name} :)"

b ← "{"⍷input
e ← »"}"⍷input

frags ← (+`e+b) ⊸ ⊔ input
keys ← {∾"{"‿(⊑𝕩)‿"}"}¨pairs
vals ← {1⊑𝕩}¨pairs
mask ← frags∊keys
values ← (mask / keys ⊐ frags)
```

Yielding:

```
⟨ 0 ⟩
```

So, this $0$ now means to get the contents at the index $0$ of `vals`.
We now need a map.
To do this we can append `⊏ vals` to the expression of `values`.
So, we refactor values to `values ← (mask / keys ⊐ frags) ⊸ ⊏ vals` to get `⟨ "Juuso" ⟩`
Here, the lollipop creates a precedence: where the handle points to will be computed first, which then passes as the left argument to `⊏`.

We now have everything needed for Under:

```bqn
pairs ← ⟨⟨"name", "Juuso"⟩, ⟨"unmatched", "foobar"⟩⟩
input ← "hello {name} :)"

b ← "{"⍷input
e ← »"}"⍷input

frags ← (+`e+b) ⊸ ⊔ input
keys ← {∾"{"‿(⊑𝕩)‿"}"}¨pairs
vals ← {1⊑𝕩}¨pairs
mask ← frags∊keys
values ← (mask / keys ⊐ frags) ⊸ ⊏ vals
•Show values⌾(mask⊸/) frags
```

Printing:

```
⟨ "hello " "Juuso" " :)" ⟩
```

Now, unwrapping the Under corresponds to:

```bqn
[ "Juuso" ] ⌾ ([0, 1, 0]⊸/) [ "hello ", "{name}", " :)" ]
```

Finally, by concatenating this with $\sim$, we get `hello Juuso :)`. Our complete code looks as such:

```bqn
pairs ← ⟨⟨"name", "Juuso"⟩, ⟨"unmatched", "foobar"⟩⟩
input ← "hello {name} :)"

b ← "{"⍷input
e ← »"}"⍷input

frags ← (+`e+b) ⊸ ⊔ input
keys ← {∾"{"‿(⊑𝕩)‿"}"}¨pairs
vals ← {1⊑𝕩}¨pairs
mask ← frags∊keys
values ← (mask / keys ⊐ frags) ⊸ ⊏ vals
•Show ∾values⌾(mask⊸/) frags
```

## Discussion

A takeaway of this example is recognizing from the get-go that our program is a lens, and then preparing the data such that it can be consumed by the construct.

Why this is different from a simple `strings.Replace` function is that the Under is not modifying the original fragment vector -- it is instead providing us a _view_ in which the contents are "streamed" from the left-hand side as seen on this original example:

```bqn
⟨"ab", "cde", "fg" ⟩ ⊣⌾∾ ⟨"---", "----" ⟩
```

Moreover, because it's array-based, it's a "single pass" operation, meaning that, in theory, the replacement operation can be run in parallel.
"Accidental" parallelism is the reason why I got interested in APL and other array programming languages in the first place: the parallelism comes as if it would be "free" -- I never particularly thought about how my code could be performed in parallel, but in the end it did!
This is in stark contrast even with the fancier programming languages with affine types like Rust, which does make parallel programming easier via libraries like `rayon`, but still requires explicit headspace from the programmer.

## Changing {} to bars ||

But wait there is more!
It is about the tokens given in `b` and `e`: the solution is specific to $b \ne e$.
If we instead define the token as `|` (arguably a more proper symbol for a bar), the sum fold gets upset:

```bqn
pairs ← ⟨⟨"name", "Juuso"⟩, ⟨"unmatched", "foobar"⟩⟩
input ← "hello |name| :)"

b ← "|"⍷input
e ← "|"⍷input

frags ← (+`e+»b) ⊸ ⊔ input
keys ← {⊑𝕩}¨pairs
vals ← {1⊑𝕩}¨pairs
mask ← frags∊keys
values ← (mask / keys ⊐ frags) ⊸ ⊏ vals
values⌾(mask⊸/) frags
```

Printing:

```
["hello ", "|", "name", "|"," :)"]
```

This is still workable but requires removing the found bars.
We do this by adding the following:

```bqn
changed ← {⟨𝕩-1,𝕩,𝕩+1⟩}¨(({⟨1,0,1⟩≡𝕩}¨(¯3↑¨1↓↑frags ∊ reps))⊸/) ({𝕩-1}¨↕≠frags)
nmask ← {+´𝕩⍷(∾changed)}¨↕≠frags
neighbors ← ∾{⟨↕0,(1⊑𝕩)⊑reps,↕0⟩}¨changed
∾neighbors⌾(nmask⊸/) reps
```

Now, this is disgusting, but bear with me -- in `changed`, we create a three-element sliding window, a.k.a stencil.
This variable collects indices in which it found in the result of the first Under, i.e., `"|", "name", "|"`, creating a matrix.
The output, in this case, would be `⟨ ⟨ 0 1 2 ⟩ ⟩`.

In `nmask`, the indices in `changed` are turned into a view vector of the shape of the `frags`.
This would output `⟨ 0 1 1 1 0 ⟩`.

In `neighbors` the indices in `changed` are used to collect elements from the original result while leaving the `|` s into empty arrays.
This would output `⟨ ⟨⟩ "Juuso" ⟨⟩ ⟩`.

Finally, we use the Under operation again.
Concatenating an empty array gets coalesced into an empty string, which is a happy little accident.
The complete code looks as such:

```bqn
pairs ← ⟨⟨"name", "Juuso"⟩, ⟨"unmatched", "foobar"⟩⟩
input ← "hello |name| :)"

b ← "|"⍷input
e ← "|"⍷input

frags ← (+`e+»b) ⊸ ⊔ input
keys ← ⊑⌜pairs
vals ← ⊑∘⌽⌜pairs
mask ← frags∊keys
values ← (mask / keys ⊐ frags) ⊸ ⊏ vals
reps ← values⌾(mask⊸/) frags

•Show changed ← {⟨𝕩-1,𝕩,𝕩+1⟩}¨(({⟨1,0,1⟩≡𝕩}¨(¯3↑¨1↓↑frags ∊ reps))⊸/) ({𝕩-1}¨↕≠frags)
•Show nmask ← {+´𝕩⍷(∾changed)}¨↕≠frags
•Show neighbors ← ∾{⟨↕0,(1⊑𝕩)⊑reps,↕0⟩}¨changed
∾neighbors⌾(nmask⊸/) reps
```

Issuing:

```
"hello Juuso :)"
```

Also, `keys` and `vals` can now use a table `⌜` instead of an iterator coupled with the reverse `⌽` to get the equivalent output.

## Wrapping up

The final code with file reading and `stdout` printing looks like this:

```bqn
pairs ← {⟨¯4↓𝕩,(•file.Chars •wdpath∾"/"∾𝕩)⟩}¨{4=+´¯4↑𝕩∊".bar"}¨⊸/•file.List •wdpath∾"/."
input ← •file.Chars •wdpath∾"/"∾ ⊑ •args

b ← "|"⍷input
e ← "|"⍷input

frags ← (+`e+»b) ⊸ ⊔ input
keys ← ⊑⌜pairs
vals ← ⊑∘⌽⌜pairs
mask ← frags∊keys
values ← (mask / keys ⊐ frags) ⊸ ⊏ vals
reps ← values⌾(mask⊸/) frags

changed ← {⟨𝕩-1,𝕩,𝕩+1⟩}¨(({⟨1,0,1⟩≡𝕩}¨(¯3↑¨1↓↑frags ∊ reps))⊸/) ({𝕩-1}¨↕≠frags)
nmask ← {+´𝕩⍷(∾changed)}¨↕≠frags
neighbors ← ∾{⟨↕0,(1⊑𝕩)⊑reps,↕0⟩}¨changed
•Out ∾neighbors⌾(nmask⊸/) reps
```

The source code is [on GitHub](https://github.com/jhvst/barbell) wrapped into a bash script.
To run the tool, anyone with Nix installed with Flakes support can run `nix run github:jhvst/barbell -- foobar.html` where `foobar.html` is the template.

To create a static web page using `barbell`, you see the [source code](https://github.com/jhvst/jhvst.github.io/blob/main/blogPosts/barbell/flake.nix) of this page.
The webpage can also be reproduced as follows: `nix build "github:jhvst/jhvst.github.io?dir=blogPosts/barbell"`, followed by `open result/barbell.html`.

This is the power of Nix Flakes!
The flake even has a Neovim configuration for those who want to try out BQN. You can run this with `nix run github:jhvst/barbell#neovim -- example.bqn`.

Finally, this program only provides a get function for the lens: it takes a collection of files and provides a unified view, which we can stream to a file with `stdout`.
An improvement would be to also implement the writing part.
Imagine that you'd now change a part in the joined file in a text editor, and then the changes would also propagate back to the original files.
This would need the whole program to have an inverse, which is a bit more tricky because it would imply that none of the operations would lose information.
Can it be done?
Maybe, but that's left for future work.

Thanks for Jeremy Gibbons and Marshall Lochbaum for the comments in this blog post, and **Tom Schrijvers** for the donut name :)
