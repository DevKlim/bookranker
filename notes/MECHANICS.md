# Game Mechanics Manual

This document explains the core systems logic, independent of the specific content.

## 1. The Grid System (`LaneManager`)

Base Zero uses a hybrid grid system optimized for 1000+ entities.

### Coordinate Systems
1.  **Tile Coordinates (Vector2i):**
    *   `x`: Depth (Distance from Core). 0 is spawn, 30 is Core.
    *   `z`: Lane ID (Row). 0 to 4.
2.  **World Coordinates (Vector3):**
    *   Standard Godot 3D space.
    *   Conversion: `Tile * GRID_SCALE + Offset`.

### Spatial Hashing (Optimization)
To avoid `O(N^2)` checks, entities are registered in specific dictionaries in `LaneManager`.
*   **`grid_state`**: Stores Buildings/Wires. Accessed by `Vector2i`.
*   **`enemy_spatial_map`**: Stores Enemies. Key is `Vector2i` (Tile). Value is `Array[Node]`.
    *   *Usage:* "Conduct" reaction only checks the 9 tiles around the target in `enemy_spatial_map`, not the whole enemy list.

---

## 2. Power Grid (`PowerGridManager`)

Power is calculated via a flood-fill algorithm on the **Wiring Layer**.

### The Cycle
1.  **Dirty Flag:** When a wire is placed/removed or a generator changes output, the grid is marked "Dirty".
2.  **Update Loop:**
    *   Collect all `PowerProviderComponent` nodes. Sum `Total Generation`.
    *   Traverse connected Wires/Buildings (BFS/Flood Fill).
    *   Identify connected `PowerConsumerComponent` nodes. Sum `Total Demand`.
3.  **Satisfaction:**
    *   If `Gen >= Demand`: All active.
    *   If `Gen < Demand`: Global Efficiency = `Gen / Demand`. All buildings operate at reduced speed.

---

## 3. Stagger & Energy System (`HealthComponent`)

Replacing standard "Stun", we use an Energy Shield system.

*   **HP:** Physical Health. Death at 0.
*   **Energy:** Stability Shield.
*   **Stagger:**
    *   `Volt` element damages Energy specifically.
    *   When Energy <= 0, Entity enters **Stagger State**.
    *   **Effect:** Movement Speed = 0, Defense = 0, Reactions trigger twice.
    *   **Recovery:** After `duration`, Energy resets to Max.

---

## 4. Item Transport (Conveyors)

Items are physical resources (`ItemResource`), not just numbers.

### Inventory Component
*   **Slots:** Arrays holding `{ item, count }`.
*   **I/O Masks:** Bitmasks (1=Down, 2=Left, 4=Up, 8=Right) determining allowed insertion/extraction sides.

### The Handover Logic
1.  **Push:** Conveyors attempt to push to the *next* tile in their facing direction.
2.  **Validate:** Target tile must have an `InventoryComponent` with `can_receive = true`.
3.  **Filter:** Target inventory checks Whitelist/Blacklist.
4.  **Transfer:** Item moves. If full, Conveyor halts (Backpressure).

---

## 5. Weight & Knockback

Entities have implicit mass based on their Element/Type. Upon entering the "Gravity" State, entities interact with the physics engine and force affects their displacement (ragdoll).

*   **Force Calculation:** `Knockback Momentum = (ImpactForce / Mass) * Time`.
*   **Mass Modifiers:**
    *   **Tera/Magne Elements:** Increase Mass (Heavier ragdoll logic).
    *   **Aero:** Decrease Air Resistance (More vulnerable to outside forces).

---

## 6. The Synergy System (EGS & Mod Chips)

The heart of Base Zero's replayability relies on combining modular traits. Elements act as **Quantifiable Substances** measured in **Units**, and Mod Chips alter their fundamental execution.

Finding new "builds" means combining **Elements**, **Mod Chips**, and **Reactions** intelligently.

### Units (U)
*   **Application:** Projectiles apply `U` units (default 1).
*   **Consumption:** Reactions consume the *weaker* element's unit count from both sources.
    *   `Remaining_Units = Max(0, Existing_Units - Incoming_Units)`
*   **Persistence:** If units remain after a reaction, the status persists.

### Mod Chips (The Synergizers)
Unlike standard upgrades, Mod Chips radically change how a building functions—similar to Jokers in Balatro.
*   **The Overheat Mod:** Applies the `Igni` property to a building. Output is increased drastically, but the building constantly loses health and will melt if not paired with a `Coolant (Aqua)` mod or an automated repair system.
*   **Combinations:** Stacking a `Light` Reaction with a `Spotlight` mod chip ensures stealth enemies are not only revealed but take highly scaled amplified damage. 

### Reaction Priority Logic
When an Incoming Element **(I)** hits a target with multiple Active Elements **(A, B, ..., N)**:

1.  **Product Check:**
    *   Does `I + A` form a new **Product** (Tier 2 Element)?
    *   If only one forms a Product, prioritize that. If both do, proceed to Step 2.
2.  **Unit Check:**
    *   Compare `A.units` vs `B.units`.
    *   **Higher Wins:** If `A > B`, react with `A`.
    *   **Equality:** If `A == B`, react with **BOTH** simultaneously (Trigger `I+A` and `I+B`).

---

## 7. Stat Reference

Elements and Mods modify stats dynamically.

### Enemy Stats
| Stat Key | Description |
| :--- | :--- |
| `speed_mult` | Multiplier. `0.1` = +10% Movement Speed. Negative slows. |
| `evasive_mult` | Multiplier. `0.1` = +10% Evasiveness. Negative makes target more likely to be critted. |
| `luck_stat` | Flat. Subtracts against both crit chance and crit damage of incoming attacks. |
| `damage_mult` | Multiplier. Affects Attack Damage output. |
| `incoming_damage_mult` | Multiplier. `0.1` = Enemy takes 10% *more* damage. |
| `defense_flat` | Flat addition to Defense (Armor). |

### Building Stats (Via Mod Chips)
| Stat Key | Description |
| :--- | :--- |
| `speed_mult` | Multiplier. `0.1` = +10% Movement speed if building has movement component. |
| `damage_mult` | Multiplier. Affects Attack Damage output. |
| `incoming_damage_mult` | Multiplier. `0.1` = Building takes 10% *more* damage. |
| `attack_speed_mult` | Multiplier. `0.1` = +10% Building Working Speed. |
| `efficiency` | Divisor. `2.0` = Uses 50% Power. |
| `processing_speed` | Multiplier. Speed of Crafting/Smelting ticks. |
| `output_chance` | Percentage. Chance to produce extra items. |
| `lux_stat` | Flat. Increases Magic Damage scaling of emitted projectiles, attacks. |

### Ally Stats (Combat & Equips)
| Stat Key | Description |
| :--- | :--- |
| `attack_damage` | Flat. Increases Base Damage of equipped weapons. |
| `attack_speed_mult` | Multiplier. `0.1` = +10% Attack Speed. |
| `damage_mult` | Multiplier. Affects final Attack Damage output. |
| `lux_stat` | Flat. Magic Damage scaling for weapons utilizing Lux traits. |

### Ally Combat (Attack Mode)
Allies in `ATTACK` mode will continuously fire their equipped weapon in the direction they are facing (their last movement direction). 
- **Requirements:** An Ally must have a Weapon equipped to enter Attack Mode.
- **Targeting:** Attacks are fired blindly in the direction faced, mapping correctly onto the grid or collision shape.
- **Cooldown:** Attacks are performed automatically whenever the weapon is off cooldown, appropriately scaled by the Ally's `attack_speed_mult`.
- **Synergy:** Damage modifiers (`damage_mult`, `lux_stat`, `attack_damage`) from global items or core buildings fully apply to the outcome!

---

## 8. Reaction Optimization Strategy

To handle high enemy counts, wide-area reactions (like **Conduct**) use a multi-layer filter to avoid $O(N^2)$ distance checks.

1. **Global Existence Check:** `if global_element_counts.has("conduct")`. Fast $O(1)$ bypass if the element isn't present anywhere on the map.
2. **Dedicated Spatial Registry:** Uses `tile_changed` signals to keep an exact hash map of where specific elements reside. The "Conduct" chain only queries the 9 directly adjacent tiles in this registry.

## 9. Shop

1. Upon starting a new level, the shop will only offer core mods.
2. After initial shops, remaining shops will contain all kinds of mods in the pool.

## 10. The Origami Factory (Manufacturing Mechanics)

In the "Back to Basics" level, players manufacture their own projectiles dynamically using an assembly line:
1. **Paper Generation:** A `Printer` consumes energy and raw materials to constantly produce `Paper`.
2. **Folding & Infusion:** The `Foldgami` machine acts as the primary assembler. It requires `Paper`, a `Stamp` (dictating the projectile type), and an **Elemental Chalk** or **Ink** (dictating the elemental property).
    *   *Element Infusion:* If an `Ignichalk` is used, the fold deals Igni (Fire) damage. If an `Aquachalk` is used, it deals Aqua damage. 
    *   *Ink Infusion:* If `Ink` is used, the fold deals physical damage but applies the **Slime** status reaction to the enemy on hit.
3. **Propulsion:** Finished folds fire by themselves forward. If there is a building in front with a valid input, it will instead deposit into that building's inventory(input). A `Box Fan` can be placed behind the `Foldgami` which applies aero to buildings and enemies in front of it. If aero is applied to foldgami, it will blow the output forward faster into the enemy lanes.

### Projectile Traversal (Streams)
Folds have specific traversal rules based on their design:
*   **Air-Borne (Planes, Shurikens, Cranes):** Travel over standard tiles by air and deal direct impact damage. Cranes possess piercing properties.
*   **Ground-Borne (Crumpled):** Roll across the floor. They collide with the first enemy they hit and disappear.
*   **Sea-Borne (Swans, Lotus):** Cannot travel on dry land. They require fluid paths to be placed down the lane.
    *   **Slipstream (Water):** Fast travel. Deals 1 instance of damage.
    *   **Tarstream (Ink):** Slow travel. Enables multi-hit properties due to the stickiness. **Walking on a Tarstream naturally applies the Slime reaction to enemies.**

## 11. The Number Cruncher (RNG Mechanic)
To introduce unpredictability and high-ceiling synergies, an RNG Number (1-9) is periodically generated during the level. 
*   **Condition:** If any instance of damage dealt to an enemy exactly matches this active number, the damage is immediately **doubled**.
*   **Synergy:** Weapons like the `Picasso`, which deals highly variable damage based on user inventory consumption, perfectly synergize to snipe the active multiplier.