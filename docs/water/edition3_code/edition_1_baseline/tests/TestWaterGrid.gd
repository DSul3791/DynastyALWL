extends Node
## Attach to an otherwise empty Node, run scene, inspect output.
const Grid = preload("res://scripts/WaterGrid2D.gd")

func _ready() -> void:
    _test_conservation()
    _test_ditch()
    _test_dam()
    print("WaterGrid2D: core smoke tests passed")

func _advance(grid: WaterGrid2D, count: int) -> void:
    for i in range(count):
        grid.step(0.1)

func _test_conservation() -> void:
    var grid: WaterGrid2D = Grid.new(12, 12, 2.0)
    grid.add_water(4, 4, 20.0)
    var initial: float = grid.total_volume()
    _advance(grid, 150)
    assert(absf(grid.total_volume() - initial) < 0.00001)
    for amount in grid.volume:
        assert(amount >= 0.0)

func _test_ditch() -> void:
    var grid: WaterGrid2D = Grid.new(8, 5, 2.0)
    # Raised ridge; a carved lower crossing is an alternate route.
    for z in range(5):
        grid.set_bed(3, z, 5.0)
    for z in range(5):
        grid.add_water(1, z, 12.0)
    _advance(grid, 60)
    var before: float = grid.total_volume()
    grid.set_bed(3, 2, 0.0)
    _advance(grid, 300)
    assert(grid.depth(4, 2) > 0.0)
    assert(absf(grid.total_volume() - before) < 0.00001)

func _test_dam() -> void:
    var grid: WaterGrid2D = Grid.new(4, 3, 2.0)
    for z in range(3):
        grid.set_east_crest(1, z, 4.0)
    grid.add_water(1, 1, 8.0)
    _advance(grid, 60)
    assert(grid.depth(2, 1) < 0.000001)
    # Removing the dam allows the water to reach the opposite side.
    for z in range(3):
        grid.set_east_crest(1, z, WaterGrid2D.NO_CREST)
    _advance(grid, 100)
    assert(grid.depth(2, 1) > 0.0)
