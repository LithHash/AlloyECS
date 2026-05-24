local AlloyECS = require("../src/init")

local testing = zune.testing
local describe = testing.describe
local it = testing.test
local expect = testing.expect

describe("views", function()
	it("iterates single-component views", function()
		local world = AlloyECS.world()
		local Position = world:component()
		local first = world:entity()
		local second = world:entity()

		world:assign(first, Position, 11)
		world:assign(second, Position, 22)

		local seen = {}

		world:view(Position):forEach(function(entity, value)
			seen[entity] = value
		end)

		expect(seen[first]).toBe(11)
		expect(seen[second]).toBe(22)
	end)

	it("intersects entities for multi-component views", function()
		local world = AlloyECS.world()
		local Position = world:component()
		local Velocity = world:component()
		local first = world:entity()
		local second = world:entity()

		world:assign(first, Position, 10)
		world:assign(first, Velocity, 2)
		world:assign(second, Position, 20)

		local rows = {}

		world:view(Position, Velocity):forEach(function(entity, position, velocity)
			rows[#rows + 1] = { entity = entity, position = position, velocity = velocity }
		end)

		expect(#rows).toBe(1)
		expect(rows[1].entity).toBe(first)
		expect(rows[1].position).toBe(10)
		expect(rows[1].velocity).toBe(2)
	end)

	it("filters excluded components from views", function()
		local world = AlloyECS.world()
		local Active = world:tag()
		local Hidden = world:tag()
		local first = world:entity()
		local second = world:entity()

		world:attach(first, Active)
		world:attach(second, Active)
		world:attach(second, Hidden)

		local entities = world:view(Active):exclude(Hidden):entities()

		expect(#entities).toBe(1)
		expect(entities[1]).toBe(first)
	end)

	it("passes true values for tag-only views", function()
		local world = AlloyECS.world()
		local Enemy = world:tag()
		local entity = world:entity()
		local seenFlag = false

		world:attach(entity, Enemy)

		world:view(Enemy):forEach(function(_, flag)
			seenFlag = flag
		end)

		expect(seenFlag).toBe(true)
	end)

	it("keeps count/entities/empty consistent", function()
		local world = AlloyECS.world()
		local Position = world:component()
		local entity = world:entity()
		local view = world:view(Position)

		expect(view:empty()).toBe(true)
		expect(view:count()).toBe(0)
		expect(#view:entities()).toBe(0)

		world:assign(entity, Position, 99)

		expect(view:empty()).toBe(false)
		expect(view:count()).toBe(1)

		local entities = view:entities()
		expect(#entities).toBe(1)
		expect(entities[1]).toBe(entity)
	end)

	it("exclude returns a derived immutable view", function()
		local world = AlloyECS.world()
		local Active = world:tag()
		local Hidden = world:tag()
		local first = world:entity()
		local second = world:entity()

		world:attach(first, Active)
		world:attach(second, Active)
		world:attach(second, Hidden)

		local baseView = world:view(Active)
		local filtered = baseView:exclude(Hidden)

		expect(baseView:count()).toBe(2)
		expect(filtered:count()).toBe(1)
	end)

	it("can cancel forEach mid iteration", function()
		local world = AlloyECS.world()
		local Position = world:component()
		local first = world:entity()
		local second = world:entity()
		local third = world:entity()
		local view = world:view(Position)
		local seen = 0

		world:assign(first, Position, 10)
		world:assign(second, Position, 20)
		world:assign(third, Position, 30)

		view:forEach(function()
			seen += 1
			view:cancel()
		end)

		expect(seen).toBe(1)
	end)

	it("filters by exact component values with whichIs", function()
		local world = AlloyECS.world()
		local Weapon = world:component()
		local Health = world:component()
		local first = world:entity()
		local second = world:entity()
		local third = world:entity()

		world:assign(first, Weapon, "Sword")
		world:assign(first, Health, 100)
		world:assign(second, Weapon, "Sword")
		world:assign(second, Health, 50)
		world:assign(third, Weapon, "Bow")
		world:assign(third, Health, 100)

		local filtered = world:view(Weapon, Health):whichIs("Sword", 100)
		local entities = filtered:entities()
		local rows = {}

		filtered:forEach(function(id, weapon, health)
			rows[#rows + 1] = { id = id, weapon = weapon, health = health }
		end)

		expect(filtered:count()).toBe(1)
		expect(#entities).toBe(1)
		expect(entities[1]).toBe(first)
		expect(#rows).toBe(1)
		expect(rows[1].id).toBe(first)
		expect(rows[1].weapon).toBe("Sword")
		expect(rows[1].health).toBe(100)
	end)

	it("composes whichIs with exclude", function()
		local world = AlloyECS.world()
		local Weapon = world:component()
		local Health = world:component()
		local Hidden = world:tag()
		local first = world:entity()
		local second = world:entity()

		world:assign(first, Weapon, "Sword")
		world:assign(first, Health, 100)
		world:assign(second, Weapon, "Sword")
		world:assign(second, Health, 100)
		world:attach(second, Hidden)

		local filtered = world:view(Weapon, Health):whichIs("Sword", 100):exclude(Hidden)
		local entities = filtered:entities()

		expect(filtered:count()).toBe(1)
		expect(#entities).toBe(1)
		expect(entities[1]).toBe(first)
	end)

	it("whichIs compares table values structurally", function()
		local world = AlloyECS.world()
		local Position = world:component()
		local first = world:entity()
		local second = world:entity()
		local third = world:entity()

		world:assign(first, Position, { x = 0, y = 0 })
		world:assign(second, Position, { x = 0, y = 0, z = 1 })
		world:assign(third, Position, { x = 0, y = 0 })

		local entities = world:view(Position):whichIs({ x = 0, y = 0 }):entities()

		expect(#entities).toBe(2)
		expect(entities[1]).toBe(first)
		expect(entities[2]).toBe(third)
	end)

	it("whichIs compares nested table values structurally", function()
		local world = AlloyECS.world()
		local State = world:component()
		local first = world:entity()
		local second = world:entity()

		world:assign(first, State, {
			mode = "Idle",
			stats = {
				health = 100,
				armor = 25,
			},
		})

		world:assign(second, State, {
			mode = "Idle",
			stats = {
				health = 100,
				armor = 0,
			},
		})

		local entities = world:view(State):whichIs({
			mode = "Idle",
			stats = {
				health = 100,
				armor = 25,
			},
		}):entities()

		expect(#entities).toBe(1)
		expect(entities[1]).toBe(first)
	end)

	it("entities returns a snapshot", function()
		local world = AlloyECS.world()
		local Active = world:tag()
		local first = world:entity()
		local second = world:entity()

		world:attach(first, Active)
		world:attach(second, Active)

		local view = world:view(Active)
		local firstSnapshot = view:entities()
		firstSnapshot[1] = 999999

		local secondSnapshot = view:entities()
		expect(secondSnapshot[1]).toBe(first)
		expect(secondSnapshot[2]).toBe(second)
	end)
end)
