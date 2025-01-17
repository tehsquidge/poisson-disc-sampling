class_name PoissonDiscSampling

var _radius: float
var _sample_region_shape
var _retries: int
var _start_pos: Vector2
var _sample_region_rect: Rect2
var _cell_size: float
var _rows: int
var _cols: int
var _cell_size_scaled: Vector2
var _grid: Array = []
var _points: Array = []
var _spawn_points: Array = []
var _transpose: Vector2
var _rng: RandomNumberGenerator

# radius - minimum distance between points
# sample_region_shape - takes any of the following:
# 		-a Rect2 for rectangular region
#		-an array of Vector2 for polygon region
#		-a Vector3 with x,y as the position and z as the radius of the circle
# retries - maximum number of attempts to look around a sample point, reduce this value to speed up generation
# start_pos - optional parameter specifying the starting point
# rng - an optional RandomNumberGenerator to use. If not specified a new RandomNumberGenerator will be created and randomized.
#
# returns an Array of Vector2D with points in the order of their discovery
func generate_points(radius: float, sample_region_shape, retries: int, start_pos := Vector2(INF, INF), rng: RandomNumberGenerator = null ) -> Array:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	_rng = rng
	_radius = radius
	_sample_region_shape = sample_region_shape
	_retries = retries
	_start_pos = start_pos
	_init_vars()
	
	while _spawn_points.size() > 0:
		var spawn_index: int = _rng.randi() % _spawn_points.size()
		var spawn_centre: Vector2 = _spawn_points[spawn_index]
		var sample_accepted: bool = false
		for i in retries:
			var angle: float = 2 * PI * _rng.randf()
			var sample: Vector2 = spawn_centre + Vector2(cos(angle), sin(angle)) * (radius + radius * _rng.randf())
			if _is_valid_sample(sample):
				_grid[int((_transpose.x + sample.x) / _cell_size_scaled.x)][int((_transpose.y + sample.y) / _cell_size_scaled.y)] = _points.size()
				_points.append(sample)
				_spawn_points.append(sample)
				sample_accepted = true
				break
		if not sample_accepted:
			_spawn_points.remove(spawn_index)
	return _points


func _is_valid_sample(sample: Vector2) -> bool:
	if _is_point_in_sample_region(sample):
		var cell := Vector2(int((_transpose.x + sample.x) / _cell_size_scaled.x), int((_transpose.y + sample.y) / _cell_size_scaled.y))
		var cell_start := Vector2(max(0, cell.x - 2), max(0, cell.y - 2))
		var cell_end := Vector2(min(cell.x + 2, _cols - 1), min(cell.y + 2, _rows - 1))
	
		for i in range(cell_start.x, cell_end.x + 1):
			for j in range(cell_start.y, cell_end.y + 1):
				var search_index: int = _grid[i][j]
				if search_index != -1:
					var dist: float = _points[search_index].distance_to(sample)
					if dist < _radius:
						return false
		return true
	return false


func _is_point_in_sample_region(sample: Vector2) -> bool:
	if _sample_region_rect.has_point(sample):
		match typeof(_sample_region_shape):
			TYPE_RECT2:
				return true
			TYPE_VECTOR2_ARRAY, TYPE_ARRAY:
				if Geometry.is_point_in_polygon(sample, _sample_region_shape):
					return true
			TYPE_VECTOR3:
				if Geometry.is_point_in_circle(sample, Vector2(_sample_region_shape.x, _sample_region_shape.y), _sample_region_shape.z):
					return true
			_:
				return false
	return false

func _init_vars() -> void:
	
	# identify the type of shape and it's bounding rectangle and starting point
	match typeof(_sample_region_shape):
		TYPE_RECT2:
			_sample_region_rect = _sample_region_shape
			if _start_pos.x == INF:
				_start_pos.x = _sample_region_rect.position.x + _sample_region_rect.size.x * _rng.randf()
				_start_pos.y = _sample_region_rect.position.y + _sample_region_rect.size.y * _rng.randf()
			
		TYPE_VECTOR2_ARRAY, TYPE_ARRAY:
			var start: Vector2 = _sample_region_shape[0]
			var end: Vector2 = _sample_region_shape[0]
			for i in range(1, _sample_region_shape.size()):
				start.x = min(start.x, _sample_region_shape[i].x)
				start.y = min(start.y, _sample_region_shape[i].y)
				end.x = max(end.x, _sample_region_shape[i].x)
				end.y = max(end.y, _sample_region_shape[i].y)
			_sample_region_rect = Rect2(start, end - start)
			if _start_pos.x == INF:
				var n: int = _sample_region_shape.size()
				var i: int = _rng.randi() % n
				_start_pos = _sample_region_shape[i] + (_sample_region_shape[(i + 1) % n] - _sample_region_shape[i]) * _rng.randf()
			
		TYPE_VECTOR3:
			var x = _sample_region_shape.x
			var y = _sample_region_shape.y
			var r = _sample_region_shape.z
			_sample_region_rect = Rect2(x - r, y - r, r * 2, r * 2)
			if _start_pos.x == INF:
				var angle: float = 2 * PI * _rng.randf()
				_start_pos = Vector2(x, y) + Vector2(cos(angle), sin(angle)) * r * _rng.randf()
		_:
			_sample_region_shape = Rect2(0, 0, 0, 0)
			push_error("Unrecognized shape!!! Please input a valid shape")
	
	_cell_size = _radius / sqrt(2)
	_cols = max(floor(_sample_region_rect.size.x / _cell_size), 1)
	_rows = max(floor(_sample_region_rect.size.y / _cell_size), 1)
	# scale the cell size in each axis 
	_cell_size_scaled.x = _sample_region_rect.size.x / _cols 
	_cell_size_scaled.y = _sample_region_rect.size.y / _rows
	# use tranpose to map points starting from origin to calculate grid position
	_transpose = -_sample_region_rect.position
	
	_grid = []
	for i in _cols:
		_grid.append([])
		for j in _rows:
			_grid[i].append(-1)
	
	_points = []
	_spawn_points = []
	_spawn_points.append(_start_pos)
