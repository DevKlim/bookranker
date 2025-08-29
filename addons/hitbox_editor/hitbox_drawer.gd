@tool
extends Node2D

var current_attack: Attack = null
var animated_sprite: AnimatedSprite2D = null

func _draw():
	if not is_instance_valid(current_attack) or not is_instance_valid(animated_sprite):
		return

	var frame = animated_sprite.frame
	
	for hitbox_data in current_attack.hitboxes:
		if not is_instance_valid(hitbox_data) or not is_instance_valid(hitbox_data.shape):
			continue

		# Check if the hitbox is active on the current frame
		if frame >= hitbox_data.start_frame and frame < hitbox_data.end_frame:
			var shape: Shape2D = hitbox_data.shape
			var position: Vector2 = hitbox_data.position
			var color = Color.RED if hitbox_data.start_frame == frame else Color(1.0, 0.6, 0.0) # Red for first frame, orange otherwise
			
			if shape is RectangleShape2D:
				var rect = Rect2(position - shape.size / 2.0, shape.size)
				draw_rect(rect, color.lightened(0.5)) # Semi-transparent fill
				draw_rect(rect, color, false, 2.0) # Solid outline
			elif shape is CircleShape2D:
				draw_circle(position, shape.radius, color.lightened(0.5))
				draw_circle(position, shape.radius, color, false, 2.0)
			elif shape is CapsuleShape2D:
				draw_rect(Rect2(position - Vector2(shape.radius, shape.height / 2.0), Vector2(shape.radius * 2, shape.height)), color.lightened(0.5))
				draw_circle(position + Vector2(0, -shape.height / 2.0), shape.radius, color.lightened(0.5))
				draw_circle(position + Vector2(0, shape.height / 2.0), shape.radius, color.lightened(0.5))