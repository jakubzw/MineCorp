extends Resource
class_name BuildingData

# ──────────────────────────────────────────
#  BuildingData — dane budynku jako Resource
#  Tworzy się przez: nowy plik .tres w edytorze
# ──────────────────────────────────────────

## Wyświetlana nazwa budynku
@export var display_name: String = "Budynek"

## Ikona wyświetlana w menu (Texture2D)
@export var icon: Texture2D

## Scena 3D budynku do umieszczenia na mapie
@export var scene: PackedScene

## Rozmiar na siatce (w kafelkach)
@export var grid_size: Vector2i = Vector2i(1, 1)

## Kategoria budynku (do filtrowania w menu)
@export_enum("Wydobycie", "Produkcja", "Logistyka", "Infrastruktura") var category: int = 0

## Koszt budowy
@export var cost_gold: int = 100

## Krótki opis (tooltip)
@export_multiline var description: String = ""
