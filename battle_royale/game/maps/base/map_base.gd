class_name MapBase
extends Node3D
## Common map setup. Expected children (all optional):
##   Spawns/T/*, Spawns/CT/*  (Marker3D, -Z = facing)
##   Zones/*                  (Zone: bombsites A/B, buy zones, callouts)
##   Bot/Points/*             (Marker3D with metadata "kind": hold_a, hold_b, hold_mid, plant_a, post_plant_a, ...)
##   Bot/Routes/<T_A_Long>/*  (ordered Marker3D waypoints; names start with t_a / t_b)
##   Nav                      (NavigationRegion3D; baked at load if empty)
##   MenuCam*                 (Marker3D path for the title screen flyover)

@export var map_title := "Mapa"
@export var radar_texture := ""
@export var radar_rect := Rect2(-60, -60, 120, 120)
@export var surfaces := {}      # nome do nó (prefixo) -> superfície para som/efeitos
@export var indirect_strength := 1.0
## Luz assada (Cycles) desligada: iluminação simples em tempo real (sol + céu), sem bake de 20 min a cada mudança.
@export var use_baked_light := false


func _ready() -> void:
	set_meta("radar_texture", radar_texture)
	set_meta("radar_rect", radar_rect)
	var preview := has_meta("menu_preview")
	for n in find_children("*", "Marker3D", true, false):
		var p := String(n.get_parent().name)
		if p == "T" and n.get_parent().get_parent().name == "Spawns":
			n.add_to_group("spawn_t")
		elif p == "CT" and n.get_parent().get_parent().name == "Spawns":
			n.add_to_group("spawn_ct")
		elif p == "Points":
			n.add_to_group("bot_points")
			if not n.has_meta("kind"):
				n.set_meta("kind", String(n.name).to_lower().rstrip("0123456789_"))
	var routes := get_node_or_null("Bot/Routes")
	if routes:
		for r in routes.get_children():
			r.add_to_group("bot_routes")
	for z in find_children("*", "Zone", true, false):
		z.add_to_group("zones")
	_tag_surfaces(self)
	_fix_materials(self)
	var cap := get_node_or_null("Capture")
	if cap:
		for c in cap.get_children():
			c.add_to_group("capture_points")
	if not preview:
		var nav := get_node_or_null("Nav") as NavigationRegion3D
		if nav and (nav.navigation_mesh == null or nav.navigation_mesh.get_polygon_count() == 0):
			if nav.navigation_mesh == null:
				nav.navigation_mesh = _default_navmesh()
			nav.bake_navigation_mesh(false)


func _default_navmesh() -> NavigationMesh:
	var nm := NavigationMesh.new()
	nm.agent_radius = 0.5
	nm.agent_height = 1.8
	nm.agent_max_climb = 0.5
	nm.agent_max_slope = 46.0
	nm.cell_size = 0.25
	nm.cell_height = 0.1
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_ROOT_NODE_CHILDREN
	nm.region_min_size = 4.0
	return nm


## Colliders herdam a superfície pelo nome do nó (ex.: "Crate_03" -> wood) via o dicionário surfaces.
func _tag_surfaces(n: Node) -> void:
	if n is CollisionObject3D and not n.has_meta("surface"):
		var key := _surface_for(n)
		if key != "":
			n.set_meta("surface", key)
	for c in n.get_children():
		_tag_surfaces(c)


func _surface_for(n: Node) -> String:
	var cur := n
	while cur and cur != self:
		if cur.has_meta("surface"):
			return str(cur.get_meta("surface"))
		var nm := String(cur.name).to_lower()
		for prefix: String in surfaces:
			if nm.begins_with(prefix.to_lower()):
				return surfaces[prefix]
		cur = cur.get_parent()
	return ""


## Material-paleta: amostragem sem mistura entre células e cor de vértice como variação pintada.
## Blocos assados (BLOCO_<nome>) recebem o shader de cenário com a textura de luz luz_<nome>.png.
func _fix_materials(n: Node) -> void:
	if use_baked_light and n is MeshInstance3D and String(n.name).begins_with("BLOCO_"):
		var mi0 := n as MeshInstance3D
		var bloco := String(n.name).trim_prefix("BLOCO_")
		var dir := scene_file_path.get_base_dir()
		var luz_path := dir.path_join("luz_%s.png" % bloco)
		var pal_path := dir.path_join("paleta_poeira.png")
		var sm := ShaderMaterial.new()
		sm.shader = load("res://shaders/cenario.gdshader")
		if ResourceLoader.exists(pal_path):
			sm.set_shader_parameter("paleta", load(pal_path))
		if ResourceLoader.exists(luz_path):
			sm.set_shader_parameter("luz", load(luz_path))
		else:
			sm.set_shader_parameter("tem_luz", false)
		sm.set_shader_parameter("forca_indireta", indirect_strength)
		mi0.material_override = sm
		return
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		for i in (mi.mesh.get_surface_count() if mi.mesh else 0):
			var m := mi.get_active_material(i)
			if m is BaseMaterial3D and not m.has_meta("fixed"):
				var b := m as BaseMaterial3D
				b.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
				b.vertex_color_use_as_albedo = true
				b.roughness = 0.9
				b.metallic_specular = 0.3
				b.set_meta("fixed", true)
	for c in n.get_children():
		_fix_materials(c)
