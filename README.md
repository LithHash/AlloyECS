# AlloyECS

A simple and lightweight Entity Component System (ECS) for Luau.

## Example Usage

```lua
local world = world()

--// Create components
local position = world:component()
local velocity = world:component()

--// Create an entity and assign components
local entity = world:entity()
world:assign(entity, position, { x = 0, y = 0 })
world:assign(entity, velocity, { x = 1, y = 1 })

--/ Query entities with both position and velocity
local view = world:view(position, velocity)
view:forEach(function(id, pos, vel)
    print(id, pos.x, pos.y)
end)
```

## Installation
Pesde:

```bash
pesde add lithhash/alloyecs
```

## License

MIT License