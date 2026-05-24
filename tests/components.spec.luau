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

	it("supports defaulted component creation", function()
		local world = AlloyECS.world()
		local Position = world:component({ x = 0, y = 0 })
		local entity = world:entity()

		world:assign(entity, Position, { x = 12, y = 30 })

		local value = world:read(entity, Position)
		expect(value).toBeDefined()
		expect(value.x).toBe(12)
		expect(value.y).toBe(30)
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

	it("attach assigns defaults for defaulted data components", function()
		local world = AlloyECS.world()
		local Position = world:component({ x = 0, y = 0 })
		local entity = world:entity()

		world:attach(entity, Position)

		local value = world:read(entity, Position)
		expect(value).toBeDefined()
		expect(value.x).toBe(0)
		expect(value.y).toBe(0)
	end)

	it("attach clones table defaults per entity", function()
		local world = AlloyECS.world()
		local Position = world:component({ x = 0, y = 0 })
		local first = world:entity()
		local second = world:entity()

		world:attach(first, Position)
		world:attach(second, Position)

		local firstValue = world:read(first, Position)
		local secondValue = world:read(second, Position)
		firstValue.x = 100

		expect(secondValue.x).toBe(0)
		expect(secondValue.y).toBe(0)
	end)

	it("attach errors for non-default data components", function()
		local world = AlloyECS.world()
		local Position = world:component()
		local entity = world:entity()

		local ok = pcall(function()
			world:attach(entity, Position)
		end)

		expect(ok).toBe(false)
	end)

	it("mutation APIs assert on destroyed entities", function()
		local world = AlloyECS.world()
		local Data = world:component()
		local Tag = world:tag()
		local entity = world:entity()

		world:destroy(entity)

		local okAssign = pcall(function()
			world:assign(entity, Data, 10)
		end)

		local okAttach = pcall(function()
			world:attach(entity, Tag)
		end)

		local okRemove = pcall(function()
			world:remove(entity, Data)
		end)

		local okUpdate = pcall(function()
			world:update(entity, Data, function(current)
				return current
			end)
		end)

		expect(okAssign).toBe(false)
		expect(okAttach).toBe(false)
		expect(okRemove).toBe(false)
		expect(okUpdate).toBe(false)
	end)

	it("allows components to contain data akin to entites", function()
		local world = AlloyECS.world()

		local humanoid = world:component()
		local characterType = world:tag()

		world:attach(humanoid, characterType)

		expect(world:has(humanoid, characterType)).toBe(true)

		local found = 0

		world:view(characterType):forEach(function(entity: number, tag: true)
			found += 1
		end)

		expect(found).toBe(1)
	end)
end)
