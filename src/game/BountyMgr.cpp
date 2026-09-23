#include "BountyMgr.h"
#include "Player.h"
#include "World.h"
#include "WorldSession.h"
#include "ObjectMgr.h"
#include "SQLStorages.h"
#include "Language.h"
#include <sstream>
#include <algorithm>
#include <mutex>

namespace
{
    // A "real" player is one connected through an actual client socket. Both the
    // ike3 playerbots and the PlayerBotMgr bots run on socket-less sessions whose
    // remote address is reported as "<BOT>". A human controlling bots (or using
    // self-bot mode) still has a socket and therefore still counts as real.
    bool IsRealPlayer(Player const* player)
    {
        return player && player->GetSession() && player->GetSession()->GetRemoteAddress() != "<BOT>";
    }

    std::string GetAreaName(Player const* player)
    {
        if (AreaEntry const* area = sAreaStorage.LookupEntry<AreaEntry>(player->GetAreaId()))
            if (area->Name)
                return area->Name;

        if (AreaEntry const* zone = sAreaStorage.LookupEntry<AreaEntry>(player->GetZoneId()))
            if (zone->Name)
                return zone->Name;

        return "Unknown";
    }

    // Largest bounty that can be expressed in copper without overflowing.
    uint32 const MAX_BOUNTY_GOLD = MAX_MONEY_AMOUNT / 10000;
}

void BountyMgr::Update(uint32 diff)
{
    uint32 const intervalMinutes = sWorld.getConfig(CONFIG_UINT32_BOUNTY_ANNOUNCE_DIGEST_INTERVAL);
    if (!intervalMinutes)
    {
        m_digestTimer = 0;
        return;
    }

    m_digestTimer += diff;
    if (m_digestTimer < intervalMinutes * MINUTE * IN_MILLISECONDS)
        return;

    m_digestTimer = 0;
    SendDigest();
}

void BountyMgr::SendDigest()
{
    std::vector<BountyEntry> const top = GetTopBounties(DIGEST_ENTRIES);
    if (top.empty())
        return;

    std::ostringstream ss;
    ss << "|cffffd700[Bounty Board]|r Most wanted: ";
    for (size_t i = 0; i < top.size(); ++i)
    {
        if (i)
            ss << ", ";
        ss << top[i].name << " (Lvl " << top[i].level << ", " << top[i].bountyGold << "g)";
    }
    ss << ". Type .bounty list or visit a Bounty Board for the full list.";

    sWorld.SendWorldText(LANG_SYSTEMMESSAGE, ss.str().c_str());
}

bool BountyMgr::Announce(std::string const& text, bool involvesRealPlayer)
{
    uint32 const mode = sWorld.getConfig(CONFIG_UINT32_BOUNTY_ANNOUNCE_MODE);
    if (mode == BOUNTY_ANNOUNCE_NONE)
        return false;

    if (mode == BOUNTY_ANNOUNCE_REAL_PLAYERS && !involvesRealPlayer)
        return false;

    time_t const now = time(nullptr);
    if (time_t const cooldown = sWorld.getConfig(CONFIG_UINT32_BOUNTY_ANNOUNCE_COOLDOWN))
    {
        std::unique_lock<std::shared_mutex> guard(m_lock);
        if (m_lastAnnounceTime && now < m_lastAnnounceTime + cooldown)
            return false;

        m_lastAnnounceTime = now;
    }

    sWorld.SendWorldText(LANG_SYSTEMMESSAGE, text.c_str());
    return true;
}

uint32 BountyMgr::AddBountyGold(ObjectGuid guid, uint32 goldAmount)
{
    std::unique_lock<std::shared_mutex> guard(m_lock);
    uint32& total = m_bounties[guid];
    total = std::min<uint32>(total + goldAmount, MAX_BOUNTY_GOLD);
    return total;
}

void BountyMgr::RecordPvPKill(Player* killer, Player* victim)
{
    if (!killer || !victim || killer == victim)
        return;

    bool const killerReal = IsRealPlayer(killer);
    bool const victimReal = IsRealPlayer(victim);
    bool const involvesRealPlayer = killerReal || victimReal;

    uint32 streak = 0;
    uint32 addedBounty = 0;
    uint32 killerBounty = 0;
    uint32 claimedGold = 0;

    {
        std::unique_lock<std::shared_mutex> guard(m_lock);

        // 1. Killer streak increment
        streak = ++m_killstreaks[killer->GetObjectGuid()];

        // Milestone killstreak bounties
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
            uint32& total = m_bounties[killer->GetObjectGuid()];
            total = std::min<uint32>(total + addedBounty, MAX_BOUNTY_GOLD);
            killerBounty = total;
        }

        // 2. Claim bounty on victim if present
        auto it = m_bounties.find(victim->GetObjectGuid());
        if (it != m_bounties.end())
        {
            claimedGold = it->second;
            m_bounties.erase(it);
        }

        // Reset victim streak
        m_killstreaks.erase(victim->GetObjectGuid());
    }

    // Messaging happens outside the lock: broadcasting walks every session.
    if (claimedGold > 0)
    {
        // Give reward to killer (gold in copper: 1 gold = 10000 copper)
        killer->ModifyMoney(int32(claimedGold * 10000));

        std::ostringstream ss;
        ss << "|cff00ff00[Bounty Claimed]|r " << killer->GetName() << " has SLAIN "
           << victim->GetName() << " and claimed the bounty of " << claimedGold << " Gold!";
        bool const announced = Announce(ss.str(), involvesRealPlayer);

        if (killerReal)
            killer->PSendSysMessage("|cff00ff00[Bounty]|r You received %u Gold for claiming the bounty on %s!", claimedGold, victim->GetName());

        if (victimReal && !announced)
            victim->PSendSysMessage("|cffff0000[Bounty]|r %s has claimed the %u Gold bounty on your head!", killer->GetName(), claimedGold);
    }

    if (addedBounty > 0)
    {
        std::ostringstream ss;
        ss << "|cffff0000[Bounty]|r " << killer->GetName() << " (Level " << killer->GetLevel()
           << ") is on a " << streak << " PvP KILLSTREAK in " << GetAreaName(killer)
           << "! Total Bounty: " << killerBounty << " Gold!";
        bool const announced = Announce(ss.str(), involvesRealPlayer);

        if (killerReal && !announced)
            killer->PSendSysMessage("|cffff0000[Bounty]|r You are on a %u PvP killstreak! The bounty on your head is now %u Gold.", streak, killerBounty);
    }
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

    if (goldAmount > MAX_BOUNTY_GOLD)
    {
        placer->PSendSysMessage("Bounty amount must be between 1 and %u Gold.", MAX_BOUNTY_GOLD);
        return false;
    }

    uint32 costCopper = goldAmount * 10000;
    if (placer->GetMoney() < costCopper)
    {
        placer->PSendSysMessage("You do not have enough gold to place this bounty (%u Gold required).", goldAmount);
        return false;
    }

    placer->ModifyMoney(-int32(costCopper));
    uint32 const totalBounty = AddBountyGold(target->GetObjectGuid(), goldAmount);

    bool const placerReal = IsRealPlayer(placer);
    bool const targetReal = IsRealPlayer(target);

    std::ostringstream ss;
    ss << "|cffff0000[Bounty]|r " << placer->GetName() << " has placed a " << goldAmount
       << " Gold bounty on the head of " << target->GetName() << "! Total Bounty: "
       << totalBounty << " Gold!";
    bool const announced = Announce(ss.str(), placerReal || targetReal);

    if (!announced)
    {
        if (placerReal)
            placer->PSendSysMessage("|cffff0000[Bounty]|r You placed a %u Gold bounty on %s. Total bounty: %u Gold.", goldAmount, target->GetName(), totalBounty);

        if (targetReal)
            target->PSendSysMessage("|cffff0000[Bounty]|r %s has placed a %u Gold bounty on your head! Total bounty: %u Gold.", placer->GetName(), goldAmount, totalBounty);
    }

    return true;
}

bool BountyMgr::AddBotBounty(Player* botPlacer, Player* target, uint32 goldAmount)
{
    if (!botPlacer || !target || goldAmount == 0)
        return false;

    uint32 const totalBounty = AddBountyGold(target->GetObjectGuid(), goldAmount);

    bool const targetReal = IsRealPlayer(target);

    std::ostringstream ss;
    ss << "|cffff0000[Bounty]|r " << botPlacer->GetName() << " has placed a " << goldAmount
       << " Gold revenge bounty on the head of " << target->GetName() << "! Total Bounty: "
       << totalBounty << " Gold!";
    bool const announced = Announce(ss.str(), IsRealPlayer(botPlacer) || targetReal);

    if (targetReal && !announced)
        target->PSendSysMessage("|cffff0000[Bounty]|r %s has placed a %u Gold revenge bounty on your head! Total bounty: %u Gold.", botPlacer->GetName(), goldAmount, totalBounty);

    return true;
}

bool BountyMgr::HasBounty(ObjectGuid guid) const
{
    std::shared_lock<std::shared_mutex> guard(m_lock);
    auto it = m_bounties.find(guid);
    return it != m_bounties.end() && it->second > 0;
}

uint32 BountyMgr::GetBountyAmount(ObjectGuid guid) const
{
    std::shared_lock<std::shared_mutex> guard(m_lock);
    auto it = m_bounties.find(guid);
    return it != m_bounties.end() ? it->second : 0;
}

uint32 BountyMgr::GetKillstreak(ObjectGuid guid) const
{
    std::shared_lock<std::shared_mutex> guard(m_lock);
    auto it = m_killstreaks.find(guid);
    return it != m_killstreaks.end() ? it->second : 0;
}

std::vector<BountyEntry> BountyMgr::GetTopBounties(uint32 maxCount) const
{
    std::vector<BountyEntry> list;

    {
        std::shared_lock<std::shared_mutex> guard(m_lock);
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
            entry.zoneName = GetAreaName(player);

            auto streakIt = m_killstreaks.find(pair.first);
            entry.killstreak = streakIt != m_killstreaks.end() ? streakIt->second : 0;

            list.push_back(entry);
        }
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
    std::unique_lock<std::shared_mutex> guard(m_lock);
    m_bounties.erase(guid);
    m_killstreaks.erase(guid);
}
