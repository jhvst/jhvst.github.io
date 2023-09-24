data ← ↕16
subgroup ← (↕∘≠˘)⌾⊢⊸+(0⌜(∘‿4)⥊⊢)⌾⊢ ↕16
view ← (≢subgroup) ⥊ data
prefix_sum ← +`˘view

Ravel_last ← {≠⥊⊑}˘⌽˘
subgroup_view ← Ravel_last prefix_sum
global_view ← ⥊ subgroup_view

•Show +` ⊏ ⍉subgroup_view
