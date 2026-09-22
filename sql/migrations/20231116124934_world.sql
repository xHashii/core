DROP PROCEDURE IF EXISTS add_migration;
DELIMITER ??
CREATE PROCEDURE `add_migration`()
BEGIN
DECLARE v INT DEFAULT 1;
SET v = (SELECT COUNT(*) FROM `migrations` WHERE `id`='20231116124934');
IF v = 0 THEN
INSERT INTO `migrations` VALUES ('20231116124934');
-- Add your query below.


-- Fix Zandalarian Hero Charm.
DELETE FROM `spell_proc_event` WHERE `entry` IN (24658, 24659);
INSERT INTO `spell_proc_event` (`entry`, `SchoolMask`, `SpellFamilyName`, `SpellFamilyMask0`, `SpellFamilyMask1`, `SpellFamilyMask2`, `procFlags`, `procEx`, `ppmRate`, `CustomChance`, `Cooldown`, `build_min`, `build_max`) VALUES (24659, 0, 0, 0, 0, 0, 0, 524288, 0, 0, 0, 5302, 5875);


-- End of migration.
END IF;
END??
DELIMITER ;
CALL add_migration();
DROP PROCEDURE IF EXISTS add_migration;
