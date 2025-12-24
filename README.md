# Base Zero (Working Title)

A roguelike tower-defense factory-builder about surviving against a mechanical apocalypse, presented in a 2D isometric pixel art style.

## Overview

**Base Zero** is an ambitious project that fuses the strategic, lane-based defense of *Plants vs. Zombies*, the complex logistical and automation puzzles of *Factorio*, and the intense, wave-based survival and power progression of *Vampire Survivors*. Set in a desolate future, you play as the last human survivor, an engineer tasked with defending the last bastion of humanity—the Core—from an unending horde of rogue androids.

This game challenges players to think like an engineer, a tactician, and a survivor. You will not only place defensive structures but also design and manage the intricate power grid that fuels them. Success depends on your ability to expand your factory, harness powerful elemental reactions, and adapt your strategy on the fly with randomized, run-altering upgrades. The world is presented in a distinct 2D pixel art style, using an isometric perspective to give a clear and tactical overview of the battlefield.

For the initial development phase, the gameplay scope will focus on one 5-lane path approaching the top right of the Core.

## Core Gameplay Mechanics

The gameplay is built upon a layered foundation of defense, resource management, and roguelike progression. Each mechanic is designed to interact with the others, creating deep and emergent strategic possibilities.

### 1. Defend the Core: The Heart of the Operation

The Core is the central entity of your base and the singular objective of your defense. It serves two critical functions:

*   **Ultimate Objective:** Enemies move in a straight path from one end of a lane to the other, dictated by the tilemap. They will relentlessly march towards the Core. If its health is depleted, the run is over.
*   **Primary Power Source:** At the start of each run, the Core provides a small, finite amount of energy. It is the genesis of your power grid, from which all your initial machinery must be powered.

### 2. Building: The Wiring and Mech Layers

During the game, the player enters a "building state" with an allotted time to place structures. Building is divided into two distinct layers:

*   **The Wiring Layer:** In this world, science is magical. Players have access to "magic dust" which acts as wires/redstone. All magic dust placeables are on the wiring layer, where they can be placed only inside an existing tile. This network connects from the Core and powers any building on the mech layer above it.
*   **The Mech Layer:** This layer contains the functional buildings that can be placed on top of any tile. All mechs have a defined input and output, allowing them to be chained together for automation.

### 3. Factory Construction & Automation

Your primary method of interaction with the world is through building. You will transform a barren landscape into a sprawling, automated fortress of destruction.

*   **Placement and Construction:** Players select structures from a build menu and place them on the isometric tile-based world. Once placed, a mech must be on a tile powered by the Wiring Layer to become operational.
*   **Building Modifiers:** Items stored within a building's inventory (e.g., input buffers) can modify the building's stats. For example, feeding a **Super Conductor** into a turret might increase its power efficiency, while a **Magma Core** could boost damage.
*   **Mech Archetypes:**
    *   **Drills:** Mine resource deposits located directly underneath them.
    *   **Conveyor Belts:** Move items from their input to their output.
    *   **Processors:** Convert raw materials into advanced items or ammo.
    *   **Turrets:** Fire stored items as projectiles.

### 4. The Elemental Reaction System

A deep and strategic combat system built on elemental synergies. Elements are defined dynamically via resources.

*   **Application:** Projectiles and traps apply elemental status effects (Fire, Water, Shock, Chem).
*   **Reactions:** When a new element is applied to an enemy already affected by another, a reaction occurs based on rules defined in the JSON data (e.g., **Fire + Chem = Explosion** or **Water + Shock = Electrocute**).

### 5. Data-Driven Content Pipeline

The game features a robust system for adding content without writing code.

*   **Manifest:** All game data is defined in `data/content_manifest.json`. This includes Elements, Items (with stats and modifiers), Recipes, and Enemies.
*   **Importer Tool:** A custom Godot tool (`scripts/tools/data_importer.gd`) parses this JSON and automatically generates or updates the `.tres` Resource files used by the engine.
*   **Modding Friendly:** New items and balance changes can be implemented simply by editing the text file and running the importer.

## Setting and Narrative

In a not-so-distant future, a catastrophic event known as the "Cascade" caused the global network of benevolent androids to turn against their creators. You are the Architect, the last human engineer, sheltered within a heavily fortified outpost. Your only companion is the silent, humming Core—a mysterious power source that you must protect at all costs.

## Art Style and Presentation

The game employs a **2D isometric pixel art style** to merge nostalgic aesthetics with gameplay clarity.

*   **Isometric World:** The environment, the tile grid, and all defensive machines are rendered as pixel art on an isometric grid. This provides a clear, tactical view with a sense of depth and place.
*   **Pixel Art Characters:** The player character (a cosmetic UI element) and all enemy androids are rendered as high-fidelity pixel art sprites.

## Project Setup

This project is being developed using the Godot Engine.

1.  Ensure you have the latest stable version of the [Godot Engine](https://godotengine.org/download/) installed.
2.  Clone this repository to your local machine.
3.  Open the Godot project manager and import the project.
4.  **Important:** To generate the initial game data, open the `DataImporter.tscn` scene (or attach `scripts/tools/data_importer.gd` to a node) and check the "Import Data" box in the Inspector. This will generate the necessary `.tres` files in the `resources/` folder.

## Planned Controls

*   **Camera Movement:** A (Left), D (Right), W (Up), S (Down)
*   **Build Menu:** B
*   **Place Structure:** Left Mouse Button
*   **Cancel Action:** Right Mouse Button
*   **Camera Zoom:** Mouse Wheel

## Technology Stack

*   **Game Engine:** Godot Engine (Version 4.x)
*   **Programming Language:** GDScript
*   **Data Format:** JSON (Content Manifest)
