--!strict
--!native
--!optimize 2

export type EntityType = number

export type ChangeTracker = {
	added: { [EntityType]: { [EntityType]: boolean } },
	removed: { [EntityType]: { [EntityType]: boolean } },
	changed: { [EntityType]: { [EntityType]: boolean } },
	addedLists: { [EntityType]: { EntityType } },
	removedLists: { [EntityType]: { EntityType } },
	changedLists: { [EntityType]: { EntityType } },
	dirty: boolean,
}

local function create(): ChangeTracker
	return {
		added = {},
		removed = {},
		changed = {},
		addedLists = {},
		removedLists = {},
		changedLists = {},
		dirty = false,
	}
end

local function ensureAddedSet(tracker: ChangeTracker, componentId: EntityType): { [EntityType]: boolean }
	local set = tracker.added[componentId]
	if not set then
		set = {}
		tracker.added[componentId] = set
		tracker.addedLists[componentId] = {}
	end

	return set
end

local function ensureRemovedSet(tracker: ChangeTracker, componentId: EntityType): { [EntityType]: boolean }
	local set = tracker.removed[componentId]
	if not set then
		set = {}
		tracker.removed[componentId] = set
		tracker.removedLists[componentId] = {}
	end

	return set
end

local function ensureChangedSet(tracker: ChangeTracker, componentId: EntityType): { [EntityType]: boolean }
	local set = tracker.changed[componentId]
	if not set then
		set = {}
		tracker.changed[componentId] = set
		tracker.changedLists[componentId] = {}
	end

	return set
end

local function recordAdded(tracker: ChangeTracker, entityId: EntityType, componentId: EntityType)
	local set = ensureAddedSet(tracker, componentId)
	if not set[entityId] then
		set[entityId] = true
		local list = tracker.addedLists[componentId]
		list[#list + 1] = entityId
		tracker.dirty = true
	end
end

local function recordRemoved(tracker: ChangeTracker, entityId: EntityType, componentId: EntityType)
	local set = ensureRemovedSet(tracker, componentId)
	if not set[entityId] then
		set[entityId] = true
		local list = tracker.removedLists[componentId]
		list[#list + 1] = entityId
		tracker.dirty = true
	end
end

local function recordChanged(tracker: ChangeTracker, entityId: EntityType, componentId: EntityType)
	local set = ensureChangedSet(tracker, componentId)
	if not set[entityId] then
		set[entityId] = true
		local list = tracker.changedLists[componentId]
		list[#list + 1] = entityId
		tracker.dirty = true
	end
end

local function getAdded(tracker: ChangeTracker, componentId: EntityType): { EntityType }
	return tracker.addedLists[componentId] or {}
end

local function getRemoved(tracker: ChangeTracker, componentId: EntityType): { EntityType }
	return tracker.removedLists[componentId] or {}
end

local function getChanged(tracker: ChangeTracker, componentId: EntityType): { EntityType }
	return tracker.changedLists[componentId] or {}
end

local function hasAdded(tracker: ChangeTracker, entityId: EntityType, componentId: EntityType): boolean
	local set = tracker.added[componentId]
	return set ~= nil and set[entityId] == true
end

local function hasRemoved(tracker: ChangeTracker, entityId: EntityType, componentId: EntityType): boolean
	local set = tracker.removed[componentId]
	return set ~= nil and set[entityId] == true
end

local function hasChanged(tracker: ChangeTracker, entityId: EntityType, componentId: EntityType): boolean
	local set = tracker.changed[componentId]
	return set ~= nil and set[entityId] == true
end

local function isDirty(tracker: ChangeTracker): boolean
	return tracker.dirty
end

local function clearFrame(tracker: ChangeTracker)
	for componentId, set in tracker.added do
		table.clear(set)
		table.clear(tracker.addedLists[componentId])
	end

	for componentId, set in tracker.removed do
		table.clear(set)
		table.clear(tracker.removedLists[componentId])
	end

	for componentId, set in tracker.changed do
		table.clear(set)
		table.clear(tracker.changedLists[componentId])
	end

	tracker.dirty = false
end

local function clearComponent(tracker: ChangeTracker, componentId: EntityType)
	local addedSet = tracker.added[componentId]
	if addedSet then
		table.clear(addedSet)
		table.clear(tracker.addedLists[componentId])
	end

	local removedSet = tracker.removed[componentId]
	if removedSet then
		table.clear(removedSet)
		table.clear(tracker.removedLists[componentId])
	end

	local changedSet = tracker.changed[componentId]
	if changedSet then
		table.clear(changedSet)
		table.clear(tracker.changedLists[componentId])
	end
end

local function getAddedCount(tracker: ChangeTracker, componentId: EntityType): number
	local list = tracker.addedLists[componentId]

	return if list then #list else 0
end

local function getRemovedCount(tracker: ChangeTracker, componentId: EntityType): number
	local list = tracker.removedLists[componentId]

	return if list then #list else 0
end

local function getChangedCount(tracker: ChangeTracker, componentId: EntityType): number
	local list = tracker.changedLists[componentId]
    
	return if list then #list else 0
end

return {
	create = create,
	recordAdded = recordAdded,
	recordRemoved = recordRemoved,
	recordChanged = recordChanged,
	getAdded = getAdded,
	getRemoved = getRemoved,
	getChanged = getChanged,
	hasAdded = hasAdded,
	hasRemoved = hasRemoved,
	hasChanged = hasChanged,
	isDirty = isDirty,
	clearFrame = clearFrame,
	clearComponent = clearComponent,
	getAddedCount = getAddedCount,
	getRemovedCount = getRemovedCount,
	getChangedCount = getChangedCount,
}
