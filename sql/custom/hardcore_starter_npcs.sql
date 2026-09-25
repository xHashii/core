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
-- 1. Northshire Valley (Human Starter) - East of merchant row, clear road space
(@CGUID +  1,  80000, 0,   -8885.0,    -135.0,   82.0, 2.74, 30, 30, 0, 100, 100, 0, 0, 0, 0, 10),

-- 2. Coldridge Valley / Anvilmar (Dwarf & Gnome Starter) - East side of village, gate path
(@CGUID +  2,  80000, 0,   -6196.0,     326.0,  383.5, 3.37, 30, 30, 0, 100, 100, 0, 0, 0, 0, 10),

-- 3. Shadowglen / Aldrassil (Night Elf Starter) - West edge of village, clear of Ilthalaine
(@CGUID +  3,  80000, 1,   10290.0,     848.0, 1339.0, 5.97, 30, 30, 0, 100, 100, 0, 0, 0, 0, 10),

-- 4. Valley of Trials (Orc & Troll Starter) - North of village, clear of trainer row
(@CGUID +  4,  80000, 1,    -625.0,   -4278.0,   40.5, 3.28, 30, 30, 0, 100, 100, 0, 0, 0, 0, 10),

-- 5. Camp Narache (Tauren Starter) - SW edge of village, clear of Chief Hawkwind
(@CGUID +  5,  80000, 1,   -2915.0,    -295.0,   55.5, 1.54, 30, 30, 0, 100, 100, 0, 0, 0, 0, 10),

-- 6. Deathknell (Undead Starter) - Village entrance, on the main road
(@CGUID +  6,  80000, 0,    1905.0,    1575.0,   88.5, 4.24, 30, 30, 0, 100, 100, 0, 0, 0, 0, 10),

-- 7. Goldshire (Elwynn Forest) - South edge of village, on the road (was mid-street)
(@CGUID +  7,  80000, 0,   -9455.0,     135.0,   58.0, 2.65, 30, 30, 0, 100, 100, 0, 0, 0, 0, 10),

-- 8. Kharanos (Dun Morogh) - East plaza, clear of inn & trainers
(@CGUID +  8,  80000, 0,   -5560.0,    -520.0,  401.5, 1.92, 30, 30, 0, 100, 100, 0, 0, 0, 0, 10),

-- 9. Dolanaar (Teldrassil) - East side of village, clear of sentinels
(@CGUID +  9,  80000, 1,    9915.0,     955.0, 1313.0, 3.67, 30, 30, 0, 100, 100, 0, 0, 0, 0, 10),

-- 10. Razor Hill (Durotar) - North plaza, clear of inn & trainers
(@CGUID + 10,  80000, 1,     300.0,   -4705.0,   14.5, 5.27, 30, 30, 0, 100, 100, 0, 0, 0, 0, 10),

-- 11. Bloodhoof Village (Mulgore) - West edge of village, clear of Baine
(@CGUID + 11,  80000, 1,   -2355.0,    -420.0,   -7.5, 2.95, 30, 30, 0, 100, 100, 0, 0, 0, 0, 10),

-- 12. Brill (Tirisfal Glades) - North edge of village, clear of tavern
(@CGUID + 12,  80000, 0,    2230.0,     215.0,   34.5, 0.00, 30, 30, 0, 100, 100, 0, 0, 0, 0, 10),

-- 13. Stormwind City - Trade District, south plaza
(@CGUID + 13,  80000, 0,   -8850.0,     690.0,   97.5, 0.55, 30, 30, 0, 100, 100, 0, 0, 0, 0, 10),

-- 14. Ironforge - The Commons, west plaza
(@CGUID + 14,  80000, 0,   -4930.0,    -930.0,  502.0, 4.04, 30, 30, 0, 100, 100, 0, 0, 0, 0, 10),

-- 15. Darnassus - Temple of the Moon, north foot of the platform
(@CGUID + 15,  80000, 1,    9955.0,    2300.0, 1331.0, 4.17, 30, 30, 0, 100, 100, 0, 0, 0, 0, 10),

-- 16. Orgrimmar - Valley of Strength, west side clear of inn & bank
(@CGUID + 16,  80000, 1,    1610.0,   -4425.0,   12.5, 2.95, 30, 30, 0, 100, 100, 0, 0, 0, 0, 10),

-- 17. Thunder Bluff - Central Rise, east side clear of emissaries
(@CGUID + 17,  80000, 1,   -1245.0,     125.0,  132.0, 1.90, 30, 30, 0, 100, 100, 0, 0, 0, 0, 10),

-- 18. Undercity - Trade Quarter, upper level NW of the Auction House
(@CGUID + 18,  80000, 0,    1555.0,     190.0,  -43.0, 0.77, 30, 30, 0, 100, 100, 0, 0, 0, 0, 10);
