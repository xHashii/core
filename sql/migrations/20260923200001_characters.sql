DROP PROCEDURE IF EXISTS add_migration;
DELIMITER ??
CREATE PROCEDURE `add_migration`()
BEGIN
DECLARE v INT DEFAULT 1;
SET v = (SELECT COUNT(*) FROM `migrations` WHERE `id`='20260923200001');
IF v = 0 THEN
INSERT INTO `migrations` VALUES ('20260923200001');
-- Add your query below.

-- ============================================================
-- Remove the 20-man raid conversion (feature removed from the
-- codebase). Drops the `instance.raid_mode` column that was
-- added by migration 20260923110000 (and to characters.sql).
-- Guarded so the migration also works on DBs created from a
-- clean characters.sql (column already absent).
-- ============================================================

SET @col_exists := (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'instance' AND COLUMN_NAME = 'raid_mode');
SET @sql := IF(@col_exists > 0, 'ALTER TABLE `instance` DROP COLUMN `raid_mode`', 'SELECT 1');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- End of migration.
END IF;
END??
DELIMITER ;
CALL add_migration();
DROP PROCEDURE IF EXISTS add_migration;
