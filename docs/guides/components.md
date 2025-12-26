---
sidebar_position: 1
---

# Components

Components are pure data containers that you attach to entities. This guide covers everything you need to know about components in AlloyECS.

## Creating Components

```lua
local Position = world:component()
local Velocity = world:component()
local Health = world:component()
```

Each call to `component()` returns a unique component ID (a number).

## Storage Types

AlloyECS supports different storage types optimized for different use cases:

| Type | Description | Best For |
|------|-------------|----------|
| `sparse` | Default, hash-map based | Most components |
| `dense` | *(Coming soon)* Array-based | Components on 50%+ of entities |
| `tag` | No data storage | Boolean flags |

```lua
-- Sparse (default)
local Position = world:component()
local Position = world:component({ storage = "sparse" })

-- Tag - no data, just presence
local Visible = world:component({ storage = "tag" })
```

:::note Dense Storage
Dense storage is planned for a future release. For now, use `sparse` (the default).
:::

## Tags

Tags are components without data. Use them to mark or categorize entities:

```lua
-- Create a tag (shorthand for storage = "tag")
local Player = world:tag()
local Enemy = world:tag()
local Dead = world:tag()

-- Add to entity
world:add(entity, Player)

-- Check presence
if world:has(entity, Player) then
    -- This is a player
end

-- Tags return nil from get()
local value = world:get(entity, Player) -- nil

-- Use has() instead
local isPlayer = world:has(entity, Player) -- true/false
```

## Setting Component Data

```lua
-- Set a component value
world:set(entity, Position, Vector3.new(0, 10, 0))
world:set(entity, Health, 100)

-- Setting adds the component if not present
-- Setting updates the value if already present
```

## Getting Component Data

```lua
local pos = world:get(entity, Position)

if pos then
    print("Position:", pos.X, pos.Y, pos.Z)
end
```

## Checking Components

```lua
-- Check single component
if world:has(entity, Position) then
    -- Entity has Position
end

-- Check multiple components
if world:has(entity, Position, Velocity) then
    -- Entity has both Position AND Velocity
end
```

## Removing Components

```lua
world:remove(entity, Velocity)
```

## Component Hooks

React to component changes with hooks:

```lua
-- When component is added
world:onAdd(Position, function(entityId, value)
    print("Entity", entityId, "gained Position:", value)
end)

-- When component is removed
world:onRemove(Health, function(entityId, oldValue)
    if oldValue <= 0 then
        print("Entity", entityId, "died!")
    end
end)

-- When component value changes
world:onChange(Position, function(entityId, oldPos, newPos)
    print("Entity", entityId, "moved from", oldPos, "to", newPos)
end)
```

### Unsubscribing

Hooks return an unsubscribe function:

```lua
local unsubscribe = world:onAdd(Position, function(entityId, value)
    -- ...
end)

-- Later, stop listening
unsubscribe()
```

## Best Practices

### 1. Keep Components Small

```lua
-- ✅ Good - small, focused components
local Position = world:component()  -- Vector3
local Velocity = world:component()  -- Vector3
local Health = world:component()    -- number

-- ❌ Avoid - large monolithic components
local PlayerData = world:component() -- { pos, vel, health, mana, inventory, ... }
```

### 2. Use Tags for Flags

```lua
-- ✅ Good - tags for boolean state
local Dead = world:tag()
local Stunned = world:tag()

-- ❌ Avoid - components with boolean values
local IsDead = world:component()
world:set(entity, IsDead, true)
```

### 3. Define Components Once

```lua
-- ✅ Good - define at module level
local Position = world:component()
local Velocity = world:component()

-- ❌ Avoid - creating in loops or functions
for i = 1, 100 do
    local Position = world:component() -- Creates 100 different components!
end
```
