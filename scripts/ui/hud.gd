extends CanvasLayer
# ──────────────────────────────────────────
#  HUD — główny interfejs gry
#  Struktura sceny:
#
#  HUD (CanvasLayer) ← ten skrypt
#  └── MarginContainer
#      ├── TopBar (HBoxContainer)        ← zasoby, czas itp.
#      └── BottomBar (HBoxContainer)
#          └── BuildMenu (Panel) ← build_menu.gd
# ──────────────────────────────────────────

@onready var _build_menu = $MarginContainer/VBoxContainer/BottomBar/BuildMenu


func _ready() -> void:
	# Podłącz sygnały BuildManagera do HUD
	BuildManager.building_selected.connect(_on_building_selected)
	BuildManager.building_cancelled.connect(_on_building_cancelled)


func _on_building_selected(data: BuildingData) -> void:
	# Możesz tu pokazać np. tooltip lub panel kosztu
	pass


func _on_building_cancelled() -> void:
	pass
