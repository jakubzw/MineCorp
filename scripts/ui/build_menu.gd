extends PanelContainer
# ──────────────────────────────────────────
#  BuildMenu — pasek budynków na dole ekranu
#
#  Struktura sceny BuildMenu:
#
#  BuildMenu (PanelContainer) ← ten skrypt
#  └── VBoxContainer
#      ├── CategoryTabs (HBoxContainer)   ← zakładki kategorii
#      └── ScrollContainer
#          └── BuildingList (HBoxContainer) ← kafelki budynków
# ──────────────────────────────────────────

## Lista wszystkich dostępnych budynków (przypisz w Inspektorze)
@export var building_list: Array[BuildingData] = []

@onready var _building_list_container: HBoxContainer = $VBoxContainer/ScrollContainer/BuildingList
@onready var _category_tabs: HBoxContainer = $VBoxContainer/CategoryTabs

# Nazwy kategorii muszą zgadzać się z export_enum w BuildingData
const CATEGORIES: Array[String] = ["Wszystkie", "Wydobycie", "Produkcja", "Logistyka", "Infrastruktura"]

var _active_category: int = 0        # 0 = wszystkie
var _selected_button: Button = null  # aktualnie podświetlony kafelek


func _ready() -> void:
	_build_category_tabs()
	_build_building_tiles()
	BuildManager.building_cancelled.connect(_on_building_cancelled)


# ──────────────────────────────────────────
#  Budowanie UI
# ──────────────────────────────────────────
func _build_category_tabs() -> void:
	for child in _category_tabs.get_children():
		child.queue_free()

	for i: int in CATEGORIES.size():
		var btn := Button.new()
		btn.text = CATEGORIES[i]
		btn.toggle_mode = true
		btn.button_pressed = (i == 0)
		btn.pressed.connect(_on_category_pressed.bind(i, btn))
		btn.add_theme_font_size_override("font_size", 12)
		_category_tabs.add_child(btn)


func _build_building_tiles() -> void:
	# Wyczyść stare kafelki
	for child in _building_list_container.get_children():
		child.queue_free()
	_selected_button = null

	# Filtruj według aktywnej kategorii
	var filtered: Array[BuildingData] = []
	for data: BuildingData in building_list:
		if _active_category == 0 or data.category == _active_category - 1:
			filtered.append(data)

	# Utwórz kafelek dla każdego budynku
	for data: BuildingData in filtered:
		var tile := _create_building_tile(data)
		_building_list_container.add_child(tile)


func _create_building_tile(data: BuildingData) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(80, 80)
	btn.toggle_mode = true
	btn.tooltip_text = "%s\nKoszt: %d złota\n%s" % [data.display_name, data.cost_gold, data.description]

	# Układ kafelka: VBox z ikoną i nazwą
	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(vbox)

	# Ikona
	if data.icon != null:
		var icon_rect := TextureRect.new()
		icon_rect.texture = data.icon
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.custom_minimum_size = Vector2(48, 48)
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(icon_rect)
	else:
		# Placeholder gdy brak ikony
		var placeholder := ColorRect.new()
		placeholder.custom_minimum_size = Vector2(48, 48)
		placeholder.color = Color(0.3, 0.3, 0.3)
		placeholder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(placeholder)

	# Nazwa
	var label := Label.new()
	label.text = data.display_name
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 10)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(label)

	# Podłącz akcję
	btn.pressed.connect(_on_tile_pressed.bind(data, btn))

	return btn


# ──────────────────────────────────────────
#  Callbacki
# ──────────────────────────────────────────
func _on_category_pressed(index: int, btn: Button) -> void:
	# Odznacz pozostałe zakładki
	for child in _category_tabs.get_children():
		if child is Button and child != btn:
			child.button_pressed = false

	_active_category = index
	_build_building_tiles()
	BuildManager.cancel_building()


func _on_tile_pressed(data: BuildingData, btn: Button) -> void:
	if btn.button_pressed:
		# Odznacz poprzedni kafelek
		if _selected_button != null and _selected_button != btn:
			_selected_button.button_pressed = false
		_selected_button = btn
		BuildManager.select_building(data)
	else:
		# Kliknięto ponownie — anuluj
		_selected_button = null
		BuildManager.cancel_building()


func _on_building_cancelled() -> void:
	# Odznacz kafelek gdy budowanie anulowane z zewnątrz (np. klawisz Escape)
	if _selected_button != null:
		_selected_button.button_pressed = false
		_selected_button = null
