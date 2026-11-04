local _, ns = ...
local L = ns.L

local N = {}
ns.Notes = N

-- A note: { id, section, title, body, created, updated, char = "Name-Realm" or nil (all characters),
--           pinned, images = { "map.png" }, attach = { kind = "npc"|"item"|"zone", key = "...", label = "..." } }

function N.Sections()
	return ns.db.sections
end

function N.Section(id)
	for _, s in ipairs(ns.db.sections) do
		if s.id == id then
			return s
		end
	end
end

function N.AddSection(name)
	name = ns.Trim(name)
	if name == "" then
		return nil
	end
	local s = { id = ns.NewID("s"), name = name }
	table.insert(ns.db.sections, s)
	ns.Fire("notes")
	return s
end

function N.RenameSection(id, name)
	local s = N.Section(id)
	name = ns.Trim(name)
	if s and name ~= "" then
		s.name = name
		ns.Fire("notes")
	end
end

-- The first tab cannot be deleted; notes of a deleted tab move to the first one.
function N.DeleteSection(id)
	local sections = ns.db.sections
	if #sections <= 1 or sections[1].id == id then
		return false
	end
	for i, s in ipairs(sections) do
		if s.id == id then
			table.remove(sections, i)
			break
		end
	end
	for _, note in pairs(ns.db.notes) do
		if note.section == id then
			note.section = sections[1].id
		end
	end
	ns.Fire("notes")
	return true
end

function N.Get(id)
	return ns.db.notes[id]
end

function N.Create(fields)
	fields = fields or {}
	local now = time()
	local note = {
		id = ns.NewID("n"),
		section = fields.section or ns.db.sections[1].id,
		title = ns.Trim(fields.title),
		body = fields.body or "",
		created = now,
		updated = now,
		char = fields.char,
		images = {},
	}
	ns.db.notes[note.id] = note
	ns.Fire("notes", note.id)
	return note
end

function N.Update(id, fields)
	local note = ns.db.notes[id]
	if not note then
		return nil
	end
	for k, v in pairs(fields) do
		note[k] = v
	end
	if fields.title then
		note.title = ns.Trim(fields.title)
	end
	note.updated = time()
	ns.Fire("notes", id)
	return note
end

function N.Delete(id)
	if ns.db.notes[id] then
		ns.db.notes[id] = nil
		ns.Fire("notes")
		return true
	end
	return false
end

function N.DisplayTitle(note)
	if note.title and note.title ~= "" then
		return note.title
	end
	local first = ns.Preview(note.body or "", 40)
	return first ~= "" and first or L.UNTITLED
end

-- Visible to this character: account notes and its own.
function N.Visible(note, charKey)
	return note.char == nil or note.char == charKey
end

-- Notes of a tab (or every tab when section is nil) matching every word of the query, pinned first, newest first.
function N.Search(query, section, charKey)
	local words = {}
	for w in ns.Lower(query):gmatch("%S+") do
		table.insert(words, w)
	end
	local out = {}
	for _, note in pairs(ns.db.notes) do
		if (section == nil or note.section == section) and N.Visible(note, charKey) then
			local hay = string.lower(ns.PlainText((note.title or "") .. "\n" .. (note.body or "")))
			if note.attach then
				hay = hay .. "\n" .. string.lower(note.attach.label or "")
			end
			local ok = true
			for _, w in ipairs(words) do
				if not hay:find(w, 1, true) then
					ok = false
					break
				end
			end
			if ok then
				table.insert(out, note)
			end
		end
	end
	table.sort(out, function(a, b)
		if (a.pinned and true or false) ~= (b.pinned and true or false) then
			return a.pinned and true or false
		end
		if a.updated ~= b.updated then
			return a.updated > b.updated
		end
		return a.id < b.id
	end)
	return out
end

-- Attachments ------------------------------------------------------------------------------------

-- NPC ID from a creature GUID ("Creature-0-1234-0-56-448-0000ABCDEF" -> 448); nil for players and secret GUIDs.
function N.NpcIDFromGUID(guid)
	guid = ns.Plain(guid)
	if type(guid) ~= "string" then
		return nil
	end
	local kind, _, _, _, _, id = strsplit("-", guid)
	if kind == "Creature" or kind == "Vehicle" then
		return tonumber(id)
	end
	return nil
end

function N.Attach(id, kind, key, label)
	local note = ns.db.notes[id]
	if not note then
		return nil
	end
	if kind == nil then
		note.attach = nil
	else
		note.attach = { kind = kind, key = tostring(key), label = label }
	end
	note.updated = time()
	ns.Fire("notes", id)
	return note
end

function N.ForAttachment(kind, key, charKey)
	local out = {}
	if key == nil then
		return out
	end
	key = tostring(key)
	for _, note in pairs(ns.db.notes) do
		local a = note.attach
		if a and a.kind == kind and a.key == key and N.Visible(note, charKey) then
			table.insert(out, note)
		end
	end
	table.sort(out, function(a, b)
		return a.updated > b.updated
	end)
	return out
end

-- The first item linked in the body, to attach the note to that item: (itemID, name) or nil.
function N.FirstItemLink(note)
	local link = (note.body or ""):match("(|Hitem:.-|h.-|h)")
	if not link then
		return nil
	end
	local itemID = C_Item.GetItemInfoInstant(link)
	return itemID, ns.PlainText(link)
end

-- Images -----------------------------------------------------------------------------------------

local IMAGE_EXT = { png = true, jpg = true, jpeg = true, tga = true, blp = true }

-- Only a plain file name inside the images folder: no paths, so a note cannot point anywhere else.
function N.ValidImageName(name)
	name = ns.Trim(name)
	if name == "" or #name > 80 or not name:match("^[%w_%-%.]+$") or name:find("..", 1, true) then
		return nil
	end
	local ext = name:match("%.(%w+)$")
	if not ext or not IMAGE_EXT[string.lower(ext)] then
		return nil
	end
	return name
end

function N.ImagePath(name)
	-- PNG paths must include the extension (warcraft.wiki.gg, SetTexture); for the other formats it is optional
	return ns.IMAGE_FOLDER .. name
end

function N.AddImage(id, name)
	local note = ns.db.notes[id]
	name = N.ValidImageName(name)
	if not note or not name then
		return nil
	end
	note.images = note.images or {}
	for _, existing in ipairs(note.images) do
		if existing == name then
			return note
		end
	end
	table.insert(note.images, name)
	note.updated = time()
	ns.Fire("notes", id)
	return note
end

function N.RemoveImage(id, index)
	local note = ns.db.notes[id]
	if note and note.images and note.images[index] then
		table.remove(note.images, index)
		note.updated = time()
		ns.Fire("notes", id)
		return true
	end
	return false
end
