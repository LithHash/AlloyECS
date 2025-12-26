---
sidebar_position: 2
---

# Getting Started

This guide will walk you through the basics of AlloyECS.

## Creating a World

The World is the container for all ECS data. Start by creating one:

```lua
local AlloyECS = require(path.to.AlloyECS)

local world = AlloyECS.createWorld()
```

### World Configuration

You can enable optional features:

```lua
local world = AlloyECS.createWorld({
    trackChanges = true,  -- Enable reactive queries (added/removed/changed)
    debug = true,         -- Enable debug warnings
})
```

## Defining Components

Components are data containers. Create them using `world:component()`:

```lua
-- Components with data
local Position = world:component()
local Health = world:component()
local Name = world:component()

-- Tags (no data, just markers)
local Player = world:tag()
local Enemy = world:tag()
```

:::tip Component Storage
For components that will be on most entities, consider using dense storage:
```lua
local Transform = world:component({ storage = "dense" })
```
:::

## Creating Entities

Entities are just numbers. Create them with `world:entity()`:

```lua
local player = world:entity()
local enemy = world:entity()
```

## Adding Components to Entities

Use `set` for components with data, `add` for tags:

```lua
-- Set component data
world:set(player, Position, Vector3.new(0, 5, 0))
world:set(player, Health, 100)
world:set(player, Name, "Hero")

-- Add tags
world:add(player, Player)
```

## Querying Entities

Find entities with specific components:

```lua
-- Simple query
for entityId, pos in world:query(Position) do
    print(entityId, "is at", pos)
end

-- Multiple components
for entityId, pos, health in world:query(Position, Health) do
    print(entityId, "at", pos, "with", health, "HP")
end

-- With filters
for entityId, pos in world:query(Position):with(Player):without(Enemy):iter() do
    -- Only players with Position, not enemies
end
```

## Reading and Modifying Components

```lua
-- Read a component
local pos = world:get(entity, Position)

-- Check if entity has component
if world:has(entity, Position) then
    -- ...
end

-- Remove a component
world:remove(entity, Velocity)

-- Destroy an entity entirely
world:destroy(entity)
```

## Game Loop Integration

Use `step()` to run all systems and handle cleanup:

```lua
local RunService = game:GetService("RunService")

RunService.Heartbeat:Connect(function(deltaTime)
    world:step(deltaTime)
end)
```

## Next Steps

Now that you know the basics, check out:

- [Components Guide](./guides/components) - Storage types, tags, and best practices
- [Queries Guide](./guides/queries) - Advanced querying techniques
- [Systems Guide](./guides/systems) - Organizing game logic
