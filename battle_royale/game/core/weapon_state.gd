class_name WeaponState
extends RefCounted
## Runtime instance of a weapon (ammo). Survives drops/pickups.

var def: WeaponDef
var mag := 0
var reserve := 0
var br_uid := -1 # item correspondente na mochila do jogador; -1 para bots/CS


func _init(d: WeaponDef) -> void:
	def = d
	refill()


func refill() -> void:
	mag = def.mag_size if def.mag_size > 0 else 0
	reserve = def.reserve_max
