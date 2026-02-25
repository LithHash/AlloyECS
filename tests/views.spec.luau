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
end)
