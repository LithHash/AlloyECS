--!strict
local RunService = game:GetService("RunService")
local ecs = require(script.Parent)

export type StepMethod = "Heartbeat" | "PreRender" | "PreSimulation"

export type SystemConfig = {
	update: (world: ecs.World, deltaTime: number) -> (),
	condition: ((world: ecs.World) -> boolean)?,
	step: StepMethod?,
	priority: number?,
}

export type System = {
	name: string,
	update: (world: ecs.World, deltaTime: number) -> (),
	condition: ((world: ecs.World) -> boolean)?,
	step: StepMethod,
	priority: number,
	_thread: thread,
	_paused: boolean,
	_pauseUntil: number,
}

type SystemGroup = {
	systems: {System},
	connection: RBXScriptConnection?,
}

local IS_CLIENT: boolean = RunService:IsClient()
local systemGroups: {[StepMethod]: SystemGroup} = {}

local SENTINEL = {}

local function createThread(system: System): thread
	return coroutine.create(function()
		while true do
			local world: ecs.World, deltaTime: number = coroutine.yield(SENTINEL)
			system.update(world, deltaTime)
		end
	end)
end

local function create(name: string, config: SystemConfig): System
	local step: StepMethod = config.step or "Heartbeat"
	if step == "PreRender" and not IS_CLIENT then
		step = "Heartbeat"
	end

	local system: System = {
		name = name,
		update = config.update,
		condition = config.condition,
		step = step,
		priority = config.priority or 100,
		_thread = nil :: any,
		_paused = false,
		_pauseUntil = 0,
	}

	system._thread = createThread(system)
	coroutine.resume(system._thread)

	return system
end

local function pauseSystem(system: System, reason: string): ()
	system._paused = true
	system._pauseUntil = os.clock() + 10
	warn(`[ECS] System '{system.name}' paused for 10 seconds - Reason: {reason}`)

	task.delay(10, function()
		if system._paused and os.clock() >= system._pauseUntil then
			system._paused = false
			system._thread = createThread(system)
			coroutine.resume(system._thread)
			warn(`[ECS] System '{system.name}' resumed after pause`)
		end
	end)
end

local function start(system: System, world: ecs.World): ()
	local group: SystemGroup = systemGroups[system.step] or {
		systems = {},
		connection = nil,
	}
	systemGroups[system.step] = group

	local existingIndex: number? = table.find(group.systems, system)
	if existingIndex then
		warn(`[ECS] System '{system.name}' is already running`)
		return
	end

	table.insert(group.systems, system)
	table.sort(group.systems, function(a: System, b: System): boolean
		return a.priority < b.priority
	end)

	if group.connection == nil then
		local stepEvent: RBXScriptSignal<number> = if system.step == "PreRender" then RunService.PreRender
			elseif system.step == "PreSimulation" then RunService.PreSimulation
			else RunService.Heartbeat

		local conn: RBXScriptConnection = stepEvent:Connect(function(deltaTime: number): ()
			for _, sys: System in group.systems do
				if sys._paused then
					continue
				end

				if sys.condition then
					local conditionSuccess: boolean, conditionResult: any = pcall(sys.condition, world)
					if not conditionSuccess then
						pauseSystem(sys, `Condition error: {tostring(conditionResult)}`)
						continue
					end
					if not conditionResult then
						continue
					end
				end

				local status: string = coroutine.status(sys._thread)
				if status == "dead" then
					pauseSystem(sys, "Thread is dead before resume")
					continue
				end

				local success: boolean, result: any = coroutine.resume(sys._thread, world, deltaTime)

				if not success then
					pauseSystem(sys, `Runtime error: {tostring(result)}`)
					continue
				end

				if result ~= SENTINEL then
					pauseSystem(sys, "System yielded unexpectedly (no sentinel returned)")
					continue
				end

				local newStatus: string = coroutine.status(sys._thread)
				if newStatus ~= "suspended" then
					pauseSystem(sys, `Thread status is '{newStatus}' instead of 'suspended'`)
					continue
				end
			end
		end)

		group.connection = conn
	end
end

local function stop(system: System): ()
	local group: SystemGroup? = systemGroups[system.step]
	if group == nil then
		return
	end

	local index: number? = table.find(group.systems, system)
	if index then
		table.remove(group.systems, index)
	end

	if #group.systems == 0 then
		if group.connection then
			group.connection:Disconnect()
		end
		systemGroups[system.step] = nil :: any
	end
end

return {
	create = create,
	start = start,
	stop = stop,
}
