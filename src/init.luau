--!strict
--!native
--!optimize 2

--[=[
	@class AlloyECS

	AlloyECS is a high-performance Entity Component System (ECS) library for Roblox.

	## Features

	| Category | Features |
	|----------|----------|
	| **Entities** | Generational IDs (24-bit index + 8-bit generation), recycling |
	| **Components** | Sparse, dense, and tag storage types |
	| **Queries** | Bitset-based filtering, caching, builder pattern |
	| **Systems** | Phase-based scheduling, dependencies |
	| **Relationships** | Entity-to-entity with optional data |
	| **Prefabs** | Entity templates with builder pattern |
	| **Events** | onAdd, onRemove, onChange hooks |
	| **Deferred** | CommandBuffer for batched operations |
	| **Reactive** | Change tracking (added/removed/changed) |
	| **Persistence** | Serialization and deserialization |

	## Quick Start

	```lua
	local AlloyECS = require(path.to.AlloyECS)

	-- Create a world
	local world = AlloyECS.createWorld()

	-- Define components
	local Position = world:component()
	local Velocity = world:component()
	local Player = world:tag()

	-- Create an entity with components
	local entity = world:entity()
	world:set(entity, Position, Vector3.new(0, 0, 0))
	world:set(entity, Velocity, Vector3.new(1, 0, 0))
	world:add(entity, Player)

	-- Query and update entities
	for entityId, pos, vel in world:query(Position, Velocity) do
		world:set(entityId, Position, pos + vel)
	end
	```

	:::info Version
	This documentation is for AlloyECS v1.0.0
	:::
]=]

local Bitset = require(script.Bitset)
local CommandBuffer = require(script.CommandBuffer)
local Reactive = require(script.Reactive)
local Scheduler = require(script.Scheduler)

local ENTITY_INDEX_BITS = 24
local ENTITY_GENERATION_BITS = 8
local MAX_ENTITY_INDEX = bit32.lshift(1, ENTITY_INDEX_BITS) - 1
local MAX_GENERATION = bit32.lshift(1, ENTITY_GENERATION_BITS) - 1
local GENERATION_SHIFT = ENTITY_INDEX_BITS

type EntityType = number
type StorageType = "sparse" | "dense" | "tag"

type ComponentConfig = {
	storage: StorageType?,
}

type QueryIterator = () -> (EntityType?, ...any)

type WorldData = {
	entityGenerations: { [number]: number },
	entityComponents: { [EntityType]: { [EntityType]: any } },
	livingEntities: { [EntityType]: boolean },
	entityList: { EntityType },
	entityListIndex: { [EntityType]: number },
	entityCount: number,
	recycledIndices: { number },
	nextEntityIndex: number,
	entityBitsets: { [EntityType]: Bitset.Bitset },
	componentBitIndex: { [EntityType]: number },
	nextBitIndex: number,
	componentEntityLists: { [EntityType]: { EntityType } },
	componentEntityIndex: { [EntityType]: { [EntityType]: number } },
	componentConfigs: { [EntityType]: ComponentConfig },
	nextComponentId: number,
	tagComponents: { [EntityType]: boolean },
	queryCache: { [string]: { EntityType } },
	queryCacheByComponent: { [EntityType]: { string } },
	queryCacheDirty: boolean,
	relationships: { [EntityType]: { [EntityType]: { [EntityType]: any } } },
	relationTargets: { [EntityType]: { [EntityType]: { EntityType } } },
	prefabs: { [string]: PrefabData },
	onAddHooks: { [EntityType]: { (entityId: EntityType, value: any) -> () } },
	onRemoveHooks: { [EntityType]: { (entityId: EntityType, value: any) -> () } },
	onChangeHooks: { [EntityType]: { (entityId: EntityType, oldValue: any, newValue: any) -> () } },
	changeTracker: Reactive.ChangeTracker?,
	scheduler: Scheduler.Scheduler,
	commandBuffer: CommandBuffer.CommandBuffer,
	deferredMode: boolean,
	trackChanges: boolean,
	debug: boolean,
}

type PrefabData = {
	components: { { componentId: EntityType, value: any } },
	tags: { EntityType },
}

type PrefabBuilderData = {
	world: WorldData,
	components: { { componentId: EntityType, value: any } },
	tags: { EntityType },
}

type QueryBuilderData = {
	world: WorldData,
	includeComponents: { EntityType },
	excludeComponents: { EntityType },
	withComponents: { EntityType },
}

--[=[
	@class World

	The World is the main container for all ECS data. It manages entities,
	components, queries, systems, relationships, and more.

	Create a new world using [AlloyECS.createWorld].

	## Method Categories

	| Category | Methods |
	|----------|----------|
	| **Entity** | [World:entity], [World:isAlive], [World:destroy], [World:getEntityCount], [World:getEntities], [World:each] |
	| **Component** | [World:component], [World:tag], [World:isTag], [World:add], [World:set], [World:get], [World:has], [World:remove] |
	| **Query** | [World:query] |
	| **System** | [World:addSystem], [World:removeSystem], [World:enableSystem], [World:disableSystem], [World:runSystems], [World:runPhase], [World:step] |
	| **Relationship** | [World:relate], [World:unrelate], [World:getRelation], [World:hasRelation], [World:getTargets], [World:getSources] |
	| **Prefab** | [World:prefab], [World:spawn] |
	| **Event** | [World:onAdd], [World:onRemove], [World:onChange] |
	| **Deferred** | [World:defer], [World:deferSpawn], [World:deferDestroy], [World:deferAdd], [World:deferSet], [World:deferRemove], [World:flush], [World:hasPendingCommands] |
	| **Reactive** | [World:added], [World:removed], [World:changed], [World:clearChanges] |
	| **Persistence** | [World:serialize], [World:deserialize] |

	## Example

	```lua
	local AlloyECS = require(path.to.AlloyECS)
	local world = AlloyECS.createWorld()

	-- Create components
	local Position = world:component()
	local Velocity = world:component()

	-- Create entities
	local entity = world:entity()
	world:set(entity, Position, Vector3.new(0, 0, 0))
	world:set(entity, Velocity, Vector3.new(1, 0, 0))

	-- Query and update
	for entityId, pos, vel in world:query(Position, Velocity) do
		world:set(entityId, Position, pos + vel)
	end
	```
]=]
export type World = WorldData & {
	entity: (self: any) -> EntityType,
	isAlive: (self: any, entityId: EntityType) -> boolean,
	destroy: (self: any, entityId: EntityType) -> (),
	getEntityCount: (self: any) -> number,
	getEntities: (self: any) -> { EntityType },
	component: (self: any, config: ComponentConfig?) -> EntityType,
	tag: (self: any) -> EntityType,
	isTag: (self: any, componentId: EntityType) -> boolean,
	add: (self: any, entityId: EntityType, componentId: EntityType) -> (),
	set: (self: any, entityId: EntityType, componentId: EntityType, value: any) -> (),
	get: (self: any, entityId: EntityType, componentId: EntityType) -> any,
	has: (self: any, entityId: EntityType, ...EntityType) -> boolean,
	remove: (self: any, entityId: EntityType, componentId: EntityType) -> (),
	query: (self: any, ...EntityType) -> QueryBuilder,
	queryBuilder: (self: any, ...EntityType) -> QueryBuilder,
	added: (self: any, componentId: EntityType) -> { EntityType },
	removed: (self: any, componentId: EntityType) -> { EntityType },
	changed: (self: any, componentId: EntityType) -> { EntityType },
	clearChanges: (self: any) -> (),
	defer: (self: any) -> (),
	deferSpawn: (self: any, callback: ((EntityType) -> ())?) -> any,
	deferDestroy: (self: any, entityId: EntityType) -> any,
	deferAdd: (self: any, entityId: EntityType, componentId: EntityType) -> any,
	deferSet: (self: any, entityId: EntityType, componentId: EntityType, value: any) -> any,
	deferRemove: (self: any, entityId: EntityType, componentId: EntityType) -> any,
	flush: (self: any) -> (),
	hasPendingCommands: (self: any) -> boolean,
	addSystem: (self: any, name: string, phase: Scheduler.SystemPhase, dependencies: Scheduler.SystemDependencies, callback: (deltaTime: number) -> ()) -> Scheduler.System,
	removeSystem: (self: any, name: string) -> boolean,
	enableSystem: (self: any, name: string) -> boolean,
	disableSystem: (self: any, name: string) -> boolean,
	runSystems: (self: any, deltaTime: number) -> (),
	runPhase: (self: any, phase: Scheduler.SystemPhase, deltaTime: number) -> (),
	step: (self: any, deltaTime: number) -> (),
	relate: (self: any, source: EntityType, relation: EntityType, target: EntityType, value: any?) -> (),
	unrelate: (self: any, source: EntityType, relation: EntityType, target: EntityType) -> (),
	getRelation: (self: any, source: EntityType, relation: EntityType, target: EntityType) -> any,
	hasRelation: (self: any, source: EntityType, relation: EntityType, target: EntityType) -> boolean,
	getTargets: (self: any, source: EntityType, relation: EntityType) -> { EntityType },
	getSources: (self: any, relation: EntityType, target: EntityType) -> { EntityType },
	prefab: (self: any, name: string?) -> any,
	spawn: (self: any, prefabOrName: any) -> EntityType,
	onAdd: (self: any, componentId: EntityType, callback: (entityId: EntityType, value: any) -> ()) -> () -> (),
	onRemove: (self: any, componentId: EntityType, callback: (entityId: EntityType, value: any) -> ()) -> () -> (),
	onChange: (self: any, componentId: EntityType, callback: (entityId: EntityType, oldValue: any, newValue: any) -> ()) -> () -> (),
	serialize: (self: any, typeHandlers: { [string]: (any) -> any }?) -> SerializedWorld,
	deserialize: (self: any, data: SerializedWorld, typeHandlers: { [string]: (any) -> any }?) -> (),
	each: (self: any, callback: (entityId: EntityType) -> ()) -> (),
}

--[=[
	@interface SerializedWorld
	@within AlloyECS
	.entities { { id: number, components: { { componentId: number, value: any } } } } -- Array of serialized entities
	.relationships { { source: number, relation: number, target: number, value: any? } } -- Array of serialized relationships

	Represents a serialized world state that can be saved and restored.
]=]
export type SerializedWorld = {
	entities: { { id: EntityType, components: { { componentId: EntityType, value: any } } } },
	relationships: { { source: EntityType, relation: EntityType, target: EntityType, value: any? } },
}

--[=[
	@interface QueryBuilder
	@within AlloyECS
	.with (...number) -> QueryBuilder -- Add required components (entities must have these but values won't be returned)
	.without (...number) -> QueryBuilder -- Exclude entities with these components
	.iter () -> QueryIterator -- Execute the query and return an iterator

	A builder for constructing complex queries with filters.

	:::tip Simple Queries
	For most queries, use [World:query] directly. The builder pattern is only needed
	when you need `:with()` or `:without()` filters.
	:::

	```lua
	-- Simple query (preferred for most cases)
	for entityId, pos, vel in world:query(Position, Velocity) do
		-- ...
	end

	-- Complex query with filters
	for entityId, pos in world:query(Position):with(Player):without(Dead):iter() do
		-- Process living players with positions
	end
	```
]=]
export type QueryBuilder = QueryBuilderData & {
	with: (self: QueryBuilder, ...EntityType) -> QueryBuilder,
	without: (self: QueryBuilder, ...EntityType) -> QueryBuilder,
	iter: (self: QueryBuilder) -> QueryIterator,
}

--[=[
	@interface PrefabBuilder
	@within AlloyECS
	.with (componentId: number, value: any?) -> PrefabBuilder -- Add a component or tag to the prefab
	.build (name: string?) -> PrefabData -- Build the prefab, optionally registering it by name

	A builder for constructing entity prefabs (templates).

	```lua
	local enemyPrefab = world:prefab()
		:with(Health, 100)
		:with(Position, Vector3.zero)
		:with(Enemy)
		:build("Enemy")

	local enemy = world:spawn("Enemy")
	```
]=]
export type PrefabBuilder = PrefabBuilderData & {
	with: (self: any, componentId: EntityType, value: any?) -> any,
	build: (self: any, name: string?) -> PrefabData,
}

local WorldMethods: { [string]: any }
local QueryBuilderMethods: { [string]: any }
local QueryBuilderMetatable: { __index: { [string]: any }, __call: (QueryBuilderData) -> QueryIterator }

--[=[
	@function encodeEntityId
	@within AlloyECS
	@param index number -- The entity index (0 to MAX_ENTITY_INDEX)
	@param generation number -- The generation counter (0 to MAX_GENERATION)
	@return number -- The encoded entity ID

	Encodes an entity index and generation into a single entity ID.
	Entity IDs use 24 bits for index and 8 bits for generation.
]=]
local function encodeEntityId(index: number, generation: number): EntityType
	return bit32.bor(index, bit32.lshift(generation, GENERATION_SHIFT))
end

--[=[
	@function decodeEntityIndex
	@within AlloyECS
	@param entityId number -- The entity ID to decode
	@return number -- The entity index portion

	Extracts the index portion from an encoded entity ID.
]=]
local function decodeEntityIndex(entityId: EntityType): number
	return bit32.band(entityId, MAX_ENTITY_INDEX)
end

--[=[
	@function decodeEntityGeneration
	@within AlloyECS
	@param entityId number -- The entity ID to decode
	@return number -- The generation portion

	Extracts the generation portion from an encoded entity ID.
	Useful for checking if an entity ID is stale.
]=]
local function decodeEntityGeneration(entityId: EntityType): number
	return bit32.rshift(entityId, GENERATION_SHIFT)
end

--[=[
	@method entity
	@within World
	@tag Entity
	@return number -- The new entity ID

	Creates a new entity and returns its ID.
	Entity IDs are recycled with incremented generations when entities are destroyed.

	:::info Entity IDs
	Entity IDs encode both an index (24 bits) and a generation (8 bits).
	Use [AlloyECS.decodeEntityIndex] and [AlloyECS.decodeEntityGeneration] to extract these values.
	:::

	```lua
	local entity = world:entity()
	world:set(entity, Position, Vector3.zero)
	```
]=]
local function entity(world: WorldData): EntityType
	local index: number
	local generation: number
	local recycledCount = #world.recycledIndices

	if recycledCount > 0 then
		index = world.recycledIndices[recycledCount]
		world.recycledIndices[recycledCount] = nil
		generation = world.entityGenerations[index]
	else
		index = world.nextEntityIndex
		world.nextEntityIndex += 1
		generation = 0
		world.entityGenerations[index] = generation
	end

	local entityId = encodeEntityId(index, generation)
	world.entityComponents[entityId] = {}
	world.livingEntities[entityId] = true

	local count = world.entityCount + 1
	world.entityCount = count
	world.entityList[count] = entityId
	world.entityListIndex[entityId] = count
	world.queryCacheDirty = true

	return entityId
end

--[=[
	@method isAlive
	@within World
	@tag Entity
	@param entityId number -- The entity ID to check
	@return boolean -- True if the entity exists and is alive

	Checks if an entity is currently alive in the world.

	:::warning Stale Entity IDs
	Always check `isAlive` before using a stored entity ID, as the entity may have been destroyed
	and its ID recycled.
	:::

	```lua
	if world:isAlive(entity) then
		-- Safe to use entity
		local pos = world:get(entity, Position)
	end
	```
]=]
local function isAlive(world: WorldData, entityId: EntityType): boolean
	return world.livingEntities[entityId] == true
end

local removeFromComponentEntityList: (world: WorldData, entityId: EntityType, componentId: EntityType) -> ()

--[=[
	@method destroy
	@within World
	@tag Entity
	@param entityId number -- The entity ID to destroy

	Destroys an entity, removing all its components and relationships.
	The entity's index will be recycled with an incremented generation.

	This will trigger [World:onRemove] hooks for all components on the entity.

	```lua
	world:destroy(entity)
	```
]=]
local function destroy(world: WorldData, entityId: EntityType)
	if not world.livingEntities[entityId] then
		return
	end

	local tracker = world.changeTracker
	local components = world.entityComponents[entityId]
	if components then
		if tracker then
			for componentId in components do
				Reactive.recordRemoved(tracker, entityId, componentId)
			end
		end
		for componentId in components do
			removeFromComponentEntityList(world, entityId, componentId)
		end
	end

	world.entityComponents[entityId] = nil
	world.livingEntities[entityId] = nil
	world.entityBitsets[entityId] = nil

	local entityList = world.entityList
	local entityListIndex = world.entityListIndex
	local count = world.entityCount
	local index = entityListIndex[entityId]
	if index then
		local lastEntity = entityList[count]
		entityList[index] = lastEntity
		entityListIndex[lastEntity] = index
		entityList[count] = nil
		entityListIndex[entityId] = nil
	end

	world.entityCount = count - 1

	world.relationships[entityId] = nil
	for relation, targets in world.relationTargets do
		targets[entityId] = nil
		for target, sources in targets do
			for i = #sources, 1, -1 do
				if sources[i] == entityId then
					table.remove(sources, i)
				end
			end
		end
	end

	local entityIndex = decodeEntityIndex(entityId)
	local newGeneration = (world.entityGenerations[entityIndex] + 1) % (MAX_GENERATION + 1)
	world.entityGenerations[entityIndex] = newGeneration
	world.recycledIndices[#world.recycledIndices + 1] = entityIndex
	world.queryCacheDirty = true
end

--[=[
	@method getEntityCount
	@within World
	@tag Entity
	@return number -- The number of living entities

	Returns the total number of living entities in the world.

	```lua
	print("Entities:", world:getEntityCount())
	```
]=]
local function getEntityCount(world: WorldData): number
	return world.entityCount
end

--[=[
	@method getEntities
	@within World
	@tag Entity
	@return {number} -- Array of all living entity IDs

	Returns an array containing all living entity IDs.

	:::tip Performance
	For iteration, consider using [World:each] or [World:query] instead,
	as they don't create a new array.
	:::

	```lua
	for _, entityId in world:getEntities() do
		print(entityId)
	end
	```
]=]
local function getEntities(world: WorldData): { EntityType }
	local result = table.create(world.entityCount)
	for i = 1, world.entityCount do
		result[i] = world.entityList[i]
	end
	return result
end

--[=[
	@method component
	@within World
	@tag Component
	@param config { storage: "sparse" | "dense" | "tag" }? -- Optional configuration
	@return number -- The component ID

	Creates a new component type and returns its ID.

	| Storage Type | Description | Use Case |
	|--------------|-------------|----------|
	| `"sparse"` | Standard component with data (default) | Most components |
	| `"dense"` | Optimized for components on most entities | Components on 50%+ entities |
	| `"tag"` | No data, just marks entities | Flags like `Player`, `Enemy` |

	:::tip Tags
	For tag components (no data), use [World:tag] as a shorthand.
	:::

	```lua
	local Position = world:component()
	local Health = world:component({ storage = "sparse" })
	local Visible = world:component({ storage = "tag" })
	```
]=]
local function component(world: WorldData, config: ComponentConfig?): EntityType
	local componentId = world.nextComponentId
	world.nextComponentId += 1

	local storageType: StorageType = if config and config.storage then config.storage else "sparse"

	if storageType == "tag" then
		world.tagComponents[componentId] = true
	end

	world.componentConfigs[componentId] = config or { storage = storageType }

	local bitIndex = world.nextBitIndex
	world.nextBitIndex += 1
	world.componentBitIndex[componentId] = bitIndex
	world.componentEntityLists[componentId] = {}
	world.componentEntityIndex[componentId] = {}

	return componentId
end

--[=[
	@method tag
	@within World
	@tag Component
	@return number -- The tag component ID

	Creates a new tag component (a component with no data).
	Tags are useful for marking entities without storing any values.

	This is equivalent to `world:component({ storage = "tag" })`.

	```lua
	local Player = world:tag()
	local Enemy = world:tag()

	world:add(entity, Player)

	-- Tags work in queries but return nil for their value
	for entityId in world:query(Player) do
		print("Found player:", entityId)
	end
	```
]=]
local function tag(world: WorldData): EntityType
	return component(world, { storage = "tag" })
end

--[=[
	@method isTag
	@within World
	@tag Component
	@param componentId number -- The component ID to check
	@return boolean -- True if the component is a tag

	Checks if a component is a tag (has no data).

	```lua
	if world:isTag(componentId) then
		world:add(entity, componentId)
	else
		world:set(entity, componentId, defaultValue)
	end
	```
]=]
local function isTag(world: WorldData, componentId: EntityType): boolean
	return world.tagComponents[componentId] == true
end

local function invalidateQueriesForComponent(world: WorldData, componentId: EntityType)
	local keys = world.queryCacheByComponent[componentId]
	if keys then
		local queryCache = world.queryCache
		for _, key in keys do
			queryCache[key] = nil
		end
	end
	world.queryCacheDirty = true
end

local function updateEntityBitset(world: WorldData, entityId: EntityType, componentId: EntityType, added: boolean)
	local bitIndex = world.componentBitIndex[componentId]

	if bitIndex then
		local bitset = world.entityBitsets[entityId]

		if not bitset then
			if not added then
				return
			end

			bitset = Bitset.create(64)
			world.entityBitsets[entityId] = bitset
		end

		if added then
			Bitset.set(bitset, bitIndex)
		else
			Bitset.clear(bitset, bitIndex)
		end
	end
end

local function fireHooks(hooks: { (EntityType, any) -> () }?, entityId: EntityType, value: any)
	if hooks then
		for _, callback in hooks do
			callback(entityId, value)
		end
	end
end

local function fireChangeHooks(hooks: { (EntityType, any, any) -> () }?, entityId: EntityType, oldValue: any, newValue: any)
	if hooks then
		for _, callback in hooks do
			callback(entityId, oldValue, newValue)
		end
	end
end

local function addToComponentEntityList(world: WorldData, entityId: EntityType, componentId: EntityType)
	local entityList = world.componentEntityLists[componentId]
	local entityIndex = world.componentEntityIndex[componentId]

	if entityList and entityIndex and not entityIndex[entityId] then
		local idx = #entityList + 1
		entityList[idx] = entityId
		entityIndex[entityId] = idx
	end
end

removeFromComponentEntityList = function(world: WorldData, entityId: EntityType, componentId: EntityType)
	local entityList = world.componentEntityLists[componentId]
	local entityIndex = world.componentEntityIndex[componentId]

	if entityList and entityIndex then
		local idx = entityIndex[entityId]

		if idx then
			local lastIdx = #entityList

			if idx ~= lastIdx then
				local lastEntity = entityList[lastIdx]
				entityList[idx] = lastEntity
				entityIndex[lastEntity] = idx
			end
			entityList[lastIdx] = nil
			entityIndex[entityId] = nil
		end
	end
end

--[=[
	@method add
	@within World
	@tag Component
	@param entityId number -- The entity to add the component to
	@param componentId number -- The component/tag to add

	Adds a tag or component (with value `true`) to an entity.
	Use [World:set] instead if you need to store a specific value.

	Triggers [World:onAdd] hooks.

	```lua
	world:add(entity, Player)
	world:add(entity, Visible)
	```
]=]
local function add(world: WorldData, entityId: EntityType, componentId: EntityType)
	local components = world.entityComponents[entityId]

	if not components then
		if world.debug then
			warn("AlloyECS: Attempted to add component to non-existent entity", entityId)
		end
		return
	end

	if components[componentId] ~= nil then
		return
	end

	components[componentId] = true
	updateEntityBitset(world, entityId, componentId, true)
	addToComponentEntityList(world, entityId, componentId)
	invalidateQueriesForComponent(world, componentId)

	local tracker = world.changeTracker
	if tracker then
		Reactive.recordAdded(tracker, entityId, componentId)
	end

	fireHooks(world.onAddHooks[componentId], entityId, true)
end

--[=[
	@method set
	@within World
	@tag Component
	@param entityId number -- The entity to set the component on
	@param componentId number -- The component ID
	@param value any -- The value to store

	Sets a component value on an entity. If the entity doesn't have the component,
	it will be added.

	- Triggers [World:onAdd] hook if the component is new
	- Triggers [World:onChange] hook if updating an existing value

	```lua
	world:set(entity, Position, Vector3.new(0, 10, 0))
	world:set(entity, Health, 100)
	```
]=]
local function set(world: WorldData, entityId: EntityType, componentId: EntityType, value: any)
	local components = world.entityComponents[entityId]

	if not components then
		if world.debug then
			warn("AlloyECS: Attempted to set component on non-existent entity", entityId)
		end

		return
	end

	local oldValue = components[componentId]
	local hadComponent = oldValue ~= nil
	components[componentId] = value

	local tracker = world.changeTracker
	if tracker then
		if hadComponent then
			Reactive.recordChanged(tracker, entityId, componentId)
		else
			Reactive.recordAdded(tracker, entityId, componentId)
			updateEntityBitset(world, entityId, componentId, true)
			addToComponentEntityList(world, entityId, componentId)
			invalidateQueriesForComponent(world, componentId)
		end
	elseif not hadComponent then
		updateEntityBitset(world, entityId, componentId, true)
		addToComponentEntityList(world, entityId, componentId)
		invalidateQueriesForComponent(world, componentId)
	end

	if hadComponent then
		fireChangeHooks(world.onChangeHooks[componentId], entityId, oldValue, value)
	else
		fireHooks(world.onAddHooks[componentId], entityId, value)
	end
end

--[=[
	@method get
	@within World
	@tag Component
	@param entityId number -- The entity to get the component from
	@param componentId number -- The component ID
	@return any -- The component value, or nil if not present

	Gets a component value from an entity. Returns nil for tags or missing components.

	:::info Tags
	For tags, use [World:has] to check presence since `get` returns nil.
	:::

	```lua
	local pos = world:get(entity, Position)
	if pos then
		print(pos.X, pos.Y, pos.Z)
	end
	```
]=]
local function get(world: WorldData, entityId: EntityType, componentId: EntityType): any
	local components = world.entityComponents[entityId]

	if not components then
		return nil
	end

	if world.tagComponents[componentId] then
		return nil
	end

	return components[componentId]
end

--[=[
	@method has
	@within World
	@tag Component
	@param entityId number -- The entity to check
	@param ... number -- One or more component IDs
	@return boolean -- True if the entity has all specified components

	Checks if an entity has one or more components (including tags).

	```lua
	-- Check single component
	if world:has(entity, Position) then
		-- ...
	end

	-- Check multiple components
	if world:has(entity, Position, Velocity) then
		-- Entity has both Position and Velocity
	end

	-- Works with tags too
	if world:has(entity, Player) then
		-- Entity is a player
	end
	```
]=]
local function has(world: WorldData, entityId: EntityType, ...: EntityType): boolean
	local components = world.entityComponents[entityId]

	if not components then
		return false
	end

	local count = select("#", ...)

	if count == 1 then
		return components[...] ~= nil
	end

	for i = 1, count do
		local componentId = select(i, ...)
		if components[componentId] == nil then
			return false
		end
	end

	return true
end

--[=[
	@method remove
	@within World
	@tag Component
	@param entityId number -- The entity to remove the component from
	@param componentId number -- The component ID to remove

	Removes a component from an entity.

	Triggers [World:onRemove] hook with the old value.

	```lua
	world:remove(entity, Velocity)
	```
]=]
local function remove(world: WorldData, entityId: EntityType, componentId: EntityType)
	local components = world.entityComponents[entityId]

	if not components then
		if world.debug then
			warn("AlloyECS: Attempted to remove component from non-existent entity", entityId)
		end
		return
	end

	local oldValue = components[componentId]

	if oldValue == nil then
		return
	end

	components[componentId] = nil
	updateEntityBitset(world, entityId, componentId, false)
	removeFromComponentEntityList(world, entityId, componentId)
	invalidateQueriesForComponent(world, componentId)

	local tracker = world.changeTracker
	if tracker then
		Reactive.recordRemoved(tracker, entityId, componentId)
	end

	fireHooks(world.onRemoveHooks[componentId], entityId, oldValue)
end

local function getQueryCacheKey(components: { EntityType }, excludeComponents: { EntityType }?): string
	local count = #components

	if count == 1 and not excludeComponents then
		return tostring(components[1])
	elseif count == 2 and not excludeComponents then
		local a, b = components[1], components[2]
		if a > b then
			a, b = b, a
		end

		return tostring(a) .. "," .. tostring(b)
	end

	local sorted = table.clone(components)
	table.sort(sorted)
	local key = table.concat(sorted, ",")

	if excludeComponents and #excludeComponents > 0 then
		local sortedExclude = table.clone(excludeComponents)
		table.sort(sortedExclude)
		key = key .. "|" .. table.concat(sortedExclude, ",")
	end

	return key
end

local function getQueryCacheKeyWithFilter(components: { EntityType }, excludeComponents: { EntityType }?, withComponents: { EntityType }?): string
	local key = getQueryCacheKey(components, excludeComponents)

	if withComponents and #withComponents > 0 then
		local sortedWith = table.clone(withComponents)
		table.sort(sortedWith)
		key = key .. "&" .. table.concat(sortedWith, ",")
	end

	return key
end

local function buildQueryResultsWithFilter(world: WorldData, includeComponents: { EntityType }, excludeComponents: { EntityType }?, withComponents: { EntityType }?): { EntityType }
	local results: { EntityType } = {}
	local resultCount = 0

	local entityComponents = world.entityComponents
	local entityBitsets = world.entityBitsets
	local componentBitIndex = world.componentBitIndex
	local componentEntityLists = world.componentEntityLists

	local includeCount = #includeComponents
	local hasExclude = excludeComponents and #excludeComponents > 0
	local hasWithFilter = withComponents and #withComponents > 0

	local requiredMask: Bitset.Bitset? = nil
	local excludeMask: Bitset.Bitset? = nil

	if includeCount > 0 then
		requiredMask = Bitset.create(64)

		for _, compId in includeComponents do
			local bitIdx = componentBitIndex[compId]
			if bitIdx and requiredMask then
				Bitset.set(requiredMask, bitIdx)
			end
		end
	end

	if hasWithFilter then
		if not requiredMask then
			requiredMask = Bitset.create(64)
		end

		for _, compId in withComponents :: { EntityType } do
			local bitIdx = componentBitIndex[compId]
			if bitIdx and requiredMask then
				Bitset.set(requiredMask, bitIdx)
			end
		end
	end

	if hasExclude then
		excludeMask = Bitset.create(64)
		for _, compId in excludeComponents :: { EntityType } do
			local bitIdx = componentBitIndex[compId]
			if bitIdx and excludeMask then
				Bitset.set(excludeMask, bitIdx)
			end
		end
	end

	local smallestList: { EntityType }? = nil
	local smallestCount = math.huge

	for _, compId in includeComponents do
		local compList = componentEntityLists[compId]
		if compList then
			local listCount = #compList
			if listCount < smallestCount then
				smallestCount = listCount
				smallestList = compList
			end
		end
	end

	if hasWithFilter then
		for _, compId in withComponents :: { EntityType } do
			local compList = componentEntityLists[compId]
			if compList then
				local listCount = #compList
				if listCount < smallestCount then
					smallestCount = listCount
					smallestList = compList
				end
			end
		end
	end

	if smallestList and smallestCount < world.entityCount * 0.5 then
		for _, eid in smallestList do
			local entityBitset = entityBitsets[eid]
			if entityBitset and requiredMask then
				if not Bitset.containsAll(entityBitset, requiredMask) then
					continue
				end
			end

			if excludeMask and entityBitset then
				if Bitset.containsAny(entityBitset, excludeMask) then
					continue
				end
			end

			resultCount += 1
			results[resultCount] = eid
		end

		return results
	end

	local entityList = world.entityList
	local entityCount = world.entityCount

	if includeCount == 1 and not hasExclude and not hasWithFilter then
		local comp = includeComponents[1]

		for i = 1, entityCount do
			local eid = entityList[i]
			local components = entityComponents[eid]

			if components and components[comp] ~= nil then
				resultCount += 1
				results[resultCount] = eid
			end
		end

		return results
	end

	for i = 1, entityCount do
		local eid = entityList[i]
		local entityBitset = entityBitsets[eid]
		if requiredMask then
			if not entityBitset or not Bitset.containsAll(entityBitset, requiredMask) then
				continue
			end
		end

		if excludeMask then
			if entityBitset and Bitset.containsAny(entityBitset, excludeMask) then
				continue
			end
		end

		resultCount += 1
		results[resultCount] = eid
	end

	return results
end

local function registerQueryCacheKey(world: WorldData, cacheKey: string, includeComponents: { EntityType }, excludeComponents: { EntityType }?, withComponents: { EntityType }?)
	local queryCacheByComponent = world.queryCacheByComponent

	for _, compId in includeComponents do
		local keys = queryCacheByComponent[compId]

		if not keys then
			keys = {}
			queryCacheByComponent[compId] = keys
		end

		table.insert(keys, cacheKey)
	end

	if excludeComponents then
		for _, compId in excludeComponents do
			local keys = queryCacheByComponent[compId]

			if not keys then
				keys = {}
				queryCacheByComponent[compId] = keys
			end

			table.insert(keys, cacheKey)
		end
	end

	if withComponents then
		for _, compId in withComponents do
			local keys = queryCacheByComponent[compId]

			if not keys then
				keys = {}
				queryCacheByComponent[compId] = keys
			end

			table.insert(keys, cacheKey)
		end
	end
end

--[=[
	@method query
	@within World
	@tag Query
	@param ... number -- Component IDs to query for
	@return QueryBuilder -- A query object that can be iterated directly or filtered with `:with()` / `:without()`

	Queries for entities that have all specified components.
	Returns a query object that yields the entity ID followed by component values.

	```lua
	-- Simple query (direct iteration)
	for entityId, position in world:query(Position) do
		print(entityId, position)
	end

	-- Multiple components
	for entityId, pos, vel in world:query(Position, Velocity) do
		world:set(entityId, Position, pos + vel * deltaTime)
	end

	-- With filters (call :iter() after filters)
	for entityId, pos in world:query(Position):with(Player):without(Dead):iter() do
		-- Only living players with Position
	end
	```

	:::tip Query Caching
	Queries are cached for performance. The cache is automatically
	invalidated when entities or components change.
	:::

	:::info Filter Methods
	The query result supports chainable filter methods:
	- `:with(...)` - Require components without returning their values
	- `:without(...)` - Exclude entities with these components
	- `:iter()` - Execute the filtered query (required when using filters)
	:::
]=]
local function query(world: WorldData, ...: EntityType): QueryBuilder
	local builder: QueryBuilderData = {
		world = world,
		includeComponents = { ... },
		excludeComponents = {},
		withComponents = {},
	}

	return setmetatable(builder :: any, QueryBuilderMetatable) :: QueryBuilder
end

--[=[
	@method queryBuilder
	@within World
	@tag Query
	@tag Advanced
	@param ... number -- Component IDs to query for (values will be returned)
	@return QueryBuilder -- A query builder for adding filters

	Creates a query builder for more complex queries with filters.

	:::tip Use query() Instead
	[World:query] now supports the same `:with()` and `:without()` modifiers.
	This method is provided for backwards compatibility.
	:::

	```lua
	-- Preferred: use query() directly
	for entityId, pos in world:query(Position):with(Player):without(Dead):iter() do
		-- pos is returned, Player is required but not returned
	end

	-- Also works: explicit queryBuilder
	for entityId, pos in world:queryBuilder(Position):with(Player):without(Dead):iter() do
		-- Same result
	end
	```
]=]
local function queryBuilder(world: WorldData, ...: EntityType): QueryBuilderData
	local builder: QueryBuilderData = {
		world = world,
		includeComponents = { ... },
		excludeComponents = {},
		withComponents = {},
	}

	return setmetatable(builder :: any, QueryBuilderMetatable)
end

local function withFilter(builder: QueryBuilderData, ...: EntityType): QueryBuilderData
	local withComps = builder.withComponents
	for i = 1, select("#", ...) do
		withComps[#withComps + 1] = select(i, ...)
	end

	return builder
end

local function without(builder: QueryBuilderData, ...: EntityType): QueryBuilderData
	local exclude = builder.excludeComponents
	for i = 1, select("#", ...) do
		exclude[#exclude + 1] = select(i, ...)
	end

	return builder
end

local function iter(builder: QueryBuilderData): QueryIterator
	local world = builder.world
	local includeComponents = builder.includeComponents
	local excludeComponents = if #builder.excludeComponents > 0 then builder.excludeComponents else nil
	local withComponents = if #builder.withComponents > 0 then builder.withComponents else nil
	local componentCount = #includeComponents

	if componentCount == 0 then
		return function(): (EntityType?, ...any)
			return nil
		end
	end

	local cacheKey = getQueryCacheKeyWithFilter(includeComponents, excludeComponents, withComponents)
	local entities: { EntityType }

	if world.queryCacheDirty then
		table.clear(world.queryCache)
		table.clear(world.queryCacheByComponent)
		world.queryCacheDirty = false
	end

	entities = world.queryCache[cacheKey]
	if not entities then
		entities = buildQueryResultsWithFilter(world, includeComponents, excludeComponents, withComponents)
		world.queryCache[cacheKey] = entities
		registerQueryCacheKey(world, cacheKey, includeComponents, excludeComponents, withComponents)
	end

	local entityCount = #entities
	local index = 0
	local entityComponents = world.entityComponents
	local tagComponents = world.tagComponents

	local isTags: { boolean } = {}
	for i, comp in includeComponents do
		isTags[i] = tagComponents[comp] == true
	end

	if componentCount == 1 then
		local comp = includeComponents[1]
		local isTagComp = isTags[1]
		if isTagComp then
			return function(): (EntityType?, ...any)
				index += 1
				if index > entityCount then
					return nil
				end

				return entities[index]
			end
		end

		return function(): (EntityType?, ...any)
			index += 1
			if index > entityCount then
				return nil
			end

			local eid = entities[index]
			return eid, entityComponents[eid][comp]
		end

	elseif componentCount == 2 then
		local comp1, comp2 = includeComponents[1], includeComponents[2]
		local isTag1, isTag2 = isTags[1], isTags[2]

		return function(): (EntityType?, ...any)
			index += 1
			if index > entityCount then
				return nil
			end
            
			local eid = entities[index]
			local comps = entityComponents[eid]
			local val1 = if isTag1 then nil else comps[comp1]
			local val2 = if isTag2 then nil else comps[comp2]

			return eid, val1, val2
		end
	else
		return function(): (EntityType?, ...any)
			index += 1
			if index > entityCount then
				return nil
			end

			local eid = entities[index]
			local comps = entityComponents[eid]
			local values: { any } = table.create(componentCount)

			for i = 1, componentCount do
				values[i] = if isTags[i] then nil else comps[includeComponents[i]]
			end

			return eid, table.unpack(values)
		end
	end
end

--[=[
	@method added
	@within World
	@tag Reactive
	@param componentId number -- The component ID to check
	@return {number} -- Array of entity IDs that had this component added

	Returns entities that had the specified component added this frame.

	:::warning Requires Change Tracking
	This method requires `trackChanges = true` in [AlloyECS.createWorld] config.
	:::

	```lua
	for _, entityId in world:added(Position) do
		print("Entity gained Position:", entityId)
	end
	```
]=]
local function added(world: WorldData, componentId: EntityType): { EntityType }
	local tracker = world.changeTracker
	if tracker then
		return Reactive.getAdded(tracker, componentId)
	end
	return {}
end

--[=[
	@method removed
	@within World
	@tag Reactive
	@param componentId number -- The component ID to check
	@return {number} -- Array of entity IDs that had this component removed

	Returns entities that had the specified component removed this frame.

	:::warning Requires Change Tracking
	This method requires `trackChanges = true` in [AlloyECS.createWorld] config.
	:::

	```lua
	for _, entityId in world:removed(Health) do
		print("Entity lost Health:", entityId)
	end
	```
]=]
local function removed(world: WorldData, componentId: EntityType): { EntityType }
	local tracker = world.changeTracker
	if tracker then
		return Reactive.getRemoved(tracker, componentId)
	end
	return {}
end

--[=[
	@method changed
	@within World
	@tag Reactive
	@param componentId number -- The component ID to check
	@return {number} -- Array of entity IDs that had this component changed

	Returns entities that had the specified component value changed this frame.

	:::warning Requires Change Tracking
	This method requires `trackChanges = true` in [AlloyECS.createWorld] config.
	:::

	```lua
	for _, entityId in world:changed(Position) do
		print("Entity moved:", entityId)
	end
	```
]=]
local function changed(world: WorldData, componentId: EntityType): { EntityType }
	local tracker = world.changeTracker
	if tracker then
		return Reactive.getChanged(tracker, componentId)
	end
	return {}
end

--[=[
	@method clearChanges
	@within World
	@tag Reactive

	Clears all tracked changes for the current frame.
	Call this at the end of each frame after processing changes.

	:::tip Automatic Clearing
	[World:step] calls this automatically. Only call manually if you're
	not using `step()`.
	:::

	```lua
	-- Process changes
	for _, entityId in world:added(Position) do
		-- Handle new positions
	end

	-- Clear for next frame
	world:clearChanges()
	```
]=]
local function clearChanges(world: WorldData)
	local tracker = world.changeTracker
	if tracker then
		Reactive.clearFrame(tracker)
	end
	world.queryCacheDirty = false
end

--[=[
	@method defer
	@within World
	@tag Deferred

	Enables deferred mode. In deferred mode, use the `defer*` methods
	to queue operations that will be executed when [World:flush] is called.

	:::info Use Case
	Deferred operations are useful during iteration when you can't safely
	modify entities being queried.
	:::
]=]
local function defer(world: WorldData)
	world.deferredMode = true
end

--[=[
	@method deferSpawn
	@within World
	@tag Deferred
	@param callback ((entityId: number) -> ())? -- Optional callback with the new entity ID
	@return World -- Returns self for chaining

	Queues an entity spawn operation. The callback receives the entity ID when flushed.

	```lua
	world:deferSpawn(function(entityId)
		world:deferSet(entityId, Position, Vector3.zero)
	end)
	```
]=]
local function deferSpawn(world: WorldData, callback: ((EntityType) -> ())?): WorldData
	CommandBuffer.spawn(world.commandBuffer, callback)
	return world
end

--[=[
	@method deferDestroy
	@within World
	@tag Deferred
	@param entityId number -- The entity to destroy
	@return World -- Returns self for chaining

	Queues an entity destroy operation.

	```lua
	for entityId, health in world:query(Health) do
		if health <= 0 then
			world:deferDestroy(entityId)
		end
	end
	world:flush()
	```
]=]
local function deferDestroy(world: WorldData, entityId: EntityType): WorldData
	CommandBuffer.destroy(world.commandBuffer, entityId)
	return world
end

--[=[
	@method deferAdd
	@within World
	@tag Deferred
	@param entityId number -- The entity to add the component to
	@param componentId number -- The component to add
	@return World -- Returns self for chaining

	Queues a component add operation.

	```lua
	world:deferAdd(entity, Player)
	```
]=]
local function deferAdd(world: WorldData, entityId: EntityType, componentId: EntityType): WorldData
	CommandBuffer.add(world.commandBuffer, entityId, componentId)
	return world
end

--[=[
	@method deferSet
	@within World
	@tag Deferred
	@param entityId number -- The entity to set the component on
	@param componentId number -- The component ID
	@param value any -- The value to set
	@return World -- Returns self for chaining

	Queues a component set operation.

	```lua
	world:deferSet(entity, Position, newPosition)
	```
]=]
local function deferSet(world: WorldData, entityId: EntityType, componentId: EntityType, value: any): WorldData
	CommandBuffer.set(world.commandBuffer, entityId, componentId, value)
	return world
end

--[=[
	@method deferRemove
	@within World
	@tag Deferred
	@param entityId number -- The entity to remove the component from
	@param componentId number -- The component to remove
	@return World -- Returns self for chaining

	Queues a component remove operation.

	```lua
	world:deferRemove(entity, Velocity)
	```
]=]
local function deferRemove(world: WorldData, entityId: EntityType, componentId: EntityType): WorldData
	CommandBuffer.remove(world.commandBuffer, entityId, componentId)
	return world
end

--[=[
	@method flush
	@within World
	@tag Deferred

	Executes all queued deferred operations and exits deferred mode.

	:::tip Automatic Flushing
	[World:step] calls flush automatically. Only call manually if you're
	not using `step()`.
	:::

	```lua
	world:defer()
	world:deferSpawn()
	world:deferSet(entity, Position, pos)
	world:flush() -- All operations execute here
	```
]=]
local function flush(world: WorldData)
	local executor: CommandBuffer.CommandExecutor = {
		spawn = function()
			return entity(world)
		end,
		destroy = function(eid)
			destroy(world, eid)
		end,
		add = function(eid, cid)
			add(world, eid, cid)
		end,
		set = function(eid, cid, value)
			set(world, eid, cid, value)
		end,
		remove = function(eid, cid)
			remove(world, eid, cid)
		end,
	}
	CommandBuffer.execute(world.commandBuffer, executor)
	world.deferredMode = false
end

--[=[
	@method hasPendingCommands
	@within World
	@tag Deferred
	@return boolean -- True if there are pending deferred commands

	Checks if there are any pending deferred commands to execute.

	```lua
	if world:hasPendingCommands() then
		world:flush()
	end
	```
]=]
local function hasPendingCommands(world: WorldData): boolean
	return not CommandBuffer.isEmpty(world.commandBuffer)
end

--[=[
	@method addSystem
	@within World
	@tag System
	@param name string -- Unique name for the system
	@param phase "PreUpdate" | "Update" | "PostUpdate" | "PreRender" | "Render" -- Execution phase
	@param dependencies { reads: {number}?, writes: {number}? } -- Component dependencies
	@param callback (deltaTime: number) -> () -- System function
	@return System -- The created system

	Adds a system to the scheduler. Systems are batched by phase and can run
	in parallel if they don't have conflicting dependencies.

	| Phase | Description |
	|-------|-------------|
	| `"PreUpdate"` | Before main update logic |
	| `"Update"` | Main game logic |
	| `"PostUpdate"` | After main update logic |
	| `"PreRender"` | Before rendering |
	| `"Render"` | Rendering logic |

	```lua
	world:addSystem("Movement", "Update", {
		reads = { Position, Velocity },
		writes = { Position }
	}, function(dt)
		for entityId, pos, vel in world:query(Position, Velocity) do
			world:set(entityId, Position, pos + vel * dt)
		end
	end)
	```
]=]
local function addSystem(
	world: WorldData,
	name: string,
	phase: Scheduler.SystemPhase,
	dependencies: Scheduler.SystemDependencies,
	callback: (deltaTime: number) -> ()
): Scheduler.System
	return Scheduler.addSystem(world.scheduler, name, phase, dependencies, callback)
end

--[=[
	@method removeSystem
	@within World
	@tag System
	@param name string -- The name of the system to remove
	@return boolean -- True if the system was found and removed

	Removes a system from the scheduler.

	```lua
	world:removeSystem("Movement")
	```
]=]
local function removeSystem(world: WorldData, name: string): boolean
	return Scheduler.removeSystem(world.scheduler, name)
end

--[=[
	@method enableSystem
	@within World
	@tag System
	@param name string -- The name of the system to enable
	@return boolean -- True if the system was found and enabled

	Enables a previously disabled system.

	```lua
	world:enableSystem("AI")
	```
]=]
local function enableSystem(world: WorldData, name: string): boolean
	return Scheduler.enableSystem(world.scheduler, name)
end

--[=[
	@method disableSystem
	@within World
	@tag System
	@param name string -- The name of the system to disable
	@return boolean -- True if the system was found and disabled

	Disables a system without removing it. Disabled systems won't run.

	:::tip Use Case
	Useful for pausing specific systems, e.g., disabling AI during cutscenes.
	:::

	```lua
	world:disableSystem("AI")
	```
]=]
local function disableSystem(world: WorldData, name: string): boolean
	return Scheduler.disableSystem(world.scheduler, name)
end

--[=[
	@method runSystems
	@within World
	@tag System
	@param deltaTime number -- Time since last frame

	Runs all enabled systems in all phases.

	:::tip Use step() Instead
	[World:step] handles flushing, running systems, and clearing changes.
	Use this only if you need manual control.
	:::
]=]
local function runSystems(world: WorldData, deltaTime: number)
	Scheduler.runAll(world.scheduler, deltaTime)
end

--[=[
	@method runPhase
	@within World
	@tag System
	@param phase "PreUpdate" | "Update" | "PostUpdate" | "PreRender" | "Render" -- The phase to run
	@param deltaTime number -- Time since last frame

	Runs all enabled systems in a specific phase only.

	```lua
	-- Run only render systems
	world:runPhase("Render", dt)
	```
]=]
local function runPhase(world: WorldData, phase: Scheduler.SystemPhase, deltaTime: number)
	Scheduler.runPhase(world.scheduler, phase, deltaTime)
end

--[=[
	@method step
	@within World
	@tag System
	@param deltaTime number -- Time since last frame

	Performs a complete world update step:

	1. Flushes any pending deferred commands ([World:flush])
	2. Runs all systems ([World:runSystems])
	3. Clears change tracking ([World:clearChanges])

	```lua
	RunService.Heartbeat:Connect(function(dt)
		world:step(dt)
	end)
	```
]=]
local function step(world: WorldData, deltaTime: number)
	if hasPendingCommands(world) then
		flush(world)
	end

	runSystems(world, deltaTime)
	clearChanges(world)
end

--[=[
	@method relate
	@within World
	@tag Relationship
	@param source number -- The source entity
	@param relation number -- The relation type (a component ID)
	@param target number -- The target entity
	@param value any? -- Optional data to store with the relationship

	Creates a relationship between two entities.
	Relationships can optionally store data.

	:::info Relation Types
	Use [World:component] to create relation types. They work like components
	but connect two entities together.
	:::

	```lua
	local ChildOf = world:component()
	local Likes = world:component()

	-- Simple relationship
	world:relate(child, ChildOf, parent)

	-- Relationship with data
	world:relate(player, Likes, item, { amount = 10 })

	-- Get all children
	for _, child in world:getSources(ChildOf, parent) do
		print("Child:", child)
	end
	```
]=]
local function relate(world: WorldData, source: EntityType, relation: EntityType, target: EntityType, value: any?)
	if not world.livingEntities[source] then
		if world.debug then
			warn("AlloyECS: Attempted to create relation from non-existent entity", source)
		end
		return
	end

	local sourceRels = world.relationships[source]
	if not sourceRels then
		sourceRels = {}
		world.relationships[source] = sourceRels
	end
	local relationMap = sourceRels[relation]
	if not relationMap then
		relationMap = {}
		sourceRels[relation] = relationMap
	end

	relationMap[target] = value ~= nil and value or true

	local relTargets = world.relationTargets[relation]
	if not relTargets then
		relTargets = {}
		world.relationTargets[relation] = relTargets
	end
	local sources = relTargets[target]
	if not sources then
		sources = {}
		relTargets[target] = sources
	end

	local found = false
	for _, s in sources do
		if s == source then
			found = true
			break
		end
	end

	if not found then
		table.insert(sources, source)
	end

	world.queryCacheDirty = true
end

--[=[
	@method unrelate
	@within World
	@tag Relationship
	@param source number -- The source entity
	@param relation number -- The relation type
	@param target number -- The target entity

	Removes a relationship between two entities.

	```lua
	world:unrelate(child, ChildOf, parent)
	```
]=]
local function unrelate(world: WorldData, source: EntityType, relation: EntityType, target: EntityType)
	local sourceRels = world.relationships[source]
	if not sourceRels then
		return
	end

	local relationMap = sourceRels[relation]
	if not relationMap then
		return
	end

	relationMap[target] = nil

	local relTargets = world.relationTargets[relation]
	if relTargets then
		local sources = relTargets[target]
		if sources then
			for i, s in sources do
				if s == source then
					table.remove(sources, i)
					break
				end
			end
		end
	end

	world.queryCacheDirty = true
end

--[=[
	@method getRelation
	@within World
	@tag Relationship
	@param source number -- The source entity
	@param relation number -- The relation type
	@param target number -- The target entity
	@return any -- The relationship data, or nil

	Gets the data stored in a relationship, if any.

	```lua
	local likeData = world:getRelation(player, Likes, item)
	if likeData then
		print("Like amount:", likeData.amount)
	end
	```
]=]
local function getRelation(world: WorldData, source: EntityType, relation: EntityType, target: EntityType): any
	local sourceRels = world.relationships[source]
	if not sourceRels then
		return nil
	end

	local relationMap = sourceRels[relation]
	if not relationMap then
		return nil
	end

	local value = relationMap[target]
	return if value == true then nil else value
end

--[=[
	@method hasRelation
	@within World
	@tag Relationship
	@param source number -- The source entity
	@param relation number -- The relation type
	@param target number -- The target entity
	@return boolean -- True if the relationship exists

	Checks if a relationship exists between two entities.

	```lua
	if world:hasRelation(child, ChildOf, parent) then
		print("Is a child of parent")
	end
	```
]=]
local function hasRelation(world: WorldData, source: EntityType, relation: EntityType, target: EntityType): boolean
	local sourceRels = world.relationships[source]
	if not sourceRels then
		return false
	end

	local relationMap = sourceRels[relation]
	if not relationMap then
		return false
	end

	return relationMap[target] ~= nil
end

--[=[
	@method getTargets
	@within World
	@tag Relationship
	@param source number -- The source entity
	@param relation number -- The relation type
	@return {number} -- Array of target entity IDs

	Gets all target entities that the source has a relationship with.

	```lua
	-- Get all items this player likes
	local likedItems = world:getTargets(player, Likes)
	for _, item in likedItems do
		print("Likes:", item)
	end
	```
]=]
local function getTargets(world: WorldData, source: EntityType, relation: EntityType): { EntityType }
	local results: { EntityType } = {}

	local sourceRels = world.relationships[source]
	if not sourceRels then
		return results
	end

	local relationMap = sourceRels[relation]
	if not relationMap then
		return results
	end

	for target in relationMap do
		table.insert(results, target)
	end
	return results
end

--[=[
	@method getSources
	@within World
	@tag Relationship
	@param relation number -- The relation type
	@param target number -- The target entity
	@return {number} -- Array of source entity IDs

	Gets all source entities that have a relationship to the target.

	```lua
	-- Get all children of this parent
	local children = world:getSources(ChildOf, parent)
	for _, child in children do
		print("Child:", child)
	end
	```
]=]
local function getSources(world: WorldData, relation: EntityType, target: EntityType): { EntityType }
	local relTargets = world.relationTargets[relation]
	if not relTargets then
		return {}
	end

	local sources = relTargets[target]
	if not sources then
		return {}
	end

	return table.clone(sources)
end

local PrefabBuilderMethods: { [string]: any }

local function prefabWith(builder: PrefabBuilderData, componentId: EntityType, value: any?): PrefabBuilderData
	if value ~= nil then
		table.insert(builder.components, { componentId = componentId, value = value })
	else
		table.insert(builder.tags, componentId)
	end
	return builder
end

local function prefabBuild(builder: PrefabBuilderData, name: string?): PrefabData
	local prefabData: PrefabData = {
		components = builder.components,
		tags = builder.tags,
	}
	if name then
		builder.world.prefabs[name] = prefabData
	end
	return prefabData
end

--[=[
	@method prefab
	@within World
	@tag Prefab
	@param name string? -- Optional name to retrieve a registered prefab
	@return PrefabBuilder | PrefabData -- A builder or existing prefab data

	Creates a new prefab builder or retrieves an existing prefab by name.
	Prefabs are templates for spawning entities with predefined components.

	:::info Builder Pattern
	The prefab builder uses a fluent interface:
	- `:with(componentId, value?)` - Add a component or tag
	- `:build(name?)` - Build the prefab, optionally registering by name
	:::

	```lua
	-- Create and register a prefab
	local enemyPrefab = world:prefab()
		:with(Health, 100)
		:with(Position, Vector3.zero)
		:with(Enemy)
		:build("Enemy")

	-- Spawn from the prefab
	local enemy = world:spawn("Enemy")

	-- Retrieve existing prefab by name
	local existingPrefab = world:prefab("Enemy")
	```
]=]
local function prefab(world: WorldData, name: string?): any
	local builder: PrefabBuilderData = {
		world = world,
		components = {},
		tags = {},
	}

	if name and world.prefabs[name] then
		return world.prefabs[name]
	end

	return setmetatable(builder :: any, { __index = PrefabBuilderMethods })
end

--[=[
	@method spawn
	@within World
	@tag Prefab
	@param prefabOrName PrefabData | string -- A prefab object or registered name
	@return number -- The spawned entity ID

	Spawns a new entity from a prefab template.
	This will trigger [World:onAdd] hooks for all components in the prefab.

	```lua
	-- Spawn from registered name
	local enemy = world:spawn("Enemy")

	-- Spawn from prefab object
	local enemy2 = world:spawn(enemyPrefab)

	-- Customize after spawning
	world:set(enemy, Position, Vector3.new(10, 0, 0))
	```
]=]
local function spawn(world: WorldData, prefabOrName: any): EntityType
	local prefabData: PrefabData

	if type(prefabOrName) == "string" then
		prefabData = world.prefabs[prefabOrName]
		if not prefabData then
			if world.debug then
				warn("AlloyECS: Prefab not found:", prefabOrName)
			end
			return entity(world)
		end
	else
		prefabData = prefabOrName :: PrefabData
	end

	local eid = entity(world)

	for _, compData in prefabData.components do
		set(world, eid, compData.componentId, compData.value)
	end

	for _, tagId in prefabData.tags do
		add(world, eid, tagId)
	end

	return eid
end

PrefabBuilderMethods = {
	with = prefabWith,
	build = prefabBuild,
}

--[=[
	@method onAdd
	@within World
	@tag Event
	@param componentId number -- The component to watch
	@param callback (entityId: number, value: any) -> () -- Called when component is added
	@return () -> () -- Unsubscribe function

	Registers a callback that fires when a component is added to any entity.
	Returns a function to unsubscribe.

	:::info When It Fires
	Fires on [World:add], [World:set] (for new components), and [World:spawn].
	:::

	```lua
	local unsubscribe = world:onAdd(Position, function(entityId, value)
		print("Entity", entityId, "gained Position:", value)
	end)

	-- Later, to stop listening:
	unsubscribe()
	```
]=]
local function onAdd(world: WorldData, componentId: EntityType, callback: (entityId: EntityType, value: any) -> ()): () -> ()
	local hooks = world.onAddHooks[componentId]

	if not hooks then
		hooks = {}
		world.onAddHooks[componentId] = hooks
	end

	table.insert(hooks, callback)

	return function()
		for i, cb in hooks do
			if cb == callback then
				table.remove(hooks, i)
				break
			end
		end
	end
end

--[=[
	@method onRemove
	@within World
	@tag Event
	@param componentId number -- The component to watch
	@param callback (entityId: number, value: any) -> () -- Called when component is removed
	@return () -> () -- Unsubscribe function

	Registers a callback that fires when a component is removed from any entity.
	The callback receives the old value before removal.

	:::info When It Fires
	Fires on [World:remove] and [World:destroy] (for all components).
	:::

	```lua
	world:onRemove(Health, function(entityId, oldValue)
		if oldValue <= 0 then
			print("Entity", entityId, "died!")
		end
	end)
	```
]=]
local function onRemove(world: WorldData, componentId: EntityType, callback: (entityId: EntityType, value: any) -> ()): () -> ()
	local hooks = world.onRemoveHooks[componentId]

	if not hooks then
		hooks = {}
		world.onRemoveHooks[componentId] = hooks
	end

	table.insert(hooks, callback)

	return function()
		for i, cb in hooks do
			if cb == callback then
				table.remove(hooks, i)
				break
			end
		end
	end
end

--[=[
	@method onChange
	@within World
	@tag Event
	@param componentId number -- The component to watch
	@param callback (entityId: number, oldValue: any, newValue: any) -> () -- Called when component changes
	@return () -> () -- Unsubscribe function

	Registers a callback that fires when a component value is changed.
	Only fires for components that already exist (not on initial add).

	:::info When It Fires
	Fires on [World:set] when updating an existing component value.
	:::

	```lua
	world:onChange(Health, function(entityId, oldHealth, newHealth)
		if newHealth < oldHealth then
			print("Entity", entityId, "took", oldHealth - newHealth, "damage!")
		end
	end)
	```
]=]
local function onChange(world: WorldData, componentId: EntityType, callback: (entityId: EntityType, oldValue: any, newValue: any) -> ()): () -> ()
	local hooks = world.onChangeHooks[componentId]

	if not hooks then
		hooks = {}
		world.onChangeHooks[componentId] = hooks
	end

	table.insert(hooks, callback)

	return function()
		for i, cb in hooks do
			if cb == callback then
				table.remove(hooks, i)
				break
			end
		end
	end
end

--[=[
	@method serialize
	@within World
	@tag Persistence
	@param typeHandlers { [string]: (any) -> any }? -- Optional handlers for custom types
	@return SerializedWorld -- The serialized world state

	Serializes the entire world state to a table that can be saved.
	Use typeHandlers to convert non-serializable types like Vector3.

	:::warning Custom Types
	Roblox types like Vector3, CFrame, etc. must be converted using typeHandlers
	or they won't serialize properly.
	:::

	```lua
	local data = world:serialize({
		Vector3 = function(v)
			return { x = v.X, y = v.Y, z = v.Z }
		end,
	})

	-- Save data to DataStore, file, etc.
	```
]=]
local function serialize(world: WorldData, typeHandlers: { [string]: (any) -> any }?): SerializedWorld
	local serialized: SerializedWorld = {
		entities = {},
		relationships = {},
	}

	local function serializeValue(value: any): any
		if typeHandlers then
			local valueType = typeof(value)
			local handler = typeHandlers[valueType]
			if handler then
				return handler(value)
			end
		end
		return value
	end

	for i = 1, world.entityCount do
		local eid = world.entityList[i]
		local components = world.entityComponents[eid]

		local entityData = {
			id = eid,
			components = {},
		}

		if components then
			for componentId, value in components do
				local serializedValue = if world.tagComponents[componentId] then nil else serializeValue(value)
				table.insert(entityData.components, {
					componentId = componentId,
					value = serializedValue,
				})
			end
		end

		table.insert(serialized.entities, entityData)
	end

	for source, sourceRels in world.relationships do
		for relation, relationMap in sourceRels do
			for target, value in relationMap do
				table.insert(serialized.relationships, {
					source = source,
					relation = relation,
					target = target,
					value = if value == true then nil else serializeValue(value),
				})
			end
		end
	end

	return serialized
end

--[=[
	@method deserialize
	@within World
	@tag Persistence
	@param data SerializedWorld -- The serialized world state
	@param typeHandlers { [string]: (any) -> any }? -- Optional handlers to reconstruct custom types

	Restores world state from serialized data.

	:::danger Clears Existing Data
	This clears all existing entities, components, and relationships
	before loading the serialized data.
	:::

	```lua
	world:deserialize(savedData, {
		Vector3 = function(v)
			if v.x then
				return Vector3.new(v.x, v.y, v.z)
			end
			return nil
		end,
	})
	```
]=]
local function deserialize(world: WorldData, data: SerializedWorld, typeHandlers: { [string]: (any) -> any }?)
	table.clear(world.entityGenerations)
	table.clear(world.entityComponents)
	table.clear(world.livingEntities)
	table.clear(world.entityList)
	table.clear(world.entityListIndex)
	table.clear(world.entityBitsets)
	table.clear(world.recycledIndices)
	table.clear(world.relationships)
	table.clear(world.relationTargets)
	table.clear(world.queryCache)
	table.clear(world.queryCacheByComponent)

	for compId in world.componentEntityLists do
		world.componentEntityLists[compId] = {}
		world.componentEntityIndex[compId] = {}
	end

	world.entityCount = 0
	world.nextEntityIndex = 1
	world.queryCacheDirty = true

	local function deserializeValue(value: any): any
		if typeHandlers and type(value) == "table" then
			for _, handler in typeHandlers do
				local reconstructed = handler(value)
				if reconstructed ~= nil then
					return reconstructed
				end
			end
		end
		return value
	end

	local maxIndex = 0

	for _, entityData in data.entities do
		local eid = entityData.id
		local index = decodeEntityIndex(eid)
		local generation = decodeEntityGeneration(eid)

		if index >= maxIndex then
			maxIndex = index + 1
		end

		world.entityGenerations[index] = generation
		world.entityComponents[eid] = {}
		world.livingEntities[eid] = true
		world.entityCount += 1
		world.entityList[world.entityCount] = eid
		world.entityListIndex[eid] = world.entityCount

		for _, compData in entityData.components do
			local componentId = compData.componentId
			local value

			if compData.value ~= nil then
				value = deserializeValue(compData.value)
			else
				value = true
			end

			world.entityComponents[eid][componentId] = value

			local bitIndex = world.componentBitIndex[componentId]
			if bitIndex then
				local bitset = world.entityBitsets[eid]
				if not bitset then
					bitset = Bitset.create(64)
					world.entityBitsets[eid] = bitset
				end
				Bitset.set(bitset, bitIndex)
			end

			addToComponentEntityList(world, eid, componentId)
		end
	end

	world.nextEntityIndex = maxIndex

	for _, relData in data.relationships do
		local value = if relData.value ~= nil then deserializeValue(relData.value) else nil
		relate(world, relData.source, relData.relation, relData.target, value)
	end
end

--[=[
	@method each
	@within World
	@tag Entity
	@param callback (entityId: number) -> () -- Function to call for each entity

	Iterates over all living entities in the world.

	:::tip Alternative
	For filtering entities by component, use [World:query] instead.
	:::

	```lua
	world:each(function(entityId)
		print("Entity:", entityId)
	end)
	```
]=]
local function each(world: WorldData, callback: (entityId: EntityType) -> ())
	for i = 1, world.entityCount do
		callback(world.entityList[i])
	end
end

--[=[
	@interface WorldConfig
	@within AlloyECS
	.trackChanges boolean? -- Enable change tracking for added/removed/changed queries
	.debug boolean? -- Enable debug warnings for invalid operations

	Configuration options for creating a new world.
]=]
type WorldConfig = {
	trackChanges: boolean?,
	debug: boolean?,
}

--[=[
	@function createWorld
	@within AlloyECS
	@param config WorldConfig? -- Optional configuration
	@return World -- The new world instance

	Creates a new ECS world.

	```lua
	-- Basic world
	local world = AlloyECS.createWorld()

	-- With change tracking enabled
	local world = AlloyECS.createWorld({
		trackChanges = true,
		debug = true,
	})
	```
]=]
local function createWorld(config: WorldConfig?): World
	local trackChanges = config and config.trackChanges or false
	local debug = config and config.debug or false

	local world: WorldData = {
		entityGenerations = {},
		entityComponents = {},
		livingEntities = {},
		entityList = {},
		entityListIndex = {},
		entityCount = 0,
		recycledIndices = {},
		nextEntityIndex = 1,
		entityBitsets = {},
		componentBitIndex = {},
		nextBitIndex = 0,
		componentEntityLists = {},
		componentEntityIndex = {},
		componentConfigs = {},
		nextComponentId = 1,
		tagComponents = {},
		queryCache = {},
		queryCacheByComponent = {},
		queryCacheDirty = false,
		relationships = {},
		relationTargets = {},
		prefabs = {},
		onAddHooks = {},
		onRemoveHooks = {},
		onChangeHooks = {},
		changeTracker = if trackChanges then Reactive.create() else nil,
		scheduler = Scheduler.create(),
		commandBuffer = CommandBuffer.create(),
		deferredMode = false,
		trackChanges = trackChanges,
		debug = debug,
	}

	return setmetatable(world :: any, { __index = WorldMethods }) :: World
end

WorldMethods = {
	entity = entity,
	isAlive = isAlive,
	destroy = destroy,
	getEntityCount = getEntityCount,
	getEntities = getEntities,
	component = component,
	tag = tag,
	isTag = isTag,
	add = add,
	set = set,
	get = get,
	has = has,
	remove = remove,
	query = query,
	queryBuilder = queryBuilder,
	added = added,
	removed = removed,
	changed = changed,
	clearChanges = clearChanges,
	defer = defer,
	deferSpawn = deferSpawn,
	deferDestroy = deferDestroy,
	deferAdd = deferAdd,
	deferSet = deferSet,
	deferRemove = deferRemove,
	flush = flush,
	hasPendingCommands = hasPendingCommands,
	addSystem = addSystem,
	removeSystem = removeSystem,
	enableSystem = enableSystem,
	disableSystem = disableSystem,
	runSystems = runSystems,
	runPhase = runPhase,
	step = step,
	relate = relate,
	unrelate = unrelate,
	getRelation = getRelation,
	hasRelation = hasRelation,
	getTargets = getTargets,
	getSources = getSources,
	prefab = prefab,
	spawn = spawn,
	onAdd = onAdd,
	onRemove = onRemove,
	onChange = onChange,
	serialize = serialize,
	deserialize = deserialize,
	each = each,
}

QueryBuilderMethods = {
	with = withFilter,
	without = without,
	iter = iter,
}

QueryBuilderMetatable = {
	__index = QueryBuilderMethods,
	__call = function(self: QueryBuilderData)
		return iter(self)
	end,
}

--[=[
	@prop MAX_ENTITY_INDEX number
	@within AlloyECS

	The maximum entity index value (16,777,215 with 24-bit indices).
]=]

--[=[
	@prop MAX_GENERATION number
	@within AlloyECS

	The maximum generation value (255 with 8-bit generations).
]=]

--[=[
	@prop Bitset Bitset
	@within AlloyECS

	The Bitset module for low-level bitset operations.
]=]

--[=[
	@prop CommandBuffer CommandBuffer
	@within AlloyECS

	The CommandBuffer module for deferred operations.
]=]

--[=[
	@prop Reactive Reactive
	@within AlloyECS

	The Reactive module for change tracking.
]=]

--[=[
	@prop Scheduler Scheduler
	@within AlloyECS

	The Scheduler module for system scheduling.
]=]

return {
	createWorld = createWorld,
	encodeEntityId = encodeEntityId,
	decodeEntityIndex = decodeEntityIndex,
	decodeEntityGeneration = decodeEntityGeneration,
	MAX_ENTITY_INDEX = MAX_ENTITY_INDEX,
	MAX_GENERATION = MAX_GENERATION,
	Bitset = Bitset,
	CommandBuffer = CommandBuffer,
	Reactive = Reactive,
	Scheduler = Scheduler,
}
