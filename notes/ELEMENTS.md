# Elemental System Documentation

The elemental system in Base Zero functions as a **Reaction Engine**. Every entity has an `ElementalComponent` that tracks applied elements (Primitives or Products). When a new element is applied, it checks for reaction rules against existing elements.

## Design Guidelines: Tiers & Mods

To maintain balance and optimization with 1000+ enemies, all new elements must adhere to this hierarchy. Reactions generally scale from Simple Math (Tier 1) to Global State Changes (Tier 10).

### The "Dual-State" Rule (Combat vs. Structure)
Every Element/Reaction must have two distinct effects defined in the code/manifest:
1.  **Combat (On-Hit):** Applied to **Enemies** via Projectiles. This is usually temporary.
2.  **Structural (Mod Chip):** Applied to **Buildings** by inserting the Element item into a "Mod Slot" (Disks). This persists until removed.
    *   **Theme:** Science (Efficiency/Automation) vs. Magic (Power/Chaos).
    *   **Risk:** Powerful Mods should have drawbacks (e.g., "Igni" adds damage but increases the `temperature` stat, slowly burning the building).

### The Primitive Matrix Rule
To ensure strategic building placement (synergy vs. anti-synergy), the 5 base primitives (**Igni, Volt, Magne, Aqua, Tera**) follow strict interaction rules.

*   **2 Reactions:** Creates a new Product (Tier 1.5).
*   **1 Coexistence:** Both elements stay on the target. Used to setup Tier 2 combos.
*   **1 Cancellation:** Both elements are removed instantly. No damage, no effect. (Anti-Synergy).

*Note: **Chem, Aero, and Lux** are Universal Catalysts and react with almost everything.*

---

## Primitives (Tier 1)

The fundamental building blocks.

### Igni (Fire / Heat)
*   **Type:** Energy / Chaos
*   **Combat:** None.
*   **Mod Chip (Overheat):** Increases Damage by 1.2x, but increases the building's `temperature` stat by 1. Requires active cooling fans or it takes continuous damage.

### Volt (Electricity / Energy)
*   **Type:** Energy / Tech
*   **Combat:** None.
*   **Mod Chip (Battery):** Stores up to 500 excess Power. Releases it when grid demand > generation.

### Magne (Magnetic / Force)
*   **Type:** Physical / Tech
*   **Combat:** None.
*   **Mod Chip (Shield):** Regenerative shield of 10 HP

### Aqua (Water / Coolant)
*   **Type:** Physical / Utility
*   **Combat:** None.
*   **Mod Chip (Coolant):** Passive healing of 1HP/sec. Reduces Fire Rate by 2%.

### Tera (Earth / Structure)
*   **Type:** Physical / Structure
*   **Combat:** None.
*   **Mod Chip (Reinforce):** Multiplies Max HP by 1.2x. The building can no longer be rotated or moved (Must be "bombed" to remove).

### Aero (Air / Motion)
*   **Type:** Universal / Motion
*   **Combat:** None.
*   **Mod Chip (Vent):** Nearby buildings will obtain 1% of this building's stats

### Chem (Acid / Catalyst)
*   **Type:** Universal / Decay
*   **Combat:** None.
*   **Mod Chip (Catalyst):** Increase Duration stat of Building by 5%

### Lux (Light / Magic)
*   **Type:** Universal / Apex
*   **Combat:** None.
*   **Mod Chip (Prism):** Turns Building to scale with Magic Attack.

