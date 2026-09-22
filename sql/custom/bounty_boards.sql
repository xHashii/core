-- =========================================================================
-- Wanted: Bounty Board Spawns & Creature Template
-- Provides Bounty Boards in all Capital Cities, World PvP bases, and Villages
-- =========================================================================

-- Wanted: Bounty Board Creature Template
DELETE FROM `creature_template` WHERE `entry` = 80001;
INSERT INTO `creature_template` (
    `entry`, `patch`, `name`, `subname`,
    `level_min`, `level_max`, `faction`, `npc_flags`, `gossip_menu_id`,
    `display_id1`, `display_id2`, `display_id3`, `display_id4`,
    `display_scale1`, `display_scale2`, `display_scale3`, `display_scale4`,
    `display_probability1`, `display_probability2`, `display_probability3`, `display_probability4`,
    `display_total_probability`, `mount_display_id`,
    `speed_walk`, `speed_run`, `detection_range`, `call_for_help_range`, `leash_range`,
    `type`, `pet_family`, `rank`, `unit_class`,
    `xp_multiplier`, `health_multiplier`, `mana_multiplier`, `armor_multiplier`,
    `damage_multiplier`, `damage_variance`, `damage_school`,
    `base_attack_time`, `ranged_attack_time`,
    `holy_res`, `fire_res`, `nature_res`, `frost_res`, `shadow_res`, `arcane_res`,
    `trainer_type`, `trainer_spell`, `trainer_class`, `trainer_race`,
    `loot_id`, `pickpocket_loot_id`, `skinning_loot_id`,
    `gold_min`, `gold_max`,
    `spell_list_id`, `pet_spell_list_id`, `spawn_spell_id`, `totem_spell_id`,
    `auras`, `ai_name`, `movement_type`, `inhabit_type`,
    `civilian`, `racial_leader`, `equipment_id`,
    `trainer_id`, `vendor_id`,
    `mechanic_immune_mask`, `school_immune_mask`, `immunity_flags`,
    `static_flags1`, `static_flags2`, `flags_extra`, `script_name`
) VALUES (
    80001, 0, 'Wanted: Bounty Board', 'Bounty Master',
    60, 60, 35, 1, 0,
    2465, 0, 0, 0,
    1.2, 0, 0, 0,
    1, 0, 0, 0,
    1, 0,
    1.0, 1.14286, 20, 5, 0,
    7, 0, 0, 1,
    1, 1, 1, 1,
    1, 0.14, 0,
    2000, 2000,
    0, 0, 0, 0, 0, 0,
    0, 0, 0, 0,
    0, 0, 0,
    0, 0,
    0, 0, 0, 0,
    NULL, '', 0, 3,
    1, 0, 0,
    0, 0,
    0, 0, 0,
    0, 0, 64, 'custom_bounty_board'
);

-- Spawn Bounty Boards in all capital cities, World PvP bases, and major villages
DELETE FROM `creature` WHERE `id` = 80001;
SET @CGUID := (SELECT IFNULL(MAX(guid), 0) FROM `creature`);

INSERT INTO `creature` (
    `guid`, `id`, `map`,
    `position_x`, `position_y`, `position_z`, `orientation`,
    `spawntimesecsmin`, `spawntimesecsmax`, `wander_distance`,
    `health_percent`, `mana_percent`, `movement_type`,
    `spawn_flags`, `visibility_mod`, `patch_min`, `patch_max`
) VALUES
-- 1. Orgrimmar - Valley of Strength near Bank & Auction House
(@CGUID + 1,  80001, 1,  1635.0, -4425.0,  15.5, 0.20, 30, 30, 0, 100, 100, 0, 0, 0, 0, 10),
-- 2. Stormwind City - Trade District near Bank & Fountain
(@CGUID + 2,  80001, 0, -8855.0,   625.0,  95.0, 3.60, 30, 30, 0, 100, 100, 0, 0, 0, 0, 10),
-- 3. Ironforge - The Commons near Bank & Great Forge
(@CGUID + 3,  80001, 0, -4920.0,  -895.0, 502.0, 5.40, 30, 30, 0, 100, 100, 0, 0, 0, 0, 10),
-- 4. Undercity - Trade Quarter
(@CGUID + 4,  80001, 0,  1590.0,   235.0, -52.0, 0.00, 30, 30, 0, 100, 100, 0, 0, 0, 0, 10),
-- 5. Darnassus - Tradesmen's Terrace / Bank
(@CGUID + 5,  80001, 1,  9945.0,  2275.0, 1329.0, 1.57, 30, 30, 0, 100, 100, 0, 0, 0, 0, 10),
-- 6. Thunder Bluff - Central Rise
(@CGUID + 6,  80001, 1, -1285.0,   135.0, 130.0, 2.10, 30, 30, 0, 100, 100, 0, 0, 0, 0, 10),
-- 7. Crossroads (The Barrens - Major Horde Hub)
(@CGUID + 7,  80001, 1,  -445.0, -2640.0,  95.5, 1.20, 30, 30, 0, 100, 100, 0, 0, 0, 0, 10),
-- 8. Tarren Mill (Hillsbrad Foothills - Horde World PvP Hub)
(@CGUID + 8,  80001, 0,   -40.0,  -890.0,  54.0, 4.20, 30, 30, 0, 100, 100, 0, 0, 0, 0, 10),
-- 9. Southshore (Hillsbrad Foothills - Alliance World PvP Hub)
(@CGUID + 9,  80001, 0,  -840.0,  -570.0,  14.5, 0.80, 30, 30, 0, 100, 100, 0, 0, 0, 0, 10),
-- 10. Astranaar (Ashenvale - Alliance World PvP Hub)
(@CGUID + 10, 80001, 1,  2740.0,  -375.0, 106.0, 3.14, 30, 30, 0, 100, 100, 0, 0, 0, 0, 10),
-- 11. Splintertree Post (Ashenvale - Horde World PvP Hub)
(@CGUID + 11, 80001, 1,  2315.0, -2535.0,  99.0, 0.50, 30, 30, 0, 100, 100, 0, 0, 0, 0, 10),
-- 12. Sun Rock Retreat (Stonetalon Mountains - Horde World PvP Base)
(@CGUID + 12, 80001, 1,   975.0,   990.0, 105.0, 5.10, 30, 30, 0, 100, 100, 0, 0, 0, 0, 10),
-- 13. Windshear Peak / Crag (Stonetalon Mountains - Alliance Base)
(@CGUID + 13, 80001, 1,  1095.0,   -90.0, 140.0, 2.30, 30, 30, 0, 100, 100, 0, 0, 0, 0, 10),
-- 14. Booty Bay (Stranglethorn Vale - Neutral PvP Capital)
(@CGUID + 14, 80001, 0, -14435.0,  475.0,  15.0, 1.60, 30, 30, 0, 100, 100, 0, 0, 0, 0, 10),
-- 15. Grom'gol Base Camp (Stranglethorn Vale - Horde Base)
(@CGUID + 15, 80001, 0, -12415.0,  210.0,   4.0, 4.70, 30, 30, 0, 100, 100, 0, 0, 0, 0, 10),
-- 16. Refugee Pointe (Arathi Highlands - Alliance World PvP Base)
(@CGUID + 16, 80001, 0, -1250.0, -2530.0,  21.5, 3.40, 30, 30, 0, 100, 100, 0, 0, 0, 0, 10),
-- 17. Hammerfall (Arathi Highlands - Horde World PvP Base)
(@CGUID + 17, 80001, 0, -1030.0, -3470.0,  66.5, 0.90, 30, 30, 0, 100, 100, 0, 0, 0, 0, 10),
-- 18. Gadgetzan (Tanaris - Neutral Desert PvP Hub)
(@CGUID + 18, 80001, 1, -7170.0, -3785.0,   8.5, 2.70, 30, 30, 0, 100, 100, 0, 0, 0, 0, 10),
-- 19. Ratchet (The Barrens - Neutral Port)
(@CGUID + 19, 80001, 1,  -960.0, -3740.0,   5.5, 6.00, 30, 30, 0, 100, 100, 0, 0, 0, 0, 10),
-- 20. Darkshire (Duskwood - Alliance Town)
(@CGUID + 20, 80001, 0, -10550.0,-1185.0,  35.0, 1.10, 30, 30, 0, 100, 100, 0, 0, 0, 0, 10),
-- 21. Lakeshire (Redridge Mountains - Alliance Town)
(@CGUID + 21, 80001, 0, -9240.0, -2170.0,  64.0, 3.90, 30, 30, 0, 100, 100, 0, 0, 0, 0, 10),
-- 22. Goldshire (Elwynn Forest)
(@CGUID + 22, 80001, 0, -9460.0,    55.0,  56.0, 3.14, 30, 30, 0, 100, 100, 0, 0, 0, 0, 10),
-- 23. Razor Hill (Durotar)
(@CGUID + 23, 80001, 1,   310.0, -4745.0,  17.5, 5.00, 30, 30, 0, 100, 100, 0, 0, 0, 0, 10),
-- 24. Brill (Tirisfal Glades)
(@CGUID + 24, 80001, 0,  2235.0,   245.0,  34.0, 2.20, 30, 30, 0, 100, 100, 0, 0, 0, 0, 10),
-- 25. Bloodhoof Village (Mulgore)
(@CGUID + 25, 80001, 1, -2340.0,  -400.0,  -9.0, 3.90, 30, 30, 0, 100, 100, 0, 0, 0, 0, 10),
-- 26. Kharanos (Dun Morogh)
(@CGUID + 26, 80001, 0, -5595.0,  -530.0, 399.0, 4.50, 30, 30, 0, 100, 100, 0, 0, 0, 0, 10),
-- 27. Dolanaar (Teldrassil)
(@CGUID + 27, 80001, 1,  9875.0,   965.0, 1310.0, 1.57, 30, 30, 0, 100, 100, 0, 0, 0, 0, 10),
-- 28. Auberdine (Darkshore)
(@CGUID + 28, 80001, 1,  6360.0,   520.0,  15.0, 0.40, 30, 30, 0, 100, 100, 0, 0, 0, 0, 10),
-- 29. Sentinel Hill (Westfall)
(@CGUID + 29, 80001, 0, -10650.0, 1025.0,  34.0, 5.80, 30, 30, 0, 100, 100, 0, 0, 0, 0, 10),
-- 30. Cenarion Hold (Silithus - Endgame PvP Base)
(@CGUID + 30, 80001, 1, -6815.0,   765.0,  43.0, 3.14, 30, 30, 0, 100, 100, 0, 0, 0, 0, 10),
-- 31. Everlook (Winterspring)
(@CGUID + 31, 80001, 1,  6720.0, -4670.0, 721.0, 1.80, 30, 30, 0, 100, 100, 0, 0, 0, 0, 10),
-- 32. Light's Hope Chapel (Eastern Plaguelands)
(@CGUID + 32, 80001, 0,  2280.0, -5320.0,  88.0, 2.00, 30, 30, 0, 100, 100, 0, 0, 0, 0, 10);
