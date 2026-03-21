local AlloyECS = require("../src/init")

local testing = zune.testing
local describe = testing.describe
local it = testing.test
local expect = testing.expect

describe("signals", function()
	it("fires onAssign only after flush", function()
		local world = AlloyECS.world()
		local Position = world:component()
		local entity = world:entity()
		local calls = {}

		world:onAssign(Position, function(eventEntity, value)
			calls[#calls + 1] = { entity = eventEntity, value = value }
		end)

		world:assign(entity, Position, 12)
		expect(#calls).toBe(0)

		world:flush()

		expect(#calls).toBe(1)
		expect(calls[1].entity).toBe(entity)
		expect(calls[1].value).toBe(12)
	end)

	it("stops firing callbacks after unsubscribe", function()
		local world = AlloyECS.world()
		local Score = world:component()
		local entity = world:entity()
		local count = 0

		local disconnect = world:onAssign(Score, function()
			count += 1
		end)

		world:assign(entity, Score, 1)
		world:flush()
		expect(count).toBe(1)

		disconnect()

		world:assign(entity, Score, 2)
		world:flush()
		expect(count).toBe(1)
	end)

	it("fires onRemove and onDestroy only after flush", function()
		local world = AlloyECS.world()
		local Tag = world:tag()
		local entity = world:entity()
		local removed = 0
		local destroyed = 0

		world:onRemove(Tag, function(eventEntity)
			removed += 1
			expect(eventEntity).toBe(entity)
		end)

		world:onDestroy(function(eventEntity)
			destroyed += 1
			expect(eventEntity).toBe(entity)
		end)

		world:attach(entity, Tag)
		world:flush()

		world:destroy(entity)
		expect(removed).toBe(0)
		expect(destroyed).toBe(0)

		world:flush()
		expect(removed).toBe(1)
		expect(destroyed).toBe(1)
	end)

	it("keeps queued signal dispatch in FIFO order", function()
		local world = AlloyECS.world()
		local Value = world:component()
		local entity = world:entity()
		local order = {}

		world:onAssign(Value, function(_, value)
			order[#order + 1] = "assign:" .. tostring(value)
		end)

		world:onRemove(Value, function()
			order[#order + 1] = "remove"
		end)

		world:onDestroy(function()
			order[#order + 1] = "destroy"
		end)

		world:assign(entity, Value, 10)
		world:remove(entity, Value)
		world:assign(entity, Value, 20)
		world:destroy(entity)
		world:flush()

		expect(#order).toBe(5)
		expect(order[1]).toBe("assign:10")
		expect(order[2]).toBe("remove")
		expect(order[3]).toBe("assign:20")
		expect(order[4]).toBe("remove")
		expect(order[5]).toBe("destroy")
	end)
end)
