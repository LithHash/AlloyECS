---
sidebar_position: 4
---

# Relationships

Relationships connect entities together, enabling hierarchies, references, and graph structures.

## Creating Relationships

First, create a relation type (it's just a component):

```lua
local ChildOf = world:component()
local Owns = world:component()
local Likes = world:component()
```

Then use `world:relate()` to connect entities:

```lua
-- Create a parent-child relationship
local parent = world:entity()
local child = world:entity()

world:relate(child, ChildOf, parent)
```

## Relationship Data

Relationships can optionally store data:

```lua
local Likes = world:component()

-- Relationship without data
world:relate(player, Likes, pizza)

-- Relationship with data
world:relate(player, Likes, pizza, { amount = 100 })
```

## Querying Relationships

### Check If Relationship Exists

```lua
if world:hasRelation(child, ChildOf, parent) then
    print("Is a child of parent")
end
```

### Get Relationship Data

```lua
local likeData = world:getRelation(player, Likes, item)
if likeData then
    print("Like amount:", likeData.amount)
end
```

### Get All Targets

Find all entities that a source relates to:

```lua
-- Get everything this player likes
local likedItems = world:getTargets(player, Likes)

for _, item in likedItems do
    print("Player likes:", item)
end
```

### Get All Sources

Find all entities that relate to a target:

```lua
-- Get all children of this parent
local children = world:getSources(ChildOf, parent)

for _, child in children do
    print("Child:", child)
end
```

## Removing Relationships

```lua
world:unrelate(child, ChildOf, parent)
```

:::note Automatic Cleanup
When an entity is destroyed, all its relationships (both as source and target) are automatically removed.
:::

## Common Patterns

### Parent-Child Hierarchy

```lua
local ChildOf = world:component()

local root = world:entity()
local branch = world:entity()
local leaf = world:entity()

world:relate(branch, ChildOf, root)
world:relate(leaf, ChildOf, branch)

-- Get children
local function getChildren(parent)
    return world:getSources(ChildOf, parent)
end

-- Get parent
local function getParent(child)
    local parents = world:getTargets(child, ChildOf)
    return parents[1]  -- Assuming single parent
end
```

### Inventory System

```lua
local InInventory = world:component()

local player = world:entity()
local sword = world:entity()
local potion = world:entity()

-- Add items to inventory
world:relate(sword, InInventory, player, { slot = 1 })
world:relate(potion, InInventory, player, { slot = 2 })

-- Get all items in player's inventory
local items = world:getSources(InInventory, player)

-- Check what slot an item is in
local slotData = world:getRelation(sword, InInventory, player)
print("Sword is in slot:", slotData.slot)
```

### Targeting System

```lua
local Targeting = world:component()

-- Entity A targets Entity B
world:relate(entityA, Targeting, entityB)

-- Get what this entity is targeting
local function getTarget(entity)
    local targets = world:getTargets(entity, Targeting)
    return targets[1]
end

-- Get all entities targeting this entity
local function getTargetedBy(entity)
    return world:getSources(Targeting, entity)
end
```

### Team/Faction System

```lua
local MemberOf = world:component()

local redTeam = world:entity()
local blueTeam = world:entity()

-- Assign players to teams
world:relate(player1, MemberOf, redTeam)
world:relate(player2, MemberOf, blueTeam)

-- Get all members of a team
local function getTeamMembers(team)
    return world:getSources(MemberOf, team)
end

-- Check if two entities are on the same team
local function isSameTeam(entityA, entityB)
    local teamA = world:getTargets(entityA, MemberOf)
    local teamB = world:getTargets(entityB, MemberOf)
    return teamA[1] == teamB[1]
end
```

## Relationships vs Components

When to use each:

| Use Case | Relationships | Components |
|----------|--------------|------------|
| Connect two entities | ✅ | ❌ |
| Store entity reference | ✅ | Can work |
| One-to-many | ✅ | ❌ |
| Many-to-many | ✅ | ❌ |
| Simple data on entity | ❌ | ✅ |
| Queryable in loops | ❌ | ✅ |

```lua
-- ✅ Use relationship - connecting entities
world:relate(child, ChildOf, parent)

-- ✅ Use component - simple data
world:set(entity, Health, 100)

-- 🤔 Could use either - entity reference
world:relate(projectile, FiredBy, player)  -- Relationship
world:set(projectile, Owner, player)       -- Component (simpler)
```
