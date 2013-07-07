#pragma semicolon 1

#include "W3SIncs/War3Source_Interface"

public Plugin:myinfo = 
{
    name = "War3Source - Addon - L4D - Give people forced races",
    author = "Glider",
    description = "Forcing people into races just cause",
    version = "1.1",
};

new race_boomer;
new race_hunter;
new race_charger;
new race_jockey;
new race_smoker;
new race_spitter;
new race_tank;
new race_blazing_tank;

public OnPluginStart()
{
    CreateTimer(0.1, InfectedForceTimer, _, TIMER_REPEAT);
}

public OnWar3PluginReady()
{
    race_boomer = War3_GetRaceIDByShortname("boomer");
    race_hunter = War3_GetRaceIDByShortname("hunter");
    race_charger = War3_GetRaceIDByShortname("charger");
    race_jockey = War3_GetRaceIDByShortname("jockey");
    race_smoker = War3_GetRaceIDByShortname("smoker");
    race_spitter = War3_GetRaceIDByShortname("spitter");
    race_tank = War3_GetRaceIDByShortname("tank");
    race_blazing_tank = War3_GetRaceIDByShortname("blaztank");
}

public Action:InfectedForceTimer(Handle:timer, any:userid)
{
    decl String:modelName[100];
    for(new client=1; client <= MaxClients; client++)
    {
        if(ValidPlayer(client, true) && GetClientTeam(client) == TEAM_INFECTED && IsPlayerGhost(client)) 
        {
            GetClientModel(client, modelName, sizeof(modelName));
            
            // Don't need to check hulk since hulk can't be ghost
            if (StrContains(modelName, "boom", false) != -1 && War3_GetRace(client) != race_boomer)
                War3_SetRace(client, race_boomer);
            else if (StrContains(modelName, "hunter", false) != -1 && War3_GetRace(client) != race_hunter)
                War3_SetRace(client, race_hunter);
            else if (StrContains(modelName, "charger", false) != -1 && War3_GetRace(client) != race_charger)
                War3_SetRace(client, race_charger);
            else if (StrContains(modelName, "jockey", false) != -1 && War3_GetRace(client) != race_jockey)
                War3_SetRace(client, race_jockey);
            else if (StrContains(modelName, "smoker", false) != -1 && War3_GetRace(client) != race_smoker)
                War3_SetRace(client, race_smoker);
            else if (StrContains(modelName, "spitter", false) != -1 && War3_GetRace(client) != race_spitter)
                War3_SetRace(client, race_spitter);
        }
    }
}

public OnWar3EventSpawn(client)
{    
    if (!ValidPlayer(client))
    {
        return;
    }

    new player_race = War3_GetRace(client);

    if (GetClientTeam(client) == TEAM_SURVIVORS)
    {
        if (player_race == race_boomer || player_race == race_hunter ||
            player_race == race_charger || player_race == race_jockey ||
            player_race == race_smoker || player_race == race_spitter)
        {
            War3_SetRace(client, 0);
        }
        
        if (War3_GetRace(client) == 0)
        {
            CreateTimer(90.0, forceRaceTimer, client, TIMER_FLAG_NO_MAPCHANGE);
        }
    }
    else if (GetClientTeam(client) == TEAM_INFECTED)
    {
        decl String:modelName[100];
        GetClientModel(client, modelName, sizeof(modelName));
        
        if (StrContains(modelName, "boom", false) != -1)
        {    
            if (player_race != race_boomer)
            {
                War3_SetRace(client, race_boomer);
            }
        }
        else if (StrContains(modelName, "charger", false) != -1)
        {    
            if (player_race != race_charger)
            {
                War3_SetRace(client, race_charger);
            }
        }
        else if (StrContains(modelName, "hunter", false) != -1)
        {    
            if (player_race != race_hunter)
            {
                War3_SetRace(client, race_hunter);
            }
        }
        else if (StrContains(modelName, "jockey", false) != -1)
        {    
            if (player_race != race_jockey)
            {
                War3_SetRace(client, race_jockey);
            }
        }
        else if (StrContains(modelName, "smoker", false) != -1)
        {    
            if (player_race != race_smoker)
            {
                War3_SetRace(client, race_smoker);
            }
        }
        else if (StrContains(modelName, "spitter", false) != -1)
        {    
            if (player_race != race_spitter)
            {
                War3_SetRace(client, race_spitter);
            }
        }
        else if (StrContains(modelName, "hulk", false) != -1)
        {    
            if (player_race != race_tank && player_race != race_blazing_tank)
            {
                switch (GetRandomInt(0, 1))
                {
                    case 0:
                        War3_SetRace(client, race_tank);
                    case 1:
                        War3_SetRace(client, race_blazing_tank);
                }
            }
        }
        
        if (IsFakeClient(client))
        {
            new max_level = W3GetRaceMaxLevel(War3_GetRace(client));
            War3_SetLevel(client, War3_GetRace(client), GetRandomInt(0, max_level));
            
            War3_bots_distribute_sp(client);
        }
    }
}

public Action:forceRaceTimer(Handle:timer, any:client)
{
    new medic = War3_GetRaceIDByShortname("medic");
    new support = War3_GetRaceIDByShortname("support");

    if(ValidPlayer(client) && War3_GetRace(client) == 0 && GetClientTeam(client) == TEAM_SURVIVORS)
    {
        War3_ChatMessage(client, "Since you didn't choose a race you were forced into a supportive one.");
        if (GetRandomInt(0, 1) == 0 )
            War3_SetRace(client, medic);
        else
            War3_SetRace(client, support);
    }
}