-- Paste into Roblox Studio's Command Bar (View > Command Bar) and press Enter.
-- Finds the model named "Scene" in Workspace, collects every Decal under it, and composes them
-- into a single new Decal ("ComposedMakeup") with AssetService:ComposeDecalAsync.
do
	local AssetService = game:GetService("AssetService")

	local scene = workspace:FindFirstChild("Scene") or workspace:FindFirstChild("Scene", true)
	if not scene then
		warn("[Compose] No model named 'Scene' in Workspace.")
		return
	end

	-- Collect the decals (skip a previous ComposedMakeup so re-running doesn't feed it back in)
	local decals = {}
	for _, d in ipairs(scene:GetDescendants()) do
		if d:IsA("Decal") and d.Name ~= "ComposedMakeup" then
			table.insert(decals, d)
		end
	end
	if #decals == 0 then
		warn("[Compose] 'Scene' has no Decals under it.")
		return
	end

	-- Bottom-to-top order: Face, then Eyes, then Lips (matches how Vanity splits a full-face look);
	-- anything else goes by ZIndex, then name.
	local function rank(d)
		local n = d.Name:lower()
		if n:find("face") then return 1 end
		if n:find("eye") then return 2 end
		if n:find("lip") then return 3 end
		return 4
	end
	table.sort(decals, function(a, b)
		local ra, rb = rank(a), rank(b)
		if ra ~= rb then return ra < rb end
		if a.ZIndex ~= b.ZIndex then return a.ZIndex < b.ZIndex end
		return a.Name < b.Name
	end)

	-- One layer per decal; only include maps that are actually set
	local function isSet(c)
		local ok, set = pcall(function() return c ~= nil and c.SourceType ~= Enum.ContentSourceType.None end)
		return ok and set
	end
	local layers = {}
	for i, d in ipairs(decals) do
		local layer = {}
		if isSet(d.ColorMapContent) then layer.ColorMap = d.ColorMapContent end
		if isSet(d.RoughnessMapContent) then layer.RoughnessMap = d.RoughnessMapContent end
		if isSet(d.MetalnessMapContent) then layer.MetalnessMap = d.MetalnessMapContent end
		if isSet(d.NormalMapContent) then layer.NormalMap = d.NormalMapContent end
		table.insert(layers, layer)
		print(("[Compose] layer %d: %s"):format(i, d:GetFullName()))
	end

	-- Target decal: replace any previous result
	local old = scene:FindFirstChild("ComposedMakeup")
	if old then old:Destroy() end
	local target = Instance.new("Decal")
	target.Name = "ComposedMakeup"

	local ok, err = pcall(function()
		AssetService:ComposeDecalAsync(target, layers)
	end)
	if ok then
		target.Parent = scene
		print(("[Compose] Composed %d decals into %s"):format(#layers, target:GetFullName()))
	else
		target:Destroy()
		warn("[Compose] ComposeDecalAsync failed: " .. tostring(err))
	end
end
