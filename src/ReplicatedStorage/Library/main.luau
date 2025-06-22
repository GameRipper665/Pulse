--!strict
--[[
	Pulse: A lightweight, path-based module loader for Roblox.

	Exposes a single function, `Pulse:require()`, to lazy-load modules on demand
	using a string path (e.g., "Services.DataService"). This avoids pre-loading
	all modules into memory, this also improves initial load times.

	The loader automatically scans and registers modules from ReplicatedStorage and
	ServerScriptService, respecting the client/server/shared boundaries.
]]

-- | Services |
local RunService = game:GetService("RunService")

-- | Top |
local Pulse = {}

-- | Reference | 
local _moduleRegistry: { [string]: ModuleScript } = {}
local _moduleCache: { [ModuleScript]: any } = {}
local _assets = {}
local _config = {}
local _debug = false

-- | Types |
export type ModulePaths = "Modules.Shared.Assets" | "Modules.Shared.Directory" -- examples for autocomplete

type Pulse = {
	require: ( self: Pulse, modulePath: ModulePaths ) -> any,
	assets: { [string]: any },
	config: { [string]: any },
	_debug: boolean,
}

-- | Init |
local startTime = tick()
local contextName = RunService:IsServer() and "SERVER" or "CLIENT"

-- | Internal |
local function _scanDirectory(directory: Instance, prefix: string)
	local success, result = pcall(function()
		for _, child in ipairs(directory:GetChildren()) do
			if child:IsA("Folder") then
				_scanDirectory(child, prefix .. child.Name .. ".")
			elseif child:IsA("ModuleScript") and child.Name ~= "Library" then
				local path = prefix .. child.Name
				_moduleRegistry[path] = child
			end
		end
	end)

	if not success then
		warn(`[Pulse] Failed to scan directory '{directory:GetFullName()}': {result}`)
	end
end

local function _loadAssets(directory: Instance, targetTable: { [string]: any })
	local success, result = pcall(function()
		for _, obj in ipairs(directory:GetChildren()) do
			if obj:IsA("Folder") then
				targetTable[obj.Name] = targetTable[obj.Name] or {}
				_loadAssets(obj, targetTable[obj.Name])
			else
				targetTable[obj.Name] = obj
			end
		end
	end)

	if not success then
		warn(`[Pulse] Failed to load assets from '{directory:GetFullName()}': {result}`)
	end
end

local function _loadConfig(directory: Instance, targetTable: { [string]: any })
	local success, result = pcall(function()
		for _, child: any in ipairs(directory:GetChildren()) do
			if child:IsA("Folder") then
				targetTable[child.Name] = targetTable[child.Name] or {}
				_loadConfig(child, targetTable[child.Name])
			elseif child:IsA("ValueBase") then
				targetTable[child.Name] = child.Value
			else
				warn(`[Pulse] Ignoring unexpected instance '{child:GetFullName()}' in a Configuration folder.`)
			end
		end
	end)

	if not success then
		warn(`[Pulse] Failed to load config from '{directory:GetFullName()}': {result}`)
	end
end

function Pulse:require(modulePath: ModulePaths): any
	local moduleScript = _moduleRegistry[modulePath]
	if not moduleScript then
		error(`[Pulse]: Module "{modulePath}" not found in the registry.`, 2)
	end

	if _moduleCache[moduleScript] then
		if _debug then
			print(`[Pulse] ({contextName}) Loading cached module: {modulePath}`)
		end
		return _moduleCache[moduleScript]
	end

	if _debug then
		print(`[Pulse] ({contextName}) Requiring module: {modulePath}`)
	end

	local success, module = pcall(require, moduleScript)
	if success then
		_moduleCache[moduleScript] = module
		return module
	else
		warn(`[Pulse]: Failed to require module "{modulePath}". | Error: {module}`)
		error(`[Pulse]: Failed to require module "{modulePath}". | Error: {module}`, 2)
	end
end

Pulse.assets = _assets
Pulse.config = _config
Pulse._debug = _debug

-- | External |
local function _initialize()
	local success, result = pcall(function()
		if RunService:IsServer() then
			local serverScriptService = game:GetService("ServerScriptService")
			local replicatedStorage = game:GetService("ReplicatedStorage")
			local sssLibrary = serverScriptService:FindFirstChild("Library")
			if sssLibrary then
				local classesFolder = sssLibrary:FindFirstChild("Classes")
				if classesFolder then
					_scanDirectory(classesFolder, "Classes.")
				end

				local servicesFolder = sssLibrary:FindFirstChild("Services")
				if servicesFolder then
					_scanDirectory(servicesFolder, "Services.")
				end

				local handlersFolder = sssLibrary:FindFirstChild("Handlers")
				if handlersFolder then
					_scanDirectory(handlersFolder, "Handlers.")
				end

				for _, item in ipairs(sssLibrary:GetChildren()) do
					if item.Name == "Classes" or item.Name == "Services" or item.Name == "Handlers" or item.Name == "Configuration" then
						continue
					end

					if item:IsA("Folder") then
						_scanDirectory(item, item.Name .. ".")
					elseif item:IsA("ModuleScript") then
						_moduleRegistry[item.Name] = item
					end
				end
			end

			local rsLibrary = replicatedStorage:FindFirstChild("Library")
			if rsLibrary then
				local modulesFolder = rsLibrary:FindFirstChild("Modules")
				if modulesFolder then
					local sharedFolder = modulesFolder:FindFirstChild("Shared")
					if sharedFolder then
						_scanDirectory(sharedFolder, "Modules.Shared.")
					end
				end

				for _, item in ipairs(rsLibrary:GetChildren()) do
					if item.Name == "Modules" or item.Name == "Configuration" then
						continue
					end

					if item:IsA("Folder") then
						_scanDirectory(item, item.Name .. ".")
					elseif item:IsA("ModuleScript") then
						_moduleRegistry[item.Name] = item
					end
				end
			end

			local assetsFolder = replicatedStorage:FindFirstChild("Assets")
			if assetsFolder then _loadAssets(assetsFolder, _assets) end

			local rsConfig = rsLibrary and rsLibrary:FindFirstChild("Configuration")
			if rsConfig then _loadConfig(rsConfig, _config) end

			local ssConfig = sssLibrary and sssLibrary:FindFirstChild("Configuration")
			if ssConfig then _loadConfig(ssConfig, _config) end

		elseif RunService:IsClient() then
			local replicatedStorage = game:GetService("ReplicatedStorage")
			local rsLibrary = replicatedStorage:FindFirstChild("Library")
			if rsLibrary then
				local classesFolder = rsLibrary:FindFirstChild("Classes")
				if classesFolder then
					_scanDirectory(classesFolder, "Classes.")
				end

				local servicesFolder = rsLibrary:FindFirstChild("Services")
				if servicesFolder then
					_scanDirectory(servicesFolder, "Services.")
				end

				local handlersFolder = rsLibrary:FindFirstChild("Handlers")
				if handlersFolder then
					_scanDirectory(handlersFolder, "Handlers.")
				end

				local modulesFolder = rsLibrary:FindFirstChild("Modules")
				if modulesFolder then
					local sharedFolder = modulesFolder:FindFirstChild("Shared")
					if sharedFolder then
						_scanDirectory(sharedFolder, "Modules.Shared.")
					end
				end

				for _, item in ipairs(rsLibrary:GetChildren()) do
					if item.Name == "Classes" or item.Name == "Services" or item.Name == "Handlers" or item.Name == "Modules" or item.Name == "Configuration" then
						continue
					end

					if item:IsA("Folder") then
						_scanDirectory(item, item.Name .. ".")
					elseif item:IsA("ModuleScript") then
						_moduleRegistry[item.Name] = item
					end
				end
			end

			local assetsFolder = replicatedStorage:FindFirstChild("Assets")
			if assetsFolder then _loadAssets(assetsFolder, _assets) end

			local configFolder = rsLibrary and rsLibrary:FindFirstChild("Configuration")
			if configFolder then _loadConfig(configFolder, _config) end
		end

		if _config._debug then
			_debug = _config._debug
			Pulse._debug = _debug
		end
	end)

	if not success then
		warn(`[Pulse] Initialization failed: {result}`)
	end

	local loadTime = math.floor((tick() - startTime) * 1000)
	print(`[Pulse] ({contextName}) Took {loadTime}ms to load!`)
end

_initialize()

--[[
	Explanation: We freeze this table to enforce metatable action and prevent
	accidental modifications to the library. 
	
	This is important because
	some modules may have metatables that need to be respected.
	
	Freezing the table ensures that attempts to modify
	it will fail, potentially alerting developers to the issue.
	
	We cast to `any` to suppress the `Type 'readonly table' could not be 
	converted to 'Library' error.
]]
return table.freeze(Pulse)