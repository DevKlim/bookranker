# Base Zero

A roguelike tower-defense factory-builder developed in Godot 4.x.

## Overview

**Base Zero** combines the lane-based defense of *Plants vs. Zombies*, the logistical puzzles of *Factorio*, and the power progression of *Vampire Survivors*. You defend the **Core** from wave-based enemies by building automated defenses and managing a power grid.

## Core Pillars

1.  **Defend the Core:** The heart of your base. Generates initial power but results in Game Over if destroyed.
2.  **Dual-Layer Building:**
    *   **Wiring Layer:** Logic gates and dust placed *inside* tiles.
    *   **Mech Layer:** Turrets, drills, and factories placed *on top* of tiles (GridMap).
3.  **Component-Based Architecture:** Entities are composed of reusable logic nodes (Health, Inventory, PowerConsumer).
4.  **Elemental Reactions:** Projectiles apply status effects that combine into powerful reactions.

## Development Setup

1.  **Godot Version:** Godot 4.x (Stable).
2.  **Data Generation:**
    *   Game content is defined in `data/content_manifest.json`.
    *   **Importer Tool:** Open `scripts/tools/data_importer.gd`. Enable the **Import Data** boolean in the Inspector.
3.  **GridMap Workflow:**
    *   Blocks defined in the manifest are auto-generated into `resources/mesh_library.tres`.
    *   The importer automatically detects textures with `_top`, `_side`, `_bottom`, etc., suffixes to apply to specific cube faces.

## Controls

*   **WASD:** Camera Movement
*   **Scroll:** Zoom
*   **B:** Build Menu (Toggle)
*   **LMB:** Place Structure
*   **RMB:** Cancel / Close Menu
