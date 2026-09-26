DROP PROCEDURE IF EXISTS add_migration;
DELIMITER ??
CREATE PROCEDURE `add_migration`()
BEGIN
DECLARE v INT DEFAULT 1;
SET v = (SELECT COUNT(*) FROM `migrations` WHERE `id`='20260923160000');
IF v = 0 THEN
INSERT INTO `migrations` VALUES ('20260923160000');
-- Add your query below.

-- ============================================================
-- Hardcore mode, part 2:
--  1) Spell 65001 "Omen of Mortality" - visual-only Hardcore
--     indicator buff (Apply Aura: DUMMY = literal no-op,
--     infinite duration, customFlags=4 -> positive/buff slot).
--     Applied by Player::UpdateHardcoreIndicator().
--     The 2.4.3 client has no data for this id, so the buff
--     slot renders with a blank icon (same as custom 29999).
--     NOTE: spell_template.entry is SMALLINT UNSIGNED (max
--     65535, see migration 20240304213652), so custom spell
--     ids must stay <= 65535 - 80001 did not fit and this
--     migration originally failed with error 1264.
--  2) Reposition all 18 Watcher of Mortality (80000) spawns
--     away from NPC clutter (Goldshire was mid-street).
-- ============================================================

DELETE FROM `spell_template` WHERE `entry` = 65001;
INSERT INTO `spell_template` (`entry`, `build`, `school`, `category`, `castUI`, `dispel`, `mechanic`, `attributes`, `attributesEx`, `attributesEx2`, `attributesEx3`, `attributesEx4`, `stances`, `stancesNot`, `targets`, `targetCreatureType`, `requiresSpellFocus`, `casterAuraState`, `targetAuraState`, `castingTimeIndex`, `recoveryTime`, `categoryRecoveryTime`, `interruptFlags`, `auraInterruptFlags`, `channelInterruptFlags`, `procFlags`, `procChance`, `procCharges`, `maxLevel`, `baseLevel`, `spellLevel`, `durationIndex`, `powerType`, `manaCost`, `manCostPerLevel`, `manaPerSecond`, `manaPerSecondPerLevel`, `rangeIndex`, `speed`, `modelNextSpell`, `stackAmount`, `totem1`, `totem2`, `reagent1`, `reagent2`, `reagent3`, `reagent4`, `reagent5`, `reagent6`, `reagent7`, `reagent8`, `reagentCount1`, `reagentCount2`, `reagentCount3`, `reagentCount4`, `reagentCount5`, `reagentCount6`, `reagentCount7`, `reagentCount8`, `equippedItemClass`, `equippedItemSubClassMask`, `equippedItemInventoryTypeMask`, `effect1`, `effect2`, `effect3`, `effectDieSides1`, `effectDieSides2`, `effectDieSides3`, `effectBaseDice1`, `effectBaseDice2`, `effectBaseDice3`, `effectDicePerLevel1`, `effectDicePerLevel2`, `effectDicePerLevel3`, `effectRealPointsPerLevel1`, `effectRealPointsPerLevel2`, `effectRealPointsPerLevel3`, `effectBasePoints1`, `effectBasePoints2`, `effectBasePoints3`, `effectMechanic1`, `effectMechanic2`, `effectMechanic3`, `effectImplicitTargetA1`, `effectImplicitTargetA2`, `effectImplicitTargetA3`, `effectImplicitTargetB1`, `effectImplicitTargetB2`, `effectImplicitTargetB3`, `effectRadiusIndex1`, `effectRadiusIndex2`, `effectRadiusIndex3`, `effectApplyAuraName1`, `effectApplyAuraName2`, `effectApplyAuraName3`, `effectAmplitude1`, `effectAmplitude2`, `effectAmplitude3`, `effectMultipleValue1`, `effectMultipleValue2`, `effectMultipleValue3`, `effectChainTarget1`, `effectChainTarget2`, `effectChainTarget3`, `effectItemType1`, `effectItemType2`, `effectItemType3`, `effectMiscValue1`, `effectMiscValue2`, `effectMiscValue3`, `effectTriggerSpell1`, `effectTriggerSpell2`, `effectTriggerSpell3`, `effectPointsPerComboPoint1`, `effectPointsPerComboPoint2`, `effectPointsPerComboPoint3`, `spellVisual1`, `spellVisual2`, `spellIconId`, `activeIconId`, `spellPriority`, `name`, `nameFlags`, `nameSubtext`, `nameSubtextFlags`, `description`, `descriptionFlags`, `auraDescription`, `auraDescriptionFlags`, `manaCostPercentage`, `startRecoveryCategory`, `startRecoveryTime`, `minTargetLevel`, `maxTargetLevel`, `spellFamilyName`, `spellFamilyFlags`, `maxAffectedTargets`, `dmgClass`, `preventionType`, `stanceBarOrder`, `dmgMultiplier1`, `dmgMultiplier2`, `dmgMultiplier3`, `minFactionId`, `minReputation`, `requiredAuraVision`, `customFlags`) VALUES (65001, 5875, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 101, 0, 0, 0, 0, 1, 21, 0, 0, 0, 0, 0, 12, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, -1, 0, 0, 6, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 4, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1324, 0, 0, 'Omen of Mortality', 4128894, '', 4128892, '', 4128892, '', 4128892, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 4);

DELETE FROM `creature` WHERE `id` = 80000;
SET @CGUID := (SELECT IFNULL(MAX(`guid`), 0) FROM `creature`);
INSERT INTO `creature` (`guid`, `id`, `map`, `position_x`, `position_y`, `position_z`, `orientation`,
    `spawntimesecsmin`, `spawntimesecsmax`, `wander_distance`,
    `health_percent`, `mana_percent`, `movement_type`,
    `spawn_flags`, `visibility_mod`, `patch_min`, `patch_max`) VALUES
(@CGUID +  1,  80000, 0,   -8885.0,    -135.0,   82.0, 2.74, 30, 30, 0, 100, 100, 0, 0, 0, 0, 10),
(@CGUID +  2,  80000, 0,   -6196.0,     326.0,  383.5, 3.37, 30, 30, 0, 100, 100, 0, 0, 0, 0, 10),
(@CGUID +  3,  80000, 1,   10290.0,     848.0, 1339.0, 5.97, 30, 30, 0, 100, 100, 0, 0, 0, 0, 10),
(@CGUID +  4,  80000, 1,    -625.0,   -4278.0,   40.5, 3.28, 30, 30, 0, 100, 100, 0, 0, 0, 0, 10),
(@CGUID +  5,  80000, 1,   -2915.0,    -295.0,   55.5, 1.54, 30, 30, 0, 100, 100, 0, 0, 0, 0, 10),
(@CGUID +  6,  80000, 0,    1905.0,    1575.0,   88.5, 4.24, 30, 30, 0, 100, 100, 0, 0, 0, 0, 10),
(@CGUID +  7,  80000, 0,   -9455.0,     135.0,   58.0, 2.65, 30, 30, 0, 100, 100, 0, 0, 0, 0, 10),
(@CGUID +  8,  80000, 0,   -5560.0,    -520.0,  401.5, 1.92, 30, 30, 0, 100, 100, 0, 0, 0, 0, 10),
(@CGUID +  9,  80000, 1,    9915.0,     955.0, 1313.0, 3.67, 30, 30, 0, 100, 100, 0, 0, 0, 0, 10),
(@CGUID + 10,  80000, 1,     300.0,   -4705.0,   14.5, 5.27, 30, 30, 0, 100, 100, 0, 0, 0, 0, 10),
(@CGUID + 11,  80000, 1,   -2355.0,    -420.0,   -7.5, 2.95, 30, 30, 0, 100, 100, 0, 0, 0, 0, 10),
(@CGUID + 12,  80000, 0,    2230.0,     215.0,   34.5, 0.00, 30, 30, 0, 100, 100, 0, 0, 0, 0, 10),
(@CGUID + 13,  80000, 0,   -8850.0,     690.0,   97.5, 0.55, 30, 30, 0, 100, 100, 0, 0, 0, 0, 10),
(@CGUID + 14,  80000, 0,   -4930.0,    -930.0,  502.0, 4.04, 30, 30, 0, 100, 100, 0, 0, 0, 0, 10),
(@CGUID + 15,  80000, 1,    9955.0,    2300.0, 1331.0, 4.17, 30, 30, 0, 100, 100, 0, 0, 0, 0, 10),
(@CGUID + 16,  80000, 1,    1610.0,   -4425.0,   12.5, 2.95, 30, 30, 0, 100, 100, 0, 0, 0, 0, 10),
(@CGUID + 17,  80000, 1,   -1245.0,     125.0,  132.0, 1.90, 30, 30, 0, 100, 100, 0, 0, 0, 0, 10),
(@CGUID + 18,  80000, 0,    1555.0,     190.0,  -43.0, 0.77, 30, 30, 0, 100, 100, 0, 0, 0, 0, 10);

END IF;
END??
DELIMITER ;
CALL add_migration();
DROP PROCEDURE IF EXISTS add_migration;
