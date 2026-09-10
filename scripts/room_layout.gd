extends RefCounted
## Hand-built geometry based on Levels/Sampple.bmp, in existing arena coordinates.
const ALERTS = [Vector2(175, 105), Vector2(725, 105), Vector2(175, 485), Vector2(725, 485)]
const ENTRIES = [Vector2(0, 290), Vector2(900, 290), Vector2(450, 0), Vector2(450, 580)]
const DIRECTIONS = [Vector2.RIGHT, Vector2.LEFT, Vector2.DOWN, Vector2.UP]
const WALLS = [
	Rect2(0, 0, 330, 40), Rect2(0, 0, 45, 200), Rect2(305, 0, 25, 175),
	Rect2(0, 175, 210, 25), Rect2(290, 175, 40, 25),
	Rect2(570, 0, 330, 40), Rect2(570, 0, 25, 175), Rect2(855, 0, 45, 200),
	Rect2(570, 175, 40, 25), Rect2(690, 175, 210, 25),
	Rect2(0, 390, 210, 25), Rect2(290, 390, 40, 25),
	Rect2(0, 390, 45, 190), Rect2(305, 415, 25, 160), Rect2(0, 555, 330, 25),
	Rect2(570, 390, 40, 25), Rect2(690, 390, 210, 25),
	Rect2(570, 415, 25, 160), Rect2(855, 390, 45, 190), Rect2(570, 555, 330, 25),
	Rect2(330, 85, 40, 25), Rect2(530, 95, 40, 30),
	Rect2(690, 200, 25, 55), Rect2(185, 325, 25, 65), Rect2(525, 465, 45, 30),
]
