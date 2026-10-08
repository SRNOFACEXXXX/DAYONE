extends Control
## Overlay da luneta (ACOG): máscara de tela cheia + retículo. Em alça aberta não desenha nada (mira = modelo 3D da arma).

const SCOPE_SHADER := preload("res://shaders/acog_overlay.gdshader")

var amount := 0.0
var acog := false
var dot := false             # ACOG em modo red dot (curta distância): sem máscara de luneta, só o ponto vermelho
var _scope: ColorRect
var _reticle: SightReticle


class SightReticle extends Control:
	var amount := 0.0
	var acog := false
	var dot := false
	var pos := Vector2(-1, -1)          # ponto da holográfica projetado (colimador); (-1,-1) = centro da tela
	var janela := Rect2()                # janela da mira projetada: o ponto só aparece através do vidro

	func _draw() -> void:
		if amount <= 0.02:
			return
		var c := size * 0.5
		var alpha := clampf((amount - 0.45) * 2.0, 0.0, 1.0)
		if acog and dot:
			if pos.x >= 0.0:
				c = pos
				if janela.size.x > 1.0 and not janela.grow(2.0).has_point(c):
					return   # o eixo da mira saiu da janela (coice forte): o ponto some atrás da carcaça
			# holográfica (docs/ref/mira_holografica_REF.md): anel + 4 ticks + ponto, vermelho com brilho, sem máscara de luneta
			var red := Color(1.0, 0.12, 0.08, alpha)
			var glow := Color(1.0, 0.1, 0.05, alpha * 0.28)
			draw_arc(c, 17.0, 0.0, TAU, 48, glow, 5.0, true)
			draw_arc(c, 17.0, 0.0, TAU, 48, red, 1.8, true)
			for d in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
				draw_line(c + d * 17.0, c + d * 25.0, red, 2.0, true)
			draw_circle(c, 4.0, glow)
			draw_circle(c, 2.2, red)
		elif acog:
			var radius := minf(size.x, size.y) * 0.34
			draw_arc(c, radius, 0.0, TAU, 96, Color(0.025, 0.035, 0.04, alpha), 3.0, true)
			var red := Color(0.9, 0.13, 0.09, alpha)
			draw_line(c + Vector2(-24, 0), c + Vector2(-5, 0), red, 2.0, true)
			draw_line(c + Vector2(5, 0), c + Vector2(24, 0), red, 2.0, true)
			draw_line(c + Vector2(0, -22), c + Vector2(0, -4), red, 2.0, true)
			draw_line(c + Vector2(0, 4), c + Vector2(0, 30), red, 2.0, true)
			draw_circle(c, 1.5, red)
		# alça aberta: sem marca de tela; a única mira é a alça/massa do próprio modelo 3D (uma só mira, coerente com a arma)


func _ready() -> void:
	process_priority = 1000
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scope = ColorRect.new()
	_scope.name = "ScopeShade"
	_scope.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scope.color = Color.WHITE
	_scope.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = SCOPE_SHADER
	_scope.material = mat
	add_child(_scope)
	_reticle = SightReticle.new()
	_reticle.name = "SightReticle"
	_reticle.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_reticle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_reticle)


## Fonte do ponto (viewmodel.reticulo_holo): lida no fim do quadro (process_priority alto), depois do viewmodel e da
## câmera se moverem — senão o ponto anda um quadro atrás da arma no coice.
var fonte_reticulo: Callable


func _process(_dt: float) -> void:
	if dot and visible and fonte_reticulo.is_valid():
		set_reticulo(fonte_reticulo.call())


func set_reticulo(info: Dictionary) -> void:
	_reticle.pos = info.get("pos", Vector2(-1, -1)) if bool(info.get("ok", false)) else Vector2(-1, -1)
	_reticle.janela = info.get("janela", Rect2()) if bool(info.get("ok", false)) else Rect2()
	_reticle.queue_redraw()


func set_aim(value: float, use_acog: bool, red_dot := false) -> void:
	amount = value
	acog = use_acog
	dot = red_dot
	visible = amount > 0.02
	_scope.visible = visible and acog and not dot
	(_scope.material as ShaderMaterial).set_shader_parameter("strength", clampf((amount - 0.25) * 1.1, 0.0, 0.92))
	_reticle.amount = amount
	_reticle.acog = acog
	_reticle.dot = dot
	_reticle.queue_redraw()
