---
title: On Structural Under and GPUs
author: Juuso Haavisto
sub_title: "\"Structural Under is the same concept as a (lawful) lens in functional programming (see also bidirectional transformation). Lenses are usually defined as getter/setter pairs, but BQN's restriction to structural functions makes an implicit setter work even for polymorphic array functions.\"

- BQN documentation of Under"
theme:
  override:
    footer:
      style: template
      left: juuso.haavisto@cs.ox.ac.uk
      right: "{current_slide} / {total_slides}"
---

Defining the title
===

<!-- column_layout: [1, 1] -->

<!-- column: 0 -->

# Structural Under

## 𝕨 𝔽 ⌾ 𝔾 𝕩

- BQNs approach to immutable arrays
- must preserve the original shape of `x`
- finds the inverse for us (part of specification)

```bash +exec
cbqn -e '•Show ⟨"ab", "cde", "fg"⟩ ⊣ ⌾ ∾ ⟨"---", "----"⟩'
```

Glossary:
- ⊣  left identity
- ∾  concat (inverse defined as reshape)

<!-- column: 1 -->

# GPUs

Opinionated memory model:
- no dynamic memory allocation
- represents memory as 1d array
- slow memory copies with CPU, and slow communication between far-out cores
- APIs like SPIR-V expose deeply nested architecture of thread management
- parallel by default, sequential on request
- threads do not know input sizes

How to minimize communication?

<!-- end_slide -->

Defining the description
===

<!-- column_layout: [1, 1] -->

<!-- column: 0 -->

# Lens

e.g. input is separate tables in a database, output is a joined view -- writing to the output causes information to propagate into the source tables

structural Under can represent lens laws:

```
Law     Math                           BQN
GetPut  put(s, get(s)) = s             s ≡ ⊢⌾F s
PutGet  get(put(s, v)) = v             v ≡ F v˙⌾F s
PutPut  put(put(s, w), v) = put(s, v)  (v˙⌾F s) ≡ v˙⌾F w˙⌾F s
```

<!-- column: 1 -->

# Bidirectional transformation

"input and output at the same time"

covers lenses but also structures like conjugations (mathematical / computational Under)

e.g. encoding, input is cleartext, output is gibberish -- writing to the inverse definition causes gibberish to become cleartext

e.g. game semantics in corecursive manner: my turn, your turn

<!-- end_slide -->

Mixing it up
===

<!-- column_layout: [1, 1] -->

<!-- column: 0 -->

# Structural Under

an ergonic lens: figures the inverse for us

<!-- column: 1 -->

# GPUs

opinionated memory model vs. CPU

<!-- column_layout: [1, 1] -->

<!-- column: 0 -->

# Lens

given source(s), provides an updatable view that propagates into source(s) via bidirectionality

<!-- column: 1 -->

# Bidirectional transformation

general "in-n-out" structure that covers e.g. both cases of Under

<!-- end_slide -->

dependent types
===

- The spruce is on fire = Kuusi palaa
- The spruce returns = Kuusi palaa
- The number six is on fire = Kuusi palaa
- The number six returns = Kuusi palaa
- Six of them are on fire = Kuusi palaa
- Six of them return = Kuusi palaa
- Your moon is on fire = Kuusi palaa
- Your moon returns = Kuusi palaa
- Six pieces = Kuusi palaa

semantically equivalent definitions where the precise meaning is parsed from a context later on

which looks in practice like...

<!-- end_slide -->

static rank polymorphism
===

```haskell
-- shape (Reduce (SomeVect 4))
-- shape (Reduce (SomeMat 3 3))
-- shape (Sum (SomeVect 4) (shape (Reduce (SomeMat 3 3))))
-- shape (Sum SomeScalar (shape (Reduce (SomeVect 4))))
Reduce : Shape q (MkDim (S r) (S n)) -> Phase
Reduce {q=FZ} o = MkPhase Slash o
Reduce {q=FS(FZ)} {n} o = MkPhase Slash SomeScalar
Reduce {q=FS(FS(FZ))} {r} {n} o = MkPhase Slash (SomeVect (S n))
```

i.e., admits that "kuusi palaa" is a sentence, but leaves further interpretation to a later time

__shapely operations__: shapes determine interpretations

What dependent types give us is a way to compose programs such that the intermediate types are known. This is useful for library embeddings: we have dependently typed array solutions. Compilers can use intermediate types for further optimizations.

This also avoids back-and-forth between the CPU since GPU knows statically how to preallocate memory for function compositions.

Total, so downsides exist (but these types are never shown or required in the frontend language itself).

TODO: The optimizations using _lenses_...

<!-- end_slide -->

superoptimizations with dependent types
===

Sum reduce vector of `X` elements. Denotationally the output is `SomeScalar`. Operationally, e.g.:

1. Suppose GPUs called Red and Green. The GPU API tells that the Green is more powerful, so you split the dataset `40/60`.
2. The second view defines the thread grid. On the Red GPU, the assigned dataset length happens to be divisible by 3, so you choose `1023` threads per `x` dimension. On Green GPU, the dataset is disivisible by 4, so you choose `1024`.
3. On Red, the subgroup length is `64`. On Green, the subgroup length is `32`. You further divide the dataset into views of chunks of 64 and 32.
4. Red loads `2` values into a register on each invocation of a subgroup, and Green loads `4`.
5. The sum reduce happens.
6. The views destruct using bidirectionality.

Goal: I need a way to abstract away this complexity. Coincidentally, many parallel shapely operations have special cases which require nicely divisible datasets, but statically input size is not known, so strategies cannot be pre-chosen.

Point: but when the intermediate shapes are known, communication optimization within the GPU kernel can also be done. Under adds ergonomics to this. Obs: the deeper levels have constraints from physical properties of the GPU which prune paths from exhaustive searches.

Lenses: the `G` function in structural Under splits up the data into partitions. An effect `F` is the actual sum reduction, and happens on the deepest level of the recursion. Lenses compose, so you can nest the calls. Bidirectionality fulfills the initial denotational type of a single (significant) value.

<!-- end_slide -->

bidirectional transformation maximalism
===

## Axiom: everything is __Under__ under the hood

1. __lenses__ (structural Under) select and assign
2. __conjugations__ (computational Under) as agent-based communication

---

<!-- column_layout: [1, 1] -->

<!-- column: 0 -->

# Computation
1. data mappings: allocation of memory to cores
2. divide and conquer: e.g. cores transfer memory between warps a.k.a subgroups

<!-- column: 1 -->

# Networking
1. network graphs: nodes are records in a static definition of a compute cluster
2. game semantics: turn-based protocols where nodes send and receive tasks

<!-- reset_layout -->

---

## Computation & Networking combined: rank polymorphic scheduling?

<!-- column_layout: [1, 1] -->

<!-- column: 0 -->

- "scalar" is an invocation
- "vector" is a subgroup
- "matrix" is a workgroup
- "cuboid" is a thread grid

<!-- column: 1 -->

- "scalar" is a GPU
- "vector" is multiple GPUs on a node
- "matrix" is a cluster of GPU nodes
- "cuboid" is a two separate clusters

<!-- reset_layout -->

<!-- end_slide -->

takeaways
===

1. explained the convoluted story how an aside comment got added to BQN documentation
2. structural Under is a nice construct that is already given, and might play a role in solver-guided compiler optimizations

Should array programming languages be designed as multi-node from the get-go? Are there other "native" approaches to do it, such that the scheduling could also be modeled in the array language?

<!-- end_slide -->

questions
===

