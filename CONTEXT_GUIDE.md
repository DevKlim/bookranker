# Developer Context Guide

This document outlines the file structure and provides "Context Recipes" for specific development tasks. Use this to determine which files to read or edit when implementing new features to minimize Context Window usage.

**Architecture:** Component-Based (Godot). Logic is distributed into reusable components attached to Entities. Global logic is handled by Singletons (Managers).

## 1. Data Entry & Configuration (No Logic Coding)

**Primary Method:** The game uses a JSON-driven content pipeline.
*   **Source:** `data/content_manifest.json`
*   **Tool:** `scripts/tools/data_importer.gd` (Open `DataImporter.tscn` or attach script, check `Import Data` in Inspector).

### A. Adding a New Item, Ore, or Recipe
*   **Action:** Edit `data/content_manifest.json`.
*   **Ores:** Add `ore_data` to an item entry to register it as a mineable resource.
*   **Run Tool:** The importer will generate `.tres` files in `resources/items/`.

### B. configuring Enemies & Stats
*   **Action:** Edit `data/content_manifest.json`.
*   **Structure:** Define `logic` (health, speed) and `params` (component variables).
*   **Run Tool:** The importer generates `.tres` files in `resources/enemies/`.

---

## 2. Logic Implementation (Coding Tasks)

### A. Creating a New Processing Building (e.g., Crusher, Mixer)
*   **Core Context:** `scripts/entities/base_building.gd`
*   **Component:** `scripts/components/inventory_component.gd`
*   **Reference Implementation:**
    *   If it auto-converts 1 input -> 1 output (like a Furnace), read: `scripts/entities/buildings/burnace.gd`
    *   If it combines inputs (Crafting), read: `scripts/entities/buildings/asourcer.gd`
*   **Task:** Implement `_process` to handle the timer and `receive_item` to accept inputs.

### B. implementing Conveyor Logic (Splitters, Mergers, Underground)
*   **Core Context:** `scripts/entities/buildings/conveyor.gd`
*   **Parent Logic:** `scripts/entities/base_building.gd` (Specifically `get_neighbor` and `try_output_from_inventory`)
*   **Grid Context:** `scripts/singletons/lane_manager.gd` (To understand logical connections vs physical tiles)
*   **Task:** Override `receive_item` to handle sorting logic and `_try_pass_item` to handle output direction logic.

### C. creating Logic Gates / Advanced Wiring
*   **Core Context:** `scripts/entities/base_wiring.gd`
*   **Network Logic:** `scripts/singletons/wiring_manager.gd`
*   **Reference:** `scripts/entities/buildings/wire.gd`
*   **Task:** Create a script inheriting `BaseWiring`. Use `WiringManager` to read the state of neighbors and set `is_powered` on self.

### D. UI & HUD Modifications
*   **Core Context:** `scripts/ui/game_ui.gd`
*   **Sub-Menu:** (Depending on task) `scripts/ui/inventory_gui.gd` OR `scripts/ui/hotbar.gd`
*   **Interaction:** `scripts/main.gd` (Handles mouse inputs/selection that trigger UI)

---

## 3. Predicted Upcoming Tasks

These are complex tasks likely to appear next in development, with their specific context requirements.

### Task: Implementing "Tech Tree" or Unlocks
*   **Reason:** Roguelike progression usually requires unlocking buildings.
*   **Required Context:**
    *   `scripts/singletons/game_manager.gd` (To track game state/progress)
    *   `scripts/ui/build_ui.gd` or `scripts/ui/game_ui.gd` (To lock/hide buttons)
    *   `scripts/singletons/build_manager.gd` (To validate if an item is placeable)

### Task: Adding Sound Effects (SFX)
*   **Reason:** Game feel.
*   **Strategy:** Don't add audio players to every script. Create an `AudioManager`.
*   **Required Context:**
    *   `scripts/singletons/game_manager.gd` (To listen for global events like Wave Start)
    *   `scripts/components/shooter_component.gd` (Add signal `shot_fired`)
    *   `scripts/entities/base_building.gd` (Add audio logic for placing/working)

### Task: Adding "Boss" Enemies (Multi-tile or Complex Behavior)
*   **Reason:** Wave progression.
*   **Required Context:**
    *   `scripts/entities/enemy.gd` (Movement logic)
    *   `scripts/components/health_component.gd` (Boss health bars)
    *   `scripts/singletons/lane_manager.gd` (If boss is wide, it needs to check collision on multiple lanes)

### Task: Save/Load System
*   **Reason:** Persisting runs.
*   **Required Context:**
    *   `scripts/singletons/lane_manager.gd` (To serialize the `grid_state` dictionary)
    *   `scripts/singletons/wiring_manager.gd` (To serialize wire map)
    *   `scripts/singletons/game_manager.gd` (To save wave number/resources)
    *   `scripts/entities/base_building.gd` (To serialize inventory contents)

---

## 4. Quick Component Reference

If you are writing a script and need to...

*   **Make it die:** Add `HealthComponent`.
*   **Make it store items:** Add `InventoryComponent`.
*   **Make it move:** Add `MoveComponent`.
*   **Make it shoot:** Add `ShooterComponent` + `TargetAcquirerComponent`.
*   **Make it use electricity:** Add `PowerConsumerComponent`.
*   **Make it generate electricity:** Add `PowerProviderComponent`.
*   **Make it exist on the grid:** `GridComponent` (Added automatically by `BaseBuilding`/`BaseWiring`).
*   **Apply Fire/Ice/etc:** `ElementManager.apply_element(target, resource)`.
