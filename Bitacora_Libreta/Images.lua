local _, ns = ...

-- The pictures of the notes and the album. They live in Interface\AddOns\BitacoraImagenes, a folder of the
-- player's own: an addon cannot create folders, read the clipboard or list files. The capture helper
-- (ayudante/ in the repository, a Windows script) does those three things from outside the game and leaves
-- an index there, Indice.lua, which is a tiny addon of its own:
--
--   BitacoraImagenesIndice = { version = 1, made = <unix>, images = {
--       { file = "captura_03.tga", title = "Captura 16/11 14:32", w = 1920, h = 1080, t = <unix>,
--         shot = "111626_143200", from = "arg.jpg" }, ... } }
--
-- file  the texture to load (a plain name inside the folder)
-- w, h  the picture's own size: the texture is squeezed to powers of two, these give back its shape
-- shot  for a game screenshot, the stamp of WoWScrnShot_<stamp>.jpg (the album matches on it)
-- from  the file it was made from, when the helper converted a picture that was already in the folder
--
-- Without the helper: the game's own screenshots are known by name (the album notes the stamp of each one,
-- WoWScrnShot_<stamp>.jpg), so they can be listed and shown as soon as the files are somewhere the game
-- loads pictures from. I.Locate looks for them (SetTexture says whether a file loaded); the player only
-- copies files, never types a name.

local I = {}
ns.Images = I

local EXT = { png = true, jpg = true, jpeg = true, tga = true, blp = true }

-- Only a plain file name inside the images folder: no paths, so a note cannot point anywhere else.
function I.ValidName(name)
	name = ns.Trim(name)
	if name == "" or #name > 80 or not name:match("^[%w_%-%.]+$") or name:find("..", 1, true) then
		return nil
	end
	local ext = name:match("%.(%w+)$")
	if not ext or not EXT[string.lower(ext)] then
		return nil
	end
	return name
end

local function stem(name)
	return (string.lower(name):gsub("%.%w+$", ""))
end

-- The helper's index, checked entry by entry (it is a file on disk: anything could be in it). Newest first.
-- nil when there is no helper.
local cache, cacheOf
function I.Index()
	local raw = _G.BitacoraImagenesIndice
	if type(raw) ~= "table" or type(raw.images) ~= "table" then
		return nil
	end
	if cacheOf == raw then
		return cache
	end
	local list = {}
	for _, e in ipairs(raw.images) do
		local file = type(e) == "table" and type(e.file) == "string" and I.ValidName(e.file)
		if file then
			list[#list + 1] = {
				file = file,
				title = type(e.title) == "string" and e.title ~= "" and e.title:sub(1, 80) or nil,
				w = tonumber(e.w),
				h = tonumber(e.h),
				t = tonumber(e.t) or 0,
				shot = type(e.shot) == "string" and e.shot:match("^[%d_]+$") or nil,
				from = type(e.from) == "string" and I.ValidName(e.from) or nil,
			}
		end
	end
	table.sort(list, function(a, b)
		if a.t ~= b.t then
			return a.t > b.t
		end
		return a.file < b.file
	end)
	cache, cacheOf = list, raw
	return list
end

function I.HasHelper()
	return I.Index() ~= nil
end

-- The index entry for a name: the file itself, the file it was converted from, or the same name with
-- another extension ("arg.png" typed for arg.jpg, which the helper turned into arg.tga).
function I.Find(name)
	local index = I.Index()
	if not index or type(name) ~= "string" then
		return nil
	end
	local lower, s = string.lower(name), stem(name)
	local byStem
	for _, e in ipairs(index) do
		if string.lower(e.file) == lower or (e.from and string.lower(e.from) == lower) then
			return e
		end
		if not byStem and (stem(e.file) == s or (e.from and stem(e.from) == s)) then
			byStem = e
		end
	end
	return byStem
end

-- Where a picture can be: the pictures folder; the game's own Screenshots folder (if this client lets an
-- addon load from it, nothing has to be copied at all); and the AddOns and Interface folders, for whoever
-- pasted their screenshots there without making a folder.
I.FOLDERS = { ns.IMAGE_FOLDER, "Screenshots\\", "Interface\\AddOns\\", "Interface\\" }

local probe, canProbe, way
local located = {}

-- Ways of asking the game whether a file loaded. In Forever SetTexture's "success" does not tell a missing
-- file from a real one (seen in the client, 16/11), so the others are tried too: the first way that says yes
-- to a texture of ours and no to a name that cannot exist is the one used.
local function reset(tex)
	pcall(tex.SetTexture, tex, nil)
end
local function getter(method)
	return function(tex, path)
		reset(tex)
		pcall(tex.SetTexture, tex, path)
		local ok, v = pcall(tex[method], tex)
		return ok and v ~= nil and v ~= "" and v ~= 0
	end
end
I.WAYS = {
	{
		"SetTexture",
		function(tex, path)
			reset(tex)
			local ok, loaded = pcall(tex.SetTexture, tex, path)
			return ok and loaded == true
		end,
	},
	{ "GetTextureFileID", getter("GetTextureFileID") },
	{ "GetTexture", getter("GetTexture") },
	{ "GetTextureFilePath", getter("GetTextureFilePath") },
	{
		"GetFileIDFromPath",
		function(_, path)
			local ok, id = pcall(GetFileIDFromPath, path)
			return ok and type(id) == "number" and id ~= 0
		end,
	},
}
local function knownPaths()
	return ns.MEDIA .. "icon.tga", ns.IMAGE_FOLDER .. "__no_existe__.jpg"
end

-- Can this client tell a picture that loads from one that is not there? Checked once; I.Way() names how.
function I.CanProbe()
	if canProbe == nil then
		probe = probe or UIParent:CreateTexture(nil, "BACKGROUND")
		probe:Hide()
		local yes, no = knownPaths()
		canProbe = false
		for _, w in ipairs(I.WAYS) do
			if w[2](probe, yes) == true and w[2](probe, no) == false then
				canProbe, way = true, w
				break
			end
		end
		reset(probe)
	end
	return canProbe
end

function I.Way()
	return I.CanProbe() and way[1] or nil
end

-- The path where this file loads, or nil. Looked for once per session, found or not: a file copied while
-- playing shows up after a /reload anyway, and a reload starts the session again.
function I.Locate(file)
	if not I.CanProbe() or type(file) ~= "string" then
		return nil
	end
	if located[file] == nil then
		located[file] = false
		for _, folder in ipairs(I.FOLDERS) do
			if way[2](probe, folder .. file) == true then
				located[file] = folder .. file
				break
			end
		end
		reset(probe)
	end
	return located[file] or nil
end

-- The texture path of a note's picture. PNG paths must include the extension (warcraft.wiki.gg, SetTexture);
-- for the other formats it is optional.
function I.Path(name)
	local e = I.Find(name)
	if e then
		return ns.IMAGE_FOLDER .. e.file
	end
	return I.Locate(name) or (ns.IMAGE_FOLDER .. name)
end

-- Game screenshots ------------------------------------------------------------------------------------
-- "jpeg", "tga" or "png" (the screenshotFormat setting): the extension of the files the game writes.
local SHOT_EXT = { jpeg = "jpg", jpg = "jpg", tga = "tga", png = "png" }
local function shotExtensions()
	local now = C_CVar and C_CVar.GetCVar and C_CVar.GetCVar("screenshotFormat")
	local first = SHOT_EXT[string.lower(tostring(now or "jpeg"))] or "jpg"
	local out = { first }
	for _, ext in ipairs({ "jpg", "tga", "png" }) do
		if ext ~= first then
			out[#out + 1] = ext
		end
	end
	return out
end

-- The file of an album entry: its name and, when the game can load it from somewhere, true. Without a way
-- to tell (I.CanProbe), the name the game gives by default and nil.
function I.ShotFile(shot)
	if type(shot) ~= "table" or type(shot.stamp) ~= "string" or not shot.stamp:match("^[%d_]+$") then
		return nil
	end
	local base = "WoWScrnShot_" .. shot.stamp .. "."
	local exts = shotExtensions()
	if I.CanProbe() then
		for _, ext in ipairs(exts) do
			if I.Locate(base .. ext) then
				return base .. ext, true
			end
		end
	end
	return base .. exts[1], nil
end

-- Every screenshot the album knows, of every character: stamp → { shot, who }.
local function albumShots()
	local out = {}
	for key, c in pairs(ns.db and ns.db.chars or {}) do
		for _, shot in ipairs(type(c) == "table" and c.album or {}) do
			if type(shot) == "table" and shot.stamp then
				out[#out + 1] = { shot = shot, who = key }
			end
		end
	end
	table.sort(out, function(a, b)
		return (a.shot.t or 0) > (b.shot.t or 0)
	end)
	return out
end

-- What to call it: the name the player gave it here, the helper's title, or the file name.
function I.Title(name)
	local e = I.Find(name)
	local key = string.lower(e and e.file or name)
	local own = ns.db and ns.db.imageTitles and ns.db.imageTitles[key]
	if own or e then
		return own or e.title or name
	end
	-- a game screenshot: its caption in the album, or when and where it was taken
	local stamp = type(name) == "string" and name:match("^WoWScrnShot_([%d_]+)%.")
	if stamp then
		for _, c in pairs(ns.db and ns.db.chars or {}) do
			for _, shot in ipairs(type(c) == "table" and c.album or {}) do
				if type(shot) == "table" and shot.stamp == stamp then
					return shot.caption or (ns.Album and ns.Album.Describe(shot)) or name
				end
			end
		end
	end
	return name
end

function I.SetTitle(name, text)
	local e = I.Find(name)
	local key = string.lower(e and e.file or name)
	text = ns.Trim(text or ""):sub(1, 60)
	ns.db.imageTitles = ns.db.imageTitles or {}
	ns.db.imageTitles[key] = text ~= "" and text or nil
	ns.Fire("images")
end

-- Width and height that fit a box and keep the picture's shape. Without a known size: the box itself.
function I.Fit(name, boxW, boxH)
	local e = I.Find(name)
	local w, h = e and e.w, e and e.h
	if (not w or not h) and type(name) == "string" and name:match("^WoWScrnShot_") then
		-- a game screenshot has the shape of the screen
		if GetPhysicalScreenSize then
			w, h = GetPhysicalScreenSize()
		end
	end
	if not w or not h or w <= 0 or h <= 0 then
		return boxW, boxH
	end
	local scale = math.min(boxW / w, boxH / h)
	return math.max(1, math.floor(w * scale + 0.5)), math.max(1, math.floor(h * scale + 0.5))
end

-- How many notes use each picture (by the file it resolves to).
local function uses()
	local n = {}
	for _, note in pairs(ns.db and ns.db.notes or {}) do
		for _, name in ipairs(note.images or {}) do
			local e = I.Find(name)
			local key = string.lower(e and e.file or name)
			n[key] = (n[key] or 0) + 1
		end
	end
	return n
end

-- Everything there is to pick from: the helper's index (newest first), the game screenshots the album
-- knows and the game can load (all of them when it cannot tell: `unsure`), then the names typed by hand in
-- notes. { file, title, w, h, t, shot, uses, typed, unsure }
function I.List()
	local out, seen, count = {}, {}, uses()
	local brought = {}
	for _, e in ipairs(I.Index() or {}) do
		local key = string.lower(e.file)
		seen[key] = true
		if e.shot then
			brought[e.shot] = true
		end
		out[#out + 1] = { file = e.file, title = I.Title(e.file), w = e.w, h = e.h, t = e.t, shot = e.shot, uses = count[key] or 0 }
	end
	local sure, unsureShown = I.CanProbe(), 0
	for _, a in ipairs(albumShots()) do
		local file, found = I.ShotFile(a.shot)
		local key = file and string.lower(file)
		unsureShown = unsureShown + (found and 0 or 1)
		-- when the game cannot tell what loads, only the newest ones: a long list of maybes helps nobody
		if file and not seen[key] and not brought[a.shot.stamp] and (found or (not sure and unsureShown <= 30)) then
			seen[key] = true
			local own = ns.db.imageTitles and ns.db.imageTitles[key]
			local title = own or a.shot.caption or (ns.Album and ns.Album.Describe(a.shot)) or file
			out[#out + 1] = { file = file, title = title, t = a.shot.t or 0, shot = a.shot.stamp, uses = count[key] or 0, unsure = not sure or nil, album = true }
		end
	end
	table.sort(out, function(a, b)
		if (a.t or 0) ~= (b.t or 0) then
			return (a.t or 0) > (b.t or 0)
		end
		return a.file < b.file
	end)
	local typed = {}
	for _, note in pairs(ns.db and ns.db.notes or {}) do
		for _, name in ipairs(note.images or {}) do
			local key = string.lower(name)
			if not seen[key] and not I.Find(name) then
				seen[key] = true
				typed[#typed + 1] = { file = name, title = I.Title(name), t = 0, uses = count[key] or 0, typed = true }
			end
		end
	end
	table.sort(typed, function(a, b)
		return a.file < b.file
	end)
	for _, e in ipairs(typed) do
		out[#out + 1] = e
	end
	return out
end

-- The picture of a game screenshot: the helper's copy, or the game's own file wherever it loads from.
-- Returns the name to hand to I.Path / UI.FitImage, or nil.
function I.ByShot(stamp)
	if not stamp then
		return nil
	end
	for _, e in ipairs(I.Index() or {}) do
		if e.shot == stamp then
			return e.file
		end
	end
	local file, found = I.ShotFile({ stamp = stamp })
	return found and file or nil
end

-- For /bita imagenes: where pictures load from in this client, and what the game answers to each way of
-- asking (for a bug report: with this one can tell which way would work here).
function I.Report()
	local lines = {}
	lines[#lines + 1] = "puedo saber qué archivos hay: " .. (I.CanProbe() and ("sí, con " .. way[1]) or "no")
	lines[#lines + 1] = "ayudante: " .. (I.HasHelper() and (#I.Index() .. " imágenes") or "no instalado")
	local shots = albumShots()
	local found, where = 0, {}
	for _, a in ipairs(shots) do
		local file, ok = I.ShotFile(a.shot)
		if ok then
			found = found + 1
			local folder = (I.Locate(file) or ""):match("^(.*\\)") or "?"
			where[folder] = (where[folder] or 0) + 1
		end
	end
	lines[#lines + 1] = ("capturas del álbum: %d, de las que el juego puede mostrar: %d"):format(#shots, found)
	for folder, n in pairs(where) do
		lines[#lines + 1] = ("  %d en %s"):format(n, folder)
	end
	-- what each way answers: a texture of ours, a name that cannot exist, and the newest screenshots in the
	-- pictures folder and in the game's own
	local yes, no = knownPaths()
	local paths = { { "nuestra", yes }, { "inexistente", no } }
	for i = 1, math.min(3, #shots) do
		local file = I.ShotFile(shots[i].shot)
		paths[#paths + 1] = { "imagenes " .. i, ns.IMAGE_FOLDER .. file }
		if i == 1 then
			paths[#paths + 1] = { "screenshots", "Screenshots\\" .. file }
		end
	end
	probe = probe or UIParent:CreateTexture(nil, "BACKGROUND")
	for _, p in ipairs(paths) do
		local bits = {}
		for _, w in ipairs(I.WAYS) do
			bits[#bits + 1] = w[1] .. "=" .. (w[2](probe, p[2]) and "si" or "no")
		end
		lines[#lines + 1] = p[1] .. ": " .. table.concat(bits, " ")
	end
	reset(probe)
	return lines
end
