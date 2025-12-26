--!strict
--!native
--!optimize 2

export type EntityType = number

export type CommandType = "spawn" | "destroy" | "add" | "set" | "remove"

export type Command = {
	type: CommandType,
	entityId: EntityType?,
	componentId: EntityType?,
	value: any?,
	callback: ((EntityType) -> ())?,
}

export type CommandBuffer = {
	commands: { Command },
	pendingCount: number,
}

export type CommandExecutor = {
	spawn: () -> EntityType,
	destroy: (entityId: EntityType) -> (),
	add: (entityId: EntityType, componentId: EntityType) -> (),
	set: (entityId: EntityType, componentId: EntityType, value: any) -> (),
	remove: (entityId: EntityType, componentId: EntityType) -> (),
}

local function create(): CommandBuffer
	return {
		commands = {},
		pendingCount = 0,
	}
end

local function spawn(buffer: CommandBuffer, callback: ((EntityType) -> ())?): CommandBuffer
	buffer.pendingCount += 1
	buffer.commands[buffer.pendingCount] = {
		type = "spawn",
		entityId = nil,
		componentId = nil,
		value = nil,
		callback = callback,
	}

	return buffer
end

local function destroy(buffer: CommandBuffer, entityId: EntityType): CommandBuffer
	buffer.pendingCount += 1
	buffer.commands[buffer.pendingCount] = {
		type = "destroy",
		entityId = entityId,
		componentId = nil,
		value = nil,
		callback = nil,
	}

	return buffer
end

local function add(buffer: CommandBuffer, entityId: EntityType, componentId: EntityType): CommandBuffer
	buffer.pendingCount += 1
	buffer.commands[buffer.pendingCount] = {
		type = "add",
		entityId = entityId,
		componentId = componentId,
		value = nil,
		callback = nil,
	}

	return buffer
end

local function set(buffer: CommandBuffer, entityId: EntityType, componentId: EntityType, value: any): CommandBuffer
	buffer.pendingCount += 1
	buffer.commands[buffer.pendingCount] = {
		type = "set",
		entityId = entityId,
		componentId = componentId,
		value = value,
		callback = nil,
	}

	return buffer
end

local function remove(buffer: CommandBuffer, entityId: EntityType, componentId: EntityType): CommandBuffer
	buffer.pendingCount += 1
	buffer.commands[buffer.pendingCount] = {
		type = "remove",
		entityId = entityId,
		componentId = componentId,
		value = nil,
		callback = nil,
	}
    
	return buffer
end

local function clearBuffer(buffer: CommandBuffer)
	table.clear(buffer.commands)
	buffer.pendingCount = 0
end

local function isEmpty(buffer: CommandBuffer): boolean
	return buffer.pendingCount == 0
end

local function getCount(buffer: CommandBuffer): number
	return buffer.pendingCount
end

local function getCommands(buffer: CommandBuffer): { Command }
	return buffer.commands
end

local function execute(buffer: CommandBuffer, executor: CommandExecutor)
	local commands = buffer.commands
	local count = buffer.pendingCount
	for i = 1, count do
		local cmd = commands[i]
		local cmdType = cmd.type
		if cmdType == "spawn" then
			local newEntity = executor.spawn()
			if cmd.callback then
				cmd.callback(newEntity)
			end
		elseif cmdType == "destroy" then
			executor.destroy(cmd.entityId :: EntityType)
		elseif cmdType == "add" then
			executor.add(cmd.entityId :: EntityType, cmd.componentId :: EntityType)
		elseif cmdType == "set" then
			executor.set(cmd.entityId :: EntityType, cmd.componentId :: EntityType, cmd.value)
		elseif cmdType == "remove" then
			executor.remove(cmd.entityId :: EntityType, cmd.componentId :: EntityType)
		end
	end

	clearBuffer(buffer)
end

return {
	create = create,
	spawn = spawn,
	destroy = destroy,
	add = add,
	set = set,
	remove = remove,
	clear = clearBuffer,
	isEmpty = isEmpty,
	getCount = getCount,
	getCommands = getCommands,
	execute = execute,
}
