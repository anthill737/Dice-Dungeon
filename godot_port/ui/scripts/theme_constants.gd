class_name DungeonTheme
## Shared color palette, font sizes, and helper methods for the dungeon UI.
## All panels reference this to stay consistent.

# --- Font sizes ---
const FONT_TITLE := 24
const FONT_HEADING := 20
const FONT_SUBHEADING := 16
const FONT_LABEL := 14
const FONT_BODY := 13
const FONT_SMALL := 11
const FONT_LOG := 13
const FONT_BUTTON := 13

# --- Background colors ---
const BG_PRIMARY := Color(0.11, 0.07, 0.05)
const BG_SECONDARY := Color(0.14, 0.09, 0.06)
const BG_PANEL := Color(0.17, 0.11, 0.08)
const BG_HEADER := Color(0.09, 0.06, 0.04)
const BG_LOG := Color(0.08, 0.05, 0.03)
const BG_OVERLAY := Color(0.07, 0.05, 0.09, 0.97)

# --- Text colors ---
const TEXT_GOLD := Color(0.83, 0.69, 0.22)
const TEXT_BONE := Color(0.91, 0.86, 0.77)
const TEXT_RED := Color(0.78, 0.33, 0.31)
const TEXT_GREEN := Color(0.50, 0.68, 0.50)
const TEXT_CYAN := Color(0.37, 0.65, 0.65)
const TEXT_PURPLE := Color(0.55, 0.40, 0.65)
const TEXT_BLUE := Color(0.50, 0.60, 0.90)
const TEXT_SECONDARY := Color(0.66, 0.60, 0.52)
const TEXT_DIM := Color(0.45, 0.40, 0.35)

# --- Border colors ---
const BORDER := Color(0.55, 0.45, 0.33)
const BORDER_GOLD := Color(0.72, 0.58, 0.18)

# --- HP bar ---
const HP_FULL := Color(0.50, 0.68, 0.50)
const HP_MID := Color(0.83, 0.65, 0.22)
const HP_LOW := Color(0.78, 0.33, 0.31)
const HP_BG := Color(0.10, 0.06, 0.03)

# --- Buttons ---
const BTN_PRIMARY := Color(0.83, 0.69, 0.22)
const BTN_SECONDARY := Color(0.37, 0.65, 0.65)
const BTN_DISABLED_BG := Color(0.20, 0.17, 0.13)
const BTN_DISABLED_TEXT := Color(0.38, 0.33, 0.28)
const BTN_HOVER := Color(0.94, 0.81, 0.35)
const BTN_PRESSED := Color(0.70, 0.55, 0.15)

# --- Dice ---
const DICE_BG := Color(0.13, 0.10, 0.08)
const DICE_LOCKED_BORDER := Color(0.83, 0.69, 0.22)
const DICE_UNLOCKED_BORDER := Color(0.40, 0.35, 0.30)
const DICE_CELL_SIZE := 64
const DICE_FONT_SIZE := 32

# --- Combat ---
const ENEMY_SELECTED_BG := Color(0.78, 0.33, 0.31, 0.25)
const COMBAT_ACCENT := Color(0.78, 0.33, 0.31)

# Combat log line colors — mirrors Python tag_config
const LOG_PLAYER := Color(0.37, 0.65, 0.65)      # cyan
const LOG_ENEMY := Color(0.78, 0.33, 0.31)        # red
const LOG_SYSTEM := Color(0.83, 0.69, 0.22)       # gold
const LOG_CRIT := Color(0.71, 0.40, 0.71)         # magenta
const LOG_LOOT := Color(0.55, 0.44, 0.61)         # purple
const LOG_SUCCESS := Color(0.50, 0.68, 0.50)      # green
const LOG_FIRE := Color(1.0, 0.27, 0.0)           # orange-red
const LOG_SEPARATOR := Color(0.45, 0.40, 0.35)    # dim

# Enemy dice
const ENEMY_DICE_BG := Color(0.29, 0.0, 0.0)      # #4a0000
const ENEMY_DICE_BORDER := Color(0.55, 0.0, 0.0)   # #8b0000
const ENEMY_DICE_SIZE := 36
const ENEMY_DICE_FONT := 18

# Damage flash
const FLASH_RED := Color(0.85, 0.15, 0.10)
const FLASH_DURATION := 0.35

# --- Standard sizes ---
const PANEL_MARGIN := 16
const PANEL_CORNER := 6
const PANEL_BORDER_WIDTH := 2
const BTN_MIN_HEIGHT := 32
const BTN_ICON_SIZE := Vector2(32, 28)
const SEPARATOR_THICKNESS := 1

# --- Animation ---
const FADE_DURATION := 0.15
const SLIDE_DURATION := 0.2


## Creates a styled panel background StyleBoxFlat.
static func make_panel_bg(bg_color: Color, border_color: Color = BORDER_GOLD) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg_color
	s.border_color = border_color
	s.set_border_width_all(PANEL_BORDER_WIDTH)
	s.set_corner_radius_all(PANEL_CORNER)
	s.set_content_margin_all(PANEL_MARGIN)
	return s


## Creates a styled button with accent color.
static func make_styled_btn(text: String, accent: Color, min_width: int = 100) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(min_width, BTN_MIN_HEIGHT)
	btn.add_theme_font_size_override("font_size", FONT_BUTTON)

	var normal := StyleBoxFlat.new()
	normal.bg_color = accent.darkened(0.55)
	normal.border_color = accent.darkened(0.15)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(4)
	normal.set_content_margin_all(6)
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_color_override("font_color", accent.lightened(0.35))

	var hover := StyleBoxFlat.new()
	hover.bg_color = accent.darkened(0.35)
	hover.border_color = accent.lightened(0.15)
	hover.set_border_width_all(1)
	hover.set_corner_radius_all(4)
	hover.set_content_margin_all(6)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)

	var pressed := StyleBoxFlat.new()
	pressed.bg_color = accent.darkened(0.65)
	pressed.set_corner_radius_all(4)
	pressed.set_content_margin_all(6)
	btn.add_theme_stylebox_override("pressed", pressed)

	var disabled := StyleBoxFlat.new()
	disabled.bg_color = BTN_DISABLED_BG
	disabled.set_corner_radius_all(4)
	disabled.set_content_margin_all(6)
	btn.add_theme_stylebox_override("disabled", disabled)
	btn.add_theme_color_override("font_disabled_color", BTN_DISABLED_TEXT)

	return btn


## Creates a panel header label.
static func make_header(text: String, color: Color = TEXT_GOLD, size: int = FONT_HEADING) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", color)
	return lbl


## Creates a standard separator line.
static func make_separator(color: Color = BORDER_GOLD) -> HSeparator:
	var sep := HSeparator.new()
	var s := StyleBoxLine.new()
	s.color = color
	s.thickness = SEPARATOR_THICKNESS
	sep.add_theme_stylebox_override("separator", s)
	return sep


## Creates a themed item list.
static func make_item_list(min_height: int = 120) -> ItemList:
	var list := ItemList.new()
	list.custom_minimum_size = Vector2(0, min_height)
	list.max_columns = 1
	list.add_theme_font_size_override("font_size", FONT_LABEL)
	list.add_theme_color_override("font_color", TEXT_BONE)
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.06, 0.04, 0.05, 0.9)
	s.set_corner_radius_all(4)
	s.set_content_margin_all(4)
	s.border_color = BORDER.darkened(0.3)
	s.set_border_width_all(1)
	list.add_theme_stylebox_override("panel", s)
	return list


## Styles an HP bar based on fill ratio.
static func style_hp_bar(bar: ProgressBar, ratio: float) -> void:
	var fill_color: Color
	if ratio > 0.6:
		fill_color = HP_FULL
	elif ratio > 0.3:
		fill_color = HP_MID
	else:
		fill_color = HP_LOW

	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = fill_color
	fill_style.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("fill", fill_style)

	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = HP_BG
	bg_style.set_corner_radius_all(3)
	bg_style.border_color = BORDER
	bg_style.set_border_width_all(1)
	bar.add_theme_stylebox_override("background", bg_style)
