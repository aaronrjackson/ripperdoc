extends Control

func _ready() -> void:
	anchor_right = 1.0
	anchor_bottom = 1.0
	grow_horizontal = 2
	grow_vertical = 2
	mouse_filter = MOUSE_FILTER_IGNORE

func _draw() -> void:
	get_parent()._draw_overlay(self)
