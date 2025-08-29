# Character Generation Script (`generate_character.py`)

This document provides instructions on how to use the `generate_character.py` script to automatically generate new character scenes and scripts for the Godot project.

## 1. Purpose

The script automates the tedious process of:
-   Creating a new character scene (`.tscn`) based on a template.
-   Creating a new character script (`.gd`) by copying the base `Player.gd`.
-   Reading a character's asset folder and a corresponding CSV file.
-   Generating a `SpriteFrames` resource with all standard and attack animations.
-   Creating and configuring `Attack` nodes for every attack animation defined in the CSV.

This allows you to add new characters to the game in minutes instead of hours.

## 2. Prerequisites

Before running the script, you must have Python and the `pandas` library installed.

If you don't have `pandas`, open your terminal or command prompt and run:
```bash
pip install pandas
```

## 3. Step-by-Step Instructions

Follow these steps precisely to ensure the script works correctly.

### Step 1: Create the Character Asset Folder

1.  Navigate to the `assets/characters/` directory in the project.
2.  Create a new folder for your character. The name should be `PascalCase` (e.g., **Knight**, **Mage**, **Rogue**).
3.  Inside your character's folder (e.g., `assets/characters/Knight/`), create subfolders for each of your animation spritesheets (e.g., `Idle`, `Run`, `GroundAttack1`, etc.).
4.  Place the corresponding `.png` spritesheet file inside each subfolder.

**Example Folder Structure:**
```
assets/
└── characters/
    └── Knight/
        ├── AirAttack1/
        │   └── player_sword_stab_96x48.png
        ├── Fall/
        │   └── player_land_48x48.png
        ├── GroundAttack1/
        │   └── Player_Jab_48x48.png
        ├── GroundAttack2/
        │   └── Player_Punch_Cross_64x64.png
        ├── Idle/
        │   └── Player_Idle_48x48.png
        ├── Jump/
        │   └── player_jump_48x48.png
        ├── Land/
        │   └── player_land_48x48.png
        ├── Run/
        │   └── player_run_48x48.png
        ├── Walk/
        │   └── PlayerWalk_48x48.png
        └── knight_sprite_info.csv  <-- See Step 2
```

### Step 2: Create the Sprite Info CSV File

1.  Inside your character's main folder (e.g., `assets/characters/Knight/`), create a new CSV file.
2.  The file **must be named** in all lowercase: `charactername_sprite_info.csv` (e.g., `knight_sprite_info.csv`).
3.  Open the CSV file and add the required columns. The script will fail if any of these columns are missing.

**Required Columns:**

| Column Name        | Description                                                                                             | Example                             | Notes                                                                  |
| ------------------ | ------------------------------------------------------------------------------------------------------- | ----------------------------------- | ---------------------------------------------------------------------- |
| `SpritePath`       | The relative path to the `.png` from inside the character's folder.                                     | `Idle/Player_Idle_48x48.png`        | **Required for all rows.**                                             |
| `AnimationName`    | The name the animation will have in Godot.                                                              | `Idle`, `Sprint`, `Attack1_1`       | **Required for all rows.** Use standard names like `Idle`, `Sprint`, `Walk`, `Jump_Start`, `Fall`, `Land` for movement animations. |
| `AnimationType`    | The type of animation. Must be either `Movement` or `Attack`.                                           | `Movement` or `Attack`              | **Required for all rows.**                                             |
| `FrameWidth`       | The width in pixels of a single frame in the spritesheet.                                               | `48`                                | **Required for all rows.**                                             |
| `FrameHeight`      | The height in pixels of a single frame in the spritesheet.                                              | `48`                                | **Required for all rows.**                                             |
| `HFrames`          | The number of horizontal frames in the spritesheet.                                                     | `10`                                | **Required for all rows.**                                             |
| `AttackState`      | The player state required for an attack. Can be `Grounded`, `Aerial`, `Running`, `Crouching`.           | `Grounded`                          | **Required for `Attack` types only.** Leave blank for `Movement`.      |
| `AttackInput`      | The input that triggers the attack. Usually `attack1` or `attack2`.                                     | `attack1`                           | **Required for `Attack` types only.** Leave blank for `Movement`.      |
| `AttackComboIndex` | The position of the attack in a combo chain (starts at `1`).                                            | `1`                                 | **Required for `Attack` types only.** Leave blank for `Movement`.      |

**Example `knight_sprite_info.csv`:**
```csv
SpritePath,AnimationName,AnimationType,FrameWidth,FrameHeight,HFrames,AttackState,AttackInput,AttackComboIndex
Idle/Player Idle 48x48.png,Idle,Movement,48,48,10,,,,
Run/player run 48x48.png,Sprint,Movement,48,48,8,,,,
Walk/PlayerWalk 48x48.png,Walk,Movement,48,48,8,,,,
Jump/player jump 48x48.png,Jump_Start,Movement,48,48,3,,,,
Fall/player land 48x48.png,Fall,Movement,48,48,3,,,,
Land/player land 48x48.png,Land,Movement,48,48,4,,,,
GroundAttack1/Player Jab 48x48.png,Attack1_1,Attack,48,48,6,Grounded,attack1,1
GroundAttack2/Player Punch Cross 64x64.png,Attack1_2,Attack,64,64,7,Grounded,attack1,2
AirAttack1/player sword stab 96x48.png,Air_Attack1,Attack,96,48,7,Aerial,attack1,1
```

### Step 3: Configure the Script

1.  Open the `generate_character.py` script in the project's root directory.
2.  Find the `CHARACTER_NAME` variable at the top of the script.
3.  Change its value to match the name of the character folder you created in Step 1.

```python
# --- CONFIGURATION ---
CHARACTER_NAME = "Knight" # <-- CHANGE THIS VALUE
# --- END CONFIGURATION ---
```

### Step 4: Run the Script

1.  Open a terminal or command prompt in the **root directory of your Godot project**.
2.  Run the script using Python.

```bash
python generate_character.py
```

### Step 5: Review the Output

If the script runs successfully, you will see output in the terminal and two new files will be created:
-   A new scene file at `scenes/characters/CharacterName.tscn` (e.g., `scenes/characters/Knight.tscn`).
-   A new script file at `scripts/characters/CharacterName.gd` (e.g., `scripts/characters/Knight.gd`).

### Step 6: Use and Refine in Godot

1.  Open your Godot project. The new files will be imported automatically.
2.  You can now drag the new character scene (e.g., `Knight.tscn`) into your `Main.tscn` or any other level.
3.  **IMPORTANT:** The script generates basic placeholder hitboxes for all attacks. You **must** open the character scene, expand the `Attacks` node, and select each attack to manually adjust its properties (hitbox shape/size, cancel frames, applied velocity, etc.) in the Inspector.

## 4. Troubleshooting

-   **`FileNotFoundError` or `No such file or directory`**:
    -   Make sure you are running the script from the project's root directory.
    -   Double-check that your `CHARACTER_NAME` in the script matches the folder name exactly (it's case-sensitive).
    -   Ensure your CSV file is named correctly (`charactername_sprite_info.csv`).
-   **`KeyError: 'ColumnName'`**: You are missing a required column in your CSV file. Make sure all columns from the table in Step 2 are present.
-   **Script Overwrites Files**: The script will overwrite existing character files with the same name without warning. Be careful when re-running it for a character that you have already modified in the editor.