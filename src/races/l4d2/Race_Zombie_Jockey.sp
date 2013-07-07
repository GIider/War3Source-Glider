#pragma semicolon 1

#include "W3SIncs/War3Source_Interface"
#include <sdkhooks>

public Plugin:myinfo = 
{
    name = "War3Source Race - L4D Zombie Jockey",
    author = "Glider",
    description = "The Zombie Jockey race for War3Source.",
    version = "1.0",
};

//=======================================================================
//                             VARIABLES
//=======================================================================

new thisRaceID;

new SKILL_SHAKY_HANDS;

new Float:ShakyChance[5] = {0.0, 0.02, 0.04, 0.06, 0.08};

//=======================================================================
//                                 INIT
//=======================================================================

public OnWar3PluginReady(){
    thisRaceID = War3_CreateNewRace("[ZOMBIE] Jockey", "jockey");
    War3_AddRaceSkill(thisRaceID, "Dummy", "Enables you to level", false, 4);
    War3_AddRaceSkill(thisRaceID, "Dummy", "Enables you to level", false, 4);
    War3_AddRaceSkill(thisRaceID, "Dummy", "Enables you to level", false, 4);
    SKILL_SHAKY_HANDS = War3_AddRaceSkill(thisRaceID, "Shaky Hands", "Survivors you damage have a 2/4/6/8% chance to drop a item", false, 4);
    
    War3_CreateRaceEnd(thisRaceID);
}

public OnPluginStart()
{
    if(War3_GetGame() != Game_L4D && War3_GetGame() != Game_L4D2)
        SetFailState("Only works in the L4D engine! %i", War3_GetGame());
}

public OnW3TakeDmgAllPre(victim,attacker,Float:damage){
    if(ValidPlayer(victim, true) && ValidPlayer(attacker, true) && GetClientTeam(victim) == TEAM_SURVIVORS && GetClientTeam(attacker) == TEAM_INFECTED)
    {
        if(War3_GetRace(attacker) == thisRaceID)
        {
            new skill = War3_GetSkillLevel(attacker, thisRaceID, SKILL_SHAKY_HANDS);
            if(skill >= 0)
            {
                if (GetRandomFloat(0.0, 1.0) <= ShakyChance[skill])
                {
                    new slot = -1;
                    new weapon = -1;
                    
                    while(weapon == -1) {
                        slot = GetRandomInt(1, 5);

                        weapon = GetPlayerWeaponSlot(victim, slot);
                        if (weapon != -1) {
                            War3_ChatMessage(victim, "The jockey made you drop something!");
                            SDKHooks_DropWeapon(victim, weapon, NULL_VECTOR,NULL_VECTOR);
                        }
                    }
                }
            }
        }
    }
}
