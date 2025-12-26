---
sidebar_position: 5
---

# Prefabs

Prefabs are templates for creating entities with predefined components. They're perfect for spawning enemies, items, projectiles, and other game objects.

## Creating Prefabs

Use the builder pattern to define a prefab:

```lua
local enemyPrefab = world:prefab()
    :with(Health, 100)
    :with(Position, Vector3.zero)
    :with(Damage, 10)
    :with(Enemy)  -- Tag (no value needed)
    :build()
```

### Named Prefabs

Register prefabs by name for easy access:

```lua
world:prefab()
    :with(Health, 100)
    :with(Position, Vector3.zero)
    :with(Enemy)
    :build("BasicEnemy")

world:prefab()
    :with(Health, 500)
    :with(Position, Vector3.zero)
    :with(Damage, 50)
    :with(Enemy)
    :with(Boss)
    :build("BossEnemy")
```

## Spawning from Prefabs

### From Prefab Object

```lua
local enemy = world:spawn(enemyPrefab)
```

### From Name

```lua
local enemy = world:spawn("BasicEnemy")
local boss = world:spawn("BossEnemy")
```

## Customizing After Spawn

Prefabs create the entity with default values. Customize afterward:

```lua
local enemy = world:spawn("BasicEnemy")

-- Override position
world:set(enemy, Position, Vector3.new(10, 0, 20))

-- Add additional components
world:set(enemy, PatrolPath, { ... })
```

## Retrieving Prefabs

Get a registered prefab by name:

```lua
local prefab = world:prefab("BasicEnemy")
```

## Practical Examples

### Enemy Types

```lua
-- Components
local Health = world:component()
local Damage = world:component()
local Speed = world:component()
local Position = world:component()
local Enemy = world:tag()
local Flying = world:tag()
local Boss = world:tag()

-- Define enemy prefabs
world:prefab()
    :with(Health, 50)
    :with(Damage, 5)
    :with(Speed, 10)
    :with(Position, Vector3.zero)
    :with(Enemy)
    :build("Slime")

world:prefab()
    :with(Health, 30)
    :with(Damage, 10)
    :with(Speed, 20)
    :with(Position, Vector3.zero)
    :with(Enemy)
    :with(Flying)
    :build("Bat")

world:prefab()
    :with(Health, 1000)
    :with(Damage, 50)
    :with(Speed, 5)
    :with(Position, Vector3.zero)
    :with(Enemy)
    :with(Boss)
    :build("Dragon")

-- Spawn enemies
local function spawnEnemy(enemyType, position)
    local enemy = world:spawn(enemyType)
    world:set(enemy, Position, position)
    return enemy
end

spawnEnemy("Slime", Vector3.new(10, 0, 10))
spawnEnemy("Bat", Vector3.new(0, 10, 0))
spawnEnemy("Dragon", Vector3.new(100, 0, 100))
```

### Item System

```lua
local Name = world:component()
local Value = world:component()
local Stackable = world:tag()
local Consumable = world:tag()
local Equipment = world:tag()

-- Consumables
world:prefab()
    :with(Name, "Health Potion")
    :with(Value, 50)
    :with(Stackable)
    :with(Consumable)
    :build("HealthPotion")

world:prefab()
    :with(Name, "Mana Potion")
    :with(Value, 30)
    :with(Stackable)
    :with(Consumable)
    :build("ManaPotion")

-- Equipment
world:prefab()
    :with(Name, "Iron Sword")
    :with(Damage, 15)
    :with(Equipment)
    :build("IronSword")
```

### Projectiles

```lua
local Velocity = world:component()
local Lifetime = world:component()
local Projectile = world:tag()

world:prefab()
    :with(Position, Vector3.zero)
    :with(Velocity, Vector3.zero)
    :with(Damage, 10)
    :with(Lifetime, 5)
    :with(Projectile)
    :build("Arrow")

world:prefab()
    :with(Position, Vector3.zero)
    :with(Velocity, Vector3.zero)
    :with(Damage, 30)
    :with(Lifetime, 3)
    :with(Projectile)
    :build("Fireball")

-- Spawn projectile with direction
local function fireProjectile(prefabName, origin, direction, speed)
    local proj = world:spawn(prefabName)
    world:set(proj, Position, origin)
    world:set(proj, Velocity, direction.Unit * speed)
    return proj
end

fireProjectile("Arrow", playerPos, aimDirection, 100)
```

## Best Practices

### 1. Use Descriptive Names

```lua
-- ✅ Good
world:prefab():with(...):build("BasicEnemy")
world:prefab():with(...):build("FireElemental")

-- ❌ Avoid
world:prefab():with(...):build("e1")
world:prefab():with(...):build("enemy")
```

### 2. Create Prefabs at Startup

```lua
-- ✅ Good - create once at startup
local function initPrefabs(world)
    world:prefab():with(...):build("Enemy")
    world:prefab():with(...):build("Item")
end

-- ❌ Avoid - creating during gameplay
local function spawnEnemy()
    world:prefab():with(...):build("Enemy")  -- Recreates each time!
    return world:spawn("Enemy")
end
```

### 3. Keep Prefabs Generic

Use prefabs for common base values, customize specific instances:

```lua
-- ✅ Good - generic prefab, specific customization
local enemy = world:spawn("Enemy")
world:set(enemy, Position, spawnPoint)
world:set(enemy, PatrolPath, specificPath)

-- ❌ Avoid - overly specific prefabs
world:prefab()
    :with(Position, Vector3.new(10, 0, 20))  -- Too specific!
    :build("EnemyAtPosition10_0_20")
```
