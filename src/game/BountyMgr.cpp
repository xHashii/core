#include "BountyMgr.h"
#include "Player.h"
#include "World.h"
#include "ObjectMgr.h"
#include "SQLStorages.h"
#include "Language.h"
#include <sstream>
#include <algorithm>

void BountyMgr::RecordPvPKill(Player* killer, Player* victim)
{
    if (!killer || !victim || killer == victim)
        return;

    // 1. Killer streak increment
    uint32 streak = ++m_killstreaks[killer->GetObjectGuid()];

    // Milestone killstreak bounties
    uint32 addedBounty = 0;
    if (streak == 3)
        addedBounty = 5;
    else if (streak == 5)
        addedBounty = 15;
    else if (streak == 10)
        addedBounty = 50;
    else if (streak == 20)
        addedBounty = 100;
    else if (streak > 20 && streak % 10 == 0)
        addedBounty = 50;

    if (addedBounty > 0)
    {
        m_bounties[killer->GetObjectGuid()] += addedBounty;

        std::string zoneName = "Unknown";
        if (AreaEntry const* area = sAreaStorage.LookupEntry<AreaEntry>(killer->GetAreaId()))
            zoneName = area->Name ? area->Name : "Unknown";
        else if (AreaEntry const* zone = sAreaStorage.LookupEntry<AreaEntry>(killer->GetZoneId()))
            zoneName = zone->Name ? zone->Name : "Unknown";

        std::ostringstream ss;
        ss << "|cffff0000[Bounty]|r " << killer->GetName() << " (Level " << killer->GetLevel()
           << ") is on a " << streak << " PvP KILLSTREAK in " << zoneName
           << "! Total Bounty: " << m_bounties[killer->GetObjectGuid()] << " Gold!";
        sWorld.SendWorldText(LANG_SYSTEMMESSAGE, ss.str().c_str());
    }

    // 2. Claim bounty on victim if present
    auto it = m_bounties.find(victim->GetObjectGuid());
    if (it != m_bounties.end() && it->second > 0)
    {
        uint32 goldReward = it->second;
        m_bounties.erase(it);

        // Give reward to killer (gold in copper: 1 gold = 10000 copper)
        killer->ModifyMoney(goldReward * 10000);

        std::ostringstream ss;
        ss << "|cff00ff00[Bounty Claimed]|r " << killer->GetName() << " has SLAIN "
           << victim->GetName() << " and claimed the bounty of " << goldReward << " Gold!";
        sWorld.SendWorldText(LANG_SYSTEMMESSAGE, ss.str().c_str());

        killer->PSendSysMessage("|cff00ff00[Bounty]|r You received %u Gold for claiming the bounty on %s!", goldReward, victim->GetName());
    }

    // Reset victim streak
    m_killstreaks[victim->GetObjectGuid()] = 0;
}

bool BountyMgr::AddBounty(Player* placer, Player* target, uint32 goldAmount)
{
    if (!placer || !target || goldAmount == 0)
        return false;

    if (placer == target)
    {
        placer->PSendSysMessage("You cannot place a bounty on yourself.");
        return false;
    }

    uint32 costCopper = goldAmount * 10000;
    if (placer->GetMoney() < costCopper)
    {
        placer->PSendSysMessage("You do not have enough gold to place this bounty (%u Gold required).", goldAmount);
        return false;
    }

    placer->ModifyMoney(-int32(costCopper));
    m_bounties[target->GetObjectGuid()] += goldAmount;

    std::ostringstream ss;
    ss << "|cffff0000[Bounty]|r " << placer->GetName() << " has placed a " << goldAmount
       << " Gold bounty on the head of " << target->GetName() << "! Total Bounty: "
       << m_bounties[target->GetObjectGuid()] << " Gold!";
    sWorld.SendWorldText(LANG_SYSTEMMESSAGE, ss.str().c_str());

    return true;
}

bool BountyMgr::AddBotBounty(Player* botPlacer, Player* target, uint32 goldAmount)
{
    if (!botPlacer || !target || goldAmount == 0)
        return false;

    m_bounties[target->GetObjectGuid()] += goldAmount;

    std::ostringstream ss;
    ss << "|cffff0000[Bounty]|r " << botPlacer->GetName() << " has placed a " << goldAmount
       << " Gold revenge bounty on the head of " << target->GetName() << "! Total Bounty: "
       << m_bounties[target->GetObjectGuid()] << " Gold!";
    sWorld.SendWorldText(LANG_SYSTEMMESSAGE, ss.str().c_str());

    return true;
}

bool BountyMgr::HasBounty(ObjectGuid guid) const
{
    auto it = m_bounties.find(guid);
    return it != m_bounties.end() && it->second > 0;
}

uint32 BountyMgr::GetBountyAmount(ObjectGuid guid) const
{
    auto it = m_bounties.find(guid);
    return it != m_bounties.end() ? it->second : 0;
}

uint32 BountyMgr::GetKillstreak(ObjectGuid guid) const
{
    auto it = m_killstreaks.find(guid);
    return it != m_killstreaks.end() ? it->second : 0;
}

std::vector<BountyEntry> BountyMgr::GetTopBounties(uint32 maxCount) const
{
    std::vector<BountyEntry> list;
    for (const auto& pair : m_bounties)
    {
        if (pair.second == 0)
            continue;

        Player* player = sObjectMgr.GetPlayer(pair.first);
        if (!player)
            continue;

        BountyEntry entry;
        entry.guid = pair.first;
        entry.name = player->GetName();
        entry.race = player->GetRace();
        entry.playerClass = player->GetClass();
        entry.level = player->GetLevel();
        entry.bountyGold = pair.second;
        entry.killstreak = GetKillstreak(pair.first);

        if (AreaEntry const* area = sAreaStorage.LookupEntry<AreaEntry>(player->GetAreaId()))
            entry.zoneName = area->Name ? area->Name : "Unknown";
        else if (AreaEntry const* zone = sAreaStorage.LookupEntry<AreaEntry>(player->GetZoneId()))
            entry.zoneName = zone->Name ? zone->Name : "Unknown";
        else
            entry.zoneName = "Unknown";

        list.push_back(entry);
    }

    std::sort(list.begin(), list.end(), [](const BountyEntry& a, const BountyEntry& b) {
        return a.bountyGold > b.bountyGold;
    });

    if (list.size() > maxCount)
        list.resize(maxCount);

    return list;
}

void BountyMgr::ResetBounty(ObjectGuid guid)
{
    m_bounties.erase(guid);
    m_killstreaks.erase(guid);
}
