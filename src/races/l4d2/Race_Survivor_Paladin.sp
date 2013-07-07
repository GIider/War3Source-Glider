#pragma semicolon 1

#include "W3SIncs/War3Source_Interface"

public Plugin:myinfo = 
{
    name = "War3Source Race - L4D Survivor Paladin",
    author = "Glider",
    description = "The Survivor Paladin race for War3Source.",
    version = "1.0",
};

//=======================================================================
//                             VARIABLES
//=======================================================================

new thisRaceID;
new SKILL_AURA_DMG, SKILL_AURA_DEF, SKILL_AURA_THORNS;
new ULT_OVERDRIVE;

new AURA_DMG, AURA_DEF, AURA_THORNS;

enum ACTIVEAURA{
    None,
    Defensive,
    Offensive,
    Thorns,
}

new ACTIVEAURA:CurrentAura[MAXPLAYERS];

new Float:DamageResistance[6] = {1.0, 0.95, 0.9, 0.85, 0.8, 0.6};
new Float:DamageIncrease[6] = {1.0, 1.15, 1.2, 1.25, 1.3, 1.5};
new Float:ThornsEffect[6] = {0.0, 1.0, 2.0, 3.0, 4.0, 6.0};

new g_BeamSprite;
new g_HaloSprite;

new Float:ULT_COOLDOWN = 120.0;
new Float:AURA_RANGE = 1500.0;

new bool:IsOverdriving[MAXPLAYERS];

//=======================================================================
//                                 INIT
//=======================================================================

public OnWar3PluginReady(){
    thisRaceID = War3_CreateNewRace("Paladin", "paladin");
    SKILL_AURA_DMG = War3_AddRaceSkill(thisRaceID, "Damage Aura", "Everyone in range gains 15/20/25/30% more damage", false, 4);
    SKILL_AURA_DEF = War3_AddRaceSkill(thisRaceID, "Defense Aura", "Everyone in range takes 5/10/15/20% less damage", false, 4);
    SKILL_AURA_THORNS = War3_AddRaceSkill(thisRaceID, "Thorns Aura", "Everyone in range reflects 100/200/300/400% of the damage taken", false, 4);
    ULT_OVERDRIVE = War3_AddRaceSkill(thisRaceID, "Aura Overdrive", "You activate all your auras at once for 10 seconds, increasing your auras strength. CD: 120s", true, 1);
    
    War3_CreateRaceEnd(thisRaceID);
}

public OnPluginStart()
{
    if(War3_GetGame() != Game_L4D && War3_GetGame() != Game_L4D2)
        SetFailState("Only works in the L4D engine! %i", War3_GetGame());
    
    AURA_DMG = W3RegisterAura("pal_dmg", AURA_RANGE, false);
    AURA_DEF = W3RegisterAura("pal_def", AURA_RANGE, false);
    AURA_THORNS = W3RegisterAura("pal_tho", AURA_RANGE, false);
    
    CreateTimer(0.1, AuraDrawTimer, _, TIMER_REPEAT);
    CreateTimer(30.0, BotSwitcher, _, TIMER_REPEAT);
}

public OnMapStart()
{
    g_BeamSprite = PrecacheModel("materials/sprites/laserbeam.vmt");
    g_HaloSprite = PrecacheModel("materials/sprites/glow01.vmt");
}

/* Aura removal */

public OnWar3EventSpawn(client)
{
    if (ValidPlayer(client))
        IsOverdriving[client] = false;
}

public OnWar3EventDeath(victim, attacker)
{
    if (ValidPlayer(victim))
    {
        RemoveAllAuras(victim);
        IsOverdriving[victim] = false;
    }
}

public OnRaceChanged(client, oldrace, newrace)
{
    if (ValidPlayer(client))
    {
        if (newrace != thisRaceID)
        {
            RemoveAllAuras(client);
            IsOverdriving[client] = false;
        }
    }
}

public OnSkillLevelChanged(client, race, skill, newskilllevel)
{
    checkAura(client);
}

RemoveAllAuras(client)
{
    if (ValidPlayer(client))
    {
        W3SetAuraFromPlayer(AURA_DMG, client, false, 4);
        W3SetAuraFromPlayer(AURA_DEF, client, false, 4);
        W3SetAuraFromPlayer(AURA_THORNS, client, false, 4);
    }
}

checkAura(client)
{
    if(ValidPlayer(client, true) && (War3_GetRace(client) == thisRaceID))
    {
        RemoveAllAuras(client);
        
        if (IsOverdriving[client])
        {        
            W3SetAuraFromPlayer(AURA_DEF, client, true, War3_GetSkillLevel(client, thisRaceID, SKILL_AURA_DEF) + 1);
            W3SetAuraFromPlayer(AURA_DMG, client, true, War3_GetSkillLevel(client, thisRaceID, SKILL_AURA_DMG) + 1);
            W3SetAuraFromPlayer(AURA_THORNS, client, true, War3_GetSkillLevel(client, thisRaceID, SKILL_AURA_THORNS) + 1);
        }
        else
        {
            if (CurrentAura[client] == Defensive)
            {
                W3SetAuraFromPlayer(AURA_DEF, client, true, War3_GetSkillLevel(client, thisRaceID, SKILL_AURA_DEF));
            }
            else if (CurrentAura[client] == Offensive)
            {
                W3SetAuraFromPlayer(AURA_DMG, client, true, War3_GetSkillLevel(client, thisRaceID, SKILL_AURA_DMG));
            }
            else if (CurrentAura[client] == Thorns)
            {
                W3SetAuraFromPlayer(AURA_THORNS, client, true, War3_GetSkillLevel(client, thisRaceID, SKILL_AURA_THORNS));
            }
        }
    }
}

/* Auras */

public OnW3TakeDmgAllPre(victim, attacker, Float:damage)
{
    if(ValidPlayer(victim, true))
    {
        new level_def;
        new bool:hasDefAura = W3HasAura(AURA_DEF, victim, level_def);
        if (hasDefAura && level_def > 0)
        {
            War3_DamageModPercent(DamageResistance[level_def]);
        }
        
        if (War3_ZombieHittingSurvivor(victim, attacker))
        {
            new level_tho;
            new bool:hasThornsAura = W3HasAura(AURA_THORNS, victim, level_tho);
            if (hasThornsAura && level_tho > 0)
            {
                War3_DealDamage(attacker, RoundToCeil(damage * ThornsEffect[level_tho]), victim, W3GetDamageType(), "thorns_aura", _, _, _, true);
            }
        }
    }

    if(War3_SurvivorHittingZombie(victim, attacker))
    {
        new level_off;
        new bool:hasOffAura = W3HasAura(AURA_DMG, attacker, level_off);
        if (hasOffAura && level_off > 0)
        {
            War3_DamageModPercent(DamageIncrease[level_off]);
        }
    }
}

/* Not-so-pretty rings */

// Note: You can't make this prettier by using OnGameFrame or OnPlayerRunCmd
// the BeamRingPoints have a minimum lifetime of 0.1 seconds so there's no
// real improvement
public Action:AuraDrawTimer(Handle:timer)
{
    for(new i=1; i <= MaxClients; i++)
    {
        if(ValidPlayer(i, true))
        {
            new level_def, level_tho, level_off;
            new bool:hasDefAura = W3HasAura(AURA_DEF, i, level_def);
            new bool:hasThornsAura = W3HasAura(AURA_THORNS, i, level_tho);
            new bool:hasOffAura = W3HasAura(AURA_DMG, i, level_off);
            
            new Float:effect_vec[3];
            GetClientAbsOrigin(i, effect_vec);
            
            if(hasOffAura && level_off > 0)
            {
                effect_vec[2] += (float(level_off) * 2.0);
                TE_SetupBeamRingPoint(effect_vec, 45.0, 44.0, g_BeamSprite, g_HaloSprite, 0, 15, 0.1, float(level_off), 0.0, {255, 0, 0, 255}, 10, 0);
                TE_SendToAll();
            }
            if(hasDefAura && level_def > 0)
            {
                effect_vec[2] += (float(level_def) * 2.0);
                TE_SetupBeamRingPoint(effect_vec,45.0,44.0,g_BeamSprite,g_HaloSprite,0,15,0.1,float(level_def),0.0,{0,0,255,255},10,0);
                TE_SendToAll();
            }
            if(hasThornsAura && level_tho > 0)
            {
                effect_vec[2] += (float(level_tho) * 2.0);
                TE_SetupBeamRingPoint(effect_vec,45.0,44.0,g_BeamSprite,g_HaloSprite,0,15,0.1,float(level_tho),0.0,{0,255,0,255},10,0);
                TE_SendToAll();
            }
        }
    }
}

/* Menu and shit */

public OnUltimateCommand(client, race, bool:pressed)
{
    if(ValidPlayer(client, true) && 
       race == thisRaceID && 
       pressed && 
       !Silenced(client) &&
       GetClientTeam(client) == TEAM_SURVIVORS &&
       !War3_L4D_IsHelpless(client) &&
       !War3_IsPlayerIncapped(client))
    {    
        new skill_defensive = War3_GetSkillLevel(client, thisRaceID, SKILL_AURA_DEF);
        new skill_offensive = War3_GetSkillLevel(client, thisRaceID, SKILL_AURA_DMG);
        new skill_thorns = War3_GetSkillLevel(client, thisRaceID, SKILL_AURA_THORNS);
        new skill_overdrive = War3_GetSkillLevel(client, thisRaceID, ULT_OVERDRIVE);
        
        // No auras yet? Don't bother...
        if((skill_defensive == 0) && (skill_offensive == 0) && (skill_thorns == 0))
        {
            PrintHintText(client, "You first need a aura!");
        }
        else
        {
            new Handle:menu = CreateMenu(SelectAura);
            SetMenuTitle(menu, "What do you want to do?");

            if(skill_defensive > 0)
            {
                AddMenuItem(menu, "defensive", "Activate defensive aura");
            }
            if(skill_offensive > 0)
            {
                AddMenuItem(menu, "offensive", "Activate offensive aura");
            }
            if(skill_thorns > 0)
            {
                AddMenuItem(menu, "thorns", "Activate thorns aura");
            }
            if(skill_overdrive > 0)
            {
                if(War3_SkillNotInCooldown(client, thisRaceID, ULT_OVERDRIVE, true))
                {
                    AddMenuItem(menu, "overdrive", "ACTIVATE OVERDRIVE");
                }
            }
            
            SetMenuExitButton(menu, false);
            DisplayMenu(menu, client, 20);
        }
    }
}

public SelectAura(Handle:menu, MenuAction:action, param1, param2)
{
    if (action == MenuAction_Select)
    {
        new String:info[32];
        GetMenuItem(menu, param2, info, sizeof(info));
        if(StrEqual(info, "defensive"))
        {
            CurrentAura[param1] = Defensive;
        }
        else if(StrEqual(info, "offensive"))
        {
            CurrentAura[param1] = Offensive;
        }
        else if(StrEqual(info, "thorns"))
        {
            CurrentAura[param1] = Thorns;
        }
        else if(StrEqual(info, "overdrive"))
        {
            IsOverdriving[param1] = true;
            CreateTimer(10.0, ResetUltimate, param1);
            War3_CooldownMGR(param1, ULT_COOLDOWN, thisRaceID, ULT_OVERDRIVE);
        }
        checkAura(param1);
    }
    /* If the menu has ended, destroy it */
    else if (action == MenuAction_End)
    {
        CloseHandle(menu);
    }
}

public Action:BotSwitcher(Handle:timer,any:userid)
{
    for(new i=1; i <= MaxClients; i++)
    {
        if(ValidPlayer(i, true) && (War3_GetRace(i) == thisRaceID) && IsFakeClient(i))
        {
            switch (GetRandomInt(0, 3))
            {
                case 0:
                    CurrentAura[i] = Offensive;
                case 1:
                    CurrentAura[i] = Defensive;
                case 2:
                    CurrentAura[i] = Thorns;
                case 3:
                    OnUltimateCommand(i, thisRaceID, true);
            }
        }
    }
}


// for debugging
/* 
public OnW3PlayerAuraStateChanged(client,tAuraID,bool:inAura,level)
{
    if(ValidPlayer(client, true))
    {
        if (inAura)
        {
            War3_ChatMessage(client, "You now have aura %i", tAuraID);
        }
        else
        {
            War3_ChatMessage(client, "You lost aura %i", tAuraID);
        }
    }
}
*/

public Action:ResetUltimate(Handle:timer, any:client)
{
    IsOverdriving[client] = false;
    checkAura(client);
}