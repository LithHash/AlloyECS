# AlloyECS

An opinionated, lightweight, ECS for Luau.

## Installation

```bash
pesde add lithhash/alloyecs
```

**OR**

You can also grab the latest code from [here](https://github.com/LithHash/AlloyECS/blob/main/src/init.luau)

## Examples

```lua
local world = world()

--// Create components
local position = world:component({ x = 0, y = 0 })
local velocity = world:component()
local health = world:component()
local enemy = world:tag()
local hidden = world:tag()

--// Create an entity and assign components
local entity = world:entity()
world:attach(entity, position)
world:assign(entity, velocity, { x = 1, y = 1 })
world:assign(entity, health, 100)
world:attach(entity, enemy)

--// Query entities with both position and velocity
local movingThings = world:view(position, velocity)
movingThings:forEach(function(id, pos, vel)
	print(id, pos.x, pos.y, vel.x, vel.y)
end)

--// Cancel iteration early
movingThings:forEach(function(id)
	if id == entity then
		movingThings:cancel()
	end
end)

--// Query components with specific values
local healthyThings = world:view(health):whichIs(100)
healthyThings:forEach(function(id, currentHealth)
	print(id, currentHealth)
end)

--// Query table components by structure
local idlePositions = world:view(position):whichIs({ x = 0, y = 0 })
idlePositions:forEach(function(id, currentPosition)
	print(id, currentPosition.x, currentPosition.y)
end)

--// Query tags
world:view(enemy):forEach(function(id, isEnemy)
	print(id, isEnemy)
end)

--// Exclude tags from a view
local visibleEnemies = world:view(enemy):exclude(hidden)
visibleEnemies:forEach(function(id)
	print(id)
end)
```

Defaulted components can be attached directly. When the default is a table, AlloyECS shallow-clones it with `table.clone()` for each entity.

## Why was this created?

Because archetypes pissed me off.

## License

MIT
