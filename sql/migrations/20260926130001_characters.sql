DROP PROCEDURE IF EXISTS add_migration;
DELIMITER ??
CREATE PROCEDURE `add_migration`()
BEGIN
DECLARE v INT DEFAULT 1;
SET v = (SELECT COUNT(*) FROM `migrations` WHERE `id`='20260926130001');
IF v = 0 THEN
INSERT INTO `migrations` VALUES ('20260926130001');
-- Add your query below.

-- Hardcore mode, part 3 (characters DB companion of world migration
-- 20260926130000): the Hardcore indicator buff moved from custom spell
-- 65001 (unrenderable on 1.12.1 clients, no Spell.dbc record) to the
-- client-known spell 5 "Death Touch". Remove any auras of the retired
-- id that were saved to character_aura while a Hardcore player was
-- logged out, so the aura loader does not spam "unknown spell 65001"
-- on the next login. The indicator is re-applied on login by
-- Player::UpdateHardcoreIndicator(), so nothing playable is lost.
DELETE FROM `character_aura` WHERE `spell` = 65001;

END IF;
END??
DELIMITER ;
CALL add_migration();
DROP PROCEDURE IF EXISTS add_migration;
