DROP PROCEDURE IF EXISTS add_migration;
DELIMITER ??
CREATE PROCEDURE `add_migration`()
BEGIN
DECLARE v INT DEFAULT 1;
SET v = (SELECT COUNT(*) FROM `migrations` WHERE `id`='20220907211803');
IF v = 0 THEN
INSERT INTO `migrations` VALUES ('20220907211803');
-- Add your query below.


-- Fix Elemental Weapons not affecting Flametongue Weapon.
UPDATE `spell_affect` SET `SpellFamilyMask` = `SpellFamilyMask` | 2097152 WHERE `entry` IN (16266, 29079, 29080) && `effectId`=1;


-- End of migration.
END IF;
END??
DELIMITER ;
CALL add_migration();
DROP PROCEDURE IF EXISTS add_migration;
