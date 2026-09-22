DROP PROCEDURE IF EXISTS add_migration;
DELIMITER ??
CREATE PROCEDURE `add_migration`()
BEGIN
DECLARE v INT DEFAULT 1;
SET v = (SELECT COUNT(*) FROM `migrations` WHERE `id`='20211204182213');
IF v = 0 THEN
INSERT INTO `migrations` VALUES ('20211204182213');
-- Add your query below.


-- Remove Sleep Immunity From Sunken Temple Dragonkin
UPDATE `creature_template` SET `mechanic_immune_mask` = 0 WHERE `entry` IN (5283, 5277, 8319, 5280);


-- End of migration.
END IF;
END??
DELIMITER ;
CALL add_migration();
DROP PROCEDURE IF EXISTS add_migration;
