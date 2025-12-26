# AlloyECS

A fast, feature-rich Entity Component System for Roblox.

## Features

- ⚡ High performance with bitset queries and caching
- 🏷️ Tag components for zero-cost markers
- 🔗 Entity relationships
- 📦 Prefab system for templates
- 🎯 System scheduler with phases
- 🔄 Change tracking (added/removed/changed)
- 💾 Serialization support

## Installation

### Manual

Download the latest release and add the `src` folder to your project.

## Quick Start

```lua
local AlloyECS = require(path.to.AlloyECS)

local world = AlloyECS.createWorld()

-- Define components
local Position = world:component()
local Velocity = world:component()

-- Create entity
local entity = world:entity()
world:set(entity, Position, Vector3.zero)
world:set(entity, Velocity, Vector3.new(1, 0, 0))

-- Query and update
for id, pos, vel in world:query(Position, Velocity) do
    world:set(id, Position, pos + vel)
end
```

## License

MIT
