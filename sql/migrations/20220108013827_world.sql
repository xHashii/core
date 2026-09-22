DROP PROCEDURE IF EXISTS add_migration;
DELIMITER ??
CREATE PROCEDURE `add_migration`()
BEGIN
DECLARE v INT DEFAULT 1;
SET v = (SELECT COUNT(*) FROM `migrations` WHERE `id`='20220108013827');
IF v = 0 THEN
INSERT INTO `migrations` VALUES ('20220108013827');
-- Add your query below.


-- Fix nonsensical target and flags combination on 2 mobs.
UPDATE `creature_ai_scripts` SET `target_type` = 0 WHERE `data_flags` = 4 && `target_type` = 1;


-- End of migration.
END IF;
END??
DELIMITER ;
CALL add_migration();
DROP PROCEDURE IF EXISTS add_migration;
