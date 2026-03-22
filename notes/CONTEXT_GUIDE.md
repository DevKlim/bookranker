# Base Zero - Developer Guide

## Architecture Overview

Base Zero uses a **Component-Based Architecture** in Godot 4.x. Entities (Buildings, Enemies, Projectiles) are composed of reusable nodes that handle specific logic.

### Core Components

*   **`HealthComponent`**: Manages HP, Defense, and the new **Energy/Stagger** system.
    *   *Signals*: `health_changed`, `died`, `staggered`, `recovered`.
    *   *Fields*: `max_health`, `defense`, `purity` (CC resistance).
*   **`PowerConsumerComponent`**: Handles connecting to the power grid.
    *   *Logic*: Checks for `Wire` on the same tile or uses efficiency stats.
*   **`InventoryComponent`**: Storage for items.
    *   *Features*: Whitelists/Blacklists, I/O direction logic (can_receive/can_output).
*   **`ShooterComponent`**: Handles spawning projectiles.
    *   *Logic*: Calculates damage based on Parent Stats + Ammo Stats + Elemental Modifiers.
*   **`ElementalComponent`**: The heart of the status system.
    *   *Logic*: Tracks active elements, calculates Stat Modifiers (speed, attack speed, etc.), and displays visuals.
*   **`TargetAcquirerComponent`**: Finds targets (Enemies) within a radius using PhysicsQueries.
*   **`StreamComponent`**: Manages surface modifiers (Slipstream/Tarstream) on tiles, affecting entity speed and allowing sea-borne projectiles/conveyed items to traverse.
*   **`WindComponent`**: Used by fans/blowers. Applies a directional physics force and the Aero element to entities/projectiles within a collision shape.

---

## The Element System

Elements are no longer just "types". They are active status effects that interact.

1.  **Application**: When a projectile (or source) hits an entity, the Element is applied via `ElementManager`.
2.  **Reactions**: The `ElementManager` checks the target's *existing* elements against the *incoming* element.
    *   If a pair matches a rule in `content_manifest.json`, a **Reaction** occurs.
    *   Example: Target has **Igni**. Hit by **Volt**. Result -> **Light** (Reaction triggered, Igni consumed, Light applied).
3.  **Stats**: While an element is active (duration based), it applies modifiers found in `stat_modifiers` to the entity.

### Available Stats
*   `speed_mult`: Movement speed multiplier (0.1 = +10%).
*   `damage_mult`: Output damage multiplier.
*   `incoming_damage_mult`: Multiplier on damage taken (negative reduces damage).
*   `attack_speed_mult`: Fire rate modifier.
*   `defense_flat`: Flat reduction of incoming damage.
*   `lux_flat`: Added magic damage.
*   `efficiency`: Power consumption divisor.
*   `temperature`: Abstract stat tracked by Mod Chips. High values degrade building HP over time unless offset by Coolants.
---

## Data Pipeline & Importer Schema

Game content is defined in `data/content_manifest.json`. The `scripts/tools/data_importer.gd` tool reads this and generates `.tres` resources and `.tscn` scenes.

**To Run Import:**
1. Open `scripts/tools/data_importer.gd`.
2. In the Inspector, check **Import Data**.

### JSON Schema Reference

#### 1. Elements
Defines status effects and reactions.
```json
{
  "id": "igni",
  "name": "Igni",
  "color": "#FFFFFF",
  "duration": 5.0,
  "cooldown": 0.5,
  "reactions": {
    "target_element_id": "result_element_id"
  },
  "effects": {
    "stat_name": 0.1
  }
}
```

#### 2. Items
Defines inventory items and projectiles.
```json
{
  "id": "iron_ore",
  "name": "Iron Ore",
  "texture": "res://path/to/icon.png",
  "item_data": {
    "damage": 5.0,
    "stack": 50,
    "element": "magne",
    "element_units": 1,
    "ignore_element_cd": false,
    "modifiers": {} 
  },
  "ore_generation": { 
    "block": "Block Name in MeshLib",
    "min_depth": 0,
    "max_depth": 30,
    "rarity": 0.1
  }
}
```

#### 3. Recipes
Defines crafting rules.
```json
{
  "id": "smelt_iron",
  "name": "Smelt Iron",
  "category": "assembly",
  "time": 2.0,
  "tier": 1,
  "output": "iron_alloy", 
  "count": 1,
  "inputs": {
    "iron_ore": 1,
    "coal": 1
  }
}
```

#### 4. Enemies
Defines units. The importer generates a Scene extending `Enemy.gd` with components attached.
```json
{
  "id": "basic_robot",
  "name": "Basic Robot",
  "scene_path": "res://scenes/enemies/custom_scene.tscn", 
  "template": "res://optional_base_scene.tscn",
  "logic": {
    "health": 50.0,
    "speed": 40.0,
    "defense": 0.0,
    "resistances": { "igni": 0.5 }
  },
  "params": {
    "attack_damage": 10.0,
    "attack_speed": 1.0
  },
  "drops": [
    { "item": "scrap", "min": 1, "max": 2, "chance": 0.5 }
  ]
}
```

#### 5. Buildables (Buildings & Wires)
Defines structures. The importer generates scenes with `BaseBuilding` logic.
```json
{
  "id": "turret",
  "name": "Turret",
  "description": "Shoots things.",
  "template": "res://path/to/base_scene.tscn", 
  "grid": {
    "width": 1,
    "height": 1,
    "layer": "mech" 
  },
  "visuals": {
    "type": "sprite", 
    "texture": "res://path/to/sheet.png",
    "width": 32, "height": 32,
    "animations": { 
      "default": { "row": 0, "count": 4, "loop": true } 
    }
  },
  "structure": [
    { "offset": [0,0], "texture": "res://block_tex.png", "rotation": 0, "is_center": true }
  ],
  "logic": {
    "power_cost": 10.0,
    "health": 100.0,
    "rotates": true,
    "processing": true,  
    "targeting": true,   
    "shooting": true,    
    "has_input": true,
    "has_output": false,
    "io_config": {
      "input": ["back", "left", "right", "all", "none"], 
      "output": ["front"] 
    },
    "inventory": {
      "slots": 1,
      "capacity": 50,
      "can_receive": true,
      "can_output": false,
      "omni": false,
      "whitelist": ["item_id"],
      "blacklist": []
    }
  }
}
```
*Note: `grid.layer` can be "wire" (logic layer) or "mech" (physical layer).*

#### 6. Blocks
Defines standard GridMap cubes.
```json
{
  "id": 0,
  "name": "Dirt",
  "texture_base": "res://assets/blocks/dirt.png", 
  "dimensions": [1, 1, 1]
}
```
*`texture_base` automatically looks for `_top`, `_side`, `_bottom` suffixes.*
