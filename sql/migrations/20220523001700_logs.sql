DROP PROCEDURE IF EXISTS add_migration;
DELIMITER ??
CREATE PROCEDURE `add_migration`()
BEGIN
DECLARE v INT DEFAULT 1;
SET v = (SELECT COUNT(*) FROM `migrations` WHERE `id`='20220523001700');
IF v = 0 THEN
INSERT INTO `migrations` VALUES ('20220523001700');
-- Add your query below.


-- Unused
DROP TABLE IF EXISTS `logs_behavior`;


-- End of migration.
END IF;
END??
DELIMITER ;
CALL add_migration();
DROP PROCEDURE IF EXISTS add_migration;
