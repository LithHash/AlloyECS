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
	default: any?,
	hasDefault: boolean,
	kind: "data" | "tag",
}

export type ComponentMask = { [number]: boolean }

export type View<T...> = {
	forEach: (self: View<T...>, fn: (EntityId, T...) -> ()) -> (),
	cancel: (self: View<T...>) -> (),
	exclude: (self: View<T...>, ...AnyComponentId) -> View<T...>,
	whichIs: (self: View<T...>, ...any) -> View<T...>,
	count: (self: View<T...>) -> number,
	entities: (self: View<T...>) -> { EntityId },
	empty: (self: View<T...>) -> boolean,
}

type ViewIteration = {
	cancelled: boolean,
}

type ViewInternal = {
	_world: World,
	_componentIds: { ComponentId<any> },
	_componentPools: { Component },
	_excludedPools: { Component },
	_expectedValues: { any }?,
	_numComponents: number,
	_smallestPool: Component,
	_activeIteration: ViewIteration?,
}

type ViewMethodTable = {
	cancel: <T...>(self: View<T...>) -> (),
	forEach: <T...>(self: View<T...>, fn: (EntityId, T...) -> ()) -> (),
	exclude: <T...>(self: View<T...>, ...AnyComponentId) -> View<T...>,
	whichIs: <T...>(self: View<T...>, ...any) -> View<T...>,
	count: <T...>(self: View<T...>) -> number,
	entities: <T...>(self: View<T...>) -> { EntityId },
	empty: <T...>(self: View<T...>) -> boolean,
}

type ViewObject = ViewInternal & ViewMethodTable

export type World = {
	nextEntityId: number,
	nextComponentId: number,
	openEntityIds: { EntityId },
	components: { [number]: Component },
	entities: { [EntityId]: ComponentMask },
	_assignSignals: { [number]: SignalBucket },
	_removeSignals: { [number]: SignalBucket },
	_destroySignals: SignalBucket,
	_nextId: number,
	_queue: { QueuedEvent },

	component: ((self: World) -> DataComponentId<any>) & (<T>(self: World, defaultValue: T) -> DataComponentId<T>),
	tag: (self: World) -> TagComponentId,
	entity: (self: World) -> EntityId,
	destroy: (self: World, id: EntityId) -> (),
	exists: (self: World, id: EntityId) -> boolean,
	assign: <T>(self: World, entity: EntityId, component: DataComponentId<T>, value: T) -> (),
	attach: (self: World, entity: EntityId, component: AnyComponentId) -> (),
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
		) -> View<A, B, C, D, E, F, G, H>),

	onAssign: <T>(
		self: World,
		id: ComponentId<T>,
		fn: (id: EntityId, value: T) -> ()
	) -> () -> (),
	onRemove: <T>(self: World, id: ComponentId<T>, fn: (id: EntityId) -> ()) -> () -> (),
	onDestroy: (self: World, fn: (id: EntityId) -> ()) -> () -> (),
	flush: (self: World) -> (),
}

type SignalBucket = { [number]: (...any) -> () }

type QueuedEvent = {
	bucket: SignalBucket,
	entity: number,
	value: any,
}

local tableCreate = table.create
local tableUnpack = table.unpack

local function queueEvent(self: World, bucket: SignalBucket, entity: number, value: any?)
	if not next(bucket) then
		return
	end

	local queue = self._queue
	queue[#queue + 1] = { bucket = bucket, entity = entity, value = value }
end

local function getComponentData(self: World, component: number): Component
	local componentData = self.components[component]
	assert(componentData, "componentData not found for: " .. tostring(component))
	return componentData
end

local function getEntityData(self: World, entity: EntityId): ComponentMask
	local entityData = self.entities[entity]
	assert(entityData, "Entity does not exist: " .. tostring(entity))
	return entityData
end

local function cloneArray<T>(source: { T }): { T }
	local result = tableCreate(#source)
	for sourceIndex = 1, #source do
		result[sourceIndex] = source[sourceIndex]
	end

	return result
end

local function cloneDefaultValue<T>(value: T): T
	if type(value) == "table" then
		return table.clone(value :: any) :: T
	end

	return value
end

local function valuesMatch(left: any, right: any, seen: { [any]: { [any]: boolean } }?): boolean
	if left == right then
		return true
	end

	if type(left) ~= type(right) then
		return false
	end

	if type(left) ~= "table" then
		return false
	end

	local visited = (seen or {}) :: any
	local leftSeen = visited[left] :: { [any]: boolean }?
	if leftSeen and leftSeen[right] then
		return true
	end

	if not leftSeen then
		leftSeen = {}
		visited[left] = leftSeen
	end

	local rightSeen = leftSeen :: { [any]: boolean }
	rightSeen[right] = true

	for key, leftValue in left do
		if not valuesMatch(leftValue, right[key], visited :: any) then
			return false
		end
	end

	for key in right do
		if left[key] == nil then
			return false
		end
	end

	return true
end

local function flush(self: World)
	local queue = self._queue
	local count = #queue
	if count == 0 then
		return
	end

	self._queue = {}

	for queueIndex = 1, count do
		local event = queue[queueIndex]
		for _, fn in event.bucket do
			local ok = pcall(fn, event.entity, event.value)
			if not ok then
				print("AlloyECS observer callback failed")
			end
		end
	end
end

local function createComponent<T>(self: World, defaultValue: T?): DataComponentId<T>
	local entityId: EntityId
	local openIds = self.openEntityIds
	local openIdCount = #openIds

	if openIdCount > 0 then
		entityId = openIds[openIdCount]
		openIds[openIdCount] = nil
	else
		entityId = self.nextEntityId
		self.nextEntityId += 1
	end

	local component: Component = {
		sparse = {},
		dense = {},
		entities = {},
		default = defaultValue,
		hasDefault = defaultValue ~= nil,
		kind = "data",
	}

	self.entities[entityId] = {}
	self.components[entityId] = component

	return entityId :: any
end

local function createTag(self: World): TagComponentId
	local entityId: number
	local openIds = self.openEntityIds
	local openIdCount = #openIds

	if openIdCount > 0 then
		entityId = openIds[openIdCount]
		openIds[openIdCount] = nil
	else
		entityId = self.nextEntityId
		self.nextEntityId += 1
	end

	local component: Component = {
		sparse = {},
		dense = {},
		entities = {},
		default = nil,
		hasDefault = false,
		kind = "tag",
	}

	self.entities[entityId] = {}
	self.components[entityId] = component

	return entityId :: any
end

local function createEntity(self: World): EntityId
	local entityId: number
	local openIds = self.openEntityIds
	local openIdCount = #openIds

	if openIdCount > 0 then
		entityId = openIds[openIdCount]
		openIds[openIdCount] = nil
	else
		entityId = self.nextEntityId
		self.nextEntityId += 1
	end

	self.entities[entityId] = {}

	return entityId
end

local function destroyEntity(self: World, id: EntityId)
	local entityData = self.entities[id]
	if not entityData then
		return
	end

	local removeSignals = self._removeSignals

	for component in entityData do
		local componentData = self.components[component]
		if not componentData then
			continue
		end

		if removeSignals[component] then
			queueEvent(self, removeSignals[component], id, nil)
		end

		local denseIndex = componentData.sparse[id]
		if not denseIndex then
			continue
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
		componentData.sparse[id] = nil
	end

	self.entities[id] = nil

	local openIds = self.openEntityIds
	openIds[#openIds + 1] = id

	if next(self._destroySignals) then
		queueEvent(self, self._destroySignals, id, nil)
	end
end

local function read<T>(self: World, entity: EntityId, component: ComponentId<T>): T?
	local componentData = getComponentData(self, component)

	local denseIndex = componentData.sparse[entity]
	if not denseIndex then
		return nil
	end

	return componentData.dense[denseIndex] :: T
end

local function has<T>(self: World, entity: EntityId, component: ComponentId<T>): boolean
	local mask = self.entities[entity]
	if not mask then
		return false
	end

	return mask[component] ~= nil
end

local function remove<T>(self: World, entity: EntityId, component: ComponentId<T>)
	local entityData = getEntityData(self, entity)
	local componentData = getComponentData(self, component)

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
	entityData[component] = nil

	if self._removeSignals[component] then
		queueEvent(self, self._removeSignals[component], entity, nil)
	end
end

local function assign<T>(self: World, entity: EntityId, component: DataComponentId<T>, value: T)
	local entityData = getEntityData(self, entity)
	local componentData = getComponentData(self, component)

	if entityData[component] then
		componentData.dense[componentData.sparse[entity]] = value
	else
		entityData[component] = true

		local denseIndex = #componentData.dense + 1
		componentData.sparse[entity] = denseIndex
		componentData.dense[denseIndex] = value
		componentData.entities[denseIndex] = entity
	end

	if self._assignSignals[component] then
		queueEvent(self, self._assignSignals[component], entity, value)
	end
end

local function attach(self: World, entity: EntityId, component: AnyComponentId)
	local entityData = getEntityData(self, entity)
	local componentData = getComponentData(self, component)

	if entityData[component] then
		return
	end

	if componentData.kind == "data" then
		assert(componentData.hasDefault, `Cannot attach non-default data component {component}`)
		assign(self, entity, component :: DataComponentId<any>, cloneDefaultValue(componentData.default))
		return
	end

	entityData[component] = true

	local denseIndex = #componentData.entities + 1
	componentData.sparse[entity] = denseIndex
	componentData.dense[denseIndex] = true
	componentData.entities[denseIndex] = entity

	if self._assignSignals[component] then
		queueEvent(self, self._assignSignals[component], entity, true)
	end
end

local function update<T>(self: World, entity: EntityId, component: DataComponentId<T>, fn: (T) -> T)
	getEntityData(self, entity)
	local componentData = getComponentData(self, component)

	local denseIndex = componentData.sparse[entity]
	assert(denseIndex, "Entity does not have component: " .. tostring(component))

	local newValue = fn(componentData.dense[denseIndex] :: T)
	componentData.dense[denseIndex] = newValue

	if self._assignSignals[component] then
		queueEvent(self, self._assignSignals[component], entity, newValue)
	end
end

local function exists(self: World, entity: EntityId): boolean
	return self.entities[entity] ~= nil
end

local function onAssign<T>(
	self: World,
	id: ComponentId<T>,
	fn: (id: EntityId, value: T) -> ()
): () -> ()
	local bucket: SignalBucket = self._assignSignals[id] or {}
	self._assignSignals[id] = bucket
	self._nextId += 1

	local observerId = self._nextId
	bucket[observerId] = fn :: any

	return function()
		bucket[observerId] = nil
	end
end

local function onRemove<T>(
	self: World,
	id: ComponentId<T>,
	fn: (id: EntityId) -> ()
): () -> ()
	local bucket: SignalBucket = self._removeSignals[id] or {}
	self._removeSignals[id] = bucket
	self._nextId += 1

	local observerId = self._nextId
	bucket[observerId] = fn :: any

	return function()
		bucket[observerId] = nil
	end
end

local function onDestroy(self: World, fn: (...any) -> ()): () -> ()
	self._nextId += 1

	local id = self._nextId
	self._destroySignals[id] = fn

	return function()
		self._destroySignals[id] = nil
	end
end

local function createViewInternal<T...>(
	self: World,
	componentIds: { ComponentId<any> },
	excludedPools: { Component },
	matchedValues: { any }?
): View<T...>
	local numComponents = #componentIds

	assert(numComponents > 0, "View must have at least one component")

	local componentPools = tableCreate(numComponents) :: { Component }
	local smallestPool: Component = nil :: any
	local smallestSize = math.huge

	for componentIndex, componentId in componentIds do
		local componentData = self.components[componentId]
		assert(componentData, "Component does not exist: " .. tostring(componentId))

		componentPools[componentIndex] = componentData
		local size = #componentData.entities
		if size < smallestSize then
			smallestSize = size
			smallestPool = componentData
		end
	end

	local view: ViewObject = {
		_world = self,
		_componentIds = componentIds,
		_componentPools = componentPools,
		_excludedPools = excludedPools,
		_expectedValues = matchedValues,
		_numComponents = numComponents,
		_smallestPool = smallestPool,
		_activeIteration = nil,

		cancel = viewCancel,
		forEach = viewForEach,
		exclude = viewExclude,
		whichIs = viewWhichIs,
		count = viewCount,
		entities = viewEntities,
		empty = viewEmpty,
	}

	return view :: View<T...>
end

local function getViewInternal<T...>(self: View<T...>): ViewInternal
	return self :: ViewInternal
end

function viewCancel<T...>(self: View<T...>)
	local iteration = getViewInternal(self)._activeIteration
	if iteration then
		iteration.cancelled = true
	end
end

local function viewEntityMatches(self: ViewInternal, entity: EntityId, values: { any }): boolean
	for excludedPoolIndex = 1, #self._excludedPools do
		if self._excludedPools[excludedPoolIndex].sparse[entity] then
			return false
		end
	end

	local expectedValues = self._expectedValues
	local numComponents = self._numComponents

	if expectedValues and #expectedValues ~= numComponents then
		return false
	end

	for componentIndex = 1, numComponents do
		local pool = self._componentPools[componentIndex]
		local denseIndex = pool.sparse[entity]
		if not denseIndex then
			return false
		end

		local value = pool.dense[denseIndex]
		if expectedValues and not valuesMatch(expectedValues[componentIndex], value) then
			return false
		end

		values[componentIndex] = value
	end

	return true
end

local function iterateView(self: ViewInternal, onMatch: (EntityId, { any }) -> ())
	local previousIteration = self._activeIteration
	local iteration = { cancelled = false }
	self._activeIteration = iteration

	local values = tableCreate(self._numComponents)
	local entities = self._smallestPool.entities

	for entityIndex = 1, #entities do
		local entity = entities[entityIndex]
		if viewEntityMatches(self, entity, values) then
			onMatch(entity, values)
			if iteration.cancelled then
				break
			end
		end
	end

	self._activeIteration = previousIteration
end

function viewForEach<T...>(self: View<T...>, fn: (EntityId, T...) -> ())
	local internal = getViewInternal(self)
	iterateView(internal, function(entity, values)
		(fn :: any)(entity, tableUnpack(values, 1, internal._numComponents))
	end)
end

function viewExclude<T...>(self: View<T...>, ...: AnyComponentId): View<T...>
	local internal = getViewInternal(self)
	local nextExcludedPools = cloneArray(internal._excludedPools)

	for _, id in { ... } do
		local pool = internal._world.components[id]
		if pool then
			nextExcludedPools[#nextExcludedPools + 1] = pool
		end
	end

	return createViewInternal(internal._world, internal._componentIds, nextExcludedPools, internal._expectedValues)
end

function viewWhichIs<T...>(self: View<T...>, ...: any): View<T...>
	local internal = getViewInternal(self)
	return createViewInternal(internal._world, internal._componentIds, internal._excludedPools, { ... })
end

function viewCount<T...>(self: View<T...>): number
	local internal = getViewInternal(self)
	local count = 0

	iterateView(internal, function()
		count += 1
	end)

	return count
end

function viewEntities<T...>(self: View<T...>): { EntityId }
	local internal = getViewInternal(self)
	local result: { EntityId } = {}

	iterateView(internal, function(entity)
		result[#result + 1] = entity
	end)

	return result
end

function viewEmpty<T...>(self: View<T...>): boolean
	return viewCount(self) == 0
end

local function createView<T...>(self: World, ...: ComponentId<any>): View<T...>
	return createViewInternal(self, { ... }, {}, nil)
end

local function world(): World
	local self = {
		nextEntityId = 1,
		nextComponentId = 1,
		openEntityIds = {},
		components = {},
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

	return self :: World
end

return {
	world = world,
}
