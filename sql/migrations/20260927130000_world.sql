DROP PROCEDURE IF EXISTS add_migration;
DELIMITER ??
CREATE PROCEDURE `add_migration`()
BEGIN
DECLARE v INT DEFAULT 1;
SET v = (SELECT COUNT(*) FROM `migrations` WHERE `id`='20260927130000');
IF v = 0 THEN
INSERT INTO `migrations` VALUES ('20260927130000');
-- Add your query below.

-- ============================================================
-- Hardcore mode, part 5: stop pretending the server can rename
-- a client-side buff, and harden what it CAN control.
--
-- Migration 20260927120000 rewrote spell_template entry 5 with
-- name 'Hardcore' and spellIconId 136133 hoping the buff bar
-- would then read "Hardcore" with a CorpseExplode icon. It does
-- not, and it never can:
--
--   * The 1.12.1 (build 5875) and the Classic Era 1.14.2 (build
--     42597) clients build the buff frame exclusively from their
--     own Spell.dbc / SpellIcon.dbc. An aura packet only carries
--     the spell id, flags, level and duration - never a name,
--     rank, icon or description. So entry 5 is displayed as
--     "Death Touch" (icon INV_Misc_Bone_HumanSkull_01 on 1.12.1,
--     the client's own placeholder on 1.14) no matter what this
--     table contains.
--   * 136133 is a Mists of Pandaria icon id: the texture
--     Spell_Shadow_CorpseExplode does not exist in a vanilla
--     client at all, so the value could not have worked even if
--     icons were sent to the client.
--
-- What the server does control:
--   * WHICH spell id is used. It has to be one the client knows
--     (an id missing from the client's Spell.dbc is silently
--     dropped by the buff frame - that is why the custom 65001
--     "Omen of Mortality" never rendered). Entry 5 stays.
--   * WHETHER the client may cancel it: AFLAG_CANCELABLE is only
--     sent for positive auras without SPELL_ATTR_NO_AURA_CANCEL
--     (see SpellAuraHolder::SetAuraFlag), and the cancel request
--     is refused server side for that attribute too (see
--     WorldSession::HandleCancelAuraOpcode).
--
-- The visible label is therefore fixed on the client, by the new
-- addons/Hardcore addon (one build per client: 1.12.1 and
-- 1.14.2), which finds the badge in the buff list and rewrites
-- its icon and tooltip to "Hardcore".
--
-- This migration:
--  1) sets SPELL_ATTR_NO_AURA_CANCEL (0x80000000) on entry 5 so
--     the permanent badge cannot be right-clicked away by the
--     player (it would stay gone until the next login, since it
--     is only re-applied by Player::UpdateHardcoreIndicator()).
--  2) restores spellIconId to the vanilla value 1324 (the icon
--     the 1.12.1 client really draws for entry 5) instead of the
--     non-existent MoP icon, so the row matches the client data
--     again. spellIconId is server side only - it is used by a
--     few hardcoded spell checks, never sent to the client.
--
-- `name` stays 'Hardcore' on purpose: it is only ever used
-- server side (logs, .aura/.unaura and GM output) and never
-- reaches a client.
-- ============================================================

-- spellIconId is server side only (it is never sent to a client); restore the
-- value the 1.12.1 Spell.dbc really has for entry 5, so the row matches the
-- client data again instead of pointing at a texture no client here owns.
UPDATE `spell_template`
   SET `spellIconId` = 1324   -- INV_Misc_Bone_HumanSkull_01 in the 1.12.1 client
 WHERE `entry` = 5;

-- SPELL_ATTR_NO_AURA_CANCEL is bit 31, which has to be written as 2147483648
-- into an UNSIGNED column and as -2147483648 into a SIGNED one (assigning the
-- unsigned literal to a signed column is an out-of-range error under
-- STRICT_TRANS_TABLES, and would be silently clamped without it). The core
-- reads either form as the same bit - Field::GetUInt32() is
-- static_cast<uint32>(atol(...)) - so pick the form the column can store.
SET @attr_type = (SELECT `COLUMN_TYPE` FROM `INFORMATION_SCHEMA`.`COLUMNS`
                   WHERE `TABLE_SCHEMA` = DATABASE()
                     AND `TABLE_NAME`   = 'spell_template'
                     AND `COLUMN_NAME`  = 'attributes');
SET @no_aura_cancel = IF(@attr_type LIKE '%unsigned%',
    'UPDATE `spell_template` SET `attributes` = `attributes` | 2147483648 WHERE `entry` = 5 AND NOT (`attributes` & 2147483648)',
    'UPDATE `spell_template` SET `attributes` = `attributes` - 2147483648 WHERE `entry` = 5 AND `attributes` >= 0');
PREPARE stmt FROM @no_aura_cancel;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

END IF;
END??
DELIMITER ;
CALL add_migration();
DROP PROCEDURE IF EXISTS add_migration;
