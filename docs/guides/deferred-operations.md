---
sidebar_position: 6
---

# Deferred Operations

Deferred operations let you safely queue changes during iteration. This is essential when you need to modify entities while looping through query results.

## The Problem

Modifying entities during iteration can cause issues:

```lua
-- ❌ Dangerous - modifying during iteration
for entityId, health in world:query(Health) do
    if health <= 0 then
        world:destroy(entityId)  -- Might break iteration!
    end
end
```

## The Solution

Queue operations and execute them after iteration:

```lua
-- ✅ Safe - deferred operations
for entityId, health in world:query(Health) do
    if health <= 0 then
        world:deferDestroy(entityId)
    end
end
world:flush()  -- Execute all queued operations
```

## Deferred Methods

| Method | Description |
|--------|-------------|
| `deferSpawn(callback?)` | Queue entity creation |
| `deferDestroy(entityId)` | Queue entity destruction |
| `deferAdd(entityId, componentId)` | Queue adding a tag |
| `deferSet(entityId, componentId, value)` | Queue setting a component |
| `deferRemove(entityId, componentId)` | Queue removing a component |
| `flush()` | Execute all queued operations |

## Examples

### Deferred Spawn

```lua
-- Spawn with callback to configure the new entity
world:deferSpawn(function(entityId)
    world:deferSet(entityId, Position, Vector3.zero)
    world:deferSet(entityId, Health, 100)
    world:deferAdd(entityId, Enemy)
end)
world:flush()
```

### Deferred Destroy

```lua
for entityId, health in world:query(Health) do
    if health <= 0 then
        world:deferDestroy(entityId)
    end
end
world:flush()
```

### Deferred Component Changes

```lua
for entityId, pos, vel in world:query(Position, Velocity) do
    -- Queue position update
    world:deferSet(entityId, Position, pos + vel * deltaTime)
    
    -- Queue removing velocity if stopped
    if vel.Magnitude < 0.1 then
        world:deferRemove(entityId, Velocity)
    end
end
world:flush()
```

## Chaining

Deferred methods return the world for chaining:

```lua
world
    :deferSpawn(function(e)
        world:deferSet(e, Position, Vector3.zero)
    end)
    :deferDestroy(oldEntity)
    :deferSet(player, Health, 100)

world:flush()
```

## Checking Pending Commands

```lua
if world:hasPendingCommands() then
    world:flush()
end
```

## Deferred Mode

Enable deferred mode to use regular methods that auto-queue:

```lua
world:defer()  -- Enable deferred mode

-- These are now automatically queued
world:set(entity, Health, 50)
world:add(entity, Poisoned)

world:flush()  -- Execute and disable deferred mode
```

## Automatic Flushing

`world:step()` automatically flushes pending commands:

```lua
RunService.Heartbeat:Connect(function(dt)
    -- Systems can use deferred operations freely
    world:step(dt)  -- Flushes at the start
end)
```

## Practical Example

A damage system that safely handles death:

```lua
local Health = world:component()
local Damage = world:component()
local Dead = world:tag()

world:addSystem("ApplyDamage", "Update", {
    reads = { Damage, Health },
    writes = { Health, Dead }
}, function(dt)
    -- Process damage
    for entityId, damage, health in world:query(Damage, Health) do
        local newHealth = health - damage
        world:deferSet(entityId, Health, newHealth)
        world:deferRemove(entityId, Damage)
        
        if newHealth <= 0 then
            world:deferAdd(entityId, Dead)
        end
    end
    -- Note: flush happens automatically in step()
end)

world:addSystem("Cleanup", "PostUpdate", {
    reads = { Dead }
}, function(dt)
    for entityId in world:query(Dead) do
        world:deferDestroy(entityId)
    end
end)
```

## Best Practices

### 1. Prefer Deferred During Iteration

```lua
-- ✅ Good
for entityId, health in world:query(Health) do
    if health <= 0 then
        world:deferDestroy(entityId)
    end
end

-- ❌ Risky
for entityId, health in world:query(Health) do
    if health <= 0 then
        world:destroy(entityId)
    end
end
```

### 2. Batch Related Operations

```lua
-- ✅ Good - one flush for multiple operations
for entityId in world:query(Enemy) do
    world:deferSet(entityId, Health, 100)
    world:deferRemove(entityId, Damaged)
end
world:flush()

-- ❌ Inefficient - flush after each
for entityId in world:query(Enemy) do
    world:deferSet(entityId, Health, 100)
    world:flush()  -- Don't do this!
end
```

### 3. Let step() Handle Flushing

```lua
-- ✅ Good - step handles it
world:addSystem("MySystem", "Update", {}, function(dt)
    world:deferSet(entity, Health, 100)
    -- No need to flush - step() does it
end)

-- Works because step() flushes automatically
RunService.Heartbeat:Connect(function(dt)
    world:step(dt)
end)
```
