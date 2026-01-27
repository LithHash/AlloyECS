--!strict
export type EntityId = number
export type ComponentId = number

export type EntityData = {
	id: EntityId,
	components: {[ComponentId]: true}
}

export type QueryResult = (EntityId, ...any) -> ()
export type Query = {
	with: {ComponentId},
	without: {ComponentId}?
}

export type InternalState = {
	entityCache: {[EntityId]: EntityData},
	componentMap: {[ComponentId]: {[EntityId]: any}},
	nextEntityId: number,
	nextComponentId: number,
}

local entityCache: {[EntityId]: EntityData} = {}
local componentMap: {[ComponentId]: {[EntityId]: any}} = {}

local nextEntityId: number = 0
local nextComponentId: number = 0

local function attachComponent(entityId: EntityId, componentId: ComponentId, value: any)
	local entity = entityCache[entityId]
	assert(entity, '[AlloyECS] Failed to fetch entity data for entity ID: '.. entityId)

	local componentData = componentMap[componentId]
	assert(componentData, '[AlloyECS] Failed to fetch component map for component ID: '.. componentId)

	entity.components[componentId] = true
	componentMap[componentId][entityId] = value
end

local function set(entityId: EntityId, componentId: ComponentId, value: any)
	attachComponent(entityId, componentId, value)
end

local function add(entityId: EntityId, componentId: ComponentId)
	attachComponent(entityId, componentId, true)
end

local function get(entityId: EntityId, componentId: ComponentId): unknown
	local componentData = componentMap[componentId]
	if componentData[entityId] == nil then
		return nil
	end

	return componentData[entityId]
end

local function has(entityId: EntityId, componentId: ComponentId): boolean
	local componentData = componentMap[componentId]
	return componentData[entityId] ~= nil
end

local function exists(entityId: EntityId): boolean
	return entityCache[entityId] ~= nil
end

local function remove(entityId: EntityId, componentId: ComponentId)
	local entity = entityCache[entityId]
	assert(entity, '[AlloyECS] Failed to fetch entity data for entity ID: '.. entityId)

	local componentData = componentMap[componentId]
	assert(componentData, '[AlloyECS] Failed to fetch component map for component ID: '.. componentId)

	if not entity.components[componentId] then
		return
	end

	entity.components[componentId] = nil
	componentData[entityId] = nil
end

local function query(queryParams: Query): () -> QueryResult
	local requiredComponents = queryParams.with
	local excludedComponents = queryParams.without or {}
	local numRequired = #requiredComponents
	local numExcluded = #excludedComponents

	assert(numRequired > 0, "[AlloyECS] Query must have at least one 'with' component")

	local requiredComponentMaps = table.create(numRequired)
	for i = 1, numRequired do
		local componentId = requiredComponents[i]
		local componentData = componentMap[componentId]
		assert(componentData, "[AlloyECS] Component does not exist")

		requiredComponentMaps[i] = componentData
	end

	local excludedEntitySet = {}
	if numExcluded > 0 then
		for i = 1, numExcluded do
			local excludedComponentData = componentMap[excludedComponents[i]]
			if not excludedComponentData then
				continue
			end

			for entityId in pairs(excludedComponentData) do
				excludedEntitySet[entityId] = true
			end
		end
	end

	local baseComponentData = requiredComponentMaps[1]
	local smallestMapSize = math.huge

	for i = 1, numRequired do
		local currentComponentData = requiredComponentMaps[i]
		local currentSize = 0

		for _ in pairs(currentComponentData:: any) do
			currentSize += 1
			if currentSize >= smallestMapSize then
				break
			end
		end

		if currentSize < smallestMapSize and currentSize > 0 then
			smallestMapSize = currentSize
			baseComponentData = currentComponentData
		end
	end

	local iteratorFunc, iteratorTable, iteratorState = pairs(baseComponentData:: any)

	return function()
		while true do
			local entityId = iteratorFunc(iteratorTable, iteratorState)
			iteratorState = entityId

			if entityId == nil then
				return nil:: any
			end

			if excludedEntitySet[entityId] then
				continue
			end

			local componentValues = table.create(numRequired)
			local hasAllRequired = true

			for i = 1, numRequired do
				local value = (requiredComponentMaps[i]:: any)[entityId]
				if value == nil then
					hasAllRequired = false
					break
				end
				componentValues[i] = value
			end

			if hasAllRequired then
				return entityId, table.unpack(componentValues, 1, numRequired)
			end
		end
	end
end

local function destroyEntity(entityId: EntityId)
	local entity = entityCache[entityId]
	if not entity then
		return
	end

	for componentId in entity.components do
		remove(entityId, componentId)
	end

	entityCache[entityId] = nil
end

local function createEntity(): EntityId
	nextEntityId += 1
	local newEntityId = nextEntityId

	local entity: EntityData = {
		id = newEntityId,
		components = {}
	}

	entityCache[newEntityId] = entity

	return newEntityId
end

local function createComponent(): ComponentId
	local newComponentId = nextComponentId + 1
	nextComponentId = newComponentId

	componentMap[newComponentId] = {}

	return newComponentId
end

local function clear()
	table.clear(entityCache)
	table.clear(componentMap)
	nextEntityId = 0
	nextComponentId = 0
end

local function getInternalState(): InternalState
	return {
		entityCache = entityCache,
		componentMap = componentMap,
		nextEntityId = nextEntityId,
		nextComponentId = nextComponentId,
	}
end

return {
	entity = createEntity,
	component = createComponent,
	get = get,
	set = set,
	add = add,
	has = has,
	exists = exists,
	remove = remove,
	destroy = destroyEntity,
	query = query,
	clear = clear,

	_internal = getInternalState,
}
