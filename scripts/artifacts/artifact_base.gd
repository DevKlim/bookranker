class_name ArtifactBase
extends RefCounted

func on_equip(agent: Node, item: ItemResource) -> void:
	pass

func on_unequip(agent: Node, item: ItemResource) -> void:
	pass

func on_use(agent: Node, target: Node, item: ItemResource) -> void:
	pass

func on_attack(agent: Node, target: Node, item: ItemResource, damage: float) -> void:
	pass

func on_mine_complete(agent: Node, target: Variant, item: ItemResource) -> void:
	pass
