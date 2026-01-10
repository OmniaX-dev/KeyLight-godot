class_name Primitives
extends RefCounted

static func fill_rounded_rect(obj : CanvasItem, rect: Rect2, color: Color, r_tl: int, r_tr: int, r_br: int, r_bl: int):
	var sb := StyleBoxFlat.new()
	sb.bg_color = color

	sb.corner_radius_top_left = r_tl
	sb.corner_radius_top_right = r_tr
	sb.corner_radius_bottom_right = r_br
	sb.corner_radius_bottom_left = r_bl

	obj.draw_style_box(sb, rect)

static func outline_rounded_rect(obj : CanvasItem, rect: Rect2, fill: Color, outline: Color, outline_width: float, r_tl: float, r_tr: float, r_br: float, r_bl: float):
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = outline
	sb.border_width_left = int(outline_width)
	sb.border_width_right = int(outline_width)
	sb.border_width_top = int(outline_width)
	sb.border_width_bottom = int(outline_width)
	sb.corner_radius_top_left = int(r_tl)
	sb.corner_radius_top_right = int(r_tr)
	sb.corner_radius_bottom_left = int(r_br)
	sb.corner_radius_bottom_right = int(r_bl)

	obj.draw_style_box(sb, rect)
