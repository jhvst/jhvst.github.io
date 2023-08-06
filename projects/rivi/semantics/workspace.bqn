# Welcome to BQN (https://mlochbaum.github.io/BQN/) REPL!
#
# How to enter BQN glyphs:
# - Use glyph bar at the top
# - Use '\'-prefix to enter glyphs from keyboard.
# - Press 'Tab' for completions
#
# Expressions are being evaluated as you type. Press 'Shift+Enter'
# to create a new cell (the current code is being preserved in the
# workspace history).
#
# Have fun!

gid ← 2⋆31
↕4˘

(4‿1 (4×⊢)˙⊢↕4)∾ ˘ (↕4) ≍⌜ ↕8


idx ← (↕4) ≍⌜ ↕8
val ← 4‿8 ⥊ 0∘↕4×8

view ← {⌊´1‿0 = 𝕩}¨idx

hits ← +´¨view∧idx

hits + val

G ← {+´(8‿1)×⊢}¨⊢

subgroups ← G idx

8↑ ˘ 8‿↑ ⥊ subgroups ˘ ↕8

G2 ← {⍉⍉(↕8‿1‿2) ˘ 𝕩}

↑‿8 ⥊ 32↑ ⍷⥊ G2 subgroups

 {≠⥊+´}⌾⊏ subgroups

buffer ← •Show ↑‿8 ⥊ •rand.Deal 32

•Show 0 ⊏ buffer

•Show {≠⥊+´}⌾⊢ (0 ⊏ buffer)

{≠⥊+´}⌾⊏ buffer

↑‿8 ⥊ 32↑ ⍷⥊ G2 subgroups
