DROP PROCEDURE IF EXISTS add_migration;
DELIMITER ??
CREATE PROCEDURE `add_migration`()
BEGIN
DECLARE v INT DEFAULT 1;
SET v = (SELECT COUNT(*) FROM `migrations` WHERE `id`='20220913193700');
IF v = 0 THEN
INSERT INTO `migrations` VALUES ('20220913193700');

ALTER TABLE `logs_trade` CHANGE `type` `type` ENUM('AuctionBid','AuctionBuyout','BuyItem','SellItem','GM','Mail','QuestMaxLevel','Quest','Loot','Trade','') CHARSET utf8 COLLATE utf8_general_ci DEFAULT '' NOT NULL, CHARSET=utf8mb3;


-- End of migration.
END IF;
END??
DELIMITER ;
CALL add_migration();
DROP PROCEDURE IF EXISTS add_migration;
