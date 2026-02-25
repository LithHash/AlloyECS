--!optimize 2
--!native
--!strict

export type ComponentId<T> = number & { __phantom: T }
export type DataComponentId<T> = ComponentId<T> & { __kind: "data" }
export type TagComponentId = ComponentId<true> & { __kind: "tag" }
export type AnyComponentId = DataComponentId<any> | TagComponentId
export type EntityId = number

export type Component = {
	sparse: { [EntityId]: number },
	dense: { [number]: any },
	entities: { [number]: EntityId },
}

export type ComponentMask = { [number]: boolean }

export type View<T...> = {
	forEach: (self: View<T...>, fn: (EntityId, T...) -> ()) -> (),
	exclude: (self: View<T...>, ...AnyComponentId) -> View<T...>,
	count: (self: View<T...>) -> number,
	entities: (self: View<T...>) -> { EntityId },
	empty: (self: View<T...>) -> boolean,
}

export type World = {
	nextEntityId: number,
	nextComponentId: number,
	openEntityIds: { EntityId },
	components: { [number]: Component },
	entities: { [EntityId]: ComponentMask },

	component: <T>(self: World) -> DataComponentId<T>,
	tag: (self: World) -> TagComponentId,
	entity: (self: World) -> EntityId,
	destroy: (self: World, entity: EntityId) -> (),
	exists: (self: World, entity: EntityId) -> boolean,
	assign: <T>(self: World, entity: EntityId, component: DataComponentId<T>, value: T) -> (),
	attach: (self: World, entity: EntityId, component: TagComponentId) -> (),
	remove: <T>(self: World, entity: EntityId, component: ComponentId<T>) -> (),
	read: <T>(self: World, entity: EntityId, component: ComponentId<T>) -> T?,
	has: <T>(self: World, entity: EntityId, component: ComponentId<T>) -> boolean,
	update: <T>(
		self: World,
		entity: EntityId,
		component: DataComponentId<T>,
		fn: (T) -> T
	) -> (),
	view:
		& (<A>(self: World, componentA: ComponentId<A>) -> View<A>)
		& (<A, B>(self: World, componentA: ComponentId<A>, componentB: ComponentId<B>) -> View<A, B>)
		& (<A, B, C>(
			self: World,
			componentA: ComponentId<A>,
			componentB: ComponentId<B>,
			componentC: ComponentId<C>
		) -> View<A, B, C>)
		& (<A, B, C, D>(
			self: World,
			componentA: ComponentId<A>,
			componentB: ComponentId<B>,
			componentC: ComponentId<C>,
			componentD: ComponentId<D>
		) -> View<A, B, C, D>)
		& (<A, B, C, D, E>(
			self: World,
			componentA: ComponentId<A>,
			componentB: ComponentId<B>,
			componentC: ComponentId<C>,
			componentD: ComponentId<D>,
			componentE: ComponentId<E>
		) -> View<A, B, C, D, E>)
		& (<A, B, C, D, E, F>(
			self: World,
			componentA: ComponentId<A>,
			componentB: ComponentId<B>,
			componentC: ComponentId<C>,
			componentD: ComponentId<D>,
			componentE: ComponentId<E>,
			componentF: ComponentId<F>
		) -> View<A, B, C, D, E, F>)
		& (<A, B, C, D, E, F, G>(
			self: World,
			componentA: ComponentId<A>,
			componentB: ComponentId<B>,
			componentC: ComponentId<C>,
			componentD: ComponentId<D>,
			componentE: ComponentId<E>,
			componentF: ComponentId<F>,
			componentG: ComponentId<G>
		) -> View<A, B, C, D, E, F, G>)
		& (<A, B, C, D, E, F, G, H>(
			self: World,
			componentA: ComponentId<A>,
			componentB: ComponentId<B>,
			componentC: ComponentId<C>,
			componentD: ComponentId<D>,
			componentE: ComponentId<E>,
			componentF: ComponentId<F>,
			componentG: ComponentId<G>,
			componentH: ComponentId<H>
		) -> View<A, B, C, D, E, F, G, H>)
		& (<T...>(self: World, ...ComponentId<any>) -> View<T...>),

	onAssign: <T>(
		self: World,
		component: ComponentId<T>,
		fn: (entity: EntityId, value: T) -> ()
	) -> () -> (),
	onRemove: <T>(self: World, component: ComponentId<T>, fn: (entity: EntityId) -> ()) -> () -> (),
	onDestroy: (self: World, fn: (entity: EntityId) -> ()) -> () -> (),
	flush: (self: World) -> (),
}

type ComponentKind = "data" | "tag"
type SignalBucket = { [number]: (...any) -> () }

type QueuedEvent = {
	bucket: SignalBucket,
	entity: number,
	value: any,
}

type WorldInternal = {
	nextEntityId: number,
	nextComponentId: number,
	openEntityIds: { EntityId },
	components: { [number]: Component },
	componentKinds: { [number]: ComponentKind },
	entities: { [EntityId]: ComponentMask },
	_assignSignals: { [number]: SignalBucket },
	_removeSignals: { [number]: SignalBucket },
	_destroySignals: SignalBucket,
	_nextId: number,
	_queue: { QueuedEvent },
}

local tableCreate = table.create
local tableUnpack = table.unpack

local function queueEvent(self: WorldInternal, bucket: SignalBucket, entity: number, value: any?)
	if not next(bucket) then
		return
	end

	local queue = self._queue
	queue[#queue + 1] = { bucket = bucket, entity = entity, value = value }
end

local function getComponentData(internal: WorldInternal, component: number): Component
	local componentData = internal.components[component]
	assert(componentData, "componentData not found for: " .. tostring(component))
	return componentData
end

local function getComponentKind(internal: WorldInternal, component: number): ComponentKind
	local kind = internal.componentKinds[component]
	assert(kind, "component kind not found for: " .. tostring(component))
	return kind :: ComponentKind
end

local function flush(self: World)
	local internal = self :: any
	local queue: { QueuedEvent } = internal._queue
	local count = #queue
	if count == 0 then
		return
	end

	for i = 1, count do
		local event = queue[i]
		for _, fn in event.bucket do
			local ok = pcall(fn, event.entity, event.value)
			if not ok then
				print("AlloyECS observer callback failed")
			end
		end

		queue[i] = nil :: any
	end
end

local function createComponent<T>(self: World): DataComponentId<T>
	local internal = self :: any
	local component: Component = {
		sparse = {},
		dense = {},
		entities = {},
	}

	local componentId = internal.nextComponentId
	internal.components[componentId] = component
	internal.componentKinds[componentId] = "data"
	internal.nextComponentId += 1

	return componentId :: DataComponentId<T>
end

local function createTag(self: World): TagComponentId
	local internal = self :: any
	local component: Component = {
		sparse = {},
		dense = {},
		entities = {},
	}

	local componentId = internal.nextComponentId
	internal.components[componentId] = component
	internal.componentKinds[componentId] = "tag"
	internal.nextComponentId += 1

	return componentId :: TagComponentId
end

local function createEntity(self: World): EntityId
	local internal = self :: any
	local entityId: number
	local openIds = internal.openEntityIds
	local n = #openIds

	if n > 0 then
		entityId = openIds[n]
		openIds[n] = nil
	else
		entityId = internal.nextEntityId
		internal.nextEntityId += 1
	end

	internal.entities[entityId] = {}

	return entityId
end

local function destroyEntity(self: World, entity: EntityId)
	local internal = self :: any
	local entityData = internal.entities[entity]
	if not entityData then
		return
	end

	local removeSignals = internal._removeSignals

	for component in entityData do
		local componentData = internal.components[component]
		if not componentData then
			continue
		end

		if removeSignals[component] then
			queueEvent(internal, removeSignals[component], entity, nil)
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

	internal.entities[entity] = nil

	local openIds = internal.openEntityIds
	openIds[#openIds + 1] = entity

	if next(internal._destroySignals) then
		queueEvent(internal, internal._destroySignals, entity, nil)
	end
end

local function read<T>(self: World, entity: EntityId, component: ComponentId<T>): T?
	local internal = self :: any
	local componentData = getComponentData(internal, component)

	local denseIndex = componentData.sparse[entity]
	if not denseIndex then
		return nil
	end

	return componentData.dense[denseIndex] :: T
end

local function has<T>(self: World, entity: EntityId, component: ComponentId<T>): boolean
	local internal = self :: any
	local mask = internal.entities[entity]
	if not mask then
		return false
	end

	return mask[component] ~= nil
end

local function remove<T>(self: World, entity: EntityId, component: ComponentId<T>)
	local internal = self :: any
	local componentData = getComponentData(internal, component)

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
	internal.entities[entity][component] = nil

	if internal._removeSignals[component] then
		queueEvent(internal, internal._removeSignals[component], entity, nil)
	end
end

local function assign<T>(self: World, entity: EntityId, component: DataComponentId<T>, value: T)
	local internal = self :: any
	local componentData = getComponentData(internal, component)
	if getComponentKind(internal, component) == "tag" then
		return
	end

	if internal.entities[entity][component] then
		componentData.dense[componentData.sparse[entity]] = value
	else
		internal.entities[entity][component] = true

		local denseIndex = #componentData.dense + 1
		componentData.sparse[entity] = denseIndex
		componentData.dense[denseIndex] = value
		componentData.entities[denseIndex] = entity
	end

	if internal._assignSignals[component] then
		queueEvent(internal, internal._assignSignals[component], entity, value)
	end
end

local function attach(self: World, entity: EntityId, component: TagComponentId)
	local internal = self :: any
	local componentData = getComponentData(internal, component)
	if getComponentKind(internal, component) == "data" then
		return
	end

	if internal.entities[entity][component] then
		return
	end

	internal.entities[entity][component] = true

	local denseIndex = #componentData.entities + 1
	componentData.sparse[entity] = denseIndex
	componentData.dense[denseIndex] = true
	componentData.entities[denseIndex] = entity

	if internal._assignSignals[component] then
		queueEvent(internal, internal._assignSignals[component], entity, true)
	end
end

local function update<T>(self: World, entity: EntityId, component: DataComponentId<T>, fn: (T) -> T)
	local internal = self :: any
	local componentData = getComponentData(internal, component)
	if getComponentKind(internal, component) == "tag" then
		return
	end

	local denseIndex = componentData.sparse[entity]
	assert(denseIndex, "Entity does not have component: " .. tostring(component))

	local newValue = fn(componentData.dense[denseIndex] :: T)
	componentData.dense[denseIndex] = newValue

	if internal._assignSignals[component] then
		queueEvent(internal, internal._assignSignals[component], entity, newValue)
	end
end

local function exists(self: World, entity: EntityId): boolean
	local internal = self :: any

	return internal.entities[entity] ~= nil
end

local function onAssign<T>(
	self: World,
	component: ComponentId<T>,
	fn: (entity: EntityId, value: T) -> ()
): () -> ()
	local internal = self :: any
	local bucket: SignalBucket = internal._assignSignals[component] or {}
	internal._assignSignals[component] = bucket
	internal._nextId += 1

	local id = internal._nextId
	bucket[id] = fn :: any

	return function()
		bucket[id] = nil
	end
end

local function onRemove<T>(
	self: World,
	component: ComponentId<T>,
	fn: (entity: EntityId) -> ()
): () -> ()
	local internal = self :: any
	local bucket: SignalBucket = internal._removeSignals[component] or {}
	internal._removeSignals[component] = bucket
	internal._nextId += 1

	local id = internal._nextId
	bucket[id] = fn :: any

	return function()
		bucket[id] = nil
	end
end

local function onDestroy(self: World, fn: (entity: EntityId) -> ()): () -> ()
	local internal = self :: any
	internal._nextId += 1

	local id = internal._nextId
	internal._destroySignals[id] = fn

	return function()
		internal._destroySignals[id] = nil
	end
end

local function createView(self: World, ...: ComponentId<any>): View<any>
	local internal = self :: any
	local componentIds = { ... }
	local numComponents = #componentIds

	assert(numComponents > 0, "View must have at least one component")

	local componentPools = tableCreate(numComponents) :: { Component }
	local smallestPool: Component = nil :: any
	local smallestSize = math.huge

	for i, componentId in componentIds do
		local componentData = internal.components[componentId]
		assert(componentData, "Component does not exist: " .. tostring(componentId))

		componentPools[i] = componentData
		local size = #componentData.entities
		if size < smallestSize then
			smallestSize = size
			smallestPool = componentData
		end
	end

	local excludedPools: { Component } = {}
	local world = self

	local view = {} :: View<any>

	function view:forEach(fn: (EntityId, ...any) -> ())
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

		local components = tableCreate(numComponents)

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
					fn(entity, tableUnpack(components, 1, numComponents))
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
					fn(entity, tableUnpack(components, 1, numComponents))
				end
			end
		end
	end

	function view:exclude(...: AnyComponentId): View<any>
		for _, componentId in { ... } do
			local pool = (world :: any).components[componentId]
			if pool then
				excludedPools[#excludedPools + 1] = pool
			end
		end

		return view
	end

	function view:count(): number
		local count = 0
		local numExclusions = #excludedPools
		local entities = smallestPool.entities
		local entitiesCount = #entities

		if numComponents == 1 and numExclusions == 0 then
			return entitiesCount
		end

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
					count += 1
				end
			end
		end

		return count
	end

	function view:entities(): { EntityId }
		local result: { EntityId } = {}
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
					result[#result + 1] = entity
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
						result[#result + 1] = entity
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
	local self = {
		nextEntityId = 1,
		nextComponentId = 1,
		openEntityIds = {},
		components = {},
		componentKinds = {},
		entities = {},
		_assignSignals = {},
		_removeSignals = {},
		_destroySignals = {},
		_nextId = 0,
		_queue = {},

		component = createComponent,
		tag = createTag,
		entity = createEntity,
		destroy = destroyEntity,
		exists = exists,
		read = read,
		has = has,
		remove = remove,
		attach = attach,
		assign = assign,
		update = update,
		view = createView,
		onAssign = onAssign,
		onRemove = onRemove,
		onDestroy = onDestroy,
		flush = flush,
	}

	return self :: any
end

return {
	world = world,
}
