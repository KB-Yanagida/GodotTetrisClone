extends TileMap

"""
`rotate_shape`:与えられたテトリミノの形状と回転角度を元に、新しいテトリミノの形状を生成
Args:
	piece (Array): 元のテトリミノの形状
	angle (int): 回転させる角度。90, 180, 270のいずれか
Returns:
	Array: 回転した後のテトリミノの形状
"""
func rotate_shape(piece, angle, axis):
	var sin = sin(angle)
	var cos = cos(angle)
	var rotated_piece = []
	for p in piece:
		# 回転軸に対する相対位置に変換
		var p_shifted = p - axis
		# 回転行列を適用
		var rotated_p_shifted = Vector2i(round(p_shifted.x * cos - p_shifted.y * sin), round(p_shifted.x * sin + p_shifted.y * cos))
		# 回転軸を元の位置に戻す
		var rotated_p = rotated_p_shifted + axis
		rotated_piece.append(rotated_p)
	return rotated_piece

#テトリミノ
var i_0 := [Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1)]
var t_0 := [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)]
var o_0 := [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]
var z_0 := [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(2, 1)]
var s_0 := [Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1), Vector2i(1, 1)]
var l_0 := [Vector2i(2, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)]
var j_0 := [Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)]
var i := [i_0, rotate_shape(i_0, PI/2, Vector2i(1, 1)), i_0, rotate_shape(i_0, PI/2, Vector2i(1, 1))]
var t := [t_0, rotate_shape(t_0, PI/2, Vector2i(1, 1)), rotate_shape(t_0, PI, Vector2i(1, 1)), rotate_shape(t_0, 3*PI/2, Vector2i(1, 1))]
var o := [o_0, o_0, o_0, o_0]
var z := [z_0, rotate_shape(z_0, PI/2, Vector2i(1, 1)), z_0, rotate_shape(z_0, PI/2, Vector2i(1, 1))]
var s := [s_0, rotate_shape(s_0, PI/2, Vector2i(1, 1)), s_0, rotate_shape(s_0, PI/2, Vector2i(1, 1))]
var l := [l_0, rotate_shape(l_0, PI/2, Vector2i(1, 1)), rotate_shape(l_0, PI, Vector2i(1, 1)), rotate_shape(l_0, 3*PI/2, Vector2i(1, 1))]
var j := [j_0, rotate_shape(j_0, PI/2, Vector2i(1, 1)), rotate_shape(j_0, PI, Vector2i(1, 1)), rotate_shape(j_0, 3*PI/2, Vector2i(1, 1))]

var shapes := [i, t, o, z, s, l, j]
var shapes_full := shapes.duplicate() #形状配列コピー

#ゲーム領域
const COLS : int = 10
const ROWS : int = 20

#ブロック変数
var piece_type
var next_piece_type
var rotation_index : int = 0 #角度0
var active_piece : Array
var ghost_pos : Vector2i
var ghost_piece = []

#プロパティ
const directions := [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.DOWN]
var steps : Array
const steps_req : int = 50
const start_pos := Vector2i(5, 0)
var cur_pos : Vector2i
var speed : float
const ACCEL : float = 0.25

#ゲーム用変数
var score : int
const REWARD : int = 100
var game_running : bool

#タイルマップ変数
var tile_id : int = 0
var tile_id_ghost : int = 1
var piece_atlas : Vector2i
var next_piece_atlas : Vector2i
var ghost_atlas : Vector2i

#レイヤー変数
var board_layer : int = 0
var active_layer : int = 1

# Called when the node enters the scene tree for the first time.
func _ready():
	new_game()
	$HUD.get_node("StartButton").pressed.connect(new_game)

func new_game():
	#変数初期化
	score = 0
	$HUD.get_node("ScoreLabel").text = "SCORE: " + str(score)
	speed = 1.0
	game_running = true
	steps = [0, 0, 0] #0:left, 1:right, 2:down
	$HUD.get_node("GameOverLabel").hide() #ゲームオーバー文字非表示	
	#クリア処理
	clear_ghost()
	clear_piece()
	clear_board()
	clear_panel()
	#ランダムでテトリミノを選択
	piece_type = pick_piece()
	piece_atlas = Vector2i(shapes_full.find(piece_type), 0)
	next_piece_type =pick_piece()
	next_piece_atlas = Vector2i(shapes_full.find(next_piece_type), 0)
	create_piece()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if game_running:
		if Input.is_action_pressed("ui_left"):
			steps[0] += 10
		elif Input.is_action_pressed("ui_right"):
			steps[1] += 10
		elif Input.is_action_pressed("ui_down"):
			steps[2] += 10 #加速
		elif Input.is_action_pressed("ui_up"):
			hard_drop(active_piece, cur_pos, piece_atlas)
		elif Input.is_action_just_pressed("rotation"):
			rotate_piece()
		
		#指定フレームを超えたら下に落ちる
		steps[2] += speed
		#ブロック移動
		for i in range(steps.size()):
			if steps[i] > steps_req:
				move_piece(directions[i])
				steps[i] = 0

#ブロック選択
func pick_piece():
	var piece
	#形状配列が空でないときはシャッフルして配列の先頭を選択
	if not shapes.is_empty():
		shapes.shuffle()
		piece = shapes.pop_front()
	else:
		shapes = shapes_full.duplicate()
		shapes.shuffle()
		piece = shapes.pop_front()
	return piece

#ブロック生成
func create_piece():
	#変数初期化
	steps = [0, 0, 0] #0:left, 1:right, 2:down
	cur_pos = start_pos
	rotation_index = 0
	active_piece = piece_type[rotation_index]
	draw_ghost(active_piece, cur_pos, ghost_atlas)
	draw_piece(active_piece, cur_pos, piece_atlas)
	#ネクスト
	draw_piece(next_piece_type[0], Vector2i(15, 6), next_piece_atlas)

#ブロッククリア
func clear_piece():
	for i in active_piece:
		erase_cell(active_layer, cur_pos + i)

func clear_ghost():
	for i in ghost_piece:
		erase_cell(active_layer, ghost_pos + i)

"""
`draw_piece`:ブロック描画
Args:
	piece (Array): テトリミノの形状。
	pos (Array): 描画位置
	atlas (Array): ブロックの色(タイルマップ指定)
Returns: none
"""
func draw_piece(piece, pos, atlas):
	for i in piece:
		set_cell(active_layer, pos + i, tile_id, atlas)

#ゴースト描画
func draw_ghost(piece, pos, atlas):
	var cur_y = pos.y
	for row in range(cur_y, ROWS):
		pos.y = row
		if not is_valid_position(piece, pos + Vector2i(0, 1)):
			break
	for i in piece:
		set_cell(active_layer, pos + i, tile_id_ghost, atlas)
	#ゴーストの位置と形状を保存
	ghost_pos = pos
	ghost_piece = piece

#回転処理
func rotate_piece():
	if can_rotate():
		clear_ghost()
		clear_piece()
		rotation_index = (rotation_index + 1) % 4
		active_piece = piece_type[rotation_index]
		draw_ghost(active_piece, cur_pos, ghost_atlas)
		draw_piece(active_piece, cur_pos, piece_atlas)

"""
`move_piece`:方向を指定してブロックを移動させる
Args:
	dir (Array): 移動方向
Returns: none
"""
func move_piece(dir):
	if can_move(dir):
		clear_ghost()
		clear_piece()
		cur_pos += dir
		draw_ghost(active_piece, cur_pos, ghost_atlas)
		draw_piece(active_piece, cur_pos, piece_atlas)
	else:
		#移動できない場合ブロックを底に固定してネクストを出現させる
		if dir == Vector2i.DOWN:
			land_piece()
			check_rows()
			piece_type = next_piece_type
			piece_atlas = next_piece_atlas
			next_piece_type = pick_piece()
			next_piece_atlas = Vector2i(shapes_full.find(next_piece_type), 0)
			clear_panel()
			create_piece()
			check_game_over()
"""
`can_move`:指定方向に移動できるか判定する
Args:
	dir (Array): 移動方向
Returns: bool
"""
func can_move(dir):
	#移動チェック(指定方向のセルが空でないときは移動できない)
	var chack_move = true
	for i in active_piece:
		if not is_free(i + cur_pos + dir):
			chack_move = false
	return chack_move

"""
`can_rotate`:回転できるか判定する
Args: none
Returns: bool
"""
func can_rotate():
	var chack_rotate = true
	var temp_rotation_index = (rotation_index + 1) % 4
	for i in piece_type[temp_rotation_index]:
		if not is_free(i + cur_pos):
			chack_rotate = false
	return chack_rotate
	
"""
`is_free`: board_layerを使用してセルが空いているか判定する。
		   board_layerのソースIDが-1（セルが空いている）ならtrue
Args:
	pos (Array): 調べるセルの位置
Returns: bool
"""
func is_free(pos):
	return get_cell_source_id(board_layer, pos) == -1
	
func is_valid_position(piece, pos):
	for i in piece:
		if not is_free(pos + i):
			return false
	return true

#ブロック設置処理
func land_piece():
	#active_layerを削除してboard_layerに移動
	for i in active_piece:
		erase_cell(active_layer, cur_pos + i)
		set_cell(board_layer, cur_pos + i, tile_id, piece_atlas)

#ネクスト表示クリア
func clear_panel():
	for i in range(14, 19):
		for j in range(5, 9):
			erase_cell(active_layer, Vector2i(i, j))

#行チェック
func check_rows():
	var row : int = ROWS
	while row > 0:
		var count = 0
		for i in range(COLS):
			if not is_free(Vector2i(i + 1, row)):
				count += 1
		if count == COLS:
			#揃ったら行を消して下にシフトする
			shift_rows(row)
			#スコア加算
			score += REWARD
			$HUD.get_node("ScoreLabel").text = "SCORE: " + str(score)
			speed += ACCEL
		else:
			row -= 1

#行削除とシフト処理
func shift_rows(row):
	var atlas
	for i in range(row, 1, -1):
		for j in range(COLS):
			atlas = get_cell_atlas_coords(board_layer, Vector2i(j + 1, i - 1))
			if atlas == Vector2i(-1, -1):
				erase_cell(board_layer, Vector2i(j + 1, i))
			else:
				set_cell(board_layer, Vector2i(j + 1, i), tile_id, atlas)

func hard_drop(piece, pos, atlas):
	clear_piece()
	var cur_y = pos.y
	for row in range(cur_y, ROWS):
		pos.y = row
		if not is_valid_position(piece, pos):
			pos.y = row - 1
			break
	draw_piece(piece, pos, atlas)
	cur_pos = pos

#ゲーム領域クリア
func clear_board():
	for i in range(ROWS + 1):
		for j in range(COLS):
			erase_cell(board_layer, Vector2i(j + 1, i))

#ゲームオーバーチェック
func check_game_over():
	for i in active_piece:
		if not is_free(i + cur_pos):
			land_piece()
			$HUD.get_node("GameOverLabel").show()
			game_running = false
