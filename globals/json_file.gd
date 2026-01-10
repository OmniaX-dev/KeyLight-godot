class_name JsonFile
extends RefCounted

var _data: Dictionary = {}

# -------------------------------------------------------------------------
# Loading / Saving
# -------------------------------------------------------------------------

func load(path: String) -> bool:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return false
	var text := f.get_as_text()
	var result: Variant = JSON.parse_string(text)
	if typeof(result) != TYPE_DICTIONARY:
		return false
	_data = result
	return true


func save(path: String) -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(_data, "\t"))
	return true


# -------------------------------------------------------------------------
# Internal dotted-path lookup
# -------------------------------------------------------------------------

func _get_value(path: String, default_value = null):
	var parts := path.split(".")
	var current: Variant = _data

	for p in parts:
		if typeof(current) != TYPE_DICTIONARY:
			return default_value
		if not current.has(p):
			return default_value
		current = current[p]

	return current


func _set_value(path: String, value) -> bool:
	var parts := path.split(".")
	var current := _data

	for i in range(parts.size() - 1):
		var p := parts[i]
		if not current.has(p) or typeof(current[p]) != TYPE_DICTIONARY:
			current[p] = {}
		current = current[p]

	current[parts[-1]] = value
	return true

func _parse_color(v: Variant, default_value: Color) -> Color:
	# Array formats: [R, G, B] or [R, G, B, A]
	if v is Array and v.size() >= 3:
		var r := int(v[0])
		var g := int(v[1])
		var b := int(v[2])
		var a := int(v[3]) if v.size() > 3 else 255
		return Color8(r, g, b, a)

	# String formats: "#RRGGBB" or "RRGGBBAA"
	if v is String:
		var s = v.strip_edges()

		# Remove leading '#'
		if s.begins_with("#"):
			s = s.substr(1)

		# Must be 6 or 8 hex digits
		if s.length() == 6 or s.length() == 8:
			var r : int = s.substr(0, 2).hex_to_int()
			var g : int = s.substr(2, 2).hex_to_int()
			var b : int = s.substr(4, 2).hex_to_int()
			var a : int = s.substr(6, 2).hex_to_int() if s.length() == 8 else 255
			return Color8(r, g, b, a)

	# Fallback
	return default_value



# -------------------------------------------------------------------------
# GETTERS
# -------------------------------------------------------------------------

func get_bool(name: String, default_value := false) -> bool:
	var v = _get_value(name)
	return bool(v) if v != null else default_value


func get_int(name: String, default_value := 0) -> int:
	var v = _get_value(name)
	return int(v) if v != null else default_value


func get_double(name: String, default_value := 0.0) -> float:
	var v = _get_value(name)
	return float(v) if v != null else default_value


func get_string(name: String, default_value := "") -> String:
	var v = _get_value(name)
	return str(v) if v != null else default_value


func get_color(name: String, default_value := Color.WHITE) -> Color:
	var v = _get_value(name)
	if v == null:
		return default_value
	return _parse_color(v, default_value)


func get_vec2(name: String, default_value := Vector2.ZERO) -> Vector2:
	var v = _get_value(name)
	if v is Array and v.size() >= 2:
		return Vector2(float(v[0]), float(v[1]))
	return default_value


func get_rect(name: String, default_value := Rect2()) -> Rect2:
	var v = _get_value(name)
	if v is Array and v.size() >= 4:
		return Rect2(float(v[0]), float(v[1]), float(v[2]), float(v[3]))
	return default_value


func get_int_array(name: String) -> Array[int]:
	var v = _get_value(name)
	if v is Array:
		return v.map(func(x): return int(x))
	return []


func get_double_array(name: String) -> Array[float]:
	var v = _get_value(name)
	if v is Array:
		return v.map(func(x): return float(x))
	return []


func get_string_array(name: String) -> Array[String]:
	var v = _get_value(name)
	if v is Array:
		return v.map(func(x): return str(x))
	return []


func get_color_array(name: String) -> Array[Color]:
	var v = _get_value(name)
	if v is Array:
		var out: Array[Color] = []
		for c in v:
			out.append(_parse_color(c, Color.WHITE))
		return out
	return []


func get_rect_array(name: String) -> Array[Rect2]:
	var v = _get_value(name)
	if v is Array:
		var out: Array[Rect2] = []
		for r in v:
			if r is Array and r.size() >= 4:
				out.append(Rect2(r[0], r[1], r[2], r[3]))
		return out
	return []


# -------------------------------------------------------------------------
# SETTERS
# -------------------------------------------------------------------------

func set_bool(name: String, value: bool) -> bool:
	return _set_value(name, value)


func set_int(name: String, value: int) -> bool:
	return _set_value(name, value)


func set_double(name: String, value: float) -> bool:
	return _set_value(name, value)


func set_string(name: String, value: String) -> bool:
	return _set_value(name, value)


func set_color(name: String, value: Color) -> bool:
	var arr = [int(value.r8), int(value.g8), int(value.b8), int(value.a8)]
	return _set_value(name, arr)


func set_vec2(name: String, value: Vector2) -> bool:
	return _set_value(name, [value.x, value.y])


func set_rect(name: String, value: Rect2) -> bool:
	return _set_value(name, [value.position.x, value.position.y, value.size.x, value.size.y])


func set_int_array(name: String, value: Array[int]) -> bool:
	return _set_value(name, value)


func set_double_array(name: String, value: Array[float]) -> bool:
	return _set_value(name, value)


func set_string_array(name: String, value: Array[String]) -> bool:
	return _set_value(name, value)


func set_color_array(name: String, value: Array[Color]) -> bool:
	var arr = []
	for c in value:
		arr.append([c.r8, c.g8, c.b8, c.a8])
	return _set_value(name, arr)


func set_rect_array(name: String, value: Array[Rect2]) -> bool:
	var arr = []
	for r in value:
		arr.append([r.position.x, r.position.y, r.size.x, r.size.y])
	return _set_value(name, arr)
