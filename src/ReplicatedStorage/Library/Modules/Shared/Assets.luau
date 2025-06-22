--!strict
--[[
    Provides asset management utilities for Pulse-loaded assets.
    Uses metatables for safe property access and type validation.
    
    Methods:
    - requestAssetId(path): Returns the AssetID for a given path
    - requestAssetName(path): Returns the formatted asset name
    - requestAssetType(path): Returns the asset's type (Sound/Model/etc)
    - requestAssetInstance(path): Returns the actual Instance object
    
    Example:
        local assets = Pulse:require("Modules.Shared.Assets")
        local themeMusicId = assets.requestAssetId("Sound.Music.MainTheme")
]]

-- | Services |
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- | Library |
local Pulse = require(ReplicatedStorage:WaitForChild("Library"))

-- | Top | 
local module = {}
module.__index = module

-- | Types |
export type AssetInfo = {
	id: string?,
	name: string,
	type: string,
	instance: Instance
}

-- | Internal |
local assetMetatable = {
	__index = function(self, key)
		local rawValue = rawget(self, key)
		if rawValue then 
			return rawValue
		end

		local pathParts = string.split(self._path .. "." .. key, ".")
		local resolved = Pulse.assets
		for _, part in ipairs(pathParts) do
			resolved = resolved[part]

			if not resolved then 
				break
			end
		end

		if type(resolved) == "table" then
			return setmetatable({
				_path = self._path .. "." .. key,
				_value = resolved
			}, assetMetatable)
		end

		return resolved
	end
}

--[[
    @param path: Dot-separated path to asset (e.g. "Sound.Music")
    @returns: (AssetInfo, string?) tuple
]]
local function _resolveAssetPath(path: string): (AssetInfo?, string?)
	local current: any = Pulse.assets
	local pathParts = string.split(path, ".")

	for i, part in ipairs(pathParts) do
		if type(current) ~= "table" then
			return nil, `Invalid path segment '{part}' at position {i}`
		end

		current = current[part]
	end

	if not current or typeof(current) ~= "Instance" then
		return nil, "Asset not found"
	end

	return {
		id = current:IsA("ValueBase") and current.Value or current.AssetId,
		name = current.Name,
		type = current.ClassName,
		instance = current
	}, nil
end

--[[
    @param path: Dot-separated path to asset
    @returns: string AssetID
]]
function module.requestAssetId(path: string): string
	local asset, err = _resolveAssetPath(path)
	if not asset then
		error(err, 2) 
	end
	return asset.id or error("AssetID not available for " .. path)
end

--[[
    @param path: Dot-separated path to asset
    @returns: string Human-readable name
]]
function module.requestAssetName(path: string): string
	local asset, err = _resolveAssetPath(path)
	if not asset then
		error(err, 2)
	end
	return string.gsub(asset.name, "[_]", " ")
end

--[[
    @param path: Dot-separated path to asset
    @returns: string Roblox class name
]]
function module.requestAssetType(path: string): string
	local asset, err = _resolveAssetPath(path)
	if not asset then 
		error(err, 2)
	end
	return asset.type
end

--[[
    @param path: Dot-separated path to asset
    @returns: Instance The Roblox object
]]
function module.requestAssetInstance(path: string): Instance
	local asset, err = _resolveAssetPath(path)
	if not asset then
		error(err, 2)
	end
	return asset.instance
end

-- | External |
return setmetatable(module, {
	__call = function(_, ...)
		return setmetatable({_path = "", _value = Pulse.assets}, assetMetatable)
	end
})