DROP PROCEDURE IF EXISTS add_migration;
DELIMITER ??
CREATE PROCEDURE `add_migration`()
BEGIN
DECLARE v INT DEFAULT 1;
SET v = (SELECT COUNT(*) FROM `migrations` WHERE `id`='20260923200000');
IF v = 0 THEN
INSERT INTO `migrations` VALUES ('20260923200000');
-- Add your query below.

-- ============================================================
-- Remove the Bounty System and the 20-man raid conversion
-- (both features were removed from the codebase).
--
--   80001      'Wanted: Bounty Board' (bounty board + wardens,
--              added by migration 20260922120000 / bounty_boards.sql)
--   80100-80104 'Raid Herald' NPCs (20-man raid conversion,
--              added by migration 20260923110001 / raid_herald.sql)
--
-- These NPCs had no DB gossip rows (gossip_menu_id = 0, gossip is
-- code-driven), so only creature_template and creature rows exist.
-- The Hardcore Watcher of Mortality (80000) and the Hardcore buff
-- spell (65001) are NOT touched.
-- ============================================================

DELETE FROM `creature_template` WHERE `entry` = 80001;
DELETE FROM `creature_template` WHERE `entry` BETWEEN 80100 AND 80104;

DELETE FROM `creature` WHERE `id` = 80001;
DELETE FROM `creature` WHERE `id` BETWEEN 80100 AND 80104;

-- End of migration.
END IF;
END??
DELIMITER ;
CALL add_migration();
DROP PROCEDURE IF EXISTS add_migration;
