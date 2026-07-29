extends Node

const TILE_WIDTH := 256.0
const TILE_HEIGHT := 128.0


func grid_to_screen(grid: Vector2, origin: Vector2) -> Vector2:
	return origin + Vector2(
		(grid.x - grid.y) * TILE_WIDTH * 0.5,
		(grid.x + grid.y) * TILE_HEIGHT * 0.5
	)


func screen_to_grid(screen: Vector2, origin: Vector2) -> Vector2:
	var rel := screen - origin
	var half_w := TILE_WIDTH * 0.5
	var half_h := TILE_HEIGHT * 0.5
	return Vector2(
		(rel.x / half_w + rel.y / half_h) * 0.5,
		(rel.y / half_h - rel.x / half_w) * 0.5
	)
