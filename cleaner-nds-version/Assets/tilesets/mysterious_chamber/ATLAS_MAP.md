# Mysterious Chamber Asset Kit

These atlases use transparent backgrounds and are designed for nearest-neighbor filtering.

## `mysterious-chamber-tiles-8x4.png`

- Image size: 1024 x 512
- Grid: 8 columns x 4 rows
- Cell size: 128 x 128
- Suggested use: Godot TileSet atlas or individually selected Sprite2D regions

| Row | C0 | C1 | C2 | C3 | C4 | C5 | C6 | C7 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 0 | Worn slab | Alternate slab | Cracked slab | Rubble slab | Iron grate | Cable trench | Hazard seam | Violet socket |
| 1 | Platform edge | Damaged edge | Left pipe corner | Right pipe corner | Alternate corner | Short stair | Maintenance hatch | Reinforced threshold |
| 2 | Dark brick | Alternate brick | Cracked brick | Breached brick | Reinforced panel | Pipe wall | Left chamber pillar | Right chamber pillar |
| 3 | Ceiling service strip | Hanging support | Square column | Column base | Column capital | Pipe junction | Ancient conduit junction | Sealed wall socket |

## `mysterious-chamber-objects-4x4.png`

- Image size: 1024 x 1024
- Grid: 4 columns x 4 rows
- Cell size: 256 x 256
- Suggested use: Sprite2D regions; add collisions per object rather than per full cell

| Row | C0 | C1 | C2 | C3 |
| --- | --- | --- | --- | --- |
| 0 | Signal relay obelisk | Capacitor bank | Broken containment pod | Ritual control console |
| 1 | Mechanical sensor eye | Coiled power cable | Runic pressure plate | Tripod warning beacon |
| 2 | Pipe manifold | Crystal socket pedestal | Hanging cable bundle | Collapsed machine fragment |
| 3 | Nephilim reliquary | Energy vent | Maintenance shrine | Clamped monolith shard |

## Godot import

- Disable texture filtering for crisp pixel art.
- Keep lossless compression enabled.
- Use the listed grid dimensions when creating atlas regions.
- Most prop artwork is smaller than its cell; use visible-pixel-shaped collision rather than the cell bounds.
- Violet elements are intentionally dim so pulse, bloom, and PointLight2D effects can be layered in-engine.
