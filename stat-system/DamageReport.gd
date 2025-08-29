# DamageReport.gd
class_name DamageReport
extends RefCounted

# --- Properties ---
var attacker: Node
var attacker_position: Vector2
var damage_amount: float

# --- Constructor ---
# This function lets us create a new report with all the data at once.
# Example: var report = DamageReport.new(player_node, player_pos, 10.0)
func _init(p_attacker: Node, p_attacker_position: Vector2, p_damage_amount: float):
	self.attacker = p_attacker
	self.attacker_position = p_attacker_position
	self.damage_amount = p_damage_amount