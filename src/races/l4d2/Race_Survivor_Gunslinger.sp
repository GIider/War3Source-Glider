#pragma semicolon 1    ///WE RECOMMEND THE SEMICOLON

#include <sdkhooks>
#include "W3SIncs/War3Source_Interface"


public Plugin:myinfo = 
{
    name = "War3Source Race - Pistoleer",
    author = "Glider",
    description = "The Pistoleer race for War3Source.",
    version = "1.0",
};
 
//=======================================================================
//                             VARIABLES
//=======================================================================

new thisRaceID;
new SKILL_PISTOL_KNOWLEDGE, SKILL_URANIUM, SKILL_SPECIAL;
new ULT_PISTOLERO;

new bool:g_bIsPistolero[MAXPLAYERS] = false;
new Float:PistolDmgBuff[5] = {0.0, 1.25, 1.5, 1.75, 2.0};
new Float:ReloadSpeed[5]= {1.0, 0.89285, 0.7857, 0.67855, 0.5714};
new Float:FireChance[5]= {0.0, 0.02, 0.04, 0.06, 0.08};
new Float:ULT_COOLDOWN = 60.0;

new g_iNextPAttO        = -1;
new g_iActiveWO            = -1;
new g_iPlayRateO        = -1;
new g_iNextAttO            = -1;
new g_iTimeIdleO        = -1;
new g_iVMStartTimeO        = -1;
new g_iViewModelO        = -1;

//=======================================================================
//                                 INIT
//=======================================================================

public OnWar3PluginReady(){
    thisRaceID = War3_CreateNewRace("Gunslinger", "gunslinger");
    SKILL_PISTOL_KNOWLEDGE = War3_AddRaceSkill(thisRaceID, "Pistol Handling", "Increases Pistol/Magnum Reload speed by 11/22/33/43%", false, 4);
    SKILL_URANIUM = War3_AddRaceSkill(thisRaceID, "Uranium Tipped Bullets", "Increase your Pistol/Magnum damage by 25/50/75/100%", false, 4);
    SKILL_SPECIAL = War3_AddRaceSkill(thisRaceID, "Fire Bullets", "2/4/6/8% chance to fire a incendiary bullet with your Pistol/Magnum", false, 4);
    ULT_PISTOLERO = War3_AddRaceSkill(thisRaceID, "Pistolero", "You gain a movement speed buff and unlimited ammo for your pistols.\n Lasts 10 seconds. CD: 60s", true, 1);
    
    War3_CreateRaceEnd(thisRaceID);
}

public OnPluginStart()
{
    if(War3_GetGame() != Game_L4D && War3_GetGame() != Game_L4D2)
        SetFailState("Only works in the L4D engine! %i", War3_GetGame());

    HookEvent("weapon_reload", Event_Reload);
    HookEvent("weapon_fire", Event_Fire);
    
    //get offsets
    g_iNextPAttO        =    FindSendPropInfo("CBaseCombatWeapon","m_flNextPrimaryAttack");
    g_iActiveWO            =    FindSendPropInfo("CBaseCombatCharacter","m_hActiveWeapon");
    g_iPlayRateO        =    FindSendPropInfo("CBaseCombatWeapon","m_flPlaybackRate");
    g_iNextAttO            =    FindSendPropInfo("CTerrorPlayer","m_flNextAttack");
    g_iTimeIdleO        =    FindSendPropInfo("CTerrorGun","m_flTimeWeaponIdle");
    g_iViewModelO        =    FindSendPropInfo("CTerrorPlayer","m_hViewModel");
    g_iVMStartTimeO        =    FindSendPropInfo("CTerrorViewModel","m_flLayerStartTime");
}

public OnMapStart()
{
    War3_PrecacheParticle("impact_incendiary_fire");
    //War3_PrecacheParticle("weapon_muzzle_flash_minigun");
}

//=======================================================================
//                  ADVANCED PISTOL KNOWLEDGE/SPECIAL AMMO
//=======================================================================

public Event_Reload (Handle:event, const String:name[], bool:dontBroadcast)
{
    new client = GetClientOfUserId(GetEventInt(event,"userid"));
    if(ValidPlayer(client, true) && GetClientTeam(client) == TEAM_SURVIVORS && War3_GetRace(client) == thisRaceID && War3_GetSkillLevel(client, thisRaceID, SKILL_PISTOL_KNOWLEDGE) > 0)
    {
        AdrenReload(client);
    }
}

public Event_Fire (Handle:event, const String:name[], bool:dontBroadcast)
{
    new client = GetClientOfUserId(GetEventInt(event,"userid"));
    decl String:weapon[64];
    
    GetEventString(event, "weapon", weapon, sizeof(weapon));
    if(ValidPlayer(client, true) && GetClientTeam(client) == TEAM_SURVIVORS && War3_GetRace(client) == thisRaceID && g_bIsPistolero[client] == true)
    {
        if (StrEqual(weapon, "pistol") || StrEqual(weapon, "pistol_magnum"))
        {
            new iWeapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
            new currentammo = GetEntProp(iWeapon, Prop_Send, "m_iClip1");
            SetEntProp(iWeapon, Prop_Send, "m_iClip1", currentammo + 1);
        }
    }
}

// ////////////////////////////////////////////////////////////////////////////
//On the start of a reload
AdrenReload (client)
{
    new iEntid = GetEntDataEnt2(client, g_iActiveWO);
    if (IsValidEntity(iEntid) == false) return;

    decl String:stClass[32];
    GetEntityNetClass(iEntid,stClass,32);

    if (StrEqual(stClass, "CPistol") || StrEqual(stClass, "CMagnumPistol"))
    {
        MagStart(iEntid, client);
    }
}

MagStart (iEntid, client)
{
    new Float:flGameTime = GetGameTime();
    new Float:flNextTime_ret = GetEntDataFloat(iEntid,g_iNextPAttO);
    
    new Float:flNextTime_calc = ( flNextTime_ret - flGameTime ) * ReloadSpeed[War3_GetSkillLevel(client, thisRaceID, SKILL_PISTOL_KNOWLEDGE)] ;
    SetEntDataFloat(iEntid, g_iPlayRateO, 1.0/ReloadSpeed[War3_GetSkillLevel(client, thisRaceID, SKILL_PISTOL_KNOWLEDGE)], true);
    CreateTimer( flNextTime_calc, Timer_MagEnd, iEntid);
    
    new Handle:hPack = CreateDataPack();
    WritePackCell(hPack, client);
    
    new Float:flStartTime_calc = flGameTime - ( flNextTime_ret - flGameTime ) * ( 1 - ReloadSpeed[War3_GetSkillLevel(client, thisRaceID, SKILL_PISTOL_KNOWLEDGE)] ) ;
    WritePackFloat(hPack, flStartTime_calc);
    
    if ( (flNextTime_calc - 0.4) > 0 )
        CreateTimer( flNextTime_calc - 0.4 , Timer_MagEnd2, hPack);
    
    flNextTime_calc += flGameTime;
    
    SetEntDataFloat(iEntid, g_iTimeIdleO, flNextTime_calc, true);
    SetEntDataFloat(iEntid, g_iNextPAttO, flNextTime_calc, true);
    SetEntDataFloat(client, g_iNextAttO, flNextTime_calc, true);
    
}

public Action:Timer_MagEnd (Handle:timer, any:iEntid)
{
    KillTimer(timer);
    if (IsServerProcessing()==false)
        return Plugin_Stop;
    
    if (iEntid <= 0
        || IsValidEntity(iEntid)==false)
        return Plugin_Stop;

    SetEntDataFloat(iEntid, g_iPlayRateO, 1.0, true);

    return Plugin_Stop;
}

public Action:Timer_MagEnd2 (Handle:timer, Handle:hPack)
{
    KillTimer(timer);
    if (IsServerProcessing()==false)
    {
        CloseHandle(hPack);
        return Plugin_Stop;
    }

    ResetPack(hPack);
    new iCid = ReadPackCell(hPack);
    new Float:flStartTime_calc = ReadPackFloat(hPack);
    CloseHandle(hPack);

    if (iCid <= 0
        || IsValidEntity(iCid)==false
        || IsClientInGame(iCid)==false)
        return Plugin_Stop;

    //experimental, remove annoying double-playback
    new iVMid = GetEntDataEnt2(iCid,g_iViewModelO);
    SetEntDataFloat(iVMid, g_iVMStartTimeO, flStartTime_calc, true);

    return Plugin_Stop;
}

public OnW3TakeDmgAllPre(victim, attacker, Float:damage)
{
    new inflictor = W3GetDamageInflictor();
            
    if (((War3_IsL4DZombieEntity(victim)) || (ValidPlayer(victim) && GetClientTeam(victim) == TEAM_INFECTED)) && 
        ValidPlayer(attacker, true) && GetClientTeam(attacker) == TEAM_SURVIVORS && War3_GetRace(attacker) == thisRaceID)
    {
        if (attacker == inflictor)
        {
            new String:weapon[64];
            GetClientWeapon(attacker, weapon, sizeof(weapon));
            
            if (StrEqual(weapon, "weapon_pistol") || StrEqual(weapon, "weapon_pistol_magnum"))
            {
                new skill_uranium = War3_GetSkillLevel(attacker, thisRaceID, SKILL_URANIUM);
                if (skill_uranium > 0)
                {
                    War3_DamageModPercent(PistolDmgBuff[skill_uranium]);
                }
            }
        }
    }
}

public OnW3TakeDmgAll(victim,attacker,Float:damage)
{
    new inflictor = W3GetDamageInflictor();
            
    if (((War3_IsL4DZombieEntity(victim)) || (ValidPlayer(victim) && GetClientTeam(victim) == TEAM_INFECTED)) && 
        ValidPlayer(attacker, true) && GetClientTeam(attacker) == TEAM_SURVIVORS && War3_GetRace(attacker) == thisRaceID)
    {
        if (attacker == inflictor)
        {
            new String:weapon[64];
            GetClientWeapon(attacker, weapon, sizeof(weapon));
            
            if (StrEqual(weapon, "weapon_pistol") || StrEqual(weapon, "weapon_pistol_magnum"))
            {            
                new skill_fire = War3_GetSkillLevel(attacker, thisRaceID, SKILL_SPECIAL);
                if (skill_fire > 0)
                {
                    if( GetRandomFloat(0.0, 1.0) <= FireChance[skill_fire])
                    {
                        War3_DealDamage(victim, 1, attacker, 8, "firebullet");
                        
                        decl Float:fPos[3];
                        if (War3_IsL4DZombieEntity(victim))
                        {
                            GetEntPropVector(victim, Prop_Send, "m_vecOrigin", fPos);
                        }
                        else if (ValidPlayer(victim, true))
                        {
                            GetClientAbsOrigin(victim, fPos);
                        }
                        ThrowAwayParticle("impact_incendiary_fire", fPos, 1.0);
                    }
                }
            }
        }
    }
}

public OnUltimateCommand(client,race,bool:pressed)
{
    if(ValidPlayer(client, true) && 
       race == thisRaceID && 
       pressed && 
       War3_SkillNotInCooldown(client, thisRaceID, ULT_PISTOLERO, true) && 
       !Silenced(client) &&
       GetClientTeam(client) == TEAM_SURVIVORS &&
       !War3_L4D_IsHelpless(client) &&
       !War3_IsPlayerIncapped(client) &&
       g_bIsPistolero[client] == false)
    {    
        new skill = War3_GetSkillLevel(client, thisRaceID, ULT_PISTOLERO);
        if (skill > 0)
        {
            g_bIsPistolero[client] = true;
            War3_SetBuff(client, fMaxSpeed, thisRaceID, 1.25);
            W3Hint(client, HINT_LOWEST, 10.0, "GOGO, PISTOLERO!");
        
            CreateTimer(10.0, ResetUltimate, client);
            War3_CooldownMGR(client, ULT_COOLDOWN, thisRaceID, ULT_PISTOLERO);
        }
    }
}

public Action:ResetUltimate(Handle:timer, any:client)
{
    W3Hint(client, HINT_LOWEST, 1.0, "Joyride is over");
    DisableUltimate(client);
}

DisableUltimate(client)
{
    g_bIsPistolero[client] = false;
    War3_SetBuff(client, fMaxSpeed, thisRaceID, 1.0);
}

public OnWar3EventSpawn(client)
{    
    DisableUltimate(client);
}

public OnWar3EventDeath(victim, attacker)
{
    if(War3_GetRace(victim) == thisRaceID)
    {
        DisableUltimate(victim);
    }
}

public OnRaceChanged(client, oldrace, newrace)
{
    if(newrace != thisRaceID)
    {
        DisableUltimate(client);
    }
}

public OnSkillLevelChanged(client, race, skill, newskilllevel)
{
    if(skill == ULT_PISTOLERO && newskilllevel == 0)
    {    
        DisableUltimate(client);
    }
}