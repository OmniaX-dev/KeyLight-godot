class_name ParticleSystemData
extends RefCounted

# Data
var disable_z : bool = true
var align_y : bool = false
var amount : int = 100
var lifetime : float = 1.0
var rand_lifetime : float = 0.0
var emission_box_extent : Vector2 = Vector2(1.0, 1.0)
var emission_ring_height : float = 1.0
var emission_ring_radius : float = 8.0
var emission_ring_inner_radius : float = 6.0
var emission_ring_cone_angle : float = 90.0
var initial_velocity_min : float = 1.0
var initial_velocity_max : float = 1.0
var radial_velocity_min : float = 1.0
var radial_velocity_max : float = 1.0
var velocity_damping_min : float = 0.0
var velocity_damping_max : float = 0.0
var spread : float = 45.0
var gravity : Vector2 = Vector2(0.0, -9.8)
var scale_min : float = 0.2
var scale_max : float = 0.6
var scale_curve : CurveTexture = null
var alpha_curve : CurveTexture = null
var radial_velocity_curve : CurveTexture = null

var texture : Texture2D = null

var emission_shape : String = "box"

var self_modulate : Color = Color.WHITE
var color_intensity : float = 1.0

func load_from_json(styleJson : JsonFile):
	disable_z = styleJson.get_bool("particles.disable_z", true)
	align_y = styleJson.get_bool("particles.align_y", false)
	amount = styleJson.get_int("particles.amount", 100)
	lifetime = styleJson.get_double("particles.lifetime", 1.0)
	rand_lifetime = styleJson.get_double("particles.lifetime_randomness", 0.0)
	emission_box_extent = styleJson.get_vec2("particles.emission_box_extent", Vector2(1.0, 1.0))
	emission_ring_height = styleJson.get_double("particles.emission_ring_height", 1.0)
	emission_ring_radius = styleJson.get_double("particles.emission_ring_radius", 8.0)
	emission_ring_inner_radius = styleJson.get_double("particles.emission_ring_inner_radius", 6.0)
	emission_ring_cone_angle = styleJson.get_double("particles.emission_ring_cone_angle", 90.0)
	initial_velocity_min = styleJson.get_double("particles.initial_velocity_min", 1.0)
	initial_velocity_max = styleJson.get_double("particles.initial_velocity_max", 1.0)
	radial_velocity_min = styleJson.get_double("particles.radial_velocity_min", 1.0)
	radial_velocity_max = styleJson.get_double("particles.radial_velocity_max", 1.0)
	velocity_damping_min = styleJson.get_double("particles.velocity_damping_min", 0.0)
	velocity_damping_max = styleJson.get_double("particles.velocity_damping_max", 0.0)
	spread = styleJson.get_double("particles.spread", 45.0)
	gravity = styleJson.get_vec2("particles.gravity", Vector2(0.0, -9.8))
	scale_min = styleJson.get_double("particles.scale_min", 1.0)
	scale_max = styleJson.get_double("particles.scale_max", 1.0)
	var tmp_arr = styleJson.get_double_array("particles.scale_curve")
	if tmp_arr.size() > 0:
		scale_curve = Common.build_curve_from_points(tmp_arr)
	tmp_arr = styleJson.get_double_array("particles.alpha_curve")
	if tmp_arr.size() > 0:
		alpha_curve = Common.build_curve_from_points(tmp_arr)
	tmp_arr = styleJson.get_double_array("particles.radial_velocity_curve")
	if tmp_arr.size() > 0:
		radial_velocity_curve = Common.build_curve_from_points(tmp_arr)
	emission_shape = styleJson.get_string("particles.emission_shape", "box")
	self_modulate = styleJson.get_color("particles.color", Color.WHITE)
	color_intensity = styleJson.get_double("particles.color_intensity", 1.0)
	var img_path = styleJson.get_string("particles.texture_file_path", "")
	if img_path != "":
		texture = load(img_path)

func create_particle_system_object(emit : bool, name : String, pre_process_s : float = 0.0) -> GPUParticles2D:
	var particles : GPUParticles2D = GPUParticles2D.new()
	var mat : ParticleProcessMaterial = ParticleProcessMaterial.new()
	particles.amount = amount
	particles.lifetime = lifetime
	particles.fixed_fps = 60
	particles.self_modulate = Common.apply_color_intensity(self_modulate, color_intensity)
	particles.texture = texture
	mat.lifetime_randomness = rand_lifetime
	mat.emission_shape = get_emission_shape_from_string(emission_shape)
	mat.particle_flag_disable_z = disable_z
	mat.particle_flag_align_y = align_y
	mat.emission_box_extents.x = emission_box_extent.x
	mat.emission_box_extents.y = emission_box_extent.y
	mat.emission_ring_height = emission_ring_height
	mat.emission_ring_radius = emission_ring_radius
	mat.emission_ring_inner_radius = emission_ring_inner_radius
	mat.emission_ring_cone_angle = emission_ring_cone_angle
	mat.initial_velocity_min = initial_velocity_min
	mat.initial_velocity_max = initial_velocity_max
	mat.radial_velocity_min = radial_velocity_min
	mat.radial_velocity_max = radial_velocity_max
	mat.damping_min = velocity_damping_min
	mat.damping_max = velocity_damping_max
	mat.spread = spread
	mat.gravity.x = gravity.x
	mat.gravity.y = gravity.y
	mat.gravity.z = 0.0
	mat.scale_min = scale_min
	mat.scale_max = scale_max
	mat.scale_curve = scale_curve
	mat.alpha_curve = alpha_curve
	mat.radial_velocity_curve = radial_velocity_curve
	particles.process_material = mat
	particles.preprocess = pre_process_s
	particles.emitting = emit
	particles.name = name
	return particles

func get_emission_shape_from_string(emission_str : String) -> ParticleProcessMaterial.EmissionShape:
	emission_str = emission_str.strip_edges().to_lower()
	if emission_str == "box":
		return ParticleProcessMaterial.EMISSION_SHAPE_BOX
	if emission_str == "ring":
		return ParticleProcessMaterial.EMISSION_SHAPE_RING
	return ParticleProcessMaterial.EMISSION_SHAPE_BOX
