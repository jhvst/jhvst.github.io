
# Barbell: Templates in BQN

_[Barbell](https://github.com/jhvst/barbell) is like the templating system Handlebars, but with BQN's Under doing the heavy lifting_

BQN is an underrated programming language. I will try to convince you why: it has built-in In-N-Out function.

In addition to being open-source, BQN has interesting squiggols like ⌾ a.k.a "Under or "Dual". I also like the name "donut" because it looks like one. There is also a [Dyalog blog post](https://www.dyalog.com/blog/2023/01/structural-vs-mathematical-under/) with more historical background. The [BQN documentation page describes](https://mlochbaum.github.io/BQN/doc/under.html) it as a 2-modifier, which means that it is "dyadic" in functions arguments. Arguments $w$ and $F$ are the left side arguments, and $G$ and $x$ are the right side:

```c
𝕨𝔽⌾𝔾𝕩
```

BQN is read right to left. Under is a sort of commitment on $G$. You can go beyond the donut, but to return, you must handle the result of $G x$ with $w$ and $F$ such that you can undo $G$. It is like drinking a lot of alcohol: you can drink (function $G$) one vodka (bottle) $x$, and then do $F$ with $w$, but eventually must handle the precussion of undoing $G x$ (and you will have lost your bottle of vodka $x$). Further, the bottle has nothing to do with the undo function anymore (I hope), but the effect with $w$ and $F$ certainly do.

The interesting thing is that what does "undoing" of $G$ mean is decided by BQN. Here, BQN leverages its inverse operation `⁼` called [Undo](https://mlochbaum.github.io/BQN/doc/undo.html). So, Under is not doing anything magical of its own, it is reusing the already defined constructs (`𝔽⌾𝔾 = 𝔾⁼∘𝔽○𝔾`) to create a trick in which the interpretation goes "in n out". This makes BQN an interesting language to toy with inverses, since one is not limited to using a "a side effect" of the $F$ to check if an inverse is found:

```c
    2 ⌽ "abcde"
"cdeab"

    2 ⌽⁼ 2 ⌽ "abcde"
"abcde"
```

When doing [Advent of Code 2022 in BQN](https://mlochbaum.github.io/BQN/community/aoc.html), I found the Under operation fascinating due to its capability to "stream" array structure. In particular, this example:

```c
  ⟨"ab", "cde", "fg"⟩ ⊣⌾∾ ⟨"---", "----"⟩
⟨ "abc" "defg" ⟩
```

Meaning that the result of the operation is `⟨ "abc" "defg" ⟩`. Here, $\sim$ (join) is $F$ which turns the dashes into a single long string (BQN is read right-to-left). Next, the left identity $\dashv$ is $G$ which replaces the dashes with the left argument `⟨"ab", "cde", "fg"⟩`. Then, the replaced array gets passed _back_ to $F$ in which the inverse of $\sim$ reshapes the concatenated string into three and four elements preserving the values from the left argument.

From a semantical standpoint, it is interesting that the inverse of $F$ is found by BQN without additional declarations from the programmer. This makes BQN feel rather magical -- even in a language like Haskell, you don't automatically get inverses of functions. And I don't know any other language in which you do. Similarly, you could ask how often does code "turn back" on a single line?


There is also a categorical story to Under. My DPhil supervisor Jeremy Gibbons noted the following:

>That page about “under” is very interesting. The operation is also known as [conjugation](https://en.wikipedia.org/wiki/Conjugacy_class) - specifically when the two transformations are inverses. And it’s also the functorial action (“map”) of the function type constructor (->), a bifunctor:

```
bimap :: (b->b’) -> (a’->a) -> (a->b) -> (a’->b’)
bimap g f k = g . k . f
```

>(note that (->) is contravariant in its left argument, to the type of f above is the opposite of what you might first think). What they call "structural under” is captured by a lens, with a “get” (to extract some component) and a “put” (to store an updated copy of that component). And “mathematical under” and “structural under” are indeed closely related: there’s a story about lenses in terms of “profunctors”, and (->) is the simplest profunctor.

This comment introduces to look at structural under as a [lens](https://ncatlab.org/nlab/show/lens+%28in+computer+science%29#). A rudimentary example of a lens-in-action is a database view: choosing data from different tables and providing a partial view into it. A practical example concerns a `deletedAt` field: you want to query undeleted records from a database. Often, you also provide a write feature which propagates the changes back: say, the user updates some field in a joined view, and the update applies the changes automatically back to the corresponding (but separate) tables. This way, the same method to read the information "routes" back also for writes.

The BQN author Marshall Lochbaum also rejoiced:

>Oh cool! I knew about conjugation, and I've always assumed (not sure I've seen an explicit reference) that it was a major influence when Iverson designed APL's Dual, which is just the mathematical part. Vaguely aware of lenses; the interesting part with structural Under is that the put is uniquely determined by the get, plus the set of all possible get functions (structural functions here, and I don't know what other sets would allow it).
>
>Come to think of it, Iverson was probably more influenced by the form [S⁻¹AS in linear algebra](https://en.wikipedia.org/wiki/Matrix_similarity), a special case of conjugation.
>
>Reading up on profunctor optics (and just saw "Our group would like to thank Jeremy Gibbons, Jules Hedges and David Jaz Myers for helpful discussion on the topic"!). Being able to compose them adds some structure. Seems like something like a lens starting at T×T that extracts the first component but puts it back in the second position would be possible. So more structure is needed; "lawful optics" sounds promising.
>
>Did you ever link [to the spec](https://mlochbaum.github.io/BQN/spec/inferred.html#under) for this by the way? Very dense, but it does have a mathematical definition and proof that it's well defined. We did recently find a gap where functions like `⥊` that automatically enclose an atom don't qualify as structural, but that's not important from the perspective of a language that wouldn't define that sort of thing.
>
>([Here in Operators and Functions](https://www.jsoftware.com/papers/opfns1.htm#8), which I believe is Iverson's first publication about Dual, he relates it to "the notion of dual functions implicit in deMorgan’s law", which is the two-argument case. Nothing here to connect it to conjugation actually.) 

After some quick thinking, Marshall added:

>Okay, relationship of BQN Under to lenses. It's clear that a function `F` and its structural inverse taking `s`, `v` to `v˙⌾F s` satisfy the lens laws where they're defined:
>
```
Law     Math                           BQN
GetPut  put(s, get(s)) = s             s ≡ ⊢⌾F s
PutGet  get(put(s, v)) = v             v ≡ F v˙⌾F s
PutPut  put(put(s, w), v) = put(s, v)  (v˙⌾F s) ≡ v˙⌾F w˙⌾F s
```
>
>(Not so obvious why PutPut is important: consider a getter function `F←⊑` that gets the first value in a pair, but a setter function `v¨⍟(v≢⊑)s` that leaves `s` alone if the first value is `v` but sets both values to `v` if not.)
>
>A lens following these laws is "lawful" or "very well-behaved". I can't find a reference stating exactly this, but it seems like a given getter function can only be part of one lawful lens. There's always an isomorphism that splits a getter argument into the part that gets got and the part that doesn't, at which point you can define the setter to replace the gotten part and undo the isomorphism. But the isomorphism isn't unique so that's not a full proof.
>
>But Under doesn't actually define a lens because the put function `v˙⌾F s` is partial: not all combinations of values `s` and `v` from the domain and range of `F` can be used. For example ↕3 is in the domain of `⊏`, but `(↕3)⌾⊏2‿2⥊0` is an error. This is the hard part of the definition, and why I need the concept of a "structural function decomposition": each structure transformation in the decomposition is actually a lens. Still, knowing lens theory seems very useful so I'll keep reading. Will probably put some reference to lenses in the Under documentation when I have a clearer idea of what's going on, in case it helps any Haskell programmer reading.

A fine motivation to practice the use of lenses and BQN, I thought. So, I decided to apply it to HTML templating by creating a tool I call `barbell`.

## Barbell

Barbell is a simple templating tool which works similar to [Handlebars](https://handlebarsjs.com). Even this page uses barbell!

Templating often comes relevant with HTML page generation when you want to have "components" or [imports](https://web.dev/imports/) to avoid redefining your `<head>` and `<footer>` elements on every page. For example:

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

Handlebars would replace `{{ title }}` and `{{ body }}` with data provided by the programmer. And after ten years of programming, I have had my fair share of different templating libraries like Handlebars, EJS of ExpressJS, and Go's `html/template` package. However, these mainly work for dynamic web applications and are language specific. My website is a collection of static HTML pages created over the years, for which these templating libraries do not work as great for.

So, what I wanted to do with `barbell` was something that worked nicely in a shell environment, because that _has_ been persistent for me while my preference of languages and frameworks come and go. Also, I wanted something that plays nicely with Nix, which I use in my current workflow extensively. Nix as a package manager can abstract away the languages and frameworks -- as long as I get the tools to print to shell, I could use them with `barbell`. And given the previous description of BQN, I also wanted to do this with BQN.

My initial solution was as follows:

```c
pairs ← ⟨⟨"name", "Juuso"⟩, ⟨"unmatched", "foobar"⟩⟩
input ← "hello {name} :)"

b ← "{"⍷input
e ← »"}"⍷input

frags ← (+`e+b) ⊸ ⊔ (input)
keys ← {∾"{"‿(⊑𝕩)‿"}"}¨pairs
vals ← {1⊑𝕩}¨pairs
mask ← frags∊keys
values ← (mask / keys ⊐ frags) ⊸ ⊏ vals
•Out ∾values⌾(mask⊸/) frags
```

This would print out `hello Juuso :)`. Making it to read files requires changing `pairs` and `input` as so:

```c
pairs ← {⟨∾"{"‿(¯4↓𝕩)‿"}",(•file.Chars 𝕩)⟩}¨{4=+´¯4↑𝕩∊".bar"}¨⊸/•file.List "."
put ← •file.Chars ⊑ •args
```

Now, suppose the following file is called `template.html`:

```HTML
<html>
<head>
  <title>{title}</title>
</head>
<body>
  {body}
</body>
</html>

```

`barbell template.html` would search the current directory for files with a filename ending in `.bar`, read those files, and insert the files' contents into the argument file replacing the `{keyword}` part. It would do this by creating pairs in which the first value is the key name and the second the file contents. Finally, I packaged this script with Nix, so that it can be called as such: `nix run github:jhvst/barbell -- template.html`. Should the current directory have files `title.bar` and `body.bar`, the contents of these files would get inserted in the respective locations.

I do not expect everyone to read hieroglyphs (or ["squiggols"](https://www.cs.ox.ac.uk/people/jeremy.gibbons/publications/squiggol-history.pdf), so what exactly is happening in the BQN script?

## Implementation

I will skip how `input` and `pairs` works when reading files, because this is rather uninteresting considering how the templating really works. What matters instead is the steps to prepare us to use Under. Eventually we want something like the following:

```c
    1‿2‿3⊸+⌾(1‿1‿0‿1⊸/) 10‿20‿30‿40
⟨ 11 22 30 43 ⟩
```

Here, BQN applies a transformation to the right argument selectively by using a view vector. In the cells that are 1, it applies the argument at the same index from the left argument.

Back to our code. The definition of `b` and `e` correspond to the beginning and end markers of the "bar" tokens that we look for. $\underline{\in}$ is a "find" which returns the indices in which the token is found. The end token result is shifted to right to capture the token into the fragment from which it started from (hence, we call the resulting fragment vector `frags`). We do this by sums the find-indices together, followed by a plus scan on the result:

```c
pairs ← ⟨⟨"name", "Juuso"⟩, ⟨"unmatched", "foobar"⟩⟩
input ← "hello {name} :)"

b ← "{"⍷input
e ← »"}"⍷input

•Show b
•Show e
```

This yields us

```
⟨ 0 0 0 0 0 0 1 0 0 0 0 0 0 0 0 ⟩
⟨ 0 0 0 0 0 0 0 0 0 0 0 0 1 0 0 ⟩
```

These view vector shows us the locations in which the tokens `{` and `}` were found, defaulting otherwise to 0. Next, we apply the sum scan:

```c
pairs ← ⟨⟨"name", "Juuso"⟩, ⟨"unmatched", "foobar"⟩⟩
input ← "hello {name} :)"

b ← "{"⍷input
e ← »"}"⍷input

•Show (+`e+b)
```

```
⟨ 0 0 0 0 0 0 1 1 1 1 1 1 2 2 2 ⟩
```

Doing a sum scan is non-obvious unless we also know about BQNs group operation $\cup$. Given a vector such as the one above, it partitions an input with the same shape:

```c
pairs ← ⟨⟨"name", "Juuso"⟩, ⟨"unmatched", "foobar"⟩⟩
input ← "hello {name} :)"

b ← "{"⍷input
e ← »"}"⍷input

frags ← (+`e+b) ⊸ ⊔ input
•Show frags
```

```
⟨ "hello " "{name}" " :)" ⟩
```

For our purposes this is what we want as the right argument. Next, we need a mask which uses the `frags` to find us the indices in which we have an existing key (if key is not found, it should not be replaced). But first, we have to distinguish the keys from values:

```c
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

```
⟨ "name" "unmatched" ⟩
⟨ "Juuso" "foobar" ⟩
```

What happens here is that `¨` iterates the pairs after which we apply a selection function `⊑`. The brackets distinguish that the selection operation should happen to the iterator values. As such, `{⊑𝕩}` defaults to the first cell, and `{1⊑𝕩}` to the second. If we also mangle with the keys a little bit, we can join it with the bars: `{∾"{"‿(⊑𝕩)‿"}"}`. This will wrap each key with the bars, giving this output instead:

```
⟨ "{name}" "{unmatched}" ⟩
⟨ "Juuso" "foobar" ⟩
```

Next is the mask. I cannot say that I instantly realized this is a single operation in BQN:

```c
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

```
⟨ 0 1 0 ⟩
```

Unwrapper, the result is easy to understand: `⟨ "hello " "{name}" " :)" ⟩ ∊ ⟨ "{name}" "{unmatched}" ⟩`. This says that the corresponding value was found: it does not return its index. If we would replace `{name}` in the input with `{unmatched}`, we would get the same result. To instead get the index of from the keys we need to use `keys ⊐ frags` instead. This would print us `⟨ 2 0 2 ⟩` -- notice that if the value is not found, it gets an index which is one more than the length of the `keys` vector. We can use this fact to filter `/` the results, by comparing each value against the length of the `keys` or `pairs`: `≠pairs` or alternatively re-using our `mask` variable:

```c
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

```
⟨ 0 ⟩
```

Next, to choose the corresponding element, we can append to values `⊏ vals`. So, we refactor values to `values ← (mask / keys ⊐ frags) ⊸ ⊏ vals` to get `⟨ "Juuso" ⟩`. Here, the lollipop creates a precendence: the thing inside of the clauses will be computed first, which then gets passed as the left argument to `⊏`.

We now have everything needed for Under:

```c
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

```
⟨ "hello " "Juuso" " :)" ⟩
```

Now, unwrapping the Under corresponds to:

```c
[ "Juuso" ] ⌾ ([0, 1, 0]⊸/) [ "hello ", "{name}", " :)" ]
```

Finally, by concatenating this with $\sim$, we get `hello Juuso :)`. Our complete code looks as such:

```c
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

Why this is different from a simple `strings.Replace` function is that the under is not modifying the original fragment vector -- it is instead providing us a _view_ in which the contents are "streamed" from the left hand side as seen on this original example:

```c
⟨"ab", "cde", "fg"⟩ ⊣⌾∾ ⟨"---", "----"⟩
```

Moreoever, because it's array-based, it's a "single pass" operation, meaning that in theory the replacement operation can be run in parallel. "Accidental" parallelism is the reason why I got interested in APL and then other array programming languages in the first place: the parallelism comes as if it would be "free" -- I never particularly thought about how my code could be performed in parallel, but in the end it did! This is in stark contrast even with the fancier programming languages with linear types like Rust, which does make parallel programming quite easy via packages like `rayon`, but still requires explicit headspace from the programmer to think about it.

## Changing {} to bars ||

There's a bit more to the story of the barbell though, which is about the tokens given in `b` and `e`: the solution is specific to tokens which are different to each other. In particular, when tokens are different, then the captured fragments include the token, which makes the replacement possible by mangling the keys `keys ← {∾"{"‿(⊑𝕩)‿"}"}¨pairs`. However, if we define the token to be, say `|` then it's not possible to capture the bars on both sides because of how the sum fold works. What we instead get is something like this:

```c
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

```
[ "hello ", "|", "name", "|", " :)" ]
```

This is still workable, but requires removing the found bars. We do this by adding these:

```c
changed ← {⟨𝕩-1,𝕩,𝕩+1⟩}¨(({⟨1,0,1⟩≡𝕩}¨(¯3↑¨1↓↑frags ∊ reps))⊸/) ({𝕩-1}¨↕≠frags)
nmask ← {+´𝕩⍷(∾changed)}¨↕≠frags
neighbors ← ∾{⟨↕0,(1⊑𝕩)⊑reps,↕0⟩}¨changed
∾neighbors⌾(nmask⊸/) reps
```

In `changed` we create a three element sliding window a.k.a stencil out of elements which are `1` in `mask`. This variable collects the indices in which of e.g. `"|", "name", "|"` creating a matrix. The output in this case would be `⟨ ⟨ 0 1 2 ⟩ ⟩`.

In `nmask` the indices in `changed` are turned into a view vector of the shape of the `frags`. This would output `⟨ 0 1 1 1 0 ⟩`.

In `neighbors` the indices in `changed` are used to collect elements from the original result, while leaving the `|`'s into empty arrays. This would output `⟨ ⟨⟩ "Juuso" ⟨⟩ ⟩`.

Finally, we use the Under operation again. Concatenating an empty array gets coalesced into an empty string. The complete code looks as such:

```c
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

```
"hello Juuso :)"
```

The diff is introducing the first Under as `reps`, then removing the joining to a single string, and then we change the definition of `b` and `e`, followed by `frags`. Also, `keys` and `vals` can also use a table `⌜` instead of an interator coupled with the reverse `⌽` to get the equivalent output.

## Wrapping up

The final code with file reading and `stdout` printing looks like this:

```c
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

The source code is [on Github](https://github.com/jhvst/barbell) wrapped into a bash script with Nix. To run the tool, anyone with Nix installed can run `nix run github:jhvst/barbell -- foobar.html` where `foobar.html` is the template.

Creating a complete website out of this is more to do with Nix than BQN, but I plan to make a blog post about this later! For the curious, you can already see the [source code](https://github.com/jhvst/jhvst.github.io/blob/main/blogPosts/barbell/flake.nix). One nice thing is that this whole webpage can be cloned as follows: `nix build 'github:jhvst/jhvst.github.io?dir=blogPosts/barbell'`, followed by `open result/barbell.html`. This is the power of Nix Flakes!

Finally, this program only provides us a get function for the lens: it takes a collection of files, and provides a unified view. An improvement would be to also implement the write part. Imagine that you'd now change a part in the joined file in a text editor, then it would be nice if those changes could also propagate back to the original files. This would need the whole program to have an inverse, which is bit more tricky, because it would imply that none of the operations would lose information. Can it be done? Maybe, but that's left for future work.
