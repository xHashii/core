/* RaidMode - 20-man conversion for 40-man raids (Phase 0+)
 * Shared lockout, normal loot, toggled by Raid Herald NPC at entrance.
 * Patch-gated per WowPatch; see Progression.h.
 */
#ifndef MANGOS_RAIDMODE_H
#define MANGOS_RAIDMODE_H

#include "Common.h"
#include "SharedDefines.h"
#include "Progression.h"

enum RaidMode : uint8
{
    RAID_MODE_40MAN = 0,
    RAID_MODE_20MAN = 1,
    MAX_RAID_MODE   = 2
};

inline const char* GetRaidModeName(uint8 mode)
{
    return mode == RAID_MODE_20MAN ? "20-man" : "40-man";
}

// Maps that are eligible for 20-man conversion in this core.
// We keep loot identical (normal loot); only maxPlayers + scaling changes.
inline bool IsRaidModeConvertibleMap(uint32 mapId)
{
    switch (mapId)
    {
        case MAP_MOLTEN_CORE:      // 409
        case MAP_ONYXIAS_LAIR:     // 249
        case MAP_BLACKWING_LAIR:   // 469
        case MAP_AHN_QIRAJ_TEMPLE: // 531 AQ40
        case MAP_NAXXRAMAS:        // 533 (unlocked later, included for phase planning)
            return true;
        default:
            return false;
    }
}

// Required patch for the 20-man version to be offered (mirrors raid availability).
inline uint8 RequiredPatchForRaid20Man(uint32 mapId)
{
    switch (mapId)
    {
        case MAP_MOLTEN_CORE:      return WOW_PATCH_102;
        case MAP_ONYXIAS_LAIR:     return WOW_PATCH_102;
        case MAP_BLACKWING_LAIR:   return WOW_PATCH_106;
        case MAP_AHN_QIRAJ_TEMPLE: return WOW_PATCH_109;
        case MAP_NAXXRAMAS:        return WOW_PATCH_111;
        default:                   return WOW_PATCH_112; // never available for unknown maps
    }
}

#endif
