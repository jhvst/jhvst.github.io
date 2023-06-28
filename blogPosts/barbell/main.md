
# Barbell: Templates in BQN

One of the more interesting operations in BQN is [⌾ a.k.a Under or a "donut"](https://mlochbaum.github.io/BQN/doc/under.html). As the documentation page describes, it is an operation which takes two function $F$ and $G$, and it applies $F$ first, then passes the result to $G$, followed by the _inverse_ of $F$. There is also a [Dyalog blog post](https://www.dyalog.com/blog/2023/01/structural-vs-mathematical-under/) with more historical background.

When doing [Advent of Code 2022 in BQN](https://mlochbaum.github.io/BQN/community/aoc.html), I found the Under operation fascinating due to its capability to "stream" array structure. In particular, this example:

```
⟨"ab", "cde", "fg"⟩ ⊣⌾∾ ⟨"---", "----"⟩
```

Which yields `⟨ "abc" "defg" ⟩`. Here, $\sim$ (concatenation) is $F$ and turns the dashes into a single long string. Next, the left identity $\dashv$ is $G$ replaces the dashes with the left argument `⟨"ab", "cde", "fg"⟩`. Then, the replaced array gets passed _back_ to $F$ in which the inverse of $\sim$ reshapes the concatenated string into one with three and four elements.

From a semantics standpoint, it is interesting that the inverse of $F$ is found by BQN without additional declarations from the programmer. This makes BQN feel rather magical -- even in a language like Haskell, you don't automatically get inverses of functions. And I don't know any other language in which you do.

There is also a categorical story to Under. My DPhil supervisor Jeremy Gibbons noted the following:

>That page about “under” is very interesting. The operation is also known as [conjugation](https://en.wikipedia.org/wiki/Conjugacy_class) - specifically when the two transformations are inverses. And it’s also the functorial action (“map”) of the function type constructor (->), a bifunctor:
>
>  bimap :: (b->b’) -> (a’->a) -> (a->b) -> (a’->b’)
>
>  bimap g f k = g . k . f
>
>(note that (->) is contravariant in its left argument, to the type of f above is the opposite of what you might first think). What they call "structural under” is captured by a lens, with a “get” (to extract some component) and a “put” (to store an updated copy of that component). And “mathematical under” and “structural under” are indeed closely related: there’s a story about lenses in terms of “profunctors”, and (->) is the simplest profunctor.

This comment introduces a new way to look at the operations: as a [lens](https://ncatlab.org/nlab/show/lens+%28in+computer+science%29#). A rudimentary example of a lens is a database view: you choose data from some tables providing a partial view into it. A common example of this is when you have a `deletedAt` field which is set, but you only want to show information that is yet to be deleted by the user. Oftentimes, you also want to provide not only a way to read this joined information, but also propagate the changes back: if the user now updates some field from the returned data, you want a way to update the underlying tables using the same "route" you initially picked the information.

To practice the use of lenses, I decided to apply it to HTML templating.

## Barbell

Barbell is a simple templating tool which works similar to [Handlebars](https://handlebarsjs.com). Even this page uses barbell!

For the uninitiated, templating comes around often in HTML page generation when you want to have web "components" or [imports](https://web.dev/imports/) to avoid redefining your `<head>` and `<footer>` elements on every single page. For example:

```HTML
<html>
<head>
  <title>Title</title>
</head>
<body>
  ...
</body>
</html>
```

With Handlebars you'd replace `Title` with `{{ title }}` and the inside of body with something like `{{ body }}`. What is a bit annoying that throughout $N$ years of programming, I have had my fair share of different templating libraries like Handlebars, but also EJS of ExpressJS, and Go's `html/template` package. However, these mainly work for dynamic web applications. My website is a collection of static HTML pages, for which these templating libraries do not work as great for.

In specific, what wanted to do with `barbell` was something that played better with Nix, which I use in my current workflow extensively. I want to be able to pass in Nix runtime values to pages, to fetch information from remote flakes. And given the previous description of BQN, I also wanted to do this with BQN.

Eventually I came up with a solution which works like as follows:

```
b ← "{"⍷input
e ← »"}"⍷input

frags ← (+`e+b) ⊸ ⊔ (input)
keys ← {∾"{"‿(⊑𝕩)‿"}"}¨pairs
vals ← {1⊑𝕩}¨pairs
mask ← frags∊keys
values ← (mask / keys ⊐ frags) ⊸ ⊏ vals
•Out ∾values⌾(mask⊸/) frags
```

Now, suppose the following file is called `template.html`:

```HTML
<html>
<head>
  <title>{title}</title>
</head>
<body>
  ...
</body>
</html>

```

`barbell template.html` would search the current directory for files with a filename ending in `.bar`, then read those files, and insert the files' contents into the argument file replacing the `{keyword}` part.

So, what is happening on the BQN script?

## Implementation

The definition of `b` and `e` correspond to the beginning and end markers of the "bar" tokens that we look for. The $\underline{\in}$ operation is a "find" which returns the indices in which the token is found. The end token result is shifted to right for reasons that come apparent in the definition of `frags`: it sums the find indices together, and then does a plus scan on the result. So, suppose the following:

```
hello {name} :)
```

With `b ← "{"⍷input` and `e ← »"}"⍷input` you would get

```
b = 000000100000000
e = 000000000001000
```

The sum scan together `(+`e+b)` yields

```
    000000111112222
```

When we then group the string with this array using BQNs group operation $\cup$. Now, ``frags ← (+`e+b) ⊸ ⊔ (input)`` returns a vector with fragments:

```
[ "hello ", "{name}", " :)" ]
```

Now, we need to find the elements of this array which we there exists a key with a corresponding file in the directory. We then want to return a view vector `mask` with `frags∊keys`:

```
[ 0, 1, 0 ]
```

This means that in each element in which we have `1`, we want to replace those elements with the contents found from the file. For this to work, we have to also compute another vector in which the file contents are inserted in place of the old values. In my initial code, I did this by removing the zeroes from the `mask` vector, and only leaving in place the changed values. So, we would get:

```
[ "Juuso" ]
```

We then also need to know the indices in the original fragment array in which these values are located, i.e., that because at index `0` we have `"hello "`, then what actually has to be replaced with Juuso is located on the index `1`. Effectively, what we want is similar to this example in Under:

```
    1‿2‿3⊸+⌾(1‿1‿0‿1⊸/) 10‿20‿30‿40
⟨ 11 22 30 43 ⟩
```

Meaning that the `1‿1‿0‿1` is a selector on which we want to apply some change on the right hand side arguments from the values given on the left hand side of the donut.

Now, consider our code:

```
keys ← {∾"{"‿(⊑𝕩)‿"}"}¨pairs
vals ← {1⊑𝕩}¨pairs
mask ← frags∊keys
values ← (mask / keys ⊐ frags) ⊸ ⊏ vals
```

Here the variable `values` is the `1 2 3` part. So, if we have a file called `name.bar` in a folder with the contents of `Juuso`, we get the `values` that we want:

```
[ "Juuso" ]
```

We now need to pass it to a Under:

```
values⌾(mask⊸/) frags
```

Typed out, this corresponds to:

```
[ "Juuso" ] ⌾ ([0, 1, 0]) [ "hello ", "{name}", " :)" ]
```

Which yields us `[ "hello ", "Juuso", " :)"`. By concatenating this with $\sim$, we get `hello Juuso :)`.

Why this is different from a simple `strings.Replace` function is that the under is not modifying the original fragment vector -- it is instead providing us a _view_ in which the contents are "streamed" from the left hand side as seen on this original example:

```
⟨"ab", "cde", "fg"⟩ ⊣⌾∾ ⟨"---", "----"⟩
```

Moreoever, because it's array-based, it's a "single pass" operation, meaning that in theory the replacement operation can be run in parallel. "Accidental" parallelism is the reason why I got interested in APL and then other array programming languages in the first place: the parallelism comes as if it would be "free" -- I never particularly thought about how my code could be performed in parallel, but in the end it did! This is in stark contrast even with the fancier programming languages with linear types like Rust, which does make parallel programming quite easy via packages like `rayon`, but still requires explicit headspace from the programmer to think about it.

## Changing {} to bars ||

There's a bit more to the story of the barbell though, which is about the tokens given in `b` and `e`: the solution is specific to tokens which are different to each other. In particular, when tokens are different, then the captured fragments include the token, which makes the replacement an easy process (seen with `keys ← {∾"{"‿(⊑𝕩)‿"}"}¨pairs`). However, if we define the token to be, say `|` then it's not possible to capture the bars on both sides because of how the sum fold works. What we instead get is something like this:

```
[ "hello ", "|", "name", "|", " :)" ]
```

This is still workable, but requires removing the found bars. We do this by adding these:

```
changed ← {⟨𝕩-1,𝕩,𝕩+1⟩}¨(({⟨1,0,1⟩≡𝕩}¨(¯3↑¨1↓↑frags ∊ reps))⊸/) ({𝕩-1}¨↕≠frags)
nmask ← {+´𝕩⍷(∾changed)}¨↕≠frags
neighbors ← ∾{⟨↕0,(1⊑𝕩)⊑reps,↕0⟩}¨changed
∾neighbors⌾(nmask⊸/) reps
```

In `changed` we create a three element sliding window a.k.a stencil out of elements which are `1` in `mask`. This variable collects the indices in which of e.g. `"|", "title", "|"` creating a matrix.

In `nmask` the indices in `changed` are turned into a view vector. In effect, this turns natural number of the indices into `1`, leaving everything else as `0`.

In `neighbors` the indices in `changed` are used to collect elements from the original result, while leaving the neighboring elements, i.e., `|`'s into empty arrays.

Finally, we use the Under operation again to turn all `|` values into empty arrays, which when coalesced into a string means an empty token.

## Wrapping up

The final code looks like this:

```
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
