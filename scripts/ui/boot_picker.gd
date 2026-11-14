class_name BootPicker
extends Control
## Krampon seçim ekranı: her krampon bir kart, dört özelliği çubukla gösterilir.

signal picked(boot: Boot)

const CARD_SIZE := Vector2(270, 330)

var _cards: Array[Button] = []
var _boots: Array[Boot] = []


func _init(boots: Array[Boot]) -> void:
	_boots = boots


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 24)
	add_child(column)
	var heading := Label.new()
	heading.text = "Krampon seç"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 34)
	column.add_child(heading)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
	column.add_child(row)
	for boot in _boots:
		var card := _make_card(boot)
		row.add_child(card)
		_cards.append(card)


func select(boot: Boot) -> void:
	for i in _cards.size():
		_cards[i].button_pressed = _boots[i] == boot


func _make_card(boot: Boot) -> Button:
	var card := Button.new()
	card.toggle_mode = true
	card.custom_minimum_size = CARD_SIZE
	card.pressed.connect(func() -> void: picked.emit(boot))
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 16)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 6)
	card.add_child(box)
	box.add_child(_label(boot.name, 30))
	box.add_child(_label(boot.type_label() + " tipi", 20, Color(1.0, 0.85, 0.3)))
	for stat in Boot.STATS:
		box.add_child(_label(Boot.STAT_LABELS[stat], 18))
		var bar := ProgressBar.new()
		bar.min_value = 0.0
		bar.max_value = 1.0
		bar.value = boot.rating(stat)
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(0, 16)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(bar)
	return card


func _label(text: String, font_size: int, color: Color = Color.WHITE) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label
