class_name CarromGame
extends MiniGame
## Carrom on the hostel's board with the crack in it (stage 27): three
## strikes each, the doctor first. Slide the striker along your line, pull
## back from it and let go. A coin in a pocket is a point, the red queen is
## three, the striker in a pocket costs one. Ties go to the home board,
## which is the doctor's.
##
## The board is a square two units across, centred on (0, 0), y down: the
## doctor shoots from the bottom line, the rival from the top. The physics
## run in fixed steps, so a strike always plays out the same way.

const STRIKES := 3
const STEP := 1.0 / 240.0
const MAX_STEPS := 12
const COIN := 0.044
const STRIKER := 0.058
const POCKET := 0.078
const POCKET_AT := 0.925
const LINE := 0.66
const LINE_HALF := 0.55
const MAX_SPEED := 3.4
const DRAG := 0.9
const SLOW := 0.35
const BOUNCE := 0.78
const KNOCK := 0.92
## How long the rival lines up a shot, in seconds.
const THINK := 1.0

## Every piece: {p, v, r, m, kind ("white", "black", "queen", "striker"), in}.
var pieces: Array[Dictionary] = []
var striker: Dictionary
var scores := [0, 0]
## Strikes taken so far (even: the doctor's turn, odd: the rival's).
var strikes := 0
## "aim", "moving", "think" or "over".
var state := "aim"
var power := 0.0
var aim := Vector2.UP
var board: Control
var _rng: SeededRandom
var _rival_skill := 0.6
var _aiming := false
var _placing := false
var _left := 0.0
var _gain := 0
var _fouled := false
var _think := 0.0


func _init(rival: String = "varun", seed_value: int = 1) -> void:
	against = rival
	_rng = SeededRandom.new(seed_value % 1000003 + 7)
	_rival_skill = 0.5 + _rng.next_float() * 0.25
	title = "Carrom"
	how = "Slide along your line to place the striker. Pull back from it and let go. Coins 1, the red queen 3."


func build() -> void:
	board = Control.new()
	board.name = "Board"
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board.mouse_filter = Control.MOUSE_FILTER_STOP
	board.draw.connect(_draw_board)
	board.gui_input.connect(_board_input)
	content.add_child(board)
	_rack()
	_score()


## The coins in the middle: the queen, and eight round her, white and black.
func _rack() -> void:
	pieces.clear()
	pieces.append({"p": Vector2.ZERO, "v": Vector2.ZERO, "r": COIN, "m": 1.0, "kind": "queen", "in": true})
	for index in 8:
		var angle := TAU * index / 8.0 + PI / 8.0
		pieces.append({"p": Vector2(cos(angle), sin(angle)) * 0.118, "v": Vector2.ZERO, "r": COIN, "m": 1.0,
			"kind": "white" if index % 2 == 0 else "black", "in": true})
	striker = {"p": Vector2(0, LINE), "v": Vector2.ZERO, "r": STRIKER, "m": 1.6, "kind": "striker", "in": true}
	pieces.append(striker)


## The card is wider than the others: the board needs the room (and the
## whole card, so it never scrolls under a drag).
func _layout() -> void:
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var view := get_viewport_rect().size if is_inside_tree() else size
	var tall := view.y - UiKit.px(28)
	var wide := minf(maxf(UiKit.px(360), tall * 0.82), view.x * 0.56)
	card.anchor_left = 1.0
	card.anchor_right = 1.0
	card.anchor_top = 0.0
	card.anchor_bottom = 1.0
	card.offset_left = -wide - UiKit.px(14)
	card.offset_right = -UiKit.px(14)
	card.offset_top = UiKit.px(14)
	card.offset_bottom = -UiKit.px(14)
	UiKit.keep_off_edges(card)


func my_turn() -> bool:
	return strikes % 2 == 0


func coins_left() -> int:
	var count := 0
	for piece: Dictionary in pieces:
		if piece != striker and bool(piece["in"]):
			count += 1
	return count


# --- Turns ---------------------------------------------------------------------------

func play(delta: float) -> void:
	match state:
		"moving":
			_left += delta
			var steps := 0
			while _left >= STEP and steps < MAX_STEPS:
				_left -= STEP
				steps += 1
				_step(STEP)
			if steps >= MAX_STEPS:
				_left = 0.0
			if _still():
				_strike_over()
		"think":
			_think -= delta
			if _think <= 0.0:
				var shot := best_shot(-LINE, 1.0, (1.0 - _rival_skill) * 0.16)
				striker["p"] = Vector2(float(shot["x"]), -LINE)
				shoot(shot["dir"], float(shot["power"]))
	if board != null:
		board.queue_redraw()


## Sends the striker off from where it is.
func shoot(direction: Vector2, strength: float) -> void:
	if state != "aim" and state != "think":
		return
	power = clampf(strength, 0.0, 1.0)
	striker["v"] = direction.normalized() * power * MAX_SPEED
	state = "moving"
	_gain = 0
	_fouled = false
	_left = 0.0
	_aiming = false
	_placing = false


func _strike_over() -> void:
	var points := _gain - (1 if _fouled else 0)
	var who := strikes % 2
	scores[who] = maxi(0, scores[who] + points)
	if points > 0:
		moment.emit("good" if who == 0 else "bad")
	strikes += 1
	if strikes >= STRIKES * 2 or coins_left() == 0:
		state = "over"
		_score()
		var mine: int = scores[0]
		var theirs: int = scores[1]
		if mine == theirs:
			end("won", "A tie, %d all. Home board wins. %s demands a recount." % [mine, name_of(against)])
		elif mine > theirs:
			end("won", "You win, %d to %d. %s is already asking for a rematch." % [mine, theirs, name_of(against)])
		else:
			end("lost", "%s wins, %d to %d. It will be on his story in four minutes." % [name_of(against), scores[1],
				scores[0]])
		return
	striker["in"] = true
	striker["v"] = Vector2.ZERO
	striker["p"] = Vector2(0, LINE if my_turn() else -LINE)
	_clear_line()
	if my_turn():
		state = "aim"
	else:
		state = "think"
		_think = THINK
	_score()


## A coin left sitting on the line where the striker goes is nudged off it.
func _clear_line() -> void:
	for piece: Dictionary in pieces:
		if piece == striker or not bool(piece["in"]):
			continue
		var gap: Vector2 = piece["p"] - striker["p"]
		if gap.length() < COIN + STRIKER:
			piece["p"] = striker["p"] + (gap.normalized() if gap.length() > 0.001 else Vector2.UP) * (COIN + STRIKER + 0.01)


func _score() -> void:
	var turn := "Your turn" if my_turn() else "%s is aiming" % name_of(against)
	if state == "over":
		turn = "Final"
	set_score("You %d   %s %d   Strike %d of %d   %s" % [scores[0], name_of(against), scores[1],
		mini(strikes / 2 + 1, STRIKES), STRIKES, turn])


# --- Physics ----------------------------------------------------------------------------

func _step(dt: float) -> void:
	for piece: Dictionary in pieces:
		if not bool(piece["in"]):
			continue
		var velocity: Vector2 = piece["v"]
		velocity = velocity.move_toward(Vector2.ZERO, SLOW * dt) * (1.0 - DRAG * dt)
		var at: Vector2 = piece["p"] + velocity * dt
		var radius := float(piece["r"])
		if at.x < -1.0 + radius:
			at.x = -1.0 + radius
			velocity.x = absf(velocity.x) * BOUNCE
		elif at.x > 1.0 - radius:
			at.x = 1.0 - radius
			velocity.x = -absf(velocity.x) * BOUNCE
		if at.y < -1.0 + radius:
			at.y = -1.0 + radius
			velocity.y = absf(velocity.y) * BOUNCE
		elif at.y > 1.0 - radius:
			at.y = 1.0 - radius
			velocity.y = -absf(velocity.y) * BOUNCE
		piece["p"] = at
		piece["v"] = velocity
	for i in pieces.size():
		var a := pieces[i]
		if not bool(a["in"]):
			continue
		for j in range(i + 1, pieces.size()):
			var b := pieces[j]
			if not bool(b["in"]):
				continue
			var gap: Vector2 = b["p"] - a["p"]
			var reach := float(a["r"]) + float(b["r"])
			var distance := gap.length()
			if distance >= reach or distance < 0.00001:
				continue
			var normal := gap / distance
			var inverse_a := 1.0 / float(a["m"])
			var inverse_b := 1.0 / float(b["m"])
			var closing := (a["v"] as Vector2 - b["v"] as Vector2).dot(normal)
			if closing > 0.0:
				var impulse := (1.0 + KNOCK) * closing / (inverse_a + inverse_b)
				a["v"] = a["v"] - normal * impulse * inverse_a
				b["v"] = b["v"] + normal * impulse * inverse_b
			var push := (reach - distance) / (inverse_a + inverse_b)
			a["p"] = a["p"] - normal * push * inverse_a
			b["p"] = b["p"] + normal * push * inverse_b
	for piece: Dictionary in pieces:
		if not bool(piece["in"]):
			continue
		for corner: Vector2 in pockets():
			if (piece["p"] as Vector2).distance_to(corner) < POCKET:
				piece["in"] = false
				piece["v"] = Vector2.ZERO
				if piece == striker:
					_fouled = true
				else:
					_gain += 3 if str(piece["kind"]) == "queen" else 1
				break


func _still() -> bool:
	for piece: Dictionary in pieces:
		if bool(piece["in"]) and (piece["v"] as Vector2).length() > 0.012:
			return false
	return true


static func pockets() -> Array[Vector2]:
	return [Vector2(-POCKET_AT, -POCKET_AT), Vector2(POCKET_AT, -POCKET_AT), Vector2(-POCKET_AT, POCKET_AT),
		Vector2(POCKET_AT, POCKET_AT)]


## The shot a careful player would take from a line (y), shooting forward
## (+1 down the board, -1 up it): the coin with the cleanest cut into a
## pocket, aimed off by up to wobble radians. {x, dir, power}.
func best_shot(line: float, forward: float, wobble: float) -> Dictionary:
	var best := {}
	var best_cost := INF
	for step in 11:
		var x := -0.5 + step * 0.1
		var from := Vector2(x, line)
		for piece: Dictionary in pieces:
			if piece == striker or not bool(piece["in"]):
				continue
			for corner: Vector2 in pockets():
				var into: Vector2 = (corner - piece["p"]).normalized()
				var contact: Vector2 = piece["p"] - into * (COIN + STRIKER)
				var path := contact - from
				if path.y * forward <= 0.08:
					continue
				var cut := absf(path.angle_to(into))
				if cut > 1.05:
					continue
				var cost := cut * 1.6 + path.length() * 0.35 + (corner - (piece["p"] as Vector2)).length() * 0.3
				if str(piece["kind"]) == "queen":
					cost -= 0.25
				if cost < best_cost:
					best_cost = cost
					var reach := path.length() + (corner - (piece["p"] as Vector2)).length() / maxf(0.35, cos(cut))
					best = {"x": x, "dir": path.normalized(), "power": clampf(0.42 + reach * 0.22, 0.4, 0.95)}
	if best.is_empty():
		best = {"x": 0.0, "dir": Vector2(0, forward), "power": 0.8}
	var turn := (_rng.next_float() * 2.0 - 1.0) * wobble
	best["dir"] = (best["dir"] as Vector2).rotated(turn)
	return best


func auto_step(skill: float) -> void:
	if state != "aim" or is_over():
		return
	var shot := best_shot(LINE, -1.0, (1.0 - clampf(skill, 0.0, 1.0)) * 0.16)
	striker["p"] = Vector2(float(shot["x"]), LINE)
	_clear_line()
	shoot(shot["dir"], float(shot["power"]))


# --- Touch -------------------------------------------------------------------------------

func _square() -> Rect2:
	var side := minf(board.size.x, board.size.y)
	return Rect2((board.size - Vector2(side, side)) / 2.0, Vector2(side, side))


func _to_board(point: Vector2) -> Vector2:
	var square := _square()
	return (point - square.position) / square.size.x * 2.0 - Vector2.ONE


func _to_screen(point: Vector2) -> Vector2:
	var square := _square()
	return square.position + (point + Vector2.ONE) / 2.0 * square.size.x


func _board_input(event: InputEvent) -> void:
	if state != "aim" or is_over():
		return
	var press := event as InputEventMouseButton
	if press != null and press.button_index == MOUSE_BUTTON_LEFT:
		var at := _to_board(press.position)
		if press.pressed:
			if at.distance_to(striker["p"]) < STRIKER * 2.8:
				_aiming = true
				_pull(at)
			elif at.y > 0.3:
				_placing = true
				_place(at.x)
		else:
			if _aiming and power > 0.08:
				shoot(aim, power)
			_aiming = false
			_placing = false
			power = 0.0
		board.queue_redraw()
		return
	var motion := event as InputEventMouseMotion
	if motion != null:
		var at := _to_board(motion.position)
		if _aiming:
			_pull(at)
		elif _placing:
			_place(at.x)
		board.queue_redraw()


func _pull(at: Vector2) -> void:
	var back: Vector2 = at - striker["p"]
	power = clampf(back.length() / 0.55, 0.0, 1.0)
	if back.length() > 0.01:
		aim = -back.normalized()


func _place(x: float) -> void:
	striker["p"] = Vector2(clampf(x, -LINE_HALF, LINE_HALF), LINE)
	_clear_line()


# --- Drawing -------------------------------------------------------------------------------

func _draw_board() -> void:
	var square := _square()
	var side := square.size.x
	var unit := side / 2.0
	board.draw_rect(square.grow(unit * 0.06), Color("#5A3418"))
	board.draw_rect(square, Color("#EAC891"))
	# The crack, from the corner, as promised.
	board.draw_polyline(PackedVector2Array([_to_screen(Vector2(0.62, -0.98)), _to_screen(Vector2(0.55, -0.82)),
		_to_screen(Vector2(0.58, -0.7))]), Color("#B48C5A"), maxf(1.0, unit * 0.008))
	for line_y: float in [LINE, -LINE]:
		for offset: float in [-0.065, 0.065]:
			board.draw_line(_to_screen(Vector2(-LINE_HALF, line_y + offset)), _to_screen(Vector2(LINE_HALF, line_y + offset)),
				Color("#7A4A26"), maxf(1.0, unit * 0.006))
		for end_x: float in [-LINE_HALF, LINE_HALF]:
			board.draw_circle(_to_screen(Vector2(end_x, line_y)), unit * 0.065, Color("#C8323C"), false, maxf(1.0, unit * 0.006))
	board.draw_circle(_to_screen(Vector2.ZERO), unit * 0.2, Color("#7A4A26"), false, maxf(1.0, unit * 0.006))
	board.draw_circle(_to_screen(Vector2.ZERO), unit * 0.03, Color("#C8323C"))
	for corner: Vector2 in pockets():
		board.draw_circle(_to_screen(corner), unit * POCKET, Color("#1B120C"))
	var font := UiKit.heavy_font()
	var size := int(maxf(10.0, unit * 0.075))
	board.draw_string(font, _to_screen(Vector2(-0.12, 0.86)), "YOU", HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color("#7A4A26"))
	board.draw_string(font, _to_screen(Vector2(-0.16, -0.8)), name_of(against).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1,
		size, Color("#7A4A26"))
	if state == "aim" and _aiming and power > 0.02:
		var start := _to_screen(striker["p"])
		var reach := unit * (0.25 + power * 0.7)
		var dots := 9
		for index in dots:
			var at := start + aim * reach * float(index + 1) / dots
			board.draw_circle(at, unit * 0.012, Color(1, 1, 1, 0.85 - index * 0.07))
		board.draw_line(start, start - aim * unit * power * 0.4, Color(UiKit.AMBER, 0.9), maxf(2.0, unit * 0.014))
	for piece: Dictionary in pieces:
		if not bool(piece["in"]):
			continue
		var at := _to_screen(piece["p"])
		var radius := unit * float(piece["r"])
		var fill := Color("#F4EEDC")
		var rim := Color("#BFAE8A")
		match str(piece["kind"]):
			"black":
				fill = Color("#2B2422")
				rim = Color("#5A4A40")
			"queen":
				fill = Color("#C8323C")
				rim = Color("#8E1F27")
			"striker":
				fill = Color("#DCEFF4")
				rim = Color("#5E9FD0")
		board.draw_circle(at + Vector2(radius * 0.12, radius * 0.16), radius, Color(0, 0, 0, 0.18))
		board.draw_circle(at, radius, fill)
		board.draw_circle(at, radius * 0.62, rim, false, maxf(1.0, radius * 0.16))
	if state == "aim" and not _aiming:
		var hint := _to_screen(striker["p"] as Vector2 + Vector2(0, 0.13))
		board.draw_string(font, hint - Vector2(unit * 0.3, 0), "pull back to shoot", HORIZONTAL_ALIGNMENT_CENTER, unit * 0.6,
			int(maxf(9.0, unit * 0.055)), Color("#5A3418"))
