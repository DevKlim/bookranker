# Base Zero - Game Progression

Base Zero is heavily inspired by factory automation and roguelikes like Balatro, where discovering synergies, breaking the game's economy, and finding entirely new ways to play is the core loop. The game consists of repeated runs ("Levels") where the factory you build can be exported to help power future runs.

## Roguelike System Loop

1. **Levels & Runs:**
   * The game is split into discrete levels featuring different biomes, specific mobs, and raw materials.
   * At the end of each level (after surviving the final boss wave), you configure what your factory "exports".
   * This completed level is saved as a "Factory Profile".

2. **Importing Factories:**
   * When starting a new level, players can import an unlocked Factory Profile. Factory profiles are only obtained from previous defeated levels (Level 2 cannot use Level 2 or higher factories; Level 3 factories can use Level 2 and 1 factories). 
   * At the end of the level, after the player defeats the boss, they can customize their field until they are satisfied with the production and then output their resources into an output area. This creates a factory for later levels to utilize items from previous gameplay.
   * The imported factory guarantees a constant baseline flow of resources (calculated by evaluating the production speeds and travel times within that factory).
   * Players must adapt their strategies by taking the exported materials of past factories to tackle increasingly harder biomes.

3. **Day / Night Cycle:**
   * **Daytime (Planning):** Time for the player to explore, mine raw materials, build infrastructure, set up automation, and craft combinations.
   * **Nighttime (Waves):** Hordes of enemies spawn. Completing waves grants temporary buffs, randomized loot drops, and permanent unlocks.

## The Synergy Engine (Balatro-style Combinations)

The true depth of Base Zero lies in its elemental reaction system and **Mod Chips**, which function similarly to Jokers in Balatro. Instead of flat linear upgrades, the player modifies how their factory behaves on a fundamental level.

### Elemental Matrix & Crafting
*   **Primitives:** Everything from Ores to Bullets has an intrinsic element (`Igni`, `Volt`, `Aqua`, `Magne`, `Tera`). 
*   **Reactions:** When two elements interact inside an entity, they create powerful Tier 2 effects.
    *   *Example:* Routing `Aqua` coolant into a `Magne` shield generator creates a `Rust` field, lowering armor of enemies passing through.
    *   *Example:* Firing `Volt` bullets into an enemy burning with `Igni` creates `Light`, a blinding plasma that amplifies all incoming damage and strips stealth.

### Mod Chips (Rule Breakers)
Mod Chips are inserted into the Mod Slots of machines or the Core itself. They dramatically shift gameplay logic, often providing huge power spikes with unique trade-offs.

*   **The "Overheat" Paradigm:** Applies `Igni` to a building. Crafting output is tripled, but the building steadily takes burn damage. The player must automate repair drones or route `Aqua` (coolant) to offset it.
*   **The "Spotlight" Amplifier:** If a building has both `Igni` and `Volt` properties applied, it becomes a beacon of `Light`. Any `Spotlight` mod chip on it will cause the building's aura to scale dynamically with the amount of light generated, granting massive buffs to surrounding turrets.
*   **The "Undervolted" Rework:** If not enough energy is supplied to a building equipped with this chip, it is afflicted with frost (`Aqua`) and still powers at a fraction dependent on the available power from the source. This allows players to build massive arrays of slow, freezing turrets running on practically zero power.

### Loot & Unlockables
*   **Drops:** Defeated wave bosses and random loot chests drop Mod Chips or rare elements.
*   **Wave Rewards:** After a wave, you choose between different game-altering relics or new blueprint recipes.
*   **Persistent Unlocks:** Beating a biome unlocks new Mod Chips, new Allies (like Bonegear the robo-dog), and new base components for future runs.

## Exploration Mechanics

To control the game's pace and force players to scale systematically, the map consists of **Explored** and **Unexplored** tiles.

*   **Explored Tiles:** The player starts with an initial grid (first 15 depths of all lanes) where buildings can be placed and vision is clear.
*   **Unexplored Tiles:** Rendered pitch black with an obscuring shadow.
    *   **Restrictions:** Cannot be interacted with, built upon, or seen into. Turrets cannot detect enemies inside unexplored tiles.
    *   **Clearing the Dark:**
        1.  *Temporary:* Players can carry a "Lux Lantern" to reveal a 3x3 area, or build a "Lighthouse" structure to beam light into the darkness.
        2.  *Permanent:* Defeating a wave or Boss naturally pushes back the darkness, permanently expanding the buildable grid for the current level.

## Example Scenario: The Scrapyard

**Setup:** Spawn with 1 Ally, 10 minutes to plan.

1. **Gathering Phase:**
   * Pick up `rocks` -> `stone`.
   * Pick up `scrap_pile` -> `gears`, `nails`, `iron_rod`.
   * **Synergy Found:** Craft `bent_pipe` (weapon) from `stone` + `iron_rod`.

2. **Field Combat:**
   * Kill roaming scrap robots (tiny roombas, uniclanks).
   * *Loot Dropped:* `drill_bits`, `lux`, `gears`, `engine`, `rubber`.

3. **Automation Phase:**
   * Build first Drill: `12x stone, 1x drill bit, 3x gears, 1x lux` -> `Stone Drill`.
   * Set up `Stone Burnace` to smelt `iron` and `copper`.

4. **Scaling Up (The Roguelike Break):**
   * Combine alloys with `lux` to craft `Lux Circuits`.
   * Obtain a **"Chain Lightning" Mod Chip** from a Wave Boss. 
   * Insert the chip into an `Asourcer` (Assembler) powered by `Volt`. Instead of crafting items, the Assembler now functions as a Tesla Coil that chains damage to 4 enemies at once based on its crafting speed. The player scales crafting speed instead of raw damage to win the run!
