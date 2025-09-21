import os
import re
import pandas as pd
import math

# --- CONFIGURATION ---
CHARACTER_NAME = "Knight" # The name of the character to generate.
BASE_PLAYER_SCENE_PATH = "scenes/Player.tscn" # The base player scene this character will instance.
ASSETS_BASE_PATH = "assets/characters"
OUTPUT_SCENES_PATH = "scenes/characters"
OUTPUT_SCRIPTS_PATH = "scripts/characters"
# --- END CONFIGURATION ---

# Template for a HitboxData resource
HITBOX_DATA_TEMPLATE = """[sub_resource type="Resource" id="Resource_{res_id}"]
script = ExtResource("{hitbox_script_id}")
damage = {damage}
stun_duration = {stun_duration}
hitlag_duration = {hitlag_duration}
knockback_amount = {knockback_amount}
knockback_direction = Vector2({knockback_x}, {knockback_y})
shape = SubResource("RectangleShape2D_{shape_id}")
position = Vector2(0, 0)
start_frame = 2
end_frame = 4
"""

# Template for a RectangleShape2D for the hitbox
RECTANGLE_SHAPE_TEMPLATE = """[sub_resource type="RectangleShape2D" id="RectangleShape2D_{shape_id}"]
size = Vector2({width}, {height})
"""

# Template for the main Scene file (.tscn)
SCENE_TEMPLATE = """[gd_scene load_steps={load_steps} format=3 uid="uid://{scene_uid}"]

{ext_resources}
{sub_resources}
[node name="{char_name}" instance=ExtResource("{base_player_scene_id}")]
script = ExtResource("{script_id}")

[node name="AnimatedSprite2D" parent="." index="0"]
sprite_frames = SubResource("SpriteFrames_main")

[node name="AnimationComponent" type="Node" parent="."]
script = ExtResource("{anim_comp_script_id}")
{anim_comp_assignments}

{attack_nodes}
"""

def generate_godot_uid():
    """Generates a plausible-looking Godot UID."""
    import random
    import string
    return ''.join(random.choices(string.ascii_lowercase + string.digits, k=13))

def sanitize_node_name(name):
    """Sanitizes animation name to be a valid Godot node name."""
    return re.sub(r'[^A-Za-z0-9_]', '_', name)

def create_character_files(char_name):
    print(f"--- Starting character generation for: {char_name} ---")

    # 1. Define Paths
    char_assets_path = os.path.join(ASSETS_BASE_PATH, char_name)
    csv_path = os.path.join(char_assets_path, f"{char_name.lower()}_sprite_info.csv")
    
    os.makedirs(OUTPUT_SCENES_PATH, exist_ok=True)
    os.makedirs(OUTPUT_SCRIPTS_PATH, exist_ok=True)
    
    output_scene_path = os.path.join(OUTPUT_SCENES_PATH, f"{char_name}.tscn")
    output_script_path = os.path.join(OUTPUT_SCRIPTS_PATH, f"{char_name}.gd")

    if not os.path.exists(csv_path):
        print(f"ERROR: CSV file not found at {csv_path}")
        return

    # 2. Create the character script (which simply extends Player.gd)
    char_script_content = f"""extends Player

# This script is for {char_name}-specific logic.
# All core logic is inherited from Player.gd.

func _ready():
	super()
	# You can add character-specific setup here.
	# For example:
	# max_health = 120
	# walk_speed = 280
"""
    with open(output_script_path, 'w', encoding='utf-8') as f_out:
        f_out.write(char_script_content)
    print(f"Successfully created script: {output_script_path}")

    # 3. Read and process CSV data
    df = pd.read_csv(csv_path).fillna('')
    animations = []
    attacks = []
    non_attack_animations = {}

    for _, row in df.iterrows():
        # Skip rows that don't have a sprite path defined
        if not row["SpritePath"] or pd.isna(row["SpritePath"]):
            continue

        anim_data = {
            "path": os.path.join(char_assets_path, row["SpritePath"]).replace("\\", "/"),
            "name": row["AnimationName"],
            "type": row["AnimationType"],
            "width": int(row["FrameWidth"]),
            "height": int(row["FrameHeight"]),
            "h_frames": int(row["HFrames"])
        }
        animations.append(anim_data)

        if anim_data["type"] == "Attack":
            attacks.append({
                "node_name": sanitize_node_name(anim_data["name"]),
                "anim_name": anim_data["name"],
                "attack_chain": row.get("AttackChain", "default"),
                "required_state": row["AttackState"],
                "required_input": row["AttackInput"],
                "combo_index": int(row["AttackComboIndex"]) if row["AttackComboIndex"] != '' else 1,
                "attack_type": row.get("AttackType", "Combo"),
                "skill_input_action": row.get("SkillInputAction", ""),
                "multi_hit": str(row.get("MultiHit", "false")).lower() == "true",
                "damage": float(row["Damage"]) if row["Damage"] != '' else 10.0,
                "stun_duration": float(row["StunDuration"]) if row["StunDuration"] != '' else 0.2,
                "hitlag_duration": float(row["HitlagDuration"]) if row["HitlagDuration"] != '' else 0.1,
                "knockback_amount": float(row["KnockbackAmount"]) if row["KnockbackAmount"] != '' else 300.0,
                "knockback_x": float(row["KnockbackDirectionX"]) if row["KnockbackDirectionX"] != '' else 1.0,
                "knockback_y": float(row["KnockbackDirectionY"]) if row["KnockbackDirectionY"] != '' else -0.5,
                "mana_cost": float(row["ManaCost"]) if row["ManaCost"] != '' else 0.0,
                "hp_cost": float(row["HPCost"]) if row["HPCost"] != '' else 0.0,
            })
        else:
            non_attack_animations[anim_data["type"]] = anim_data["name"]


    print(f"Found {len(animations)} animations and {len(attacks)} attacks.")

    # 4. Generate the Scene (.tscn) file content
    ext_resources = []
    sub_resources = []
    
    # --- Ext Resources ---
    # Find the UID of the base Player.tscn
    player_scene_uid = ""
    with open(f"{BASE_PLAYER_SCENE_PATH}.uid", "r") as f:
        player_scene_uid = f.read().strip()

    base_player_scene_id = "1_base_player"
    script_id = "2_script"
    attack_script_id = "3_attack_script"
    hitbox_script_id = "4_hitbox_script"
    anim_comp_script_id = "5_anim_comp_script"
    
    ext_resources.append(f'[ext_resource type="PackedScene" uid="{player_scene_uid}" path="res://{BASE_PLAYER_SCENE_PATH}" id="{base_player_scene_id}"]')
    ext_resources.append(f'[ext_resource type="Script" path="res://{output_script_path}" id="{script_id}"]')
    ext_resources.append(f'[ext_resource type="Script" path="res://scripts/Attack.gd" id="{attack_script_id}"]')
    ext_resources.append(f'[ext_resource type="Script" path="res://scripts/HitboxData.gd" id="{hitbox_script_id}"]')
    ext_resources.append(f'[ext_resource type="Script" path="res://scripts/components/AnimationComponent.gd" id="{anim_comp_script_id}"]')


    texture_ids = {}
    tex_counter = 6
    for anim in animations:
        if anim['path'] not in texture_ids:
            tex_id = f"tex_{tex_counter}"
            texture_ids[anim['path']] = tex_id
            ext_resources.append(f'[ext_resource type="Texture2D" uid="uid://{generate_godot_uid()}" path="res://{anim["path"]}" id="{tex_id}"]')
            tex_counter += 1

    # --- Sub Resources ---
    sprite_frames_animation_list = []
    for anim in animations:
        atlas_textures = []
        for i in range(anim["h_frames"]):
            atlas_id = f"AtlasTexture_{generate_godot_uid()[:5]}"
            atlas_textures.append(atlas_id)
            sub_resources.append(f'[sub_resource type="AtlasTexture" id="{atlas_id}"]')
            sub_resources.append(f'atlas = ExtResource("{texture_ids[anim["path"]]}")')
            sub_resources.append(f'region = Rect2({i * anim["width"]}, 0, {anim["width"]}, {anim["height"]})')
            sub_resources.append('')

        frames_str = ", ".join([f'{{"duration": 1.0, "texture": SubResource("{atlas_id}")}}' for atlas_id in atlas_textures])
        loop = "true" if anim["name"] in ["Idle", "Walk", "Sprint", "Crouch_Idle", "Crouch_Walk"] else "false"
        sprite_frames_animation_list.append(f'{{"frames": [{frames_str}], "loop": {loop}, "name": &"{anim["name"]}", "speed": 12.0}}') 
    
    sprite_frames_str = ",\n".join(sprite_frames_animation_list)
    sub_resources.append('[sub_resource type="SpriteFrames" id="SpriteFrames_main"]')
    sub_resources.append(f"animations = [{sprite_frames_str}]")
    sub_resources.append("")

    attack_nodes_str_list = []
    res_counter = 1
    for i, attack in enumerate(attacks):
        shape_id = f"shape_{res_counter}"
        res_id = f"res_{res_counter}"
        
        sub_resources.append(RECTANGLE_SHAPE_TEMPLATE.format(shape_id=shape_id, width=32, height=24)) 
        sub_resources.append(HITBOX_DATA_TEMPLATE.format(
            res_id=res_id, 
            hitbox_script_id=hitbox_script_id, 
            shape_id=shape_id, 
            damage=attack["damage"],
            stun_duration=attack["stun_duration"],
            hitlag_duration=attack["hitlag_duration"],
            knockback_amount=attack["knockback_amount"],
            knockback_x=attack["knockback_x"],
            knockback_y=attack["knockback_y"]
        ))
        
        node_str = f'[node name="{attack["node_name"]}" type="Node" parent="AttackHandlerComponent"]\n'
        node_str += f'script = ExtResource("{attack_script_id}")\n'
        node_str += f'attack_type = "{attack["attack_type"]}"\n'
        node_str += f'multi_hit = {"true" if attack["multi_hit"] else "false"}\n'
        if attack["skill_input_action"]:
            node_str += f'skill_input_action = "{attack["skill_input_action"]}"\n'
        node_str += f'attack_chain = &"{attack["attack_chain"]}"\n'
        node_str += f'combo_index = {attack["combo_index"]}\n'
        node_str += f'required_state = "{attack["required_state"]}"\n'
        node_str += f'required_input = "{attack["required_input"]}"\n'
        node_str += f'mana_cost = {attack["mana_cost"]}\n'
        node_str += f'hp_cost = {attack["hp_cost"]}\n'
        node_str += f'animation_name = &"{attack["anim_name"]}"\n'
        node_str += f'hitboxes = [SubResource("Resource_{res_id}")]'
        
        attack_nodes_str_list.append(node_str)
        res_counter += 1

    # --- Animation Component Setup ---
    prop_map = {
        "Idle": "idle", "Walk": "walk", "Run": "run", "CrouchIdle": "crouch_idle",
        "CrouchWalk": "crouch_walk", "JumpStart": "jump_start", 
        "SprintJumpStart": "sprint_jump_start", "Fall": "fall", "Land": "land",
        "RunningSlide": "running_slide", "LedgeGrab": "ledge_grab", "Hurt": "hurt",
        "Death": "death"
    }
    anim_comp_assignments_list = []
    for anim_type, anim_name in non_attack_animations.items():
        if anim_type in prop_map:
            prop_name = prop_map[anim_type]
            anim_comp_assignments_list.append(f'{prop_name} = &"{anim_name}"')
    anim_comp_assignments_str = "\n".join(anim_comp_assignments_list)

    # 5. Assemble the final .tscn file
    load_steps = len(ext_resources) + len(sub_resources) # A bit of an overestimation but safer

    final_tscn = SCENE_TEMPLATE.format(
        load_steps=load_steps, 
        scene_uid=generate_godot_uid(),
        char_name=char_name,
        script_id=script_id,
        base_player_scene_id=base_player_scene_id,
        ext_resources="\n".join(ext_resources),
        sub_resources="\n".join(sub_resources),
        anim_comp_script_id=anim_comp_script_id,
        anim_comp_assignments=anim_comp_assignments_str,
        attack_nodes="\n\n".join(attack_nodes_str_list)
    )
    
    with open(output_scene_path, 'w', encoding='utf-8') as f:
        f.write(final_tscn)
    print(f"Successfully generated scene: {output_scene_path}")
    print(f"--- Character '{char_name}' generation complete! ---")


if __name__ == "__main__":
    if not CHARACTER_NAME:
        print("ERROR: Please set the CHARACTER_NAME variable at the top of the script.")
    else:
        create_character_files(CHARACTER_NAME)