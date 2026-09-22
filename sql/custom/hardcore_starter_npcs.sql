-- Hardcore & Solo Self-Found (SSF) Guide: Watcher of Mortality
-- Spawns the NPC across all starting zones, starter hubs, and capital cities.

DELETE FROM `creature_template` WHERE `entry` = 80000;
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
    80000, 0, 'Watcher of Mortality', 'Hardcore & SSF Guide',
    60, 60, 35, 1, 0,
    15251, 0, 0, 0,
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
    0, 0, 64, 'custom_hardcore_npc'
);

-- Spawn Watcher of Mortality in all starting areas, starter towns, and capital cities
DELETE FROM `creature` WHERE `id` = 80000;
SET @CGUID := (SELECT IFNULL(MAX(guid), 0) FROM `creature`);

INSERT INTO `creature` (
    `guid`, `id`, `map`,
    `position_x`, `position_y`, `position_z`, `orientation`,
    `spawntimesecsmin`, `spawntimesecsmax`, `wander_distance`,
    `health_percent`, `mana_percent`, `movement_type`,
    `spawn_flags`, `visibility_mod`, `patch_min`, `patch_max`
) VALUES
-- 1. Northshire Valley (Human Starter) - Near Northshire Abbey entrance
(@CGUID + 1,  80000, 0, -8913.6,  -132.8,  81.0, 5.30, 30, 30, 0, 100, 100, 0, 0, 0, 0, 10),
-- 2. Coldridge Valley / Anvilmar (Dwarf & Gnome Starter) - Near Anvilmar entrance
(@CGUID + 2,  80000, 0, -6240.5,   331.8, 383.1, 6.18, 30, 30, 0, 100, 100, 0, 0, 0, 0, 10),
-- 3. Shadowglen / Aldrassil (Night Elf Starter) - Base of tree near Ilthalaine
(@CGUID + 3,  80000, 1, 10313.2,   830.4, 1326.4, 5.48, 30, 30, 0, 100, 100, 0, 0, 0, 0, 10),
-- 4. Valley of Trials (Orc & Troll Starter) - Central plaza near Den
(@CGUID + 4,  80000, 1,  -618.2, -4251.5,  38.1, 0.85, 30, 30, 0, 100, 100, 0, 0, 0, 0, 10),
-- 5. Camp Narache (Tauren Starter) - Near Chief Hawkwind
(@CGUID + 5,  80000, 1, -2917.8,  -257.5,  53.0, 4.67, 30, 30, 0, 100, 100, 0, 0, 0, 0, 10),
-- 6. Deathknell (Undead Starter) - Outside Shadow Grave crypt
(@CGUID + 6,  80000, 0,  1674.2,  1678.5, 120.5, 2.70, 30, 30, 0, 100, 100, 0, 0, 0, 0, 10),
-- 7. Goldshire (Elwynn Forest) - Outside Lion's Pride Inn
(@CGUID + 7,  80000, 0, -9464.0,    62.0,  56.0, 3.14, 30, 30, 0, 100, 100, 0, 0, 0, 0, 10),
-- 8. Kharanos (Dun Morogh) - Outside Thunderbrew Distillery
(@CGUID + 8,  80000, 0, -5590.0,  -525.0, 399.0, 4.50, 30, 30, 0, 100, 100, 0, 0, 0, 0, 10),
-- 9. Dolanaar (Teldrassil) - Near Dolanaar Inn
(@CGUID + 9,  80000, 1,  9880.0,   970.0, 1310.0, 1.57, 30, 30, 0, 100, 100, 0, 0, 0, 0, 10),
-- 10. Razor Hill (Durotar) - Outside Razor Hill Inn
(@CGUID + 10, 80000, 1,   315.0, -4740.0,  17.5, 5.00, 30, 30, 0, 100, 100, 0, 0, 0, 0, 10),
-- 11. Bloodhoof Village (Mulgore) - Near Bloodhoof Inn
(@CGUID + 11, 80000, 1, -2335.0,  -395.0,  -9.0, 3.90, 30, 30, 0, 100, 100, 0, 0, 0, 0, 10),
-- 12. Brill (Tirisfal Glades) - Near Gallows' End Tavern
(@CGUID + 12, 80000, 0,  2240.0,   240.0,  34.0, 2.20, 30, 30, 0, 100, 100, 0, 0, 0, 0, 10),
-- 13. Stormwind City - Trade District
(@CGUID + 13, 80000, 0, -8850.0,   630.0,  95.0, 3.60, 30, 30, 0, 100, 100, 0, 0, 0, 0, 10),
-- 14. Ironforge - The Commons
(@CGUID + 14, 80000, 0, -4915.0,  -890.0, 502.0, 5.40, 30, 30, 0, 100, 100, 0, 0, 0, 0, 10),
-- 15. Darnassus - Temple Gardens / Bank
(@CGUID + 15, 80000, 1,  9950.0,  2280.0, 1329.0, 1.57, 30, 30, 0, 100, 100, 0, 0, 0, 0, 10),
-- 16. Orgrimmar - Valley of Strength near Bank & AH
(@CGUID + 16, 80000, 1,  1630.0, -4420.0,  15.5, 0.20, 30, 30, 0, 100, 100, 0, 0, 0, 0, 10),
-- 17. Thunder Bluff - Central Rise
(@CGUID + 17, 80000, 1, -1280.0,   140.0, 130.0, 2.10, 30, 30, 0, 100, 100, 0, 0, 0, 0, 10),
-- 18. Undercity - Trade Quarter
(@CGUID + 18, 80000, 0,  1585.0,   240.0, -52.0, 0.00, 30, 30, 0, 100, 100, 0, 0, 0, 0, 10);
