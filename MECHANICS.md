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

### Mod Logic
*   **Batteries (Volt Mod):** store power when `Gen > Demand` and discharge when `Gen < Demand`.

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

Entities have implicit mass based on their Element/Type. Upon entering the "Gravity" State, entities with the state interacts with the physics engine and any force can affect its displacement. It will place entity into ragdoll.

*   **Force Calculation:** `Knockback Momentum = (ImpactForce / Mass) * Time`.
*   **Mass Modifiers:**
    *   **Tera/Magne Elements:** Increase Mass (Affects how the ragdoll movement weighs).
    *   **Aero:** Decrease Air Resistence (More vulnerable to outside forces).
*   **Optimization:** Physics engine is *not* used for enemy movement collisions (too expensive). As such, this effect only takes place for certain effects. Custom separation logic is used in `MoveComponent` based on `radius`.

---

## 6. Elemental Gauge System (EGS)

Elements are not binary flags; they are **Quantifiable Substances** measured in **Units**.

### Units (U)
*   **Application:** Projectiles apply `U` units (default 1).
*   **Consumption:** Reactions consume the *weaker* element's unit count from both sources.
    *   `Remaining_Units = Max(0, Existing_Units - Incoming_Units)`
*   **Persistence:** If units remain after a reaction, the status persists.

### Internal Cooldown (ICD)
Prevents infinite reaction loops and spam.
*   **Base Rule:** An element cannot be reapplied to a target within `application_cooldown` seconds (defined in Resource).
*   **Resistance:** Magical Defense acts as a time multiplier.
    *   `ICD = (Base_CD + Entity_Flat_CD) * (1.0 + Magical_Defense)`
*   **Bypass:** Reactions (Product applications) typically set `ignore_cd = true` to ensure the chain completes.

### Reaction Priority Logic
When an Incoming Element **(I)** (which may or may not be the same as one active element) hits a target with multiple Active Elements **(A, B, ..., N)**:

1.  **Product Check:**
    *   Does `I + A` form a new **Product** (Tier 2 Element)?
    *   Does `I + B` form a new **Product**?
    *   *Result:* If only one forms a Product, prioritize that. If both form Products (or both form Formulants), proceed to Step 2.
2.  **Unit Check:**
    *   Compare `A.units` vs `B.units` vs `...` vs `N.units`.
    *   **Higher Wins:** If `A > B`, react with `A`.
    *   **Equality:** If `A == B`, react with **BOTH** simultaneously (Trigger `I+A` and `I+B`).

---

## 7. Stat Reference

Elements modify stats while active.

### Enemy Stats
| Stat Key | Description |
| :--- | :--- |
| `speed_mult` | Multiplier. `0.1` = +10% Movement Speed. Negative slows. |
| `evasive_mult` | Multiplier. `0.1` = +10% Evasiveness. Negative makes target more likely to be critted from incoming attacks(-0.1 = 5% crit chance). |
| `luck_stat` | Flat. Subtracts against both crit chance and crit damage of incoming attacks. (`0.1` = -5% crit chance and -10% crit damage). |
| `damage_mult` | Multiplier. Affects Attack Damage output. |
| `damage_flat` | Flat Damage. Affects Attack Damage output. |
| `incoming_damage_mult` | Multiplier. `0.1` = Enemy takes 10% *more* damage. |
| `defense_flat` | Flat addition to Defense (Armor). |
| `attack_speed_mult` | Multiplier. Animation speed for attacks. |
| `magical_defense` | Multiplier. Increases Elemental ICD duration. |
| `size_mult` | Multiplier to hitbox and model size. |
| `range_flat` | Flat addition to enemy projectile range (Tiles). |
| `weight` | Flat. Actual weight of object that takes effect when `Gravity` effect is applied. |

### Building Stats (Via Mod Chips)
| Stat Key | Description |
| :--- | :--- |
| `speed_mult` | Multiplier. `0.1` = +10% Movement speed if building has movement component. Negative slows down speed. |
| `damage_mult` | Multiplier. Affects Attack Damage output. |
| `damage_flat` | Flat Damage. Affects Attack Damage output. |
| `incoming_damage_mult` | Multiplier. `0.1` = Building takes 10% *more* damage. |
| `attack_speed_mult` | Multiplier. `0.1` = +10% Building Working Speed. Negative slows down working speed. |
| `defense_flat` | Flat addition to Defense (Armor). |
| `efficiency` | Divisor. `2.0` = Uses 50% Power. |
| `processing_speed` | Multiplier. Speed of Crafting/Smelting ticks. |
| `range_flat` | Flat addition to Turret/sensor range (Tiles). |
| `output_chance` | Percentage. Chance to produce extra items. |
| `size_mult` | Multiplier to hitbox and model size. |
| `weight` | Flat. Actual weight of object that takes effect when `Gravity` effect is applied. |
| `luck_stat` | Flat. Increases rarity of drops/processes. |
| `lux_stat` | Flat. Increases Magic Damage scaling of emitted projectiles, attacks. |

---

## 8. Reaction Optimization Strategy

To handle high enemy counts, specific wide-area reactions (like **Conduct**) use a multi-layer filter to avoid $O(N^2)$ distance checks.

### Layer 1: Global Existence Check
The `ElementManager` maintains a `global_element_counts` dictionary.
*   **Logic:** When damage occurs (or a reaction trigger is checked), the system first queries `if global_element_counts.has("conduct")`.
*   **Benefit:** If no enemy on the map has the "Conduct" status, the logic returns immediately (Cost: $O(1)$), completely skipping neighbor scanning.

### Layer 2: Dedicated Spatial Registry
Elements flagged as `SPATIAL_ELEMENTS` (e.g., Conduct) register themselves in a specific dictionary inside `ElementManager` upon application.
*   **Structure:** `{ "conduct": { Vector2i(tile_coords): [Node1, Node2] } }`
*   **Updates:** Driven by event signals (`tile_changed`) from Enemies. This avoids iterating through all enemies every frame to update their position in this specific registry.
*   **Cleanup:** The registry auto-cleans empty tiles and empty keys to keep memory usage low.
*   **Benefit:** When damage occurs to an enemy at `(10, 2)`, the system uses this registry to only check the 9 adjacent tiles (e.g., `(9..11, 1..3)`) for enemies *specifically holding* the Conduct element, rather than scanning the general entity grid.


# 9 - Game Progression
Define a tile as explored and unexplored; unexplored tiles are shadowed, pitch
black to indicate the tile is unaccessible and you cannot see enemies in that
tile. Explored tiles are normal and player starts with 15 explored tiles from
the beginning of the lane for each lane.

Unexplored - tile cannot be interacted any way. Buildings (turrets for example)
cannot be placed, detect, and interact with unexplored tiles. Each unexplored
tile has ways it could be "explored". First, players could navigate with an ally
using a Lux Lantern tool to light up a 3x3 area around the ally. The tile will
be temporarily explored. Some specialized buildings(ex. Lighthouse) can emit a 
'light' effect that will explore nearby tile based on area size. Lastly, after
defeating a wave, unexplored depths will be permanently explored for that level.

As a roguelike, game will split into levels with different mobs and items.
At the end of each level, player can decide what to output, whether it is
materials, items, buildings; each level acts as a "factory". This means, future
levels can import factories which are beaten levels with exported goods. Player
can retry levels and save new factories after beating the boss and configuring
the export. There are only a limited number of exports

Level starts with giving player starting items unique to the level. Player,
if allowed, can import factories and get a constant output based on that
level's output speed calculated(which we will find the prod. speeds of all
buildings in a factory as well as the travel time of the transport to
calculate the output speed of a level/factory). Throughout the course of
the level, player will have periods of plan time and periods of enemy/boss waves.

Levels will start short and ramp up in either difficulty or est. time duration.

Levels separate section of depths with new mechanics, terrain, ores, enemies,
and bosses. Typically, at the end of a level, emerges a boss that the player
must eliminate to progress to the next level. It will unlock new crafting tiers,
elemental reactions, and spawnable loot.

There is a time cycle where daytime is the time that players will explore, farm
materials, build, etc. Nighttime will spawn hordes and waves of enemies. After
each horde, player will receive rewards based on the "Wave Rewards" which could be
XP, Gold, Items, Permanent Buffs, Temporary Buffs, New Recipes, New Buildings.

# 10 - Biomes

## 1 - Junkyard
First biome which is full of scrap metal and rusted machinery. Enemies are near
malfunctioning robots and machinery made from old tech of the previous era (2000s).
Some enemies include Roamba(Roomba), Unidryl(One wheel robot with drill arms), ...

There are scrap parts scattered throughout the biome with iron, copper, coal,
zinc, and aluminum to mine as well..

## 2 - 
