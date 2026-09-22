DROP PROCEDURE IF EXISTS add_migration;
DELIMITER ??
CREATE PROCEDURE `add_migration`()
BEGIN
DECLARE v INT DEFAULT 1;
SET v = (SELECT COUNT(*) FROM `migrations` WHERE `id`='20220102005704');
IF v = 0 THEN
INSERT INTO `migrations` VALUES ('20220102005704');
-- Add your query below.


-- This was never implemented.
ALTER TABLE `logs_characters`
	DROP COLUMN `clientHash`;


-- End of migration.
END IF;
END??
DELIMITER ;
CALL add_migration();
DROP PROCEDURE IF EXISTS add_migration;
