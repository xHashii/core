#ifndef BOUNTY_MGR_H
#define BOUNTY_MGR_H

#include "Common.h"
#include "ObjectGuid.h"
#include <unordered_map>
#include <string>
#include <vector>
#include <shared_mutex>

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

// Controls which bounty events (killstreak milestones, bounties placed, bounties claimed)
// are broadcast to the whole realm. See Bounty.Announce.Mode in mangosd.conf.
enum BountyAnnounceMode
{
    BOUNTY_ANNOUNCE_NONE         = 0, // never broadcast, involved real players are notified privately
    BOUNTY_ANNOUNCE_REAL_PLAYERS = 1, // only broadcast events involving at least one real (non-bot) player
    BOUNTY_ANNOUNCE_ALL          = 2, // broadcast every event, including bot-vs-bot (very spammy with many bots)
};

class BountyMgr
{
public:
    static BountyMgr& Instance()
    {
        static BountyMgr instance;
        return instance;
    }

    // Called from World::Update; drives the periodic "most wanted" digest broadcast.
    void Update(uint32 diff);

    void RecordPvPKill(Player* killer, Player* victim);
    bool AddBounty(Player* placer, Player* target, uint32 goldAmount);
    bool AddBotBounty(Player* botPlacer, Player* target, uint32 goldAmount);
    bool HasBounty(ObjectGuid guid) const;
    uint32 GetBountyAmount(ObjectGuid guid) const;
    uint32 GetKillstreak(ObjectGuid guid) const;
    std::vector<BountyEntry> GetTopBounties(uint32 maxCount = 15) const;
    void ResetBounty(ObjectGuid guid);

private:
    // Number of entries listed in the periodic digest.
    static constexpr uint32 DIGEST_ENTRIES = 3;

    // Broadcasts a bounty event to the realm, honoring Bounty.Announce.Mode and
    // Bounty.Announce.Cooldown. Returns true if the message was actually sent.
    bool Announce(std::string const& text, bool involvesRealPlayer);
    void SendDigest();

    // Adds gold to a bounty and returns the new total.
    uint32 AddBountyGold(ObjectGuid guid, uint32 goldAmount);

    // Bounty state is touched from the map update threads (PvP kills, bot target
    // selection) as well as from the world thread (commands, gossip, digest).
    mutable std::shared_mutex m_lock;
    std::unordered_map<ObjectGuid, uint32> m_bounties;    // GUID -> Gold
    std::unordered_map<ObjectGuid, uint32> m_killstreaks; // GUID -> Current streak

    time_t m_lastAnnounceTime = 0;                        // Last realm-wide event broadcast (0 = never)
    uint32 m_digestTimer = 0;                             // Milliseconds since the last digest
};

#define sBountyMgr BountyMgr::Instance()

#endif
