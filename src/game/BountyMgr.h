#ifndef BOUNTY_MGR_H
#define BOUNTY_MGR_H

#include "Common.h"
#include "ObjectGuid.h"
#include <unordered_map>
#include <string>
#include <vector>

class Player;

struct BountyEntry
{
    ObjectGuid guid;
    std::string name;
    uint32 race = 0;
    uint32 playerClass = 0;
    uint32 level = 0;
    uint32 bountyGold = 0;
    uint32 killstreak = 0;
    std::string zoneName;
};

class BountyMgr
{
public:
    static BountyMgr& Instance()
    {
        static BountyMgr instance;
        return instance;
    }

    void RecordPvPKill(Player* killer, Player* victim);
    bool AddBounty(Player* placer, Player* target, uint32 goldAmount);
    bool AddBotBounty(Player* botPlacer, Player* target, uint32 goldAmount);
    bool HasBounty(ObjectGuid guid) const;
    uint32 GetBountyAmount(ObjectGuid guid) const;
    uint32 GetKillstreak(ObjectGuid guid) const;
    std::vector<BountyEntry> GetTopBounties(uint32 maxCount = 15) const;
    void ResetBounty(ObjectGuid guid);

private:
    std::unordered_map<ObjectGuid, uint32> m_bounties;    // GUID -> Gold
    std::unordered_map<ObjectGuid, uint32> m_killstreaks; // GUID -> Current streak
};

#define sBountyMgr BountyMgr::Instance()

#endif
