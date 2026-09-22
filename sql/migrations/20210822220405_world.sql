DROP PROCEDURE IF EXISTS add_migration;
DELIMITER ??
CREATE PROCEDURE `add_migration`()
BEGIN
DECLARE v INT DEFAULT 1;
SET v = (SELECT COUNT(*) FROM `migrations` WHERE `id`='20210822220405');
IF v = 0 THEN
INSERT INTO `migrations` VALUES ('20210822220405');
-- Add your query below.


-- Reduce respawn of Fifth Mosh'aru Tablet to match that of Sixth Mosh'aru Tablet.
UPDATE `gameobject` SET `spawntimesecsmin`=25, `spawntimesecsmax`=25 WHERE `id`=175949;


-- End of migration.
END IF;
END??
DELIMITER ;
CALL add_migration();
DROP PROCEDURE IF EXISTS add_migration;
