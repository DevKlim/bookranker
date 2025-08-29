import os
import re
import pandas as pd
import math

# --- CONFIGURATION ---
CHARACTER_NAME = "Knight" # The name of the character to generate.
BASE_PLAYER_SCRIPT_PATH = "scripts/Player.gd"
ASSETS_BASE_PATH = "assets/characters"
OUTPUT_SCENES_PATH = "scenes/characters"
OUTPUT_SCRIPTS_PATH = "scripts/characters"
# --- END CONFIGURATION ---

# Template for a HitboxData resource
HITBOX_DATA_TEMPLATE = """[sub_resource type="Resource" id="Resource_{res_id}"]
script = ExtResource("{hitbox_script_id}")
shape = SubResource("RectangleShape2D_{shape_id}")
position = Vector2(0, 0)
start_frame = 1
end_frame = 999
"""

# Template for a RectangleShape2D for the hitbox
RECTANGLE_SHAPE_TEMPLATE = """[sub_resource type="RectangleShape2D" id="RectangleShape2D_{shape_id}"]
size = Vector2({width}, {height})
"""

# Template for the main Scene file (.tscn)
SCENE_TEMPLATE = """[gd_scene load_steps={load_steps} format=3 uid="uid://{scene_uid}"]

{ext_resources}
{sub_resources}
[node name="{char_name}" type="CharacterBody2D"]
collision_layer = 2
script = ExtResource("{script_id}")
walk_speed = 400.0
jump_velocity = -1200.0
friction = 2000.0
max_jumps = 1
debug_draw_hitboxes = true

[node name="AnimatedSprite2D" type="AnimatedSprite2D" parent="."]
sprite_frames = SubResource("SpriteFrames_main")

[node name="CollisionShape2D" type="CollisionShape2D" parent="."]
position = Vector2(0, 1)
shape = SubResource("CapsuleShape2D_main")

[node name="Hitbox" type="Area2D" parent="." groups=["hitbox"]]
collision_layer = 8
collision_mask = 4

[node name="Hurtbox" type="Area2D" parent="." groups=["hurtbox"]]
collision_layer = 4
collision_mask = 8

[node name="CollisionShape2D" type="CollisionShape2D" parent="Hurtbox"]
position = Vector2(-1, 1)
shape = SubResource("RectangleShape2D_hurtbox")

[node name="ComboTimer" type="Timer" parent="."]
wait_time = 0.8
one_shot = true

[node name="AttackLagTimer" type="Timer" parent="."]
one_shot = true

[node name="LandingLagTimer" type="Timer" parent="."]
wait_time = 0.15
one_shot = true

[node name="JumpBufferTimer" type="Timer" parent="."]
wait_time = 0.15
one_shot = true

[node name="FixedMoveTimer" type="Timer" parent="."]
one_shot = true

[node name="Attacks" type="Node" parent="."]
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

    # 2. Create the character script (copy of Player.gd)
    try:
        with open(BASE_PLAYER_SCRIPT_PATH, 'r') as f_in:
            base_script_content = f_in.read()
        with open(output_script_path, 'w') as f_out:
            f_out.write(base_script_content)
        print(f"Successfully created script: {output_script_path}")
    except FileNotFoundError:
        print(f"ERROR: Base player script not found at {BASE_PLAYER_SCRIPT_PATH}")
        return

    # 3. Read and process CSV data
    df = pd.read_csv(csv_path)
    animations = []
    attacks = []

    for _, row in df.iterrows():
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
            attack_data = {
                "node_name": sanitize_node_name(anim_data["name"]),
                "anim_name": anim_data["name"],
                "attack_chain": row.get("AttackChain", "default"),
                "required_state": row["AttackState"],
                "required_input": row["AttackInput"],
                "combo_index": int(row["AttackComboIndex"]),
                "can_directional_cancel": str(row.get("CanDirectionalCancel", "false")).lower() == "true",
                "directional_cancel_start_frame": int(row.get("DirectionalCancelStartFrame", 0))
            }
            attacks.append(attack_data)

    print(f"Found {len(animations)} animations and {len(attacks)} attacks.")

    # 4. Generate the Scene (.tscn) file content
    ext_resources = []
    sub_resources = []
    
    # --- Ext Resources ---
    script_id = "1_script"
    attack_script_id = "2_attack_script"
    hitbox_script_id = "3_hitbox_script"
    
    ext_resources.append(f'[ext_resource type="Script" path="res://{output_script_path}" id="{script_id}"]')
    ext_resources.append(f'[ext_resource type="Script" path="res://scripts/Attack.gd" id="{attack_script_id}"]')
    ext_resources.append(f'[ext_resource type="Script" path="res://scripts/HitboxData.gd" id="{hitbox_script_id}"]')

    texture_ids = {}
    tex_counter = 4
    for anim in animations:
        if anim['path'] not in texture_ids:
            tex_id = f"{tex_counter}_tex"
            texture_ids[anim['path']] = tex_id
            ext_resources.append(f'[ext_resource type="Texture2D" uid="uid://{generate_godot_uid()}" path="res://{anim["path"]}" id="{tex_id}"]')
            tex_counter += 1

    # --- Sub Resources ---
    # Basic physics shapes
    sub_resources.append('[sub_resource type="CapsuleShape2D" id="CapsuleShape2D_main"]\nradius = 9.0')
    sub_resources.append('[sub_resource type="RectangleShape2D" id="RectangleShape2D_hurtbox"]\nsize = Vector2(18, 30)')

    # SpriteFrames and AtlasTextures
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
        loop = "true" if anim["name"] in ["Idle", "Walk", "Sprint"] else "false"
        sprite_frames_animation_list.append(f'{{"frames": [{frames_str}], "loop": {loop}, "name": &"{anim["name"]}", "speed": 10.0}}')
    
    sprite_frames_str = ",\n".join(sprite_frames_animation_list)
    sub_resources.append('[sub_resource type="SpriteFrames" id="SpriteFrames_main"]')
    sub_resources.append(f"animations = [{sprite_frames_str}]")
    sub_resources.append("")

    # Attack nodes and their hitbox resources
    attack_nodes_str_list = []
    res_counter = 1
    for attack in attacks:
        shape_id = f"shape_{res_counter}"
        res_id = f"res_{res_counter}"
        
        # Add hitbox sub-resources
        sub_resources.append(RECTANGLE_SHAPE_TEMPLATE.format(shape_id=shape_id, width=32, height=16))
        sub_resources.append(HITBOX_DATA_TEMPLATE.format(res_id=res_id, hitbox_script_id=hitbox_script_id, shape_id=shape_id))
        
        # Add the node string
        attack_nodes_str_list.append(f'[node name="{attack["node_name"]}" type="Node" parent="Attacks"]')
        attack_nodes_str_list.append(f'script = ExtResource("{attack_script_id}")')
        attack_nodes_str_list.append(f'attack_chain = &"{attack["attack_chain"]}"')
        attack_nodes_str_list.append(f'combo_index = {attack["combo_index"]}')
        attack_nodes_str_list.append(f'required_state = "{attack["required_state"]}"')
        attack_nodes_str_list.append(f'required_input = "{attack["required_input"]}"')
        attack_nodes_str_list.append(f'animation_name = &"{attack["anim_name"]}"')
        if attack["can_directional_cancel"]:
            attack_nodes_str_list.append('can_directional_cancel = true')
            attack_nodes_str_list.append(f'directional_cancel_start_frame = {attack["directional_cancel_start_frame"]}')
        attack_nodes_str_list.append(f'hitboxes = [SubResource("Resource_{res_id}")]')
        attack_nodes_str_list.append('')
        res_counter += 1

    # 5. Assemble the final .tscn file
    final_tscn = SCENE_TEMPLATE.format(
        load_steps=len(ext_resources) + len(sub_resources), # This is an approximation but works
        scene_uid=generate_godot_uid(),
        char_name=char_name,
        script_id=script_id,
        ext_resources="\n".join(ext_resources),
        sub_resources="\n".join(sub_resources),
        attack_nodes="\n".join(attack_nodes_str_list)
    )
    
    with open(output_scene_path, 'w') as f:
        f.write(final_tscn)
    print(f"Successfully generated scene: {output_scene_path}")
    print(f"--- Character '{char_name}' generation complete! ---")


if __name__ == "__main__":
    if not CHARACTER_NAME:
        print("ERROR: Please set the CHARACTER_NAME variable at the top of the script.")
    else:
        create_character_files(CHARACTER_NAME)