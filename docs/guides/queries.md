---
sidebar_position: 2
---

# Queries

Queries are the primary way to find and iterate over entities with specific components. AlloyECS provides a powerful, cached query system.

## Basic Queries

Query for entities with specific components:

```lua
-- Single component
for entityId, position in world:query(Position) do
    print(entityId, position)
end

-- Multiple components
for entityId, pos, vel in world:query(Position, Velocity) do
    world:set(entityId, Position, pos + vel * deltaTime)
end

-- Three components
for entityId, pos, vel, health in world:query(Position, Velocity, Health) do
    -- ...
end
```

## Query Filters

Use filters to refine your queries:

### With Filter

Require components without retrieving their values:

```lua
-- Entities with Position AND Player tag, but only return Position
for entityId, pos in world:query(Position):with(Player):iter() do
    -- pos is returned
    -- Player is required but not returned (it's a tag anyway)
end
```

### Without Filter

Exclude entities with certain components:

```lua
-- Entities with Position but NOT Dead
for entityId, pos in world:query(Position):without(Dead):iter() do
    -- Only living entities
end
```

### Combining Filters

```lua
for entityId, pos, vel in world:query(Position, Velocity)
    :with(Player)
    :without(Dead, Stunned)
    :iter() 
do
    -- Players with Position and Velocity
    -- That are not Dead or Stunned
end
```

:::caution Remember iter()
When using `:with()` or `:without()`, you must call `:iter()` at the end!

```lua
-- ✅ Correct
for e, p in world:query(Position):with(Player):iter() do end

-- ❌ Wrong - missing iter()
for e, p in world:query(Position):with(Player) do end
```
:::

## Query Caching

Queries are automatically cached for performance. When you run the same query multiple times, AlloyECS reuses the cached results.

```lua
-- First call - builds and caches results
for entityId, pos in world:query(Position) do end

-- Subsequent calls - uses cache (very fast!)
for entityId, pos in world:query(Position) do end
for entityId, pos in world:query(Position) do end
```

The cache is automatically invalidated when:
- Entities are created or destroyed
- Components are added or removed

## Reactive Queries

With `trackChanges = true`, you can query for changes:

```lua
local world = AlloyECS.createWorld({ trackChanges = true })

-- Entities that gained Position this frame
for _, entityId in world:added(Position) do
    print("New position on:", entityId)
end

-- Entities that lost Position this frame
for _, entityId in world:removed(Position) do
    print("Position removed from:", entityId)
end

-- Entities whose Position changed this frame
for _, entityId in world:changed(Position) do
    print("Position changed on:", entityId)
end
```

:::warning Clear Changes
Call `world:clearChanges()` at the end of each frame, or use `world:step()` which does this automatically.
:::

## Query Performance Tips

### 1. Query Order Matters

Put the rarest component first for better performance:

```lua
-- ✅ Better - Boss is rare
for e, pos in world:query(Boss, Position) do end

-- ❌ Slower - Position is common
for e, pos in world:query(Position, Boss) do end
```

### 2. Use With for Tags

When you don't need the value, use `:with()`:

```lua
-- ✅ Better - Player value not unpacked
for e, pos in world:query(Position):with(Player):iter() do end

-- ❌ Slower - Player value unpacked but unused
for e, pos, _ in world:query(Position, Player) do end
```

### 3. Cache Query Components

Don't rebuild component lists each frame:

```lua
-- ✅ Good - components defined once
local Position, Velocity = world:component(), world:component()

RunService.Heartbeat:Connect(function(dt)
    for e, pos, vel in world:query(Position, Velocity) do
        world:set(e, Position, pos + vel * dt)
    end
end)
```

### 4. Avoid Modifying During Iteration

Use deferred operations when modifying entities during queries:

```lua
-- ✅ Safe - deferred destruction
for entityId, health in world:query(Health) do
    if health <= 0 then
        world:deferDestroy(entityId)
    end
end
world:flush()

-- ❌ Dangerous - modifying during iteration
for entityId, health in world:query(Health) do
    if health <= 0 then
        world:destroy(entityId) -- May cause issues!
    end
end
```
