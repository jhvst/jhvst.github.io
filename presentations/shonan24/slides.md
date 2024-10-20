---
author: Under - Juuso Haavisto
---

# Under

**a squiggol for lenses and conjugations**

- apl / bqn
- few words about Vulkan
- lenses
- conjugations

```bash
cbqn -e '•Show "Hello World"'
```

---

# Preliminaries

- BQN (2020) is (almost) APL++
- like all APLs, "no stinking loops" via rank polymorphism
- immutable arrays
- promotes point-free (tacit) programming
- unlike Dyalog APL, BQN is free and open-source

+ my effort: run a total fragment of BQN on a GPU
+ kernel == shader == compute shader
+ total properties <-> compiler optimizations

---

# run a total fragment of BQN on a GPU?

- "experience chasm" with GPUs vs. APLs
- can APLs leverage GPUs without semantic changes?
- dependent types -> static rank polymorphism
- GPU kernels in SPIR-V (~ parallel LLVM IR)
- GPU API is Vulkan (Rust bindings)

=> platforms I have got working: iOS, macOS (ARM & x86), Linux, Windows, with AMD and Nvidia GPUs

=> PoCs mixing GPU models and manufacturers on a single node

=> combine discrete, integrated, and software GPUs

=> runs even in a web browser (via WebGPU API)

---

# prompt: a Vulkan experience report

- successor to OpenCL and OpenGL
- a hello world is about 1K LOC of Rust
- my takeaway: writing an optimal for loop is intractable

challenge: very fine-grained control over resources, e.g.,:
- memory classes (-> manual memory allocation), queue hierarchies
- => "you should write to memory buffer 1 using queue family 0's queue #1"
- => "you should read from memory buffer 3 using queue family 2's queue #0, while using the following access bits: ..."
- grid sizes, warp/subgroup sizes and features per GPU

Vulkan is about *how* something is run, but SPIR-V shaders describe *what* is run
- translation layer to SPIR-V exists from GLSL (Khronos), HLSL (Microsoft), and MSL (Apple)

---

# Why Under?

Vulkan works

Challenge: generic SPIR-V code, i.e., vs. CUDA model. In practice:
- instruction lengths are variable for SIMD, subgroup operations must generalize
- loop boundaries of compute and communicate phases are unknown

Instead of code generation, what structures are helpful? In practice: leave "holes" for later

Common theme: an API (Vulkan) is generic, but requires tailoring for utmost performance

Reminder: to spook an APLer, show them:
- a) an index
- b) a type declaration

---

# 𝔽⌾𝔾 𝕩, 𝕨 𝔽⌾𝔾 𝕩: Under
- Apply transformation 𝔾 to all arguments
- Apply 𝔽 to the transformed arguments
- Undo transformation 𝔾

Where 𝔾 must be
- A function invertible by ⁼ (Undo)
- A structural modification

Note: Under is the only way to "redefine" a variable in BQN

---

# 𝔽⌾𝔾 𝕩, 𝕨 𝔽⌾𝔾 𝕩: Under

~~... generic SPIR-V ...~~
1. instruction lengths are variable for SIMD, subgroup operations must generalize
2. loop boundaries of compute and communicate phases are unknown

- ~~Apply transformation 𝔾 to all arguments~~
- ~~Apply 𝔽 to the transformed arguments~~
- ~~Undo transformation 𝔾~~

~~Where 𝔾 must be~~
- \2. function invertible by ⁼ (Undo)
- \1. A structural modification

---

Next, Under for:
1. lenses (structural Under)
2. conjugations (computational Under)

Both use inverses.
- **inverses are automatically defined in BQN**
- both cases use the same symbol ⌾ "donut" ...
- ... which one depends on the definition of G ...
- ... which is highly debated and causes constant confusion at Matrix

---

# A structural Under is a lens

This is the easy one:
- "represents a bidirectional stateful computation that describes the way some systems expose and update their internal state"
- right side of donut changes "shape" of input
- if left hand side of donut cannot be put back to the format of input, an error occurs

```bash
cbqn -e '•Show ⟨"ab", "cde", "fg"⟩ ⊣ ⌾ ∾ ⟨"---", "----"⟩'
```

---

# A structural Under is a lens

Lenses have laws:
```
Law     Math                           BQN
GetPut  put(s, get(s)) = s             s ≡ ⊢⌾F s
PutGet  get(put(s, v)) = v             v ≡ F v˙⌾F s
PutPut  put(put(s, w), v) = put(s, v)  (v˙⌾F s) ≡ v˙⌾F w˙⌾F s
```

BQN's restriction to structural functions makes an implicit setter work even for polymorphic array functions.

---

# Lenses and GPUs

1. Language implementator: a tool to model parallel algorithms (no 1K LOC of Rust)
2. Language user: use the algorithms from above

𝕨 𝔽⌾𝔾 𝕩

What kind of interface is meaningful to expose to the user? Suppose x is always a vector.
- manual (define the G; e.g. every row is an invocation)
- automatic scheduling (TVM approach but with type information; use a constraint solver)

Can both cases be handled?

---

# A computational Under is a conjugation

The original and tricker part of the Under. Common usages:
- domain changes
- range generation up to a bound

In comparison to structural Under:
- can modify the input shape
- much more rare
- corecursive definitions (?)

```bash
cbqn -e '•Show ↕∘⌈⌾((4+3×⊢)⁼) 20'
```

---

# Under as a construct

- inane reason: "dont spook to APLer"
- optimistic reason: could handle manual (define G) and automatic definitions (guide it with shape and GPU hw info)
- ~practical reason: lock-in an approach and see where it goes

Personal opinion: some sort of construct for automatic definition is needed eventually anyway.
- totality is our friend here

---

# Takeaways

- polarity of programming APLs vs GPUs
- lenses and conjugations can give structure to how we view and communicate memory
- dependent types, total language fragment, and GPU API constraints as guiding mechanisms


