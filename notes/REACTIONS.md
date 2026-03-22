# Reaction Compendium

This document details all elemental combinations. It is the source of truth for the `ElementManager`.

**Legend:**
*   **[C] Combat:** Effect on Enemies.
*   **[M] Mod:** Effect on Buildings.
*   **[T] Tech:** Optimization requirements for high-density waves.
*   **[COEXIST]:** Elements remain separate (setup for Tier 2).
*   **[CANCEL]:** Elements neutralize each other instantly.

---

## Tier 1.5: Primitive Reactions (The Matrix)

Direct interactions between the 5 base primitives (Igni, Volt, Magne, Aqua, Tera).

### Light (Igni + Volt)
*   **Tier:** 1.5
*   **Tags:** [C] [M] [T]
*   **Mechanic:**
    *   **[C] Highlight:** Target glows. Disables stealth/dodge chances. Incoming Igni/Volt damage is multiplied by 1.1x.
    *   **[M] Spotlight:** Building emits a cone of light that reveals stealth enemies within 15 tiles.
    *   **[T]** Use `LaneManager` spatial hash to flag enemies as "revealed" rather than raycasting every frame.
*   **Formations:** +Lux -> Plasma

### Fuse (Igni + Magne)
*   **Tier:** 1.5
*   **Tags:** [C] [M] [T]
*   **Mechanic:**
    *   **[C] Detonation:** Instant 50 AoE Damage (Radius 1.5). **Cleanses** all elements from the target (Resets state).
    *   **[M] Self-Destruct:** Instantly destroys the building, dealing 500 damage to enemies in a 2-tile radius. Leaves "Rubble" (Tera).
    *   **[T]** Queue the explosion visual/damage calculation on the next physics frame to prevent stack overflows in chain reactions.
*   **Formations:** None (Resets State)

### Scorch (Igni + Tera)
*   **Tier:** 1.5
*   **Tags:** [C] [M] [COEXIST]
*   **Mechanic:**
    *   **[C] Brittle:** The heat cracks the armor. Defense is reduced by 5 flat. Both elements persist.
    *   **[M] Kiln:** Building stops functioning but increases the `defense_flat` of adjacent buildings by 5 (Heat hardening).
*   **Formations:** +Aqua -> Obsidian

### Extinguish (Igni + Aqua)
*   **Tier:** 1.5
*   **Tags:** [C] [M] [CANCEL]
*   **Mechanic:**
    *   **[C] Vapor:** Creates a puff of steam. No extra damage, reaction stays on unit.
    *   **[M] Pressure:** Building builds up steam, increasing fire rate temporarily but risks overheating.
*   **Formations:** +Aero -> Fog

### Conduct (Volt + Magne)
*   **Tier:** 1.5
*   **Tags:** [C] [M]
*   **Mechanic:**
    *   **[C] Induction:** Damage taken by nearby enemy within 1 tile is applied to this enemy as flat True Damage (20% of original).
    *   **[M] Overclock:** Increases `processing_speed` by 5%, but increases `power_consumption` by 10%.
    *   **[T]** Use `LaneManager.get_enemies_at` for neighbor lookups. Do not use Area3D.
*   **Formations:** +Tera -> Magnetite

### Ripple (Volt + Aqua)
*   **Tier:** 1.5
*   **Tags:** [C] [M]
*   **Mechanic:**
    *   **[C] Chain:** Damage taken by this enemy is echoed to 3 nearby enemies within 2 tiles as flat Damage (20% of original).
    *   **[M] Wireless:** Connects to the Power Grid without wires (Range 3 tiles).
*   **Formations:** +Aero -> Storm

### Ground (Volt + Tera)
*   **Tier:** 1.5
*   **Tags:** [C] [M] [CANCEL]
*   **Mechanic:**
    *   **[C] Dissipate:** Removes Volt instantly. Tera remains.
    *   **[M] Earthing:** Building becomes immune to Stun/EMP effects.
*   **Formations:** None

### Rust (Magne + Aqua)
*   **Tier:** 1.5
*   **Tags:** [C] [M]
*   **Mechanic:**
    *   **[C] Corrode:** Permanently reduces Armor/Defense by 5. Stacks up to 5 times.
    *   **[M] Recycler:** On deconstruction, refunds 100% of resources (instead of 50%).
*   **Formations:** None

### Graviton (Magne + Tera)
*   **Tier:** 1.5
*   **Tags:** [C] [M]
*   **Mechanic:**
    *   **[C] Heavy:** Mass multiplier increased by 1.5x (Resistant to Knockback). Speed reduced by 40%.
    *   **[M] Anchor:** Building HP x1.5. Cannot be removed by the Remover Tool (Must be destroyed).
*   **Formations:** None

### Structure (Tera + Tera)
*   **Tier:** 1.5
*   **Tags:** [C] [M]
*   **Mechanic:**
    *   **[C] Foundation:** Crack the floor visually to prepare to build a construct. 
    *   **[M] Anchor:** Building HP x1.5. Cannot be removed by the Remover Tool (Must be destroyed).
*   **Formations:** +(Mortar, Lux) -> Golem

### Mortar (Aqua + Tera)
*   **Tier:** 1.5
*   **Tags:** [C] [M] [COEXIST]
*   **Mechanic:**
    *   **[C] Sludge:** Movement speed -50%.
    *   **[M] Coolant Reservoir:** Stores up to 100 "Heat" (prevents Igni damage until capacity full).
*   **Formations:** None.

---

## Tier 2: Catalyst Reactions (Aero / Chem)

Modifiers that spread or alter the state of primitives.

### Tailwind (Aero + Any Primitive)
*   **Tier:** 2.0
*   **Tags:** [C] [M]
*   **Mechanic:**
    *   **[C] Spread:** Applies the non-aero element to the target behind the original hit. Aero is consumed.
    *   **[M] Bellows:** Increases generic Crafting Speed by 20% due to higher heat.

### Fog (Steam + Aero)
*   **Tier:** 2.0
*   **Tags:** [C] [M]
*   **Mechanic:**
    *   **[C] Lost:** Confuses the enemy, making it randomly walk in a random direction for each step during the reaction duration. Reaction stays on the unit.
    *   **[M] Obscure:** Building becomes untargetable by ranged enemy attacks.
*   **Formations:** +Aqua -> Rain



### Pollute (Chem + Any Primitive)
*   **Tier:** 2.0
*   **Tags:** [C] [M]
*   **Mechanic:**
    *   **[C] Tox:** Extends the duration of the Primitive by 5.0s.
    *   **[M] Waste:** Doubles output yield, but damages adjacent buildings for 1 DPS.

---

## Tier 3: High Magic (Lux)

Lux is the Apex Catalyst.

### Ray (Volt + Lux)
*   **Tier:** 3.0
*   **Tags:** [C] [M]
*   **Mechanic:**
    *   **[C] Chain:** Fixed attacks bounce to 2 targets regardless of range.
    *   **[M] Relay:** Building acts as a Power Source for the entire lane (Infinite wireless range in Z-axis).

### Prism (Aqua + Lux)
*   **Tier:** 3.0
*   **Tags:** [C] [M]
*   **Mechanic:**
    *   **[C] Split:** Projectiles hitting this enemy split into 3 smaller shards hitting behind it.
    *   **[M] Solar:** Generates Power scaling with the number of light sources nearby.

### Crystal (Tera + Lux)
*   **Tier:** 3.0
*   **Tags:** [C] [M]
*   **Mechanic:**
    *   **[C] Embed:** Enemy drops 1-3 "Lux Shards" on death (Currency).
    *   **[M] Amplifier:** All installed Mod Chips operate at 1.5x effectiveness.

---

## Tier 4: Complex (Stateful)

### Plasma (Light + Igni/Magne || Plasma + Light/Igne/Magne)
*   **Tier:** 4.0
*   **Tags:** [C] [M]
*   **Mechanic:**
    *   **[C] Melt:** Incoming Igni/Volt damage is multiplied by 1.25x. If Plasma exists on the unit previously, incoming damage is instead multiplied by 1.5x
    *   **[M] Cutter:** Mining speed becomes instantaneous. Yield reduced by 50% (Vaporized).

### Slime (??? + ???)
*   **Source:** Applied intrinsically by **Ink-based** weapons and environments (e.g., Tarstream, Picasso weapon, or Origami folds infused with Ink Deposits).
*   **Tier:** 4.0 Reaction
*   **Tags:** [C] [M]
*   **Mechanic:**
    *   **[C] Sticky:** A highly viscous substance that stays on the enemy for a long duration, vastly reducing their movement speed (Speed -60%). Makes them highly vulnerable to being stunned by specific Core Mods (like *Gumball*).
    *   **[M] Gunked:** Building stops functioning but catches leaked items on the grid, holding them in place until cleaned.

### Rain (Fog + Aqua)
*   **Tier:** 3.0
*   **Tags:** [C] [M]
*   **Mechanic:**
    *   **[C] Downpour:** Creates a rain cloud on that tile that applies Aqua to anyone on that tile every 2 seconds.
    *   **[M] Wash:** Continuously cleanses negative modifiers and heat from the building.

### Chloro (Mortar + Light + Chem)
*   **Tier:** 4.0
*   **Tags:** [C] [M]
*   **Mechanic:**
    *   **[C] Entangle:** Grow roots and entangle enemy for 2 seconds. Then sprout flowers on the same tile for 30 seconds.
    *   **[M] Garden:** Generates "Biomass" fuel.

### Golem (Mortar + Structure + Lux)
*   **Tier:** 4.0
*   **Tags:** [C] [M]
*   **Mechanic:**
    *   **[C] Arise!:** Summon a friendly golem from the ground in front of the enemy and walk slowly forward. Upon colliding with enemies, act as a building to tank damage and punch the enemy with minor damage.
    *   **[M] Sentry:** Spawns a friendly golem unit every wave from the building.
