-- name: Honi's Odyssey Moveset
-- description: Wohoo Waaha Weeheehee Hoo Waah but odyssey style hell yea.

local TEXT_MOD_NAME = "[CS] Honi's Odyssey Moveset"

if not _G.charSelectExists then
    djui_popup_create("\\#ffffdc\\\n"..TEXT_MOD_NAME.."It's-a me, Honi! TURN ON CHARACTER SELECT GOD DAMNIT!!!!", 6)
    return 0
end

--local E_MODEL_HMARIO = smlua_model_util_get_id("hmario_geo")   -- Located in "actors"
--local TEX_ICON_HMARIO = get_texture_info("hmario-icon")

CHAR_HONIMARIO = _G.charSelect.character_add(
    "Mario Mario", -- Character Name
    "It's a me, le mario in the odyssey with cappy", -- Description
    "Honi", -- Credits
    "03fc7b",           -- Menu Color
    E_MODEL_MARIO,       -- Character Model
    CT_MARIO,           -- Override Character
    TEX_ICON_MARIO, -- Life Icon
    1,                  -- Camera Scale
    0                   -- Vertical Offset
)