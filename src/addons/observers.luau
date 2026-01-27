--!strict
type ECS = any
type EntityId = number
type ComponentId = number
type Connection = {
	disconnect: () -> ()
}

type EventCallback = (...any) -> ()

export type ObserverEvent =
	"EntityCreated" |
	"EntityDestroyed" |
	"ComponentAdded" |
	"ComponentChanged" |
	"ComponentRemoved"

local listeners: {[ObserverEvent]: {EventCallback}} = {
	EntityCreated = {},
	EntityDestroyed = {},
	ComponentAdded = {},
	ComponentChanged = {},
	ComponentRemoved = {},
}

local function fireEvent(eventName: ObserverEvent, ...: any)
	local eventListeners = listeners[eventName]
	if not eventListeners then return end

	for _, callback in eventListeners do
		task.spawn(callback, ...)
	end
end

local function createConnection(eventName: ObserverEvent, callback: EventCallback): Connection
	return {
		disconnect = function()
			local eventListeners = listeners[eventName]
			local index = table.find(eventListeners, callback)
			if index then
				table.remove(eventListeners, index)
			end
		end
	}
end

local function wrapEcs(ecs: ECS)
	local originalEcs = ecs

	local proxy = {}

	setmetatable(proxy, {
		__index = function(_, key)
			if key == "entity" then
				return function(): EntityId
					local entityId = originalEcs.entity()
					fireEvent("EntityCreated", entityId)
					return entityId
				end
			end

			if key == "destroy" then
				return function(entityId: EntityId)
					local state = originalEcs._internal()
					local entity = state.entityCache[entityId]

					if entity then
						local componentIds = {}
						for componentId in entity.components do
							table.insert(componentIds, componentId)
						end

						originalEcs.destroy(entityId)
						fireEvent("EntityDestroyed", entityId, componentIds)
					else
						originalEcs.destroy(entityId)
					end
				end:: any
			end

			if key == "set" then
				return function(entityId: EntityId, componentId: ComponentId, value: any)
					local hadComponent = originalEcs.has(entityId, componentId)
					local oldValue = hadComponent and originalEcs.get(entityId, componentId) or nil

					originalEcs.set(entityId, componentId, value)

					if hadComponent then
						fireEvent("ComponentChanged", entityId, componentId, value, oldValue)
					else
						fireEvent("ComponentAdded", entityId, componentId, value)
					end
				end:: any
			end

			if key == "remove" then
				return function(entityId: EntityId, componentId: ComponentId)
					if originalEcs.has(entityId, componentId) then
						local oldValue = originalEcs.get(entityId, componentId)
						originalEcs.remove(entityId, componentId)
						fireEvent("ComponentRemoved", entityId, componentId, oldValue)
					else
						originalEcs.remove(entityId, componentId)
					end
				end:: any
			end

			return originalEcs[key]
		end
	})

	return proxy
end

local function onEntityCreated(callback: (EntityId) -> ()): Connection
	table.insert(listeners.EntityCreated, callback)
	return createConnection("EntityCreated", callback)
end

local function onEntityDestroyed(callback: (EntityId, {ComponentId}) -> ()): Connection
	table.insert(listeners.EntityDestroyed, callback)
	return createConnection("EntityDestroyed", callback)
end

local function onComponentAdded(
	callback: (EntityId, ComponentId, any) -> (),
	componentId: ComponentId?
): Connection
	local wrappedCallback = callback

	if componentId then
		wrappedCallback = function(entityId: EntityId, compId: ComponentId, value: any)
			if compId == componentId then
				callback(entityId, compId, value)
			end
		end
	end

	table.insert(listeners.ComponentAdded, wrappedCallback)
	return createConnection("ComponentAdded", wrappedCallback)
end

local function onComponentChanged(
	callback: (EntityId, ComponentId, any, any) -> (),
	componentId: ComponentId?
): Connection
	local wrappedCallback = callback

	if componentId then
		wrappedCallback = function(entityId: EntityId, compId: ComponentId, newValue: any, oldValue: any)
			if compId == componentId then
				callback(entityId, compId, newValue, oldValue)
			end
		end
	end

	table.insert(listeners.ComponentChanged, wrappedCallback)
	return createConnection("ComponentChanged", wrappedCallback)
end

local function onComponentRemoved(
	callback: (EntityId, ComponentId, any) -> (),
	componentId: ComponentId?
): Connection
	local wrappedCallback = callback

	if componentId then
		wrappedCallback = function(entityId: EntityId, compId: ComponentId, oldValue: any)
			if compId == componentId then
				callback(entityId, compId, oldValue)
			end
		end
	end

	table.insert(listeners.ComponentRemoved, wrappedCallback)
	return createConnection("ComponentRemoved", wrappedCallback)
end

local function watchEntity(
	entityId: EntityId,
	callback: (event: string, ...any) -> ()
): Connection
	local connections = {}

	table.insert(connections, onComponentAdded(function(eId, compId, value)
		if eId == entityId then
			callback("ComponentAdded", compId, value)
		end
	end))

	table.insert(connections, onComponentChanged(function(eId, compId, newVal, oldVal)
		if eId == entityId then
			callback("ComponentChanged", compId, newVal, oldVal)
		end
	end))

	table.insert(connections, onComponentRemoved(function(eId, compId, oldVal)
		if eId == entityId then
			callback("ComponentRemoved", compId, oldVal)
		end
	end))

	table.insert(connections, onEntityDestroyed(function(eId, compIds)
		if eId == entityId then
			callback("EntityDestroyed", compIds)
		end
	end))

	return {
		disconnect = function()
			for _, conn in connections do
				conn.disconnect()
			end
		end
	}
end

local function clearAllListeners()
	for eventName in listeners do
		table.clear(listeners[eventName])
	end
end

local function getListenerCounts(): {[ObserverEvent]: number}
	local counts = {}
	for eventName, eventListeners in listeners do
		counts[eventName] = #eventListeners
	end
	return counts
end

return {
	wrap = wrapEcs,
	onEntityCreated = onEntityCreated,
	onEntityDestroyed = onEntityDestroyed,
	onComponentAdded = onComponentAdded,
	onComponentChanged = onComponentChanged,
	onComponentRemoved = onComponentRemoved,
	watchEntity = watchEntity,
	clearAllListeners = clearAllListeners,
	getListenerCounts = getListenerCounts,
}
