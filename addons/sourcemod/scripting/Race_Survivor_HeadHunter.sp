#pragma semicolon 1    ///WE RECOMMEND THE SEMICOLON

#include <sdkhooks>
#include "W3SIncs/War3Source_Interface"

public Plugin:myinfo = 
{
    name = "War3Source Race - Headhunter",
    author = "Glider",
    description = "The Headhunter race for War3Source.",
    version = "1.0",
};
 
//=======================================================================
//                             VARIABLES
//=======================================================================

new thisRaceID;
new SKILL_HUNT, SKILL_THRILL, SKILL_PAYDAY;
new ULT_SWIFT;

new MaxSkulls[5] = {20, 40, 60, 80, 100};
new ClientSkulls[MAXPLAYERS];
new Float:PaydayModifier[5] = {0.25, 0.5, 0.75, 1.0};
new Float:DamageBonus[5] = {0.0, 0.25, 0.5, 0.75, 1.0};

//=======================================================================
//                                 INIT
//=======================================================================

public OnWar3PluginReady(){
    thisRaceID = War3_CreateNewRace("Headhunter", "headhunter");
    SKILL_HUNT = War3_AddRaceSkill(thisRaceID, "The Hunt", "Enables you to get skulls by headshotting enemys. Increases your max amount of skulls to 40/60/80/100", false, 4);
    SKILL_THRILL = War3_AddRaceSkill(thisRaceID, "The Thrill", "Each skull increases your damage by 0.25/0.5/0.75/1%.\nDoesn't apply to burn damage.", false, 4);
    SKILL_PAYDAY = War3_AddRaceSkill(thisRaceID, "The Payday", "Each skull gives you 0.25/0.5/0.75/1 gold at roundend", false, 4);
    ULT_SWIFT = War3_AddRaceSkill(thisRaceID, "The Swift", "Pay 50 skulls to free yourself from a special infected.", true, 1);
    
    War3_CreateRaceEnd(thisRaceID);
}

public OnPluginStart()
{
    if(War3_GetGame() != Game_L4D && War3_GetGame() != Game_L4D2)
        SetFailState("Only works in the L4D engine! %i", War3_GetGame());
}

public OnMapStart()
{    
    if(GameL4DAny())
    {    
        HookEvent("mission_lost", RoundLostEvent);
    }
}

//=======================================================================
//                                 Award skulls
//=======================================================================

public OnWar3EventDeath(victim, attacker)
{
    if (ValidPlayer(attacker, true) && GetClientTeam(attacker) == TEAM_SURVIVORS && (War3_GetRace(attacker) == thisRaceID))
    {
        new Handle:event = W3GetVar(SmEvent);
        
        if (GetEventBool(event, "headshot") && (War3_IsCommonInfected(victim) || (ValidPlayer(victim) && GetClientTeam(victim) == TEAM_INFECTED)))
        {
            new skill = War3_GetSkillLevel(attacker, thisRaceID, SKILL_HUNT);
            if (skill > 0 && (ClientSkulls[attacker] < MaxSkulls[skill]))
            {
                ClientSkulls[attacker]++;
            }
        }
    }
    
    if (ValidPlayer(victim) && War3_GetRace(victim) == thisRaceID)
    {
        ClientSkulls[victim] = 0;
    }
}

public War3Source_EndRoundEvent(Handle:event,const String:name[],bool:dontBroadcast)
{
    for(new client=1; client <= MaxClients; client++)
    {
        if(ValidPlayer(client))
        {
            if(War3_GetRace(client) == thisRaceID)
            {
                new skill = War3_GetSkillLevel(client, thisRaceID, SKILL_PAYDAY);
                if(skill > 0)
                {
                    new gold = RoundToCeil(ClientSkulls[client] * PaydayModifier[skill]); 
                    W3GiveXPGold(client, XPAwardByGeneric, 0, gold, "your skulls");
                }
            }
        }
    }
}

public Action:RoundLostEvent(Handle:h_Event, const String:s_Name[], bool:b_DontBroadcast)
{
    for(new client=1; client <= MaxClients; client++)
    {
        if(ValidPlayer(client))
        {
            ClientSkulls[client] = 0;
        }
    }
}

public OnRaceChanged(client, oldrace, newrace)
{
    if(newrace != thisRaceID && oldrace == thisRaceID)
    {
        ClientSkulls[client] = 0;
    }
}

public OnSkillLevelChanged(client, race, skill, newskilllevel)
{
    if (race == thisRaceID)
    {    
        if (skill == SKILL_HUNT)
        {
            if (ClientSkulls[client] > MaxSkulls[newskilllevel])
            {
                ClientSkulls[client] = MaxSkulls[newskilllevel];
            }
        }
    }
}

public OnWar3EventSpawn(client)
{    
    if (ValidPlayer(client, true) && GetClientTeam(client) == TEAM_SURVIVORS && (War3_GetRace(client) == thisRaceID))
    {
        ClientSkulls[client] = 0;
    }
}
    


//=======================================================================
//                           Enhance damage
//=======================================================================

public OnW3TakeDmgAllPre(victim, attacker, Float:damage)
{
    if(ValidPlayer(attacker) && War3_GetRace(attacker) == thisRaceID && War3_SurvivorHittingZombie(victim, attacker))
    {
        new skill = War3_GetSkillLevel(victim, thisRaceID, SKILL_THRILL);
        if(skill > 0 && W3GetDamageType() ^ DMG_BURN)
        {
            new Float:DamageMod = 1.0;
            DamageMod += ClientSkulls[attacker] * DamageBonus[skill];
            
            War3_DamageModPercent(DamageMod);
        }
    }
}

//=======================================================================
//                           Ultimate
//=======================================================================

public OnUltimateCommand(client,race,bool:pressed)
{
    if(ValidPlayer(client, true) && 
       race == thisRaceID && 
       pressed && 
       !Silenced(client) &&
       GetClientTeam(client) == TEAM_SURVIVORS)
    {    
        if (War3_L4D_IsHelpless(client))
        {
            new skill = War3_GetSkillLevel(client, thisRaceID, ULT_SWIFT);
            if (skill > 0)
            {
                if (ClientSkulls[client] > 50)
                {
                    War3_ChatMessage(client, "You pay the price...");
                    ClientSkulls[client] -= 50;
                    
                    new attacker = L4D2_GetInfectedAttacker(client);
                    if (ValidPlayer(attacker, true))
                    {
                        War3_DealDamage(attacker, GetClientHealth(attacker), client, DMG_BLAST, "ult_swift");
                    }
                }
            }
        }
        else
        {
            War3_ChatMessage(client, "You currently have %i skulls", ClientSkulls[client]);
        }
    }
}
