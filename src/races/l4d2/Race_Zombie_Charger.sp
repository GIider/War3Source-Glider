#pragma semicolon 1

#include "W3SIncs/War3Source_Interface"
#include <sdkhooks>

public Plugin:myinfo = 
{
    name = "War3Source Race - L4D Zombie Charger",
    author = "Glider",
    description = "The Zombie Charger race for War3Source.",
    version = "1.0",
};

//=======================================================================
//                             VARIABLES
//=======================================================================

new thisRaceID;
new SKILL_ADRENALINE_RUSH;
new ULT_STEERING;

new bool:g_bIsCharging[MAXPLAYERS];
new Float:g_fCurrentSpeedBuff[MAXPLAYERS];
new Float:g_fDamageNerf[5] = {0.0, 0.6, 0.7, 0.8, 0.9};

//=======================================================================
//                                 INIT
//=======================================================================

public OnWar3PluginReady(){
    thisRaceID = War3_CreateNewRace("[ZOMBIE] Charger", "charger");
    SKILL_ADRENALINE_RUSH = War3_AddRaceSkill(thisRaceID, "Adrenaline Rush", "While charging you get a speed boost for taking damage.", false, 4);
    ULT_STEERING = War3_AddRaceSkill(thisRaceID, "Steerin'", "You can still move in other directions while charging", true, 1);
    War3_AddRaceSkill(thisRaceID, "Dummy", "Enables you to level", false, 4);
    War3_AddRaceSkill(thisRaceID, "Dummy", "Enables you to level", false, 4);

    War3_CreateRaceEnd(thisRaceID);
}

public OnPluginStart()
{
    if(War3_GetGame() != Game_L4D && War3_GetGame() != Game_L4D2)
        SetFailState("Only works in the L4D engine! %i", War3_GetGame());

    if(!HookEventEx("charger_charge_start", Event_ChargeStart))
    {
        SetFailState("Could not hook the charger_charge_start event.");
    }
    if(!HookEventEx("charger_charge_end", Event_ChargeEnd))
    {
        SetFailState("Could not hook the charger_charge_end event.");
    }
}

public OnWar3EventSpawn(client)
{    
    giveBuffs(client);
}

public OnRaceChanged(client, oldrace, newrace)
{
    if(newrace == thisRaceID)
    {
        giveBuffs(client);
    }
    else
    {
        W3ResetPlayerColor(client, thisRaceID);
    }
}

public OnSkillLevelChanged(client, race, skill, newskilllevel)
{
    if (skill == ULT_STEERING)
    {
        giveBuffs(client);
    }
}

giveBuffs(client)
{
    if (ValidPlayer(client) && GetClientTeam(client) == TEAM_INFECTED && War3_GetRace(client) == thisRaceID)
    {
        // Color Chargers with the ultimate as they are dangerous!!
        new ult_steering = War3_GetSkillLevel(client, thisRaceID, ULT_STEERING);
        if (ult_steering > 0 ) {
            W3SetPlayerColor(client, thisRaceID, 255, 0, 0, _, GLOW_ULTIMATE);
        }
        
        UnChargeClient(client);
    }
}

public OnWar3EventDeath(victim, attacker)
{
    if (ValidPlayer(victim)) {
        UnChargeClient(victim);
    }
}

UnChargeClient(client) {
    g_bIsCharging[client] = false;
    War3_SetBuff(client, fMaxSpeed, thisRaceID, 1.0);
}

public OnW3TakeDmgAllPre(victim, attacker, Float:damage){
    
    if(ValidPlayer(victim, true) && (War3_GetRace(victim) == thisRaceID) && (g_bIsCharging[victim] == true))
    {
        new skill = War3_GetSkillLevel(victim, thisRaceID, SKILL_ADRENALINE_RUSH);
        if(skill > 0) {
            g_fCurrentSpeedBuff[victim] += (damage / 1000.0) * g_fDamageNerf[skill];
            
            W3Hint(victim, HINT_COOLDOWN_COUNTDOWN, 1.0, "Speed buff: %f", 1.0 + g_fCurrentSpeedBuff[victim]);
        }
    }
}

public Event_ChargeStart(Handle:event, const String:name[], bool:dontBroadcast)
{
    new client = GetClientOfUserId(GetEventInt(event, "userid"));
    g_bIsCharging[client] = true;

    if (War3_GetRace(client) == thisRaceID) {
        new ult_steering = War3_GetSkillLevel(client, thisRaceID, ULT_STEERING);
        if (ult_steering > 0 ) {
            SetEntProp(client, Prop_Send, "m_fFlags", GetEntProp(client, Prop_Send, "m_fFlags") & ~FL_FROZEN);
        
            new entity = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
            SetEntPropFloat(entity, Prop_Send, "m_flNextSecondaryAttack", GetGameTime() + 999.9);
        }
    }
}

public Event_ChargeEnd(Handle:event, const String:name[], bool:dontBroadcast)
{
    new client = GetClientOfUserId(GetEventInt(event, "userid"));
    UnChargeClient(client);

    if (War3_GetRace(client) == thisRaceID) {
        new ult_steering = War3_GetSkillLevel(client, thisRaceID, ULT_STEERING);
        if (ult_steering > 0 ) {
            new entity = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
            SetEntPropFloat(entity, Prop_Send, "m_flNextSecondaryAttack", GetGameTime() + 1.0);
        }
    }

}