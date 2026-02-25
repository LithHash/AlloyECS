local AlloyECS = require("../src/init")

local testing = zune.testing
local describe = testing.describe
local it = testing.test
local expect = testing.expect

describe("components", function()
	it("assigns and reads component data", function()
		local world = AlloyECS.world()
		local Position = world:component()
		local entity = world:entity()

		world:assign(entity, Position, { x = 5, y = 8 })

		local value = world:read(entity, Position)
		expect(value).toBeDefined()
		expect(value.x).toBe(5)
		expect(value.y).toBe(8)
	end)

	it("returns nil when reading a missing component", function()
		local world = AlloyECS.world()
		local Health = world:component()
		local entity = world:entity()

		expect(world:read(entity, Health)).toBeNil()
	end)

	it("updates an assigned component value", function()
		local world = AlloyECS.world()
		local Score = world:component()
		local entity = world:entity()

		world:assign(entity, Score, 10)
		world:update(entity, Score, function(current)
			return current + 7
		end)

		expect(world:read(entity, Score)).toBe(17)
	end)

	it("removes components and clears membership", function()
		local world = AlloyECS.world()
		local Armor = world:component()
		local entity = world:entity()

		world:assign(entity, Armor, 25)
		world:remove(entity, Armor)

		expect(world:read(entity, Armor)).toBeNil()
		expect(world:has(entity, Armor)).toBe(false)
	end)

	it("attach stores truthy tag-like values", function()
		local world = AlloyECS.world()
		local Tag = world:tag()
		local entity = world:entity()

		world:attach(entity, Tag)

		expect(world:read(entity, Tag)).toBe(true)
		expect(world:has(entity, Tag)).toBe(true)
	end)

	it("attach on data components is a no-op", function()
		local world = AlloyECS.world()
		local Data = world:component()
		local entity = world:entity()

		world:attach(entity, Data :: any)

		expect(world:read(entity, Data)).toBeNil()
		expect(world:has(entity, Data)).toBe(false)
	end)

	it("assign and update on tag components are no-ops", function()
		local world = AlloyECS.world()
		local Tag = world:tag()
		local entity = world:entity()
		local tagAsAny = Tag :: any

		world:assign(entity, tagAsAny, 123)
		expect(world:read(entity, Tag)).toBeNil()

		world:attach(entity, Tag)
		world:update(entity, tagAsAny, function()
			return false
		end)

		expect(world:read(entity, Tag)).toBe(true)
	end)
end)
