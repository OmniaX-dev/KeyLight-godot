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

## Resolves a dot-separated path in a nested Variant structure (Dictionary or Array).
## Supports numeric indices for arrays (as strings, e.g. "players.2.score").
##
## Example paths:
##   "settings.audio.volume"           → dict["settings"]["audio"]["volume"]
##   "characters.1.name"               → array[1]["name"]
##   "inventory.weapons.0.damage"      → dict["inventory"]["weapons"][0]["damage"]
##
## @param path          Dot-separated path (e.g. "someObject.someArray.1.name")
## @param default_value Value to return if path is invalid or not found
## @return              The found value or default_value
func _get_value(path: String, default_value = null) -> Variant:
	if path.is_empty():
		return default_value

	var parts := path.split(".")
	var current: Variant = _data

	for part in parts:
		part = part.strip_edges()  # just in case

		if current == null:
			return default_value

		# ── Dictionary case ────────────────────────────────────────
		if typeof(current) == TYPE_DICTIONARY:
			if not current.has(part):
				return default_value
			current = current[part]
			continue

		# ── Array case ─────────────────────────────────────────────
		if typeof(current) == TYPE_ARRAY:
			# Try to interpret the part as an integer index
			var index := part.to_int()
			# to_int() returns 0 on failure, but we also allow "0"
			# so we check if the conversion makes sense
			if str(index) == part and index >= 0 and index < current.size():
				current = current[index]
				continue
			else:
				# Not a valid array index → path doesn't exist
				return default_value

		# If we reach here, current is neither Dictionary nor Array
		# (or is something like int/float/String/etc.)
		return default_value

	# If we successfully walked the whole path
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
	# Array formats:
	# - Float array: [0.0–1.0] * 3 or 4
	# - Int array:   [0–255]   * 3 or 4
	if v is Array and v.size() >= 3:
		var is_float := true

		# Detect if all values are floats in [0.0, 1.0]
		for x in v:
			if typeof(x) != TYPE_FLOAT:
				is_float = false
				break
			if int(x) > 1 and x / int(x) != 0:
				is_float = false
				break
			#if float(x) > 1.0:
				#is_float = false
				#break

		if is_float:
			# Treat as normalized floats
			var r := float(v[0])
			var g := float(v[1])
			var b := float(v[2])
			var a := float(v[3]) if v.size() > 3 else 1.0
			return Color(r, g, b, a)
		else:
			# Treat as 0–255 ints
			var r := int(v[0])
			var g := int(v[1])
			var b := int(v[2])
			var a := int(v[3]) if v.size() > 3 else 255
			return Color8(r, g, b, a)

	# String formats: "#RRGGBB" or "RRGGBBAA"
	if v is String:
		var s = v.strip_edges()

		if s.begins_with("#"):
			s = s.substr(1)

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
	if v == null:
		return default_value
	if typeof(v) == TYPE_STRING:
		return v.to_lower().strip_edges() == "true"
	return false


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
		var result: Array[int] = []
		result.resize(v.size())
		for i in v.size():
			result[i] = int(v[i])
		return result
	return []


func get_double_array(name: String) -> Array[float]:
	var v = _get_value(name)
	if v is Array:
		var result: Array[float] = []
		result.resize(v.size())
		for i in v.size():
			result[i] = float(v[i])
		return result
	return []


func get_string_array(name: String) -> Array[String]:
	var v = _get_value(name)
	if v is Array:
		var result: Array[String] = []
		result.resize(v.size())
		for i in v.size():
			result[i] = str(v[i])
		return result
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


func get_vec2_array(name: String) -> Array[Vector2]:
	var v = _get_value(name)
	if v is Array:
		var out: Array[Vector2] = []
		for r in v:
			if r is Array and r.size() >= 2:
				out.append(Vector2(r[0], r[1]))
		return out
	return []


func get_object_array(name: String) -> Array[Vector2]:
	var v = _get_value(name)
	if v is Array:
		var out: Array[Vector2] = []
		for r in v:
			if r is Array and r.size() >= 2:
				out.append(Vector2(r[0], r[1]))
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



func set_vec2_array(name: String, value: Array[Vector2]) -> bool:
	var arr = []
	for r in value:
		arr.append([r.x, r.y])
	return _set_value(name, arr)
