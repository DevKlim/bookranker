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

### Reaction Priority Logic
When an Incoming Element **(I)** hits a target with multiple Active Elements **(A, B, ..., N)**:

1.  **Product Check:**
    *   Does `I + A` form a new **Product** (Tier 2 Element)?
    *   If only one forms a Product, prioritize that. If both do, proceed to Step 2.
2.  **Unit Check:**
    *   Compare `A.units` vs `B.units`.
    *   **Higher Wins:** If `A > B`, react with `A`.
    *   **Equality:** If `A == B`, react with **BOTH** simultaneously (Trigger `I+A` and `I+B`).

### Units (U)
*   **Application:** Projectiles apply `U` units (default 1).
*   **Consumption:** Reactions consume the *weaker* element's unit count from both sources.
    *   `Remaining_Units = Max(0, Existing_Units - Incoming_Units)`
*   **Persistence:** If units remain after a reaction, the status persists.

### Mod Chips (The Synergizers)
Unlike standard upgrades, Mod Chips radically change how a building functions—similar to Jokers in Balatro.
*   **The Overheat Mod:** Applies the `Igni` property to a building. Output is increased drastically, but the building constantly loses health and will melt if not paired with a `Coolant (Aqua)` mod or an automated repair system.
*   **Combinations:** Stacking a `Light` Reaction with a `Spotlight` mod chip ensures stealth enemies are not only revealed but take highly scaled amplified damage. 

---

## 7. Unified Stat System & Formulas

Base Zero uses a unified stat vocabulary across Allies, Enemies, and Buildings. This allows "Mod Chips" and "Artifacts" to be completely universal, affecting entities differently based on their mechanical role. The calculations themselves are exposed in JSON strings, evaluated at runtime by Godot's `Expression` class.

### Universal Stats
| Stat Key | Effect on Allies/Enemies | Effect on Buildings |
| :--- | :--- | :--- |
| `max_health` & `health_mult` | Maximum HP capacity. | Maximum structural integrity. |
| `speed` & `speed_mult` | Walking / Movement Speed. | Conveyor belt / transport stream speed. |
| `attack_speed` & `attack_speed_mult` | Rate of weapon fire or melee strikes. | Machine crafting/processing tick speed. |
| `attack_damage` & `damage_mult` | Flat bonus/Multiplier to physical attacks. | Flat bonus/Multiplier to emitted projectiles (turrets/fans). |
| `defense` & `defense_mult` | Armor rating (flat damage reduction). | Structural reinforcement (damage reduction). |
| `magical_defense` | Multiplier scaling resistance to elemental debuffs. | Resistance to environmental hazards. |
| `lux_stat` | Magic damage scaling for spells, reactions, and ticks. | Overcharges magic-based machines and arrays. |
| `shields` | Gives a separate flat health bar that can regenerate. | Gives a separate flat health bar that can regenerate. |
| `weight` & `weight_mult` | Physics mass. High weight resists ragdolling. | Base inertia (prevents moving structures). |
| `luck_stat` | Critical hit chance and dodge percentage. | Percentage chance to produce double outputs. |
| `efficiency` | Stamina / Energy consumption rate. | Power grid drain divisor (2.0 = uses 50% power). |
| `incoming_damage_mult` | Vulnerability (+10% extra damage taken). | Vulnerability (+10% extra damage taken). |

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

## 10. Crafting Tiers
Recipes possess a `tier` rating which represents when they become available during a level's progression.
*   **Tier 1:** Unlocked initially at the start of Phase 1 (Wave 1).
*   **Tier 2+:** Unlocked after clearing subsequent phases. For example, Tier 2 recipes become available upon entering Phase 2 (Wave 2).
Building UI panels dynamically update to reveal newly unlocked recipes when players advance through the level's waves.

## 11. The Origami Factory (Manufacturing Mechanics)

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

## 12. The Number Cruncher (RNG Mechanic)
To introduce unpredictability and high-ceiling synergies, an RNG Number (1-9) is periodically generated during the level. 
*   **Condition:** If any instance of damage dealt to an enemy exactly matches this active number, the damage is immediately **doubled**.
*   **Synergy:** Weapons like the `Picasso`, which deals highly variable damage based on user inventory consumption, perfectly synergize to snipe the active multiplier.

## 13. Customizing Building UI & Inventories

Base Zero dynamically generates the player-facing interface for buildings based on the presence of certain Components and Methods in the building's script.

### Controlling the Grid UI vs. Machine UI
By default, if a building has an `InventoryComponent`, clicking the building opens the **Generic Grid UI**.
*   **Machine UI:** If you want a structured Input/Output layout (like Smelters), your script must implement `get_processing_icon()`. This triggers `inventory_gui.gd` to render the machine layout.
*   **Generic Grid UI:** Used for chests or assembly stations like `Foldgami`. 
*   **No Inventory UI:** If you omit the `InventoryComponent` completely (or set its max_slots to 0), the main inventory grid is hidden. **However**, the Mod Chip grid will still appear, allowing the building to be modded! Example: `Box Fan`.

### Customizing Generic Slots (The Foldgami Method)
If you rely on the Generic Grid UI but want specific slots to behave and look distinctly, override these methods in your building's script:

1.  **Slot Labels (Text overlay on the slot):**
    ```gdscript
    func get_slot_label(idx: int) -> String:
        if idx == 0: return "IN"
        if idx == 1: return "OUT"
        return ""
    ```
2.  **Slot Tooltips (Hover descriptions):**
    ```gdscript
    func get_slot_tooltip(idx: int) -> String:
        if idx == 0: return "Raw Materials"
        return ""
    ```
3.  **Strict Slot Filtering (Preventing wrong items):**
    To restrict specific items to specific slots dynamically (e.g. slot 1 *must* be stamps), bind a custom filter directly to the `InventoryComponent` in `_ready()`:
    ```gdscript
    func _ready() -> void:
        super._ready()
        if inventory_component:
            inventory_component.slot_filter = _my_slot_filter

    func _my_slot_filter(item: Resource, index: int) -> bool:
        var id = item.resource_path.get_file().get_basename()
        if index == 1: return id.begins_with("stamp_")
        return true
    ```

## 14. Troubleshooting & Modding Pitfalls

Recent structural fixes highlighted a few common modding pitfalls to watch out for:

*   **Scene Script Linking (`.tscn` setup):** When creating a specific building (like `Printer` or `Box Fan`), ensure the root node of the `.tscn` file points to its specialized script (e.g., `res://scripts/entities/buildings/printer.gd`), not the generic `base_building.gd`. Otherwise, custom `_physics_process` and logic will not execute.
*   **Targeting & Groups:** For AOE attacks or buffs (like the Box Fan blowing `Aero`) to recognize a building as a valid target, the building must be in the `"buildings"` group. `BaseBuilding` now automatically registers itself to this group in its `_ready()` function.
*   **UI Mod Grids (Fallback Logic):** Buildings do not require a standard `InventoryComponent` to use Mod Chips. If a building only has a `mod_inventory` (like the Box Fan), the UI gracefully adapts to show only the Mod Slots and the stats overlay.
*   **Creative Mode Trash:** To discard items quickly while in Creative mode, players can drag and drop items from their player inventory directly back into the creative item catalog grids. The grids have been assigned native drop logic (`_can_drop_trash`, `_drop_trash`).

## 15. Random Events (EventManager)
Base Zero includes a dynamic `EventManager` to introduce run-altering modifiers.
*   **Triggers:** Events can be triggered natively via the Level JSON (`random_events` pool) or directly during a specific Wave phase.
*   **Effects:** An event can grant items, apply global stat multipliers, or alter how enemies spawn.
*   **Duration:** Events with a duration > 0 will persist until the timer expires. The `EventManager` automatically rolls back temporary modifications (like Stat Multipliers) when the event ends.

## 16. Loot Buildings
In levels, `loot_buildings` can be configured to generate functional structures (like a `Cubby`) that act as clutter. They spawn populated with resources from an item pool. Players can either destroy them to drop items or open them to loot normally.
*   **Loot Component:** These buildings automatically rename themselves to "Loot" in the UI. Once all items are extracted, they automatically deconstruct themselves to clear space on the grid.

## 17. The Mist (Fog of War)
To create a sense of progression and claustrophobia, unexplored depths are covered in a dense Mist.
*   **Vision & Interaction:** The Mist completely smothers tiles. Players cannot place buildings, select entities, or interact with anything inside the Mist.
*   **Wave Spawning:** Wave enemies will continuously spawn from the exact edge of the Mist.
*   **Recession:** Upon completing a wave phase, the Mist dynamically recedes based on the `fog_depth` configuration in the level's JSON, revealing new ores, clutter, and space to build.
