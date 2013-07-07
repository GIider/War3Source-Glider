#pragma semicolon 1

#include "W3SIncs/War3Source_Interface"
#include "W3SIncs/War3Source_Bots"

public Plugin:myinfo = 
{
	name = "War3Source Race - MVM Bot",
	author = "Glider",
	description = "A dummy race for MVM bots",
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
	thisRaceID = War3_CreateNewRace("MVM Bot", "mvmbot");
	War3_CreateRaceEnd(thisRaceID);
}

public OnPluginStart()
{
	if(War3_GetGame() != Game_TF)
		SetFailState("Only works in the TF2 engine! %i", War3_GetGame());
	
}

public OnWar3EventSpawn(client)
{	
	if (!ValidPlayer(client))
	{
		return;
	}

	new player_race = War3_GetRace(client);

	if (GetClientTeam(client) == TEAM_BLUE)
	{
		if (player_race != thisRaceID)
		{
			War3_SetRace(client, thisRaceID);
		}
		
		if (IsFakeClient(client))
		{
			new max_level = W3GetRaceMaxLevel(War3_GetRace(client));
			War3_SetLevel(client, War3_GetRace(client), GetRandomInt(0, max_level));
			
			War3_bots_distribute_sp(client);
		}
	}
}