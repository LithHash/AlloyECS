--!strict
local HttpService = game:GetService("HttpService")

type ECS = any
type EntityId = number
type ComponentId = number

export type SerializedEntity = {
	components: {[ComponentId]: any}
}

export type SerializedWorld = {
	entities: {[EntityId]: SerializedEntity}
}

local function serializeEntity(ecs: ECS, entityId: EntityId): SerializedEntity?
	local state = ecs._internal()
	local entity = state.entityCache[entityId]

	if not entity then
		return nil
	end

	local serialized: SerializedEntity = {
		components = {}
	}

	for componentId in entity.components do
		local value = state.componentMap[componentId][entityId]
		serialized.components[componentId] = value
	end

	return serialized
end

local function serializeWorld(ecs: ECS): SerializedWorld
	local state = ecs._internal()
	local serialized: SerializedWorld = {
		entities = {}
	}

	for entityId in state.entityCache do
		local entityData = serializeEntity(ecs, entityId)
		if entityData then
			serialized.entities[entityId] = entityData
		end
	end

	return serialized
end

local function deserializeEntity(ecs: ECS, data: SerializedEntity): EntityId
	local entityId = ecs.entity()

	for componentId, value in data.components do
		ecs.set(entityId, componentId, value)
	end

	return entityId
end

local function serializeQuery(ecs: ECS, query: any): SerializedWorld
	local serialized: SerializedWorld = {
		entities = {}
	}

	for entityId in ecs.query(query) do
		local entityData = serializeEntity(ecs, entityId)
		if entityData then
			serialized.entities[entityId] = entityData
		end
	end

	return serialized
end

return {
	serializeEntity = serializeEntity,
	serializeWorld = serializeWorld,
	deserializeEntity = deserializeEntity,
	serializeQuery = serializeQuery,
}
