data ← ↕16
subgroup ← (↕∘≠˘)⌾⊢⊸+(0⌜(∘‿4)⥊⊢)⌾⊢ ↕16
view ← (≢subgroup) ⥊ data
prefix_sum ← +`˘view

Ravel_last ← {≠⥊⊑}˘⌽˘
•Show ⥊(Ravel_last prefix_sum)
