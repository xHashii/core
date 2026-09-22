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

            // The request may already be gone (declined by a command, flag despawned, ...)
            if (!bot->m_duel || bot->m_duel->finished || bot->m_duel->startTime != 0 || bot->m_duel->startTimer != 0)
                return false;

            // We are the one who issued the request (should not happen, we only get the packet as target)
            if (bot->m_duel->initiator == bot)
                return false;

            Player* challenger = bot->m_duel->opponent;
            bool const isMakgora = bot->m_duel->isMakgora;
            bool const fromMaster = ai->GetMaster() && ai->GetMaster()->GetObjectGuid() == playerGuid;
            bool const fromRealMaster = fromMaster && ai->HasRealPlayerMaster();
            std::string const challengerName = challenger ? challenger->GetName() : "stranger";

            bool accept = true;
            std::string declineText;

            if (bot->GetLevel() < sPlayerbotAIConfig.botAcceptDuelMinimumLevel)
            {
                accept = false;
                declineText = "I am not experienced enough to fight you yet, " + challengerName + ".";
            }
            else if (isMakgora)
            {
                // Mak'gora is a fight to the death: bots take it when they are able to fight.
                // Our own (real) master is always obeyed.
                uint32 const minHealth = sPlayerbotAIConfig.botAcceptMakgoraMinimumHealth;
                if (bot->IsInCombat())
                {
                    accept = false;
                    declineText = "I am already fighting, " + challengerName + "! Challenge me again when my blade is free.";
                }
                else if (!fromRealMaster && minHealth > 0 && bot->GetHealthPercent() < float(minHealth))
                {
                    accept = false;
                    declineText = "I am not ready to fight a Mak'gora yet, " + challengerName + "! Let me recover first.";
                }
            }
            else if (!fromRealMaster && AI_VALUE2(uint8, "health", "self target") < 90)
            {
                // regular duel: do not auto duel with low hp (unless our real master asks)
                accept = false;
            }

            if (!accept)
            {
                if (isMakgora)
                    bot->Say(declineText.c_str(), LANG_UNIVERSAL);

                WorldPacket packet(CMSG_DUEL_CANCELLED, 8);
                packet << flagGuid;
                bot->GetSession()->HandleDuelCancelledOpcode(MakeTypedPacket<WorldPackets::Duel::DuelCancelled>(packet));
                return true;
            }

            if (isMakgora)
            {
                std::string text = "I accept your challenge to the death in Mak'gora, " + challengerName + "! Lok'tar ogar!";
                bot->Say(text.c_str(), LANG_UNIVERSAL);
            }

            WorldPacket packet(CMSG_DUEL_ACCEPTED, 8);
            packet << flagGuid;
            bot->GetSession()->HandleDuelAcceptedOpcode(MakeTypedPacket<WorldPackets::Duel::DuelAccepted>(packet));

            ai->ResetStrategies();
            return true;
        }

#ifdef GenerateBotHelp
        virtual std::string GetHelpName() { return "accept duel"; } //Must equal iternal name
        virtual std::string GetHelpDescription()
        {
            return "This action accepts or declines duel invitations based on conditions.\n"
                "The bot will decline if below minimum level or low health (unless from master).\n"
                "Mak'gora (duel to the death) requests are accepted when the bot is not in combat\n"
                "and above AiPlayerbot.BotAcceptMakgoraMinimumHealth percent health; the bot says why it declines.\n"
                "After accepting, combat strategies are reset for the duel.";
        }
        virtual std::vector<std::string> GetUsedActions() { return {}; }
        virtual std::vector<std::string> GetUsedValues() { return { "health" }; }
#endif 
    };

}
