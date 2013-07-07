#pragma semicolon 1

#include "W3SIncs/War3Source_Interface"
#include <sdkhooks>

public Plugin:myinfo = 
{
    name = "War3Source Race - L4D Zombie Hunter",
    author = "Glider",
    description = "The Zombie Hunter race for War3Source.",
    version = "1.0",
};

//=======================================================================
//                             VARIABLES
//=======================================================================

new thisRaceID;

//=======================================================================
//                                 INIT
//=======================================================================

public OnWar3PluginReady(){
    thisRaceID = War3_CreateNewRace("[ZOMBIE] Hunter", "hunter");
    War3_AddRaceSkill(thisRaceID, "Dummy", "Enables you to level", false, 13);

    War3_CreateRaceEnd(thisRaceID);
}

public OnPluginStart()
{
    if(War3_GetGame() != Game_L4D && War3_GetGame() != Game_L4D2)
        SetFailState("Only works in the L4D engine! %i", War3_GetGame());
}
