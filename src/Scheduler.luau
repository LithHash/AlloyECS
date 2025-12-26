--!strict
--!native
--!optimize 2

export type EntityType = number

export type SystemPhase = "preUpdate" | "update" | "postUpdate" | "render"

export type SystemDependencies = {
	reads: { EntityType },
	writes: { EntityType },
}

export type System = {
	name: string,
	phase: SystemPhase,
	dependencies: SystemDependencies,
	callback: (deltaTime: number) -> (),
	enabled: boolean,
	order: number,
}

export type Scheduler = {
	systems: { [string]: System },
	phases: { [SystemPhase]: { System } },
	batches: { [SystemPhase]: { { System } } },
	dirty: boolean,
	nextOrder: number,
}

local PHASE_ORDER: { SystemPhase } = { "preUpdate", "update", "postUpdate", "render" }

local function create(): Scheduler
	return {
		systems = {},
		phases = {
			preUpdate = {},
			update = {},
			postUpdate = {},
			render = {},
		},
		batches = {
			preUpdate = {},
			update = {},
			postUpdate = {},
			render = {},
		},
		dirty = true,
		nextOrder = 1,
	}
end

local function hasConflict(deps1: SystemDependencies, deps2: SystemDependencies): boolean
	for _, writeComp in deps1.writes do
		for _, readComp in deps2.reads do
			if writeComp == readComp then
				return true
			end
		end

		for _, otherWrite in deps2.writes do
			if writeComp == otherWrite then
				return true
			end
		end
	end

	for _, writeComp in deps2.writes do
		for _, readComp in deps1.reads do
			if writeComp == readComp then
				return true
			end
		end
	end

	return false
end

local function canAddToBatch(batch: { System }, system: System): boolean
	for _, existingSystem in batch do
		if hasConflict(existingSystem.dependencies, system.dependencies) then
			return false
		end
	end

	return true
end

local function rebuildBatches(scheduler: Scheduler)
	for _, phase in PHASE_ORDER do
		local phaseSystems = scheduler.phases[phase :: SystemPhase]
		local phaseBatches: { { System } } = {}

		table.sort(phaseSystems, function(a, b)
			return a.order < b.order
		end)

		for _, system in phaseSystems do
			if system.enabled then
				local placed = false

				for _, batch in phaseBatches do
					if canAddToBatch(batch, system) then
						batch[#batch + 1] = system
						placed = true
						break
					end
				end

				if not placed then
					phaseBatches[#phaseBatches + 1] = { system }
				end
			end
		end

		scheduler.batches[phase :: SystemPhase] = phaseBatches
	end

	scheduler.dirty = false
end

local function addSystem(
	scheduler: Scheduler,
	name: string,
	phase: SystemPhase,
	dependencies: SystemDependencies,
	callback: (deltaTime: number) -> ()
): System
	local system: System = {
		name = name,
		phase = phase,
		dependencies = dependencies,
		callback = callback,
		enabled = true,
		order = scheduler.nextOrder,
	}

	scheduler.nextOrder += 1
	scheduler.systems[name] = system

	local phaseList = scheduler.phases[phase]
	phaseList[#phaseList + 1] = system
	scheduler.dirty = true

	return system
end

local function removeSystem(scheduler: Scheduler, name: string): boolean
	local system = scheduler.systems[name]
	if not system then
		return false
	end

	scheduler.systems[name] = nil

	local phaseList = scheduler.phases[system.phase]
	for i, sys in phaseList do
		if sys.name == name then
			table.remove(phaseList, i)
			break
		end
	end

	scheduler.dirty = true

	return true
end

local function enableSystem(scheduler: Scheduler, name: string): boolean
	local system = scheduler.systems[name]
	if system and not system.enabled then
		system.enabled = true
		scheduler.dirty = true

		return true
	end

	return false
end

local function disableSystem(scheduler: Scheduler, name: string): boolean
	local system = scheduler.systems[name]
	if system and system.enabled then
		system.enabled = false
		scheduler.dirty = true
        
		return true
	end

	return false
end

local function isSystemEnabled(scheduler: Scheduler, name: string): boolean
	local system = scheduler.systems[name]

	return system ~= nil and system.enabled
end

local function getSystem(scheduler: Scheduler, name: string): System?
	return scheduler.systems[name]
end

local function hasSystem(scheduler: Scheduler, name: string): boolean
	return scheduler.systems[name] ~= nil
end

local function getBatches(scheduler: Scheduler, phase: SystemPhase): { { System } }
	if scheduler.dirty then
		rebuildBatches(scheduler)
	end

	return scheduler.batches[phase]
end

local function getAllBatches(scheduler: Scheduler): { [SystemPhase]: { { System } } }
	if scheduler.dirty then
		rebuildBatches(scheduler)
	end

	return scheduler.batches
end

local function runPhase(scheduler: Scheduler, phase: SystemPhase, deltaTime: number)
	if scheduler.dirty then
		rebuildBatches(scheduler)
	end

	local phaseBatches = scheduler.batches[phase]
	for _, batch in phaseBatches do
		for _, system in batch do
			system.callback(deltaTime)
		end
	end
end

local function runAll(scheduler: Scheduler, deltaTime: number)
	if scheduler.dirty then
		rebuildBatches(scheduler)
	end

	for _, phase in PHASE_ORDER do
		local phaseBatches = scheduler.batches[phase :: SystemPhase]
		for _, batch in phaseBatches do
			for _, system in batch do
				system.callback(deltaTime)
			end
		end
	end
end

local function getSystemCount(scheduler: Scheduler): number
	local count = 0
	for _ in scheduler.systems do
		count += 1
	end

	return count
end

local function getPhaseSystemCount(scheduler: Scheduler, phase: SystemPhase): number
	return #scheduler.phases[phase]
end

local function getEnabledSystemCount(scheduler: Scheduler): number
	local count = 0
	for _, system in scheduler.systems do
		if system.enabled then
			count += 1
		end
	end

	return count
end

local function getSystems(scheduler: Scheduler): { [string]: System }
	return scheduler.systems
end

local function getPhaseOrder(): { SystemPhase }
	return PHASE_ORDER
end

local function canRunInParallel(scheduler: Scheduler, name1: string, name2: string): boolean
	local system1 = scheduler.systems[name1]
	local system2 = scheduler.systems[name2]
	if not system1 or not system2 then
		return false
	end
    
	return not hasConflict(system1.dependencies, system2.dependencies)
end

return {
	create = create,
	addSystem = addSystem,
	removeSystem = removeSystem,
	enableSystem = enableSystem,
	disableSystem = disableSystem,
	isSystemEnabled = isSystemEnabled,
	getSystem = getSystem,
	hasSystem = hasSystem,
	getBatches = getBatches,
	getAllBatches = getAllBatches,
	runPhase = runPhase,
	runAll = runAll,
	getSystemCount = getSystemCount,
	getPhaseSystemCount = getPhaseSystemCount,
	getEnabledSystemCount = getEnabledSystemCount,
	getSystems = getSystems,
	getPhaseOrder = getPhaseOrder,
	canRunInParallel = canRunInParallel,
}
