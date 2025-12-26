---
sidebar_position: 3
---

# Systems

Systems contain the logic that operates on entities. AlloyECS provides a scheduler for organizing and running systems.

## Creating Systems

Add systems with `world:addSystem()`:

```lua
world:addSystem(
    "Movement",           -- Unique name
    "Update",             -- Phase
    {                     -- Dependencies
        reads = { Position, Velocity },
        writes = { Position }
    },
    function(deltaTime)   -- Callback
        for entityId, pos, vel in world:query(Position, Velocity) do
            world:set(entityId, Position, pos + vel * deltaTime)
        end
    end
)
```

## System Phases

Systems run in phases, executed in order:

| Phase | Order | Typical Use |
|-------|-------|-------------|
| `PreUpdate` | 1st | Input processing, physics preparation |
| `Update` | 2nd | Main game logic |
| `PostUpdate` | 3rd | Cleanup, collision response |
| `PreRender` | 4th | Visual preparation |
| `Render` | 5th | Rendering, UI updates |

```lua
-- Input runs first
world:addSystem("Input", "PreUpdate", {}, function(dt)
    -- Process player input
end)

-- Movement runs during update
world:addSystem("Movement", "Update", {
    writes = { Position }
}, function(dt)
    -- Move entities
end)

-- Cleanup runs after
world:addSystem("DeathCleanup", "PostUpdate", {}, function(dt)
    for entityId in world:query(Dead) do
        world:destroy(entityId)
    end
end)
```

## Running Systems

### Run All Systems

```lua
world:runSystems(deltaTime)
```

### Run Specific Phase

```lua
world:runPhase("Update", deltaTime)
```

### Using Step (Recommended)

`step()` handles everything:

```lua
RunService.Heartbeat:Connect(function(dt)
    world:step(dt)  -- Flushes commands, runs systems, clears changes
end)
```

## Managing Systems

### Enable/Disable

```lua
-- Disable a system (doesn't remove it)
world:disableSystem("AI")

-- Re-enable it
world:enableSystem("AI")
```

### Remove

```lua
world:removeSystem("Movement")
```

## System Dependencies

Declare what components a system reads and writes:

```lua
world:addSystem("Movement", "Update", {
    reads = { Position, Velocity },
    writes = { Position }
}, function(dt)
    -- ...
end)
```

This helps with:
- Documentation
- Future parallelization
- Debugging

## Practical Example

Here's a complete game loop with multiple systems:

```lua
local AlloyECS = require(path.to.AlloyECS)
local RunService = game:GetService("RunService")

-- Create world
local world = AlloyECS.createWorld({ trackChanges = true })

-- Components
local Position = world:component()
local Velocity = world:component()
local Health = world:component()
local Dead = world:tag()
local Player = world:tag()

-- Input System
world:addSystem("Input", "PreUpdate", {
    writes = { Velocity }
}, function(dt)
    for entityId, vel in world:query(Velocity):with(Player):iter() do
        -- Read input and update velocity
        local input = Vector3.new(0, 0, 0)
        -- ... get input ...
        world:set(entityId, Velocity, input * 50)
    end
end)

-- Movement System
world:addSystem("Movement", "Update", {
    reads = { Velocity },
    writes = { Position }
}, function(dt)
    for entityId, pos, vel in world:query(Position, Velocity) do
        world:set(entityId, Position, pos + vel * dt)
    end
end)

-- Death System
world:addSystem("Death", "Update", {
    reads = { Health },
    writes = { Dead }
}, function(dt)
    for entityId, health in world:query(Health):without(Dead):iter() do
        if health <= 0 then
            world:add(entityId, Dead)
        end
    end
end)

-- Cleanup System
world:addSystem("Cleanup", "PostUpdate", {
    reads = { Dead }
}, function(dt)
    for entityId in world:query(Dead) do
        world:deferDestroy(entityId)
    end
end)

-- Game Loop
RunService.Heartbeat:Connect(function(dt)
    world:step(dt)
end)
```

## Tips

### 1. Keep Systems Focused

Each system should do one thing well:

```lua
-- ✅ Good - focused systems
world:addSystem("Movement", ...)
world:addSystem("Collision", ...)
world:addSystem("Damage", ...)

-- ❌ Avoid - monolithic system
world:addSystem("Everything", ..., function(dt)
    -- 500 lines of code
end)
```

### 2. Use Phases Correctly

Don't put everything in "Update":

```lua
-- ✅ Good - proper phase usage
world:addSystem("Input", "PreUpdate", ...)
world:addSystem("Physics", "Update", ...)
world:addSystem("Render", "Render", ...)
```

### 3. Disable When Not Needed

```lua
-- Disable AI during cutscenes
local function startCutscene()
    world:disableSystem("AI")
    world:disableSystem("PlayerInput")
end

local function endCutscene()
    world:enableSystem("AI")
    world:enableSystem("PlayerInput")
end
```
