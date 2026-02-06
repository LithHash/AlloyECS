--!optimize 2
--!native
--!strict

export type ComponentId = number
export type EntityId = number

export type Component = {
	sparse: {[EntityId]: number},
	dense: {[number]: any},
	entities: {[number]: EntityId}
}

export type ComponentMask = {[ComponentId]: boolean}

export type View = {
	forEach: (self: View, fn: (...any) -> ()) -> (),
	exclude: (self: View, ...ComponentId) -> View,
	count: (self: View) -> number,
	entities: (self: View) -> {EntityId},
	empty: (self: View) -> boolean,
}

export type EntityHandle = {
	id: EntityId,
	world: World,

	assign: (self: EntityHandle, component: ComponentId, value: any) -> EntityHandle,
	attach: (self: EntityHandle, component: ComponentId) -> EntityHandle,
	remove: (self: EntityHandle, component: ComponentId) -> EntityHandle,
	destroy: (self: EntityHandle) -> (),
	read: (self: EntityHandle, component: ComponentId) -> any,
	has: (self: EntityHandle, component: ComponentId) -> boolean,
	update: (self: EntityHandle, component: ComponentId, fn: (any) -> any) -> EntityHandle,
}

export type World = {
	nextEntityId: number,
	nextComponentId: number,
	openEntityIds: {EntityId},
	components: {[ComponentId]: Component},
	entities: {[EntityId]: ComponentMask},

	component: (self: World) -> ComponentId,
	entity: (self: World) -> EntityHandle,

	destroy: (self: World, entity: EntityId) -> (),
	exists: (self: World, entity: EntityId) -> boolean,

	assign: (self: World, entity: EntityId, component: ComponentId, value: any) -> (),
	attach: (self: World, entity: EntityId, component: ComponentId) -> (),
	remove: (self: World, entity: EntityId, component: ComponentId) -> (),
	read: (self: World, entity: EntityId, component: ComponentId) -> any,
	has: (self: World, entity: EntityId, component: ComponentId) -> boolean,
	update: (self: World, entity: EntityId, component: ComponentId, fn: (any) -> any) -> (),

	view: (self: World, ...ComponentId) -> View,
}

local function createComponent(self: World): ComponentId
	local component: Component = {
		sparse = {},
		dense = {},
		entities = {}
	}

	local componentId = self.nextComponentId
	self.components[componentId] = component
	self.nextComponentId += 1

	return componentId
end

local function createEntity(self: World): EntityHandle
	local entityId: number

	if next(self.openEntityIds) then
		entityId = self.openEntityIds[1]
		table.remove(self.openEntityIds, 1)
	else
		entityId = self.nextEntityId
		self.nextEntityId += 1
	end

	self.entities[entityId] = {}

	return {
		id = entityId,
		world = self,

		assign = function(handle: EntityHandle, component: ComponentId, value: any): EntityHandle
			self:assign(entityId, component, value)
			return handle
		end,

		attach = function(handle: EntityHandle, component: ComponentId): EntityHandle
			self:attach(entityId, component)
			return handle
		end,

		remove = function(handle: EntityHandle, component: ComponentId): EntityHandle
			self:remove(entityId, component)
			return handle
		end,

		destroy = function(handle: EntityHandle)
			self:destroy(entityId)
		end,

		read = function(handle: EntityHandle, component: ComponentId): any
			return self:read(entityId, component)
		end,

		has = function(handle: EntityHandle, component: ComponentId): boolean
			return self:has(entityId, component)
		end,

		update = function(handle: EntityHandle, component: ComponentId, fn: (any) -> any): EntityHandle
			self:update(entityId, component, fn)
			return handle
		end,
	} :: EntityHandle
end

local function destroyEntity(self: World, entity: EntityId)
	local entityData = self.entities[entity]
	if not entityData then
		return
	end

	for component in entityData do
		local componentData = self.components[component]
		if not componentData then
			continue
		end

		local denseIndex = componentData.sparse[entity]
		local denseSize = #componentData.dense
		local lastEntity = componentData.entities[denseSize]

		if denseIndex ~= denseSize then
			componentData.dense[denseIndex] = componentData.dense[denseSize]
			componentData.entities[denseIndex] = lastEntity
			componentData.sparse[lastEntity] = denseIndex
		end

		componentData.dense[denseSize] = nil
		componentData.entities[denseSize] = nil
		componentData.sparse[entity] = nil
	end

	self.entities[entity] = nil
	table.insert(self.openEntityIds, entity)
end

local function read(self: World, entity: EntityId, component: ComponentId): any
	local componentData = self.components[component]
	assert(componentData, "componentData not found for: ".. component)

	local denseIndex = componentData.sparse[entity]
	if not denseIndex then
		return nil
	end

	return componentData.dense[denseIndex]
end

local function has(self: World, entity: EntityId, component: ComponentId): boolean
	local mask = self.entities[entity]
	return mask and mask[component] ~= nil
end

local function remove(self: World, entity: EntityId, component: ComponentId)
	local componentData = self.components[component]
	assert(componentData, "componentData not found for: ".. component)

	local denseIndex = componentData.sparse[entity]
	if not denseIndex then
		return
	end

	local denseSize = #componentData.dense
	local lastEntity = componentData.entities[denseSize]

	if denseIndex ~= denseSize then
		componentData.dense[denseIndex] = componentData.dense[denseSize]
		componentData.entities[denseIndex] = lastEntity
		componentData.sparse[lastEntity] = denseIndex
	end

	componentData.dense[denseSize] = nil
	componentData.entities[denseSize] = nil
	componentData.sparse[entity] = nil

	self.entities[entity][component] = nil
end

local function assign(self: World, entity: EntityId, component: ComponentId, value: any)
	local componentData = self.components[component]
	assert(componentData, "componentData not found for: ".. component)

	if self.entities[entity][component] then
		componentData.dense[componentData.sparse[entity]] = value
		return
	end

	self.entities[entity][component] = true

	local denseIndex = #componentData.dense + 1
	componentData.sparse[entity] = denseIndex
	componentData.dense[denseIndex] = value
	componentData.entities[denseIndex] = entity
end

local function attach(self: World, entity: EntityId, component: ComponentId)
	local componentData = self.components[component]
	assert(componentData, "componentData not found for: ".. component)

	if self.entities[entity][component] then
		return
	end

	self.entities[entity][component] = true

	local denseIndex = #componentData.entities + 1
	componentData.sparse[entity] = denseIndex
	componentData.dense[denseIndex] = true
	table.insert(componentData.entities, entity)
end

local function update(self: World, entity: EntityId, component: ComponentId, fn: (any) -> any)
	local componentData = self.components[component]
	assert(componentData, "componentData not found for: ".. component)

	local denseIndex = componentData.sparse[entity]
	assert(denseIndex, "Entity does not have component: ".. component)

	local currentValue = componentData.dense[denseIndex]
	local newValue = fn(currentValue)
	componentData.dense[denseIndex] = newValue
end

local function exists(self: World, entity: EntityId): boolean
	return self.entities[entity] ~= nil
end

local function createView(self: World, ...: ComponentId)
	local componentIds = {...}
	local numComponents = #componentIds

	assert(numComponents > 0, "View must have at least one component")

	local componentPools = table.create(numComponents):: {Component}
	local smallestPool: Component = nil :: any
	local smallestSize = math.huge

	for i, componentId in componentIds do
		local componentData = self.components[componentId]
		assert(componentData, "Component does not exist: ".. componentId)

		componentPools[i] = componentData
		local size = #componentData.entities
		if size < smallestSize then
			smallestSize = size
			smallestPool = componentData
		end
	end

	local excludedComponents: {ComponentId} = {}
	local excludedPools: {Component} = {}
	local world = self

	local view = {} :: View

	function view:forEach(fn: (...any) -> ())
		local numExclusions = #excludedPools
		local entities = smallestPool.entities
		local entitiesCount = #entities

		if numComponents == 1 then
			local pool = componentPools[1]
			local dense = pool.dense

			if numExclusions == 0 then
				for i = 1, entitiesCount do
					fn(entities[i], dense[i])
				end
			else
				for i = 1, entitiesCount do
					local entity = entities[i]
					local isExcluded = false

					for j = 1, numExclusions do
						if excludedPools[j].sparse[entity] then
							isExcluded = true
							break
						end
					end

					if not isExcluded then
						fn(entity, dense[i])
					end
				end
			end
			return
		end

		local components = table.create(numComponents)

		if numExclusions == 0 then
			for i = 1, entitiesCount do
				local entity = entities[i]
				local hasAll = true

				for j = 1, numComponents do
					local pool = componentPools[j]
					local denseIndex = pool.sparse[entity]

					if not denseIndex then
						hasAll = false
						break
					end

					components[j] = pool.dense[denseIndex]
				end

				if hasAll then
					fn(entity, table.unpack(components, 1, numComponents))
				end
			end
		else
			for i = 1, entitiesCount do
				local entity = entities[i]
				local isExcluded = false

				for j = 1, numExclusions do
					if excludedPools[j].sparse[entity] then
						isExcluded = true
						break
					end
				end

				if isExcluded then
					continue
				end

				local hasAll = true

				for j = 1, numComponents do
					local pool = componentPools[j]
					local denseIndex = pool.sparse[entity]

					if not denseIndex then
						hasAll = false
						break
					end

					components[j] = pool.dense[denseIndex]
				end

				if hasAll then
					fn(entity, table.unpack(components, 1, numComponents))
				end
			end
		end
	end

	function view:exclude(...: ComponentId): View
		local exclusions = {...}
		for _, componentId in exclusions do
			table.insert(excludedComponents, componentId)
			local pool = world.components[componentId]
			if pool then
				table.insert(excludedPools, pool)
			end
		end
		return view
	end

	function view:entities(): {EntityId}
		local result: {EntityId} = {}
		local numExclusions = #excludedPools
		local entities = smallestPool.entities
		local entitiesCount = #entities

		if numExclusions == 0 then
			if numComponents == 1 then
				return entities
			end

			for i = 1, entitiesCount do
				local entity = entities[i]
				local hasAll = true

				for j = 1, numComponents do
					if not componentPools[j].sparse[entity] then
						hasAll = false
						break
					end
				end

				if hasAll then
					table.insert(result, entity)
				end
			end
		else
			for i = 1, entitiesCount do
				local entity = entities[i]
				local isExcluded = false

				for j = 1, numExclusions do
					if excludedPools[j].sparse[entity] then
						isExcluded = true
						break
					end
				end

				if not isExcluded then
					local hasAll = true

					for j = 1, numComponents do
						if not componentPools[j].sparse[entity] then
							hasAll = false
							break
						end
					end

					if hasAll then
						table.insert(result, entity)
					end
				end
			end
		end

		return result
	end

	function view:empty(): boolean
		return view:count() == 0
	end

	return view
end

local function world(): World
	local self: World = {
		nextEntityId = 1,
		nextComponentId = 1,
		openEntityIds = {},
		components = {},
		entities = {},

		component = createComponent,
		entity = createEntity,
		destroy = destroyEntity,

		read = read,
		has = has,
		exists = exists,

		remove = remove,
		attach = attach,
		assign = assign,
		update = update,

		view = createView,
	} :: World

	return self
end

return {
	world = world
}
