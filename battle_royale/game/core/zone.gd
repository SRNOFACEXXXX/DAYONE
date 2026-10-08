@tool
class_name Zone
extends Node3D
## Box-shaped gameplay volume (bombsite, buy zone, map area callout). Point test is analytic (no physics).

enum Kind { BOMBSITE, BUYZONE_T, BUYZONE_CT, CALLOUT, KILL }

@export var kind: Kind = Kind.CALLOUT
@export var label := ""
@export var size := Vector3(10, 4, 10):
	set(v):
		size = v
		update_gizmos()


func contains(p: Vector3) -> bool:
	var local := global_transform.affine_inverse() * p
	var h := size * 0.5
	return absf(local.x) <= h.x and absf(local.y) <= h.y and absf(local.z) <= h.z


func random_point_on_floor(margin := 0.5) -> Vector3:
	var h := size * 0.5 - Vector3(margin, 0, margin)
	return global_transform * Vector3(randf_range(-h.x, h.x), -size.y * 0.5 + 0.1, randf_range(-h.z, h.z))
