DROP PROCEDURE IF EXISTS add_migration;
DELIMITER ??
CREATE PROCEDURE `add_migration`()
BEGIN
DECLARE v INT DEFAULT 1;
SET v = (SELECT COUNT(*) FROM `migrations` WHERE `id`='20260926130000');
IF v = 0 THEN
INSERT INTO `migrations` VALUES ('20260926130000');
-- Add your query below.

-- ============================================================
-- Hardcore mode, part 3: make the indicator buff actually
-- visible in the player's buff bar.
--
-- The previous custom indicator spell 65001 "Omen of Mortality"
-- (migration 20260923160000) can never render: the 1.12.1 client
-- builds its buff frame from its own Spell.dbc and silently skips
-- every aura whose spell id has no Spell.dbc record. A custom id
-- is invisible no matter what spell_template says.
--
-- The fix is to reuse a spell id that IS in the client DBC:
--   entry 5 "Death Touch" - Blizzard's own unused GM/test spell.
--   It ships in the 1.12.1 client Spell.dbc with a proper name,
--   is not passive and not flagged aura-hidden (the two attribute
--   tests the 1.12.1 buff frame applies), is not a tracking aura,
--   has RequiredAuraVision = 0, cannot be dispelled (dispel type
--   n/a) and is not used by any content in the game - its only
--   vanilla reference is the unobtainable test item 5418
--   "Weapon of Mass Destruction (test)".
--
-- This migration therefore:
--  1) Deletes the custom spell 65001 (unrenderable, now retired).
--  2) Reshapes spell_template entry 5 into the permanent indicator:
--     the Instakill effect is replaced with Apply Aura: DUMMY
--     (no mechanical effect), infinite duration, self target,
--     customFlags = 4 (positive/buff slot), applied by
--     Player::UpdateHardcoreIndicator() via
--     SPELL_PLAYER_HARDCORE_INDICATOR.
--
-- NOTE: loading a character with a stale saved 65001 aura would
-- log "unknown spell" warnings; companion migration
-- 20260926130001 (characters DB) purges those rows from
-- `character_aura`.
-- ============================================================

DELETE FROM `spell_template` WHERE `entry` = 65001;

DELETE FROM `spell_template` WHERE `entry` = 5;
INSERT INTO `spell_template` (`entry`, `build`, `school`, `category`, `castUI`, `dispel`, `mechanic`, `attributes`, `attributesEx`, `attributesEx2`, `attributesEx3`, `attributesEx4`, `stances`, `stancesNot`, `targets`, `targetCreatureType`, `requiresSpellFocus`, `casterAuraState`, `targetAuraState`, `castingTimeIndex`, `recoveryTime`, `categoryRecoveryTime`, `interruptFlags`, `auraInterruptFlags`, `channelInterruptFlags`, `procFlags`, `procChance`, `procCharges`, `maxLevel`, `baseLevel`, `spellLevel`, `durationIndex`, `powerType`, `manaCost`, `manCostPerLevel`, `manaPerSecond`, `manaPerSecondPerLevel`, `rangeIndex`, `speed`, `modelNextSpell`, `stackAmount`, `totem1`, `totem2`, `reagent1`, `reagent2`, `reagent3`, `reagent4`, `reagent5`, `reagent6`, `reagent7`, `reagent8`, `reagentCount1`, `reagentCount2`, `reagentCount3`, `reagentCount4`, `reagentCount5`, `reagentCount6`, `reagentCount7`, `reagentCount8`, `equippedItemClass`, `equippedItemSubClassMask`, `equippedItemInventoryTypeMask`, `effect1`, `effect2`, `effect3`, `effectDieSides1`, `effectDieSides2`, `effectDieSides3`, `effectBaseDice1`, `effectBaseDice2`, `effectBaseDice3`, `effectDicePerLevel1`, `effectDicePerLevel2`, `effectDicePerLevel3`, `effectRealPointsPerLevel1`, `effectRealPointsPerLevel2`, `effectRealPointsPerLevel3`, `effectBasePoints1`, `effectBasePoints2`, `effectBasePoints3`, `effectMechanic1`, `effectMechanic2`, `effectMechanic3`, `effectImplicitTargetA1`, `effectImplicitTargetA2`, `effectImplicitTargetA3`, `effectImplicitTargetB1`, `effectImplicitTargetB2`, `effectImplicitTargetB3`, `effectRadiusIndex1`, `effectRadiusIndex2`, `effectRadiusIndex3`, `effectApplyAuraName1`, `effectApplyAuraName2`, `effectApplyAuraName3`, `effectAmplitude1`, `effectAmplitude2`, `effectAmplitude3`, `effectMultipleValue1`, `effectMultipleValue2`, `effectMultipleValue3`, `effectChainTarget1`, `effectChainTarget2`, `effectChainTarget3`, `effectItemType1`, `effectItemType2`, `effectItemType3`, `effectMiscValue1`, `effectMiscValue2`, `effectMiscValue3`, `effectTriggerSpell1`, `effectTriggerSpell2`, `effectTriggerSpell3`, `effectPointsPerComboPoint1`, `effectPointsPerComboPoint2`, `effectPointsPerComboPoint3`, `spellVisual1`, `spellVisual2`, `spellIconId`, `activeIconId`, `spellPriority`, `name`, `nameFlags`, `nameSubtext`, `nameSubtextFlags`, `description`, `descriptionFlags`, `auraDescription`, `auraDescriptionFlags`, `manaCostPercentage`, `startRecoveryCategory`, `startRecoveryTime`, `minTargetLevel`, `maxTargetLevel`, `spellFamilyName`, `spellFamilyFlags`, `maxAffectedTargets`, `dmgClass`, `preventionType`, `stanceBarOrder`, `dmgMultiplier1`, `dmgMultiplier2`, `dmgMultiplier3`, `minFactionId`, `minReputation`, `requiredAuraVision`, `customFlags`) VALUES (5, 5875, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 101, 0, 0, 0, 0, 1, 21, 0, 0, 0, 0, 0, 12, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, -1, 0, 0, 6, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 4, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1324, 0, 0, 'Death Touch', 4128894, '', 4128892, '', 4128892, '', 4128892, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 4);

END IF;
END??
DELIMITER ;
CALL add_migration();
DROP PROCEDURE IF EXISTS add_migration;
