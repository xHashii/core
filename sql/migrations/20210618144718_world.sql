DROP PROCEDURE IF EXISTS add_migration;
DELIMITER ??
CREATE PROCEDURE `add_migration`()
BEGIN
DECLARE v INT DEFAULT 1;
SET v = (SELECT COUNT(*) FROM `migrations` WHERE `id`='20210618144718');
IF v = 0 THEN
INSERT INTO `migrations` VALUES ('20210618144718');
-- Add your query below.


-- Fix middle deeprun tram subway car.
UPDATE `gameobject_template` SET `data5`=4294967295 WHERE `entry`=176084;


-- End of migration.
END IF;
END??
DELIMITER ;
CALL add_migration();
DROP PROCEDURE IF EXISTS add_migration;
