class_name PauseMenu
extends Control

signal resume_requested
signal quit_requested

@onready var resume_btn: Button = $PanelContainer/MarginContainer/VBoxContainer/ResumeButton
@onready var quit_btn: Button = $PanelContainer/MarginContainer/VBoxContainer/QuitButton

func _ready() -> void:
	resume_btn.pressed.connect(_on_resume_pressed)
	quit_btn.pressed.connect(_on_quit_pressed)

func _on_resume_pressed() -> void:
	emit_signal("resume_requested")

func _on_quit_pressed() -> void:
	emit_signal("quit_requested")

func focus_resume() -> void:
	if resume_btn: resume_btn.grab_focus()
	