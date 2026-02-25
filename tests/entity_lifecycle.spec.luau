local AlloyECS = require("../src/init")

local testing = zune.testing
local describe = testing.describe
local it = testing.test
local expect = testing.expect

describe("entity lifecycle", function()
	it("creates and destroys entities", function()
		local world = AlloyECS.world()
		local entity = world:entity()

		expect(world:exists(entity)).toBe(true)

		world:destroy(entity)

		expect(world:exists(entity)).toBe(false)
	end)

	it("reuses destroyed entity ids", function()
		local world = AlloyECS.world()
		local first = world:entity()

		world:destroy(first)

		local second = world:entity()
		expect(second).toBe(first)
	end)
end)
