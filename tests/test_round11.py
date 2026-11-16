"""Round 11 (16 November 2026): links in ink on the pages, the game's options page inside its frame, pictures
picked from a list (the capture helper's index) and the album's photos."""

from __future__ import annotations

import pytest
from test_addon import Game


@pytest.fixture
def game():
    g = Game()
    g.login()
    g.m.runTimers()
    return g


WHITE = "|cffffffff|Hitem:2589::::::::1:::::::|h[Linen Cloth]|h|r"
GREEN = "|cff1eff00|Hitem:4306|h[Silk Cloth]|h|r"


# links on parchment --------------------------------------------------------------------------------


def test_links_in_a_note_wear_ink_on_the_page_and_keep_the_games_colour_when_saved(game):
    game.m.body = "cambio " + WHITE + " por " + GREEN
    game.run("ns.Toggle(1); local n = ns.Notes.Create({ title = 'Trueques', body = MOCK.body }); ns.UI.views[1].Select(n.id); MOCK.noteId = n.id")
    shown = game.run("return ns.UI.views[1].body:GetText()")
    # white and bright green cannot be read on parchment: ink and moss instead, the link itself untouched
    assert "|cff3a2313|Hitem:2589::::::::1:::::::|h[Linen Cloth]|h|r" in shown and "|cff1f6b2a|Hitem:4306|h[Silk Cloth]|h|r" in shown
    assert "|cffffffff" not in shown and "|cff1eff00" not in shown
    # typing saves the text with the game's colours (the tooltip of an NPC is dark: there they are right)
    game.run("ns.UI.views[1].body:SetFocus(); ns.UI.views[1].body:Insert(' y listo')")
    game.m.runTimers()
    assert game.run("return ns.Notes.Get(MOCK.noteId).body") == game.m.body + " y listo"


def test_a_shift_clicked_link_lands_in_ink_and_is_saved_in_the_games_colour(game):
    game.run("ns.Toggle(1); local n = ns.Notes.Create({ title = 'Links' }); ns.UI.views[1].Select(n.id); MOCK.noteId = n.id")
    game.run("ns.UI.views[1].body:SetFocus()")
    assert game.lua.globals().ChatFrameUtil.InsertLink(WHITE) is True
    assert game.run("return ns.UI.views[1].body:GetText()") == "|cff3a2313|Hitem:2589::::::::1:::::::|h[Linen Cloth]|h|r"
    assert game.run("return ns.Notes.Get(MOCK.noteId).body") == WHITE


def test_loot_in_the_journal_is_listed_in_ink(game):
    game.m.link = "|cff1eff00|Hitem:4306|h[Silk Cloth]|h|r"
    game.run("ns.Journal.Add('loot', { link = MOCK.link, item = 4306, quality = 2, name = '[Silk Cloth]' })")
    game.run("ns.Toggle('journal')")
    view = "ns.UI.views[ns.UI.tabOfTopic.journal]"
    game.run(view + ".filter = 'all'; " + view + ".Refresh()")
    texts = game.run("local out = {}; for _, row in ipairs(" + view + ".list.box.rows or {}) do if row.text then out[#out + 1] = row.text:GetText() end end; return table.concat(out, '\\n')")
    assert "|cff1f6b2a|Hitem:4306|h[Silk Cloth]|h|r" in texts and "|cff1eff00" not in texts


# the game's options page ----------------------------------------------------------------------------


def test_the_options_page_scrolls_inside_the_games_canvas(game):
    game.run("ns.UI.options.Build()")
    o = "ns.UI.options"
    # everything is drawn on the scroll child, nothing straight on the canvas
    assert game.run(f"return {o}.scroll.scrollChild == {o}.content, {o}.checks.minimap._parent == {o}.content, {o}.lang._parent == {o}.content") == (True, True, True)
    height = game.run(f"return {o}.content:GetHeight()")
    assert 400 < height < 560  # the full Bitácora: 12 ticks and two rows of pickers
    # a canvas taller than the content: no bar, nothing to scroll
    game.run(f"{o}.scroll:SetHeight(600); {o}.UpdateScroll()")
    assert game.run(f"return {o}.ScrollRange(), {o}.thumb:IsShown(), {o}.track:IsShown()") == (0, False, False)
    # a short one (small window, big UI scale): the wheel moves it, never past either end
    game.run(f"{o}.scroll:SetHeight(300); {o}.UpdateScroll()")
    rng = game.run(f"return {o}.ScrollRange()")
    assert rng == height - 300 and game.run(f"return {o}.thumb:IsShown()") is True
    wheel = f"{o}.scroll:GetScript('OnMouseWheel')({o}.scroll, %d)"
    game.run(wheel % -1)
    assert game.run(f"return {o}.scroll:GetVerticalScroll()") == 40
    for _ in range(20):
        game.run(wheel % -1)
    assert game.run(f"return {o}.scroll:GetVerticalScroll()") == rng
    for _ in range(30):
        game.run(wheel % 1)
    assert game.run(f"return {o}.scroll:GetVerticalScroll()") == 0


def test_option_lines_are_short_and_the_long_story_is_a_tooltip(game):
    game.run("ns.UI.options.Build()")
    for key in ("chronicle", "guildReminders", "minimapMerged"):
        assert game.run(f"return ns.UI.options.checks.{key}:GetScript('OnEnter') ~= nil") is True, key
    for lang in ("en", "es"):
        game.run(f"ns.SetLocale('{lang}')")
        longest = game.run(
            "local n = 0; for _, k in ipairs({ 'OPT_TOOLTIP', 'OPT_ZONE', 'OPT_QUESTS', 'OPT_CHRONICLE', 'OPT_GUILD_REMINDERS',"
            " 'OPT_REMINDER_POPUP', 'OPT_CALENDAR', 'OPT_CALENDAR_AUTO', 'OPT_CAMP_BUFF', 'OPT_BOOK_INTRO', 'OPT_MINIMAP',"
            " 'OPT_MINIMAP_MERGED' }) do n = math.max(n, #ns.L[k]) end; return n"
        )
        assert longest <= 80, (lang, longest)  # about 540 px in the game's font: inside the canvas


def test_the_pickers_sit_two_per_row(game):
    game.run("ns.UI.options.Build()")
    pts = game.run("local out = {}; for i, k in ipairs({ 'loot', 'clock', 'chat', 'lang' }) do out[i] = ns.UI.options[k]:IsShown() end; return unpack(out)")
    assert pts == (True, True, True, True)


# pictures --------------------------------------------------------------------------------------------

INDEX = """
BitacoraImagenesIndice = { version = 1, made = 1794800000, images = {
    { file = "captura_02.tga", title = "Captura 16/11 14:32", w = 1920, h = 1080, t = 1794800000 },
    { file = "captura_01.tga", title = "Captura del juego 16/11 00:53", w = 1920, h = 1080, t = 1794750000, shot = "111626_005316" },
    { file = "arg.tga", title = "arg", w = 3000, h = 2000, t = 1700000000, from = "arg.jpg" },
    { file = "..\\\\..\\\\WTF\\\\secreto.tga", title = "afuera", w = 8, h = 8, t = 1794900000 },
    { file = "sin_medidas.tga" },
    "no soy una tabla",
} }
"""


def answer_prompt(game, text):
    """Types into the last text prompt and accepts it."""
    popups = game.m.popups
    game.m.answer = text
    game.run("local p = MOCK.popups[#MOCK.popups]; p.data.fn(MOCK.answer)")
    return popups


def test_without_the_helper_the_card_explains_it_and_typing_a_name_still_works(game):
    game.run("ns.Toggle(1); local n = ns.Notes.Create({ title = 'Fotos' }); ns.UI.views[1].Select(n.id); MOCK.noteId = n.id")
    assert game.run("return ns.Images.HasHelper()") is False
    game.run("local v = ns.UI.views[1]; v.addImage:GetScript('OnClick')(v.addImage)")
    card = "ns.UI.imagePicker"
    assert game.run(f"return {card}:IsShown(), {card}.empty:IsShown(), {card}.url:IsShown()") == (True, True, True)
    assert "capture helper" in game.run(f"return {card}.empty:GetText()")
    assert game.run(f"return {card}.url:GetText()") == "github.com/JoseArgento/bitacora/tree/main/ayudante"
    # nothing chosen: "Add to the note" is off; the old way (typing the file name) is one button away
    assert game.run(f"return {card}.use:IsEnabled()") is False
    game.run(f"{card}.typeIt:GetScript('OnClick')({card}.typeIt)")
    answer_prompt(game, "mapa.png")
    assert list(game.run("return ns.Notes.Get(MOCK.noteId).images").values()) == ["mapa.png"]
    assert game.run(f"return {card}:IsShown()") is False
    # a bad name is refused and said
    game.run("local v = ns.UI.views[1]; v.addImage:GetScript('OnClick')(v.addImage)")
    game.run(f"{card}.typeIt:GetScript('OnClick')({card}.typeIt)")
    answer_prompt(game, "..\\\\WTF\\\\Config.wtf")
    assert list(game.run("return ns.Notes.Get(MOCK.noteId).images").values()) == ["mapa.png"]
    # a name typed in a note is offered next time, marked as typed by hand
    game.run("ns.UI.PickImage(function() end)")
    assert game.run(f"return #{card}.items, {card}.items[1].file, {card}.items[1].typed, {card}.items[1].uses") == (1, "mapa.png", True, 1)


def test_the_helpers_index_is_read_carefully(game):
    game.lua.execute(INDEX)
    files = [e.file for e in game.run("return ns.Images.Index()").values()]
    # newest first; the entry that points outside the folder and the one that is not a table are dropped
    assert files == ["captura_02.tga", "captura_01.tga", "arg.tga", "sin_medidas.tga"]
    # a name is found as itself, as the file it was converted from, or by its name without the extension
    for name in ("arg.tga", "ARG.TGA", "arg.jpg", "arg.png"):
        assert game.run(f"return ns.Images.Find('{name}').file") == "arg.tga", name
    assert game.run("return ns.Images.Find('otra.png')") is None
    assert game.run("return ns.Images.Path('arg.png')") == "Interface\\AddOns\\BitacoraImagenes\\arg.tga"
    assert game.run("return ns.Images.Path('otra.png')") == "Interface\\AddOns\\BitacoraImagenes\\otra.png"
    # the picture's shape comes back from its own size (the texture is squeezed to powers of two)
    assert game.run("return ns.Images.Fit('captura_02.tga', 60, 60)") == (60, 34)
    assert game.run("return ns.Images.Fit('arg.png', 508, 506)") == (508, 339)
    assert game.run("return ns.Images.Fit('sin_medidas.tga', 60, 60)") == (60, 60)
    assert game.run("return ns.Images.ByShot('111626_005316')") == "captura_01.tga"
    assert game.run("return ns.Images.ByShot('010101_000000')") is None and game.run("return ns.Images.ByShot(nil)") is None


def test_picking_a_picture_from_the_list_puts_it_in_the_note(game):
    game.lua.execute(INDEX)
    # the note José had: "arg.png" typed by hand for a file that was arg.jpg
    game.run("ns.Toggle(1); local n = ns.Notes.Create({ title = 'Fotitos' }); ns.Notes.AddImage(n.id, 'arg.png'); ns.UI.views[1].Select(n.id); MOCK.noteId = n.id")
    game.run("local v = ns.UI.views[1]; v.addImage:GetScript('OnClick')(v.addImage)")
    card = "ns.UI.imagePicker"
    items = game.run(f"return {card}.items")
    assert [(i.file, i.uses) for i in items.values()] == [("captura_02.tga", 0), ("captura_01.tga", 0), ("arg.tga", 1), ("sin_medidas.tga", 0)]
    assert game.run(f"return {card}.empty:IsShown(), {card}.url:IsShown()") == (False, False)
    rows = f"{card}.list.box.rows"
    assert game.run(f"return {rows}[1].title:GetText(), {rows}[1].sub:GetText()")[0] == "Captura 16/11 14:32"
    assert "game screenshot" in game.run(f"return {rows}[2].sub:GetText()") and "in 1 note" in game.run(f"return {rows}[3].sub:GetText()")
    assert game.run(f"return {rows}[1].tex:GetWidth(), {rows}[1].tex:GetHeight(), {rows}[1].tex.texture") == (36, 20, "Interface\\AddOns\\BitacoraImagenes\\captura_02.tga")
    # click one: it shows big, with its shape; "Add to the note" puts it in and closes the card
    game.run(f"{rows}[1]:GetScript('OnClick')({rows}[1], 'LeftButton')")
    assert game.run(f"return {card}.tex:GetWidth(), {card}.tex:GetHeight(), {card}.name:GetText(), {card}.use:IsEnabled()") == (272, 153, "Captura 16/11 14:32", True)
    game.run(f"{card}.use:GetScript('OnClick')({card}.use)")
    assert list(game.run("return ns.Notes.Get(MOCK.noteId).images").values()) == ["arg.png", "captura_02.tga"]
    assert game.run(f"return {card}:IsShown()") is False
    # in the note: the mistyped one shows the converted file, both keep their shape inside the 64 px square
    thumbs = "ns.UI.views[1].thumbs"
    assert game.run(f"return {thumbs}[1].tex.texture, {thumbs}[1].tex:GetWidth(), {thumbs}[1].tex:GetHeight()") == ("Interface\\AddOns\\BitacoraImagenes\\arg.tga", 60, 40)
    assert game.run(f"return {thumbs}[2].tex:GetWidth(), {thumbs}[2].tex:GetHeight(), {thumbs}[3]:IsShown()") == (60, 34, False)


def test_a_picture_can_be_given_a_name_of_your_own(game):
    game.lua.execute(INDEX)
    game.run("ns.UI.PickImage(nil)")
    card = "ns.UI.imagePicker"
    rows = f"{card}.list.box.rows"
    game.run(f"{rows}[2]:GetScript('OnClick')({rows}[2], 'LeftButton')")
    game.run(f"{card}.rename:GetScript('OnClick')({card}.rename)")
    answer_prompt(game, "  Molten Core con la guild  ")
    assert game.run("return ns.Images.Title('captura_01.tga')") == "Molten Core con la guild"
    assert game.db.imageTitles["captura_01.tga"] == "Molten Core con la guild"
    assert game.run(f"return {card}.name:GetText(), {rows}[2].title:GetText()") == ("Molten Core con la guild", "Molten Core con la guild")
    # opened without a note behind it (from the album): there is nothing to add to
    assert game.run(f"return {card}.use:IsEnabled()") is False
    # an empty name gives the helper's title back
    game.run("ns.Images.SetTitle('captura_01.tga', '')")
    assert game.run("return ns.Images.Title('captura_01.tga')") == "Captura del juego 16/11 00:53"


def test_the_album_shows_the_photo_the_helper_brought(game):
    game.lua.execute(INDEX)
    game.fire("SCREENSHOT_SUCCEEDED")
    game.fire("SCREENSHOT_SUCCEEDED")
    game.run("ns.Char().album[1].stamp = '111626_005316'; ns.Char().album[2].stamp = '111626_005319'")
    game.run("ns.Toggle('album')")
    view = "ns.UI.views[ns.UI.tabOfTopic.album]"
    game.run(f"{view}.Refresh()")
    rows = f"{view}.list.box.rows"
    # newest first: the second shot has no photo, the first one does
    assert "with picture" not in game.run(f"return {rows}[1].bottom:GetText()") and "with picture" in game.run(f"return {rows}[2].bottom:GetText()")
    game.run(f"{rows}[2]:GetScript('OnClick')({rows}[2], 'LeftButton')")
    assert game.run(f"return {view}.photoBox:IsShown(), {view}.noPhoto:IsShown(), {view}.photo.texture, {view}.photo:GetWidth(), {view}.photo:GetHeight()") == (
        True,
        False,
        "Interface\\AddOns\\BitacoraImagenes\\captura_01.tga",
        320,
        180,
    )
    game.run(f"{rows}[1]:GetScript('OnClick')({rows}[1], 'LeftButton')")
    assert game.run(f"return {view}.photoBox:IsShown(), {view}.noPhoto:IsShown()") == (False, True)
    # "Pictures" opens the same card the notes use
    game.run(f"{view}.pictures:GetScript('OnClick')({view}.pictures)")
    # the four of the helper, plus the screenshot it did not bring (this mock cannot tell what loads: "unsure")
    assert game.run("return ns.UI.imagePicker:IsShown(), #ns.UI.imagePicker.items") == (True, 5)
    assert game.run("local n = 0; for _, it in ipairs(ns.UI.imagePicker.items) do if it.unsure then n = n + 1 end end; return n") == 1


def test_forevers_named_colour_links_read_as_plain_text_in_previews_and_search(game):
    # Forever writes item links as "|cnIQ1:|Hitem:…|h[Linen Cloth]|h|r": the list preview showed the colour code
    body = "120 de |cnIQ1:|Hitem:2589::::::::16:1485:::::::::|h[Linen Cloth]|h|r para el cambio"
    game.m.body = body
    assert game.run("return ns.PlainText(MOCK.body)") == "120 de [Linen Cloth] para el cambio"
    game.run("ns.Toggle(1); local n = ns.Notes.Create({ title = 'Lino', body = MOCK.body }); ns.UI.views[1].Select(n.id); MOCK.noteId = n.id")
    rows = "ns.UI.views[1].list.box.rows"
    assert game.run(f"return {rows}[1].sub:GetText()") == "120 de [Linen Cloth] para el cambio"
    # on the page the link is in ink, and what is saved is exactly what the game wrote
    assert "|cff3a2313|Hitem:2589::::::::16:1485:::::::::|h[Linen Cloth]|h|r" in game.run("return ns.UI.views[1].body:GetText()")
    game.run("ns.UI.views[1].body:SetFocus(); ns.UI.views[1].body:Insert('!')")
    game.m.runTimers()
    assert game.run("return ns.Notes.Get(MOCK.noteId).body") == body + "!"
    assert len(game.run("return ns.Notes.Search('linen cloth', nil, ns.CharKey())")) == 1


# game screenshots, with nothing installed ----------------------------------------------------------------

FOLDER = "Interface\\AddOns\\BitacoraImagenes\\"


def with_files(game, *paths):
    """A client whose SetTexture says whether the file loaded (MOCK.files = the files that exist)."""
    game.run("MOCK.files = { [ns.MEDIA .. 'icon.tga'] = true }; GetPhysicalScreenSize = function() return 1920, 1080 end")
    for path in paths:
        game.m.path = path
        game.run("MOCK.files[MOCK.path] = true")


def test_screenshots_copied_to_the_folder_are_listed_without_typing_anything(game):
    for _ in range(3):
        game.fire("SCREENSHOT_SUCCEEDED")
    game.run("local a = ns.Char().album; a[1].stamp, a[1].t = '111426_101010', 100; a[2].stamp, a[2].t = '111526_202020', 200; a[3].stamp, a[3].t = '111626_005316', 300; a[3].caption = 'Molten Core'")
    # two of the three were copied: one to the pictures folder, one pasted straight into AddOns
    with_files(game, "Interface\\AddOns\\BitacoraImagenes\\WoWScrnShot_111626_005316.jpg", "Interface\\AddOns\\WoWScrnShot_111426_101010.jpg")
    assert game.run("return ns.Images.CanProbe(), ns.Images.HasHelper()") == (True, False)
    game.run("ns.Toggle(1); local n = ns.Notes.Create({ title = 'Fotos' }); ns.UI.views[1].Select(n.id); MOCK.noteId = n.id")
    game.run("local v = ns.UI.views[1]; v.addImage:GetScript('OnClick')(v.addImage)")
    card = "ns.UI.imagePicker"
    items = game.run(f"return {card}.items")
    # newest first, named by the caption or by when and where; the one that is nowhere is not offered
    assert [(i.file, i.unsure) for i in items.values()] == [("WoWScrnShot_111626_005316.jpg", None), ("WoWScrnShot_111426_101010.jpg", None)]
    assert items[1].title == "Molten Core" and "Elwynn" in items[2].title
    assert game.run(f"return {card}.empty:IsShown(), {card}.url:IsShown()") == (False, False)
    assert "by themselves" in game.run(f"return {card}.hint:GetText()")
    rows = f"{card}.list.box.rows"
    # the thumbnail has the shape of the screen and loads from where the file was found
    assert game.run(f"return {rows}[2].tex.texture, {rows}[2].tex:GetWidth(), {rows}[2].tex:GetHeight()") == ("Interface\\AddOns\\WoWScrnShot_111426_101010.jpg", 36, 20)
    game.run(f"{rows}[1]:GetScript('OnClick')({rows}[1], 'LeftButton'); {card}.use:GetScript('OnClick')({card}.use)")
    assert list(game.run("return ns.Notes.Get(MOCK.noteId).images").values()) == ["WoWScrnShot_111626_005316.jpg"]
    thumbs = "ns.UI.views[1].thumbs"
    assert game.run(f"return {thumbs}[1].tex.texture, {thumbs}[1].tex:GetWidth(), {thumbs}[1].tex:GetHeight()") == (FOLDER.replace("\\\\", "\\") + "WoWScrnShot_111626_005316.jpg", 60, 34)
    # the album shows the photo of the ones that load, and says what to do for the other
    game.run("ns.Toggle('album')")
    view = "ns.UI.views[ns.UI.tabOfTopic.album]"
    game.run(f"{view}.Refresh()")
    arows = f"{view}.list.box.rows"
    game.run(f"{arows}[1]:GetScript('OnClick')({arows}[1], 'LeftButton')")
    assert game.run(f"return {view}.photoBox:IsShown(), {view}.photo.texture") == (True, "Interface\\AddOns\\BitacoraImagenes\\WoWScrnShot_111626_005316.jpg")
    game.run(f"{arows}[2]:GetScript('OnClick')({arows}[2], 'LeftButton')")
    assert game.run(f"return {view}.photoBox:IsShown(), {view}.noPhoto:IsShown()") == (False, True)
    assert "Screenshots" in game.run(f"return {view}.noPhoto:GetText()")


def test_a_client_that_loads_straight_from_screenshots_needs_no_copying(game):
    game.fire("SCREENSHOT_SUCCEEDED")
    game.run("ns.Char().album[1].stamp = '111626_132213'")
    with_files(game, "Screenshots\\WoWScrnShot_111626_132213.jpg")
    assert game.run("return ns.Images.ByShot('111626_132213'), ns.Images.Path('WoWScrnShot_111626_132213.jpg')") == ("WoWScrnShot_111626_132213.jpg", "Screenshots\\WoWScrnShot_111626_132213.jpg")
    assert len(game.run("return ns.Images.List()")) == 1
    # /bita imagenes says what the game answered, for a bug report
    game.m.chat = game.lua.table()
    game.lua.globals().SlashCmdList.BITACORA("imagenes")
    said = " ".join(game.m.chat.values())
    assert "capturas del álbum: 1" in said and "1 en Screenshots" in said


def test_the_screenshot_format_setting_names_the_file(game):
    game.fire("SCREENSHOT_SUCCEEDED")
    game.run("ns.Char().album[1].stamp = '111626_132213'; C_CVar = { GetCVar = function() return 'tga' end }")
    assert game.run("return (ns.Images.ShotFile(ns.Char().album[1]))") == "WoWScrnShot_111626_132213.tga"
    assert game.run("return ns.Images.ShotFile({ stamp = '../../x' })") is None


# the links of a note, where the mouse can ask about them -----------------------------------------------


def test_the_links_of_a_note_are_listed_under_the_text_with_their_tooltips(game):
    game.m.body = "armadura: " + GREEN + " y " + WHITE + " y otra vez " + WHITE
    game.run("ns.Toggle(1); local n = ns.Notes.Create({ title = 'Links', body = MOCK.body }); ns.UI.views[1].Select(n.id); MOCK.noteId = n.id")
    line = "ns.UI.views[1].linksLine"
    text = game.run(f"return {line}:GetText()")
    # each link once, in ink (the same link, so the tooltip is the item's)
    assert text == "|cff1f6b2a|Hitem:4306|h[Silk Cloth]|h|r |cff3a2313|Hitem:2589::::::::1:::::::|h[Linen Cloth]|h|r"
    assert game.run(f"return {line}:IsShown()") is True
    assert game.run(f"return {line}:GetScript('OnHyperlinkEnter') ~= nil") is True
    # a note without links shows the hint instead
    game.run("local n = ns.Notes.Create({ title = 'Sin links', body = 'nada' }); ns.UI.views[1].Select(n.id)")
    assert game.run(f"return {line}:IsShown()") is False
    # many links: the ones that do not fit on the line are counted
    many = " ".join(f"|cffffffff|Hitem:{i}|h[A fairly long item name {i}]|h|r" for i in range(1, 7))
    game.m.body = many
    game.run("local n = ns.Notes.Create({ title = 'Muchos', body = MOCK.body }); ns.UI.views[1].Select(n.id)")
    assert game.run(f"return {line}:GetText()").endswith(" +4")


def test_a_client_whose_settexture_always_says_yes_is_asked_another_way(game):
    # Forever (16/11): SetTexture's "success" could not tell a missing file. The addon tries the other ways and
    # keeps the first one that tells a texture of ours from a name that cannot exist.
    game.fire("SCREENSHOT_SUCCEEDED")
    game.run("ns.Char().album[1].stamp = '111626_141801'")
    game.m.have = "Interface\\AddOns\\BitacoraImagenes\\WoWScrnShot_111626_141801.jpg"
    game.run('MOCK.exists = { [ns.MEDIA .. "icon.tga"] = 55, [MOCK.have] = 77 }')
    # the mock's textures share their methods through Frame: SetTexture says yes to everything, the file ID tells
    game.lua.execute("""
        local probe = UIParent:CreateTexture()
        local class = debug.getmetatable(probe)
        local old = class.__index
        class.__index = function(self, key)
            if key == "SetTexture" then
                return function(t, path) rawset(t, "texture", path) return true end
            elseif key == "GetTextureFileID" then
                return function(t) return MOCK.exists[rawget(t, "texture")] or 0 end
            end
            if type(old) == "function" then return old(self, key) end
            return old[key]
        end
    """)
    assert game.run("return ns.Images.CanProbe(), ns.Images.Way()") == (True, "GetTextureFileID")
    assert game.run("return ns.Images.Locate('WoWScrnShot_111626_141801.jpg')") == game.m.have
    assert game.run("return ns.Images.Locate('WoWScrnShot_000000_000000.jpg')") is None
    report = "\n".join(game.run("return ns.Images.Report()").values())
    assert "sí, con GetTextureFileID" in report and "de las que el juego puede mostrar: 1" in report
    assert "inexistente: SetTexture=si GetTextureFileID=no" in report and "nuestra: SetTexture=si GetTextureFileID=si" in report


def test_when_the_game_cannot_tell_the_screenshots_folder_is_tried_underneath(game):
    game.fire("SCREENSHOT_SUCCEEDED")
    game.run("ns.Char().album[1].stamp = '111626_141801'")
    assert game.run("return ns.Images.CanProbe()") is False  # this mock answers nothing
    game.run("ns.UI.PickImage(nil)")
    row = "ns.UI.imagePicker.list.box.rows[1]"
    assert game.run(f"return {row}.tex.texture, {row}.tex.under.texture, {row}.tex.under:IsShown()") == (
        "Interface\\AddOns\\BitacoraImagenes\\WoWScrnShot_111626_141801.jpg",
        "Screenshots\\WoWScrnShot_111626_141801.jpg",
        True,
    )
    # the row is named by when and where, and does not repeat the date under it
    assert game.run(f"return {row}.sub:GetText()") == "game screenshot"


def test_take_screenshot_puts_the_picture_in_the_note(game):
    # Forever loads pictures straight from the Screenshots folder (seen in the client, 16/11): the button takes
    # the screenshot with the book out of the way and the note gets it, with nothing copied or typed
    game.run("MOCK.taken = 0; Screenshot = function() MOCK.taken = MOCK.taken + 1 end")
    game.run("ns.Toggle(1); local n = ns.Notes.Create({ title = 'Fotos' }); ns.UI.views[1].Select(n.id); MOCK.noteId = n.id")
    v = "ns.UI.views[1]"
    assert game.run(f"return {v}.takeShot:IsShown(), {v}.takeShot:IsEnabled()") == (True, True)
    game.run(f"{v}.takeShot:GetScript('OnClick')({v}.takeShot)")
    assert game.run("return ns.UI.frame:GetAlpha(), MOCK.taken") == (0, 0)  # the book is out of the picture first
    game.run(f"{v}.takeShot:GetScript('OnClick')({v}.takeShot)")  # a second click while it is busy does nothing
    # a tenth of a second later the game is asked for the picture (the 3 s safety net has not run yet)
    game.run("local t = MOCK.timers; MOCK.timers = { t[2] }; t[1]()")
    assert game.run("return MOCK.taken") == 1
    game.fire("SCREENSHOT_SUCCEEDED")
    stamp = game.run("local a = ns.Char().album; return a[#a].stamp")
    assert game.run("return ns.UI.frame:GetAlpha()") == 1
    assert list(game.run("return ns.Notes.Get(MOCK.noteId).images").values()) == [f"WoWScrnShot_{stamp}.jpg"]
    game.m.runTimers()
    # a screenshot taken by hand while nothing is pending is not added to any note
    game.fire("SCREENSHOT_SUCCEEDED")
    assert len(game.run("return ns.Notes.Get(MOCK.noteId).images")) == 1


def test_the_book_comes_back_when_the_game_never_takes_the_screenshot(game):
    game.run("Screenshot = function() end")
    game.run("ns.Toggle(1); local n = ns.Notes.Create({ title = 'Fotos' }); ns.UI.views[1].Select(n.id); MOCK.noteId = n.id")
    game.run("local b = ns.UI.views[1].takeShot; b:GetScript('OnClick')(b)")
    assert game.run("return ns.UI.frame:GetAlpha()") == 0
    game.m.runTimers()
    assert game.run("return ns.UI.frame:GetAlpha()") == 1
    assert game.run("return ns.Notes.Get(MOCK.noteId).images") is None or len(game.run("return ns.Notes.Get(MOCK.noteId).images")) == 0


def test_a_screenshot_stamped_a_second_late_is_still_found(game):
    # the album notes the time when the game says the screenshot is done; the file was named a moment before
    game.fire("SCREENSHOT_SUCCEEDED")
    game.run("local s = ns.Char().album[1]; s.stamp, s.t = '111626_142000', 5")
    with_files(game, "Screenshots\\WoWScrnShot_111626_141959.jpg")
    assert list(game.run("return ns.Images.EarlierStamps('111626_142000')").values()) == ["111626_141959", "111626_141958"]
    assert game.run("return ns.Images.ByShot('111626_142000', 5)") == "WoWScrnShot_111626_141959.jpg"
    items = game.run("return ns.Images.List()")
    assert len(items) == 1 and items[1].file == "WoWScrnShot_111626_141959.jpg"
    assert "Elwynn" in game.run("return ns.Images.Title('WoWScrnShot_111626_141959.jpg')")


def test_a_screenshot_taken_since_the_game_started_waits_for_the_next_start(game):
    # seen in the client (16/11): Forever loads from Screenshots only the files that were there when the game
    # started; the ones taken since do not load, not even after /reload, and do after a restart
    game.run("MOCK.taken = 0; Screenshot = function() MOCK.taken = MOCK.taken + 1 end")
    with_files(game)  # the client can tell what loads, and the new screenshot is not among it
    game.fire("SCREENSHOT_SUCCEEDED")
    game.run("local a = ns.Char().album; a[1].stamp, a[1].t = '110126_101010', time() - 20 * 86400")  # old and deleted
    game.run("ns.Toggle(1); local n = ns.Notes.Create({ title = 'Fotos' }); ns.UI.views[1].Select(n.id); MOCK.noteId = n.id")
    v = "ns.UI.views[1]"
    game.m.chat = game.lua.table()
    game.run(f"{v}.takeShot:GetScript('OnClick')({v}.takeShot)")
    game.run("local t = MOCK.timers; MOCK.timers = {}; t[1]()")
    game.fire("SCREENSHOT_SUCCEEDED")
    stamp = game.run("local a = ns.Char().album; return a[#a].stamp")
    file = f"WoWScrnShot_{stamp}.jpg"
    assert list(game.run("return ns.Notes.Get(MOCK.noteId).images").values()) == [file]
    # said once in the chat, and in the thumbnail's place
    assert sum("next time you start the game" in c for c in game.m.chat.values()) == 1
    thumbs = f"{v}.thumbs"
    assert game.run(f"return {thumbs}[1].tex.pending:IsShown(), {thumbs}[1].tex.pending:GetText()") == (True, "after a restart")
    # the list offers it (it can go into other notes meanwhile) and says why it shows no picture; the old one
    # whose file is gone is not offered
    game.run(f"{v}.addImage:GetScript('OnClick')({v}.addImage)")
    items = game.run("return ns.UI.imagePicker.items")
    assert [(i.file, i.pending, i.typed) for i in items.values()] == [(file, True, None)]
    assert "shows after you restart the game" in game.run("return ns.UI.imagePicker.list.box.rows[1].sub:GetText()")
    # after the restart the file loads: no more waiting
    game.m.path = "Screenshots\\" + file
    game.run("MOCK.files[MOCK.path] = true")
    assert game.run(f"return ns.Images.IsPending('{file}'), ns.Images.Path('{file}')") == (False, "Screenshots\\" + file)


def test_a_note_holds_up_to_eight_pictures_in_one_row(game):
    game.run("ns.Toggle(1); local n = ns.Notes.Create({ title = 'Muchas' }); for i = 1, 4 do ns.Notes.AddImage(n.id, 'foto' .. i .. '.png') end; ns.UI.views[1].Select(n.id); MOCK.noteId = n.id")
    v = "ns.UI.views[1]"
    # four: big, with their names
    assert game.run(f"return {v}.thumbs[4]:GetWidth(), {v}.thumbs[4].name:IsShown(), {v}.addImage:IsEnabled()") == (64, True, True)
    game.run("for i = 5, 8 do ns.Notes.AddImage(MOCK.noteId, 'foto' .. i .. '.png') end; ns.UI.views[1].ShowNote()")
    # eight: small, all visible in the page's width, and the buttons stop there
    assert game.run(f"return #{v}.thumbs, {v}.thumbs[8]:IsShown(), {v}.thumbs[8]:GetWidth(), {v}.thumbs[8].name:IsShown()") == (8, True, 40, False)
    assert 7 * 45 + 40 <= 366
    assert game.run(f"return {v}.addImage:IsEnabled(), {v}.takeShot:IsEnabled()") == (False, False)


def test_a_click_on_the_big_picture_shows_it_as_big_as_the_screen_allows(game):
    game.lua.execute(INDEX)
    game.run("UIParent.width, UIParent.height = 1920, 1080; GetPhysicalScreenSize = function() return 1920, 1080 end")
    game.run("ns.Toggle(1); local n = ns.Notes.Create({ title = 'Fotos' }); ns.Notes.AddImage(n.id, 'captura_02.tga'); ns.Notes.AddImage(n.id, 'chica.png'); ns.UI.views[1].Select(n.id)")
    v = "ns.UI.views[1]"
    game.run(f"{v}.thumbs[1]:GetScript('OnClick')({v}.thumbs[1], 'LeftButton')")
    assert game.run("return ns.UI.imagePreview:IsShown(), ns.UI.imagePreview.tex:GetWidth()") == (True, 508)
    game.run("ns.UI.imagePreview.box:GetScript('OnMouseUp')(ns.UI.imagePreview.box, 'LeftButton')")
    # a 1920×1080 picture on a 1920×1080 screen: 90 % of the height, its shape kept
    assert game.run("return ns.UI.imagePreview:IsShown(), ns.UI.imageZoom:IsShown(), ns.UI.imageZoom.tex:GetWidth(), ns.UI.imageZoom.tex:GetHeight()") == (False, True, 1728, 972)
    assert game.run("return ns.UI.imageZoom.title:GetText()") == "Captura 16/11 14:32"
    # a click anywhere closes it
    game.run("ns.UI.imageZoom:GetScript('OnClick')(ns.UI.imageZoom, 'LeftButton')")
    assert game.run("return ns.UI.imageZoom:IsShown()") is False
