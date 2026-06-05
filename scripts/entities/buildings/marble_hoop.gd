extends BaseBuilding

func _ready():
    grid_layer = "addon"
    if has_meta("is_preview"):
        _setup_hoop()
        return

    super._ready()
    call_deferred("_verify_placement")
    _setup_hoop()

func _verify_placement():
    var tile = LaneManager.world_to_tile(global_position)
    var b = LaneManager.get_entity_at(tile, "building")
    if not b or not b.is_in_group("stream"):
        queue_free()

func _setup_hoop():
    var hoop = get_node_or_null("blockbench_export")
    if not hoop:
        hoop = MeshInstance3D.new()
        var torus = TorusMesh.new()
        torus.inner_radius = 0.8
        torus.outer_radius = 1.0
        hoop.mesh = torus
        hoop.position = Vector3(0, 1.0, 0)
        hoop.rotation.x = deg_to_rad(90)
        var mat = StandardMaterial3D.new()
        mat.albedo_color = Color(0.9, 0.9, 0.9)
        mat.metallic = 0.8
        hoop.material_override = mat
        add_child(hoop)
    
    var area = Area3D.new()
    area.collision_layer = 0
    area.collision_mask = 4 # Projectiles Layer
    var col = CollisionShape3D.new()
    var box = BoxShape3D.new()
    box.size = Vector3(1.6, 1.6, 0.2)
    col.shape = box
    col.position = Vector3(0, 1.0, 0)
    area.add_child(col)
    area.area_entered.connect(_on_projectile_entered)
    add_child(area)

func _on_projectile_entered(area: Area3D):
    if area is Projectile:
        if area._element and area._element.element_name.to_lower() == "aqua":
            var buffed_by = area.get_meta("hoop_buffed_by", [])
            if not buffed_by.has(self):
                buffed_by.append(self)
                area.set_meta("hoop_buffed_by", buffed_by)
                area._damage += 3.0
                area._element_units += 2
                
                # Make projectile visibly bigger and stronger
                area.scale *= 1.2
                
                # Hoop Flash
                var hoop = get_node_or_null("blockbench_export")
                if hoop:
                    var t = create_tween()
                    var mat = null
                    if hoop is MeshInstance3D: mat = hoop.get_active_material(0)
                    else:
                        for c in hoop.get_children():
                            if c is MeshInstance3D: mat = c.get_active_material(0); break
                            
                    if mat:
                        var old = mat.albedo_color
                        mat.albedo_color = Color(0.2, 1.0, 1.0)
                        t.tween_property(mat, "albedo_color", old, 0.4)
                
                if get_tree().root.has_node("GameManager"):
                    var gm = get_tree().root.get_node("GameManager")
                    if gm.get("vfx_manager"):
                        gm.vfx_manager.play_vfx("reaction", global_position + Vector3(0, 1, 0))
