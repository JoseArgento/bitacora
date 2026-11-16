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
-- Without the helper everything still works by typing the file name, as before.

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

-- The texture path of a note's picture. PNG paths must include the extension (warcraft.wiki.gg, SetTexture);
-- for the other formats it is optional.
function I.Path(name)
	local e = I.Find(name)
	return ns.IMAGE_FOLDER .. (e and e.file or name)
end

-- What to call it: the name the player gave it here, the helper's title, or the file name.
function I.Title(name)
	local e = I.Find(name)
	local key = string.lower(e and e.file or name)
	local own = ns.db and ns.db.imageTitles and ns.db.imageTitles[key]
	return own or (e and e.title) or name
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

-- Everything there is to pick from: the helper's index (newest first), then the names typed by hand in
-- notes that the index does not know. { file, title, w, h, t, shot, uses, typed }
function I.List()
	local out, seen, count = {}, {}, uses()
	for _, e in ipairs(I.Index() or {}) do
		local key = string.lower(e.file)
		seen[key] = true
		out[#out + 1] = { file = e.file, title = I.Title(e.file), w = e.w, h = e.h, t = e.t, shot = e.shot, uses = count[key] or 0 }
	end
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

-- The picture of a game screenshot, when the helper brought it: WoWScrnShot_<stamp>.jpg → its entry.
function I.ByShot(stamp)
	if not stamp then
		return nil
	end
	for _, e in ipairs(I.Index() or {}) do
		if e.shot == stamp then
			return e
		end
	end
end
