DROP PROCEDURE IF EXISTS add_migration;
DELIMITER ??
CREATE PROCEDURE `add_migration`()
BEGIN
DECLARE v INT DEFAULT 1;
SET v = (SELECT COUNT(*) FROM `migrations` WHERE `id`='20260923110000');
IF v = 0 THEN
INSERT INTO `migrations` VALUES ('20260923110000');
-- Add your query below.

-- 20-man raid conversion: shared lockout (instance.raid_mode)
-- 0 = 40-man (default), 1 = 20-man
-- Characters database: instance table
-- Guard against duplicate column when DB was freshly created from characters.sql which already contains the column.
SET @col_exists := (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'instance' AND COLUMN_NAME = 'raid_mode');
SET @sql := IF(@col_exists = 0, 'ALTER TABLE `instance` ADD COLUMN `raid_mode` tinyint(3) unsigned NOT NULL DEFAULT ''0'' COMMENT ''0=40-man, 1=20-man (shared lockout)''', 'SELECT 1');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- End of migration.
END IF;
END??
DELIMITER ;
CALL add_migration();
DROP PROCEDURE IF EXISTS add_migration;
