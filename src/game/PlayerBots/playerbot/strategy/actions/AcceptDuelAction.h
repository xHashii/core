#pragma once

#include "playerbot/strategy/Action.h"

namespace ai
{
    class AcceptDuelAction : public Action
    {
    public:
        AcceptDuelAction(PlayerbotAI* ai) : Action(ai, "accept duel")
        {}

        virtual bool Execute(Event& event) override
        {
            WorldPacket p(event.getPacket());

            ObjectGuid flagGuid;
            p >> flagGuid;
            ObjectGuid playerGuid;
            p >> playerGuid;

            // do not auto duel with low hp or below certain level
            if (bot->GetLevel() < sPlayerbotAIConfig.botAcceptDuelMinimumLevel
                || ((!ai->HasRealPlayerMaster() || (ai->GetMaster() && ai->GetMaster()->GetObjectGuid() != playerGuid)) && AI_VALUE2(uint8, "health", "self target") < 90))
            {
                WorldPacket packet(CMSG_DUEL_CANCELLED, 8);
                packet << flagGuid;
                bot->GetSession()->HandleDuelCancelledOpcode(MakeTypedPacket<WorldPackets::Duel::DuelCancelled>(packet));
            }

            WorldPacket packet(CMSG_DUEL_ACCEPTED, 8);
            packet << flagGuid;
            bot->GetSession()->HandleDuelAcceptedOpcode(MakeTypedPacket<WorldPackets::Duel::DuelAccepted>(packet));

            if (bot->m_duel && (bot->HasPendingMakgoraChallenge(playerGuid) || (bot->m_duel->opponent && bot->m_duel->opponent->HasPendingMakgoraChallenge(bot->GetObjectGuid()))))
            {
                bot->m_duel->isMakgora = true;
                if (bot->m_duel->opponent && bot->m_duel->opponent->m_duel)
                    bot->m_duel->opponent->m_duel->isMakgora = true;

                bot->Say("Lok'tar Ogar! A duel to the death! Only one shall survive!", LANG_UNIVERSAL);

                std::ostringstream ss;
                ss << "|cffff0000[Mak'gora]|r " << (bot->m_duel->opponent ? bot->m_duel->opponent->GetName() : "Challenger")
                   << " and " << bot->GetName() << " have entered a Mak'gora (Duel to the Death)!";
                sWorld.SendWorldText(LANG_SYSTEMMESSAGE, ss.str().c_str());
            }

            ai->ResetStrategies();
            return true;
        }

#ifdef GenerateBotHelp
        virtual std::string GetHelpName() { return "accept duel"; } //Must equal iternal name
        virtual std::string GetHelpDescription()
        {
            return "This action accepts or declines duel invitations based on conditions.\n"
                "The bot will decline if below minimum level or low health (unless from master).\n"
                "After accepting, combat strategies are reset for the duel.";
        }
        virtual std::vector<std::string> GetUsedActions() { return {}; }
        virtual std::vector<std::string> GetUsedValues() { return {}; }
#endif 
    };

}
