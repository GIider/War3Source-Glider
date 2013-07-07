#pragma semicolon 1

#include "W3SIncs/War3Source_Interface"

public Plugin:myinfo = 
{
    name = "War3Source Race - L4D Survivor Medic",
    author = "Glider",
    description = "The Survivor Medic race for War3Source.",
    version = "1.0",
};

//=======================================================================
//                             VARIABLES
//=======================================================================

new thisRaceID;
new SKILL_LASTING_SUPPLYS, SKILL_HELPING_HAND, SKILL_AOE_REGEN;
new ULT_REVIVE;

new Float:DecayHPLimit[5]={0.0, 26.9, 51.9, 76.9, 99.9};
new Float:HelpingHandMulti[5] = {1.0, 0.8, 0.6, 0.4, 0.2};
new Float:ReviveRange = 100.0;
new Float:AoeRegenRange = 800.0;
new Float:HasntFiredForSecs[5]={0.0, 6.0, 5.0, 4.0, 3.0};
new Float:LastFiredTime[MAXPLAYERS];

new const AoERegenColor[4] = {0, 255, 0, 255};

new bool:CanRevive[MAXPLAYERS+1];
//new Float:DeathTime[MAXPLAYERS+1];
new Float:DeathPos[MAXPLAYERS+1][3];

new Handle:hRoundRespawn = INVALID_HANDLE;
new Handle:hGameConf = INVALID_HANDLE;

new Float:g_flReviveTime = -1.0;

// Tempents
new g_BeamSprite;
new g_HaloSprite;

//=======================================================================
//                                 INIT
//=======================================================================

public OnWar3PluginReady(){
    thisRaceID = War3_CreateNewRace("Medic", "medic");
    SKILL_LASTING_SUPPLYS = War3_AddRaceSkill(thisRaceID, "Lasting Supplys", "Temporary health below 25/50/75/100 HP is turned into permanent health", false, 4);
    SKILL_HELPING_HAND = War3_AddRaceSkill(thisRaceID, "Helping Hand", "You revive people 20/40/60/80% faster", false, 4);
    SKILL_AOE_REGEN = War3_AddRaceSkill(thisRaceID, "Regeneration Aura", "Stop shooting to heal people close to you.\nAfter 6/5/4/3 seconds the healing will start", false, 4);
    ULT_REVIVE = War3_AddRaceSkill(thisRaceID, "Revive", "You can revive a fallen comrade close to you without a defib.  CD: 360s", true, 1);
    
    War3_CreateRaceEnd(thisRaceID);
}

public OnPluginStart()
{
    if(War3_GetGame() != Game_L4D && War3_GetGame() != Game_L4D2)
        SetFailState("Only works in the L4D engine! %i", War3_GetGame());

    hGameConf = LoadGameConfigFile("l4d2addresses");
    if (hGameConf != INVALID_HANDLE)
    {
        StartPrepSDKCall(SDKCall_Player);
        PrepSDKCall_SetFromConf(hGameConf, SDKConf_Signature, "RoundRespawn");
        hRoundRespawn = EndPrepSDKCall();
        if (hRoundRespawn == INVALID_HANDLE) 
        {
            SetFailState("RoundRespawn Signature broken");
        }
      }
    
    //HookEvent("pills_used", PillsUsedEvent);
    //HookEvent("adrenaline_used", AdrenalineUsedEvent);
    HookEvent("revive_begin", Event_ReviveBeginPre, EventHookMode_Pre);
    HookEvent("weapon_fire", Event_Fire);
    g_flReviveTime        =    GetConVarFloat(FindConVar("survivor_revive_duration"));
    
    CreateTimer(0.1, TempHealthTimer, _, TIMER_REPEAT);
    CreateTimer(3.0, RegenTeamTimer, _, TIMER_REPEAT);
}

public OnMapStart()
{
    g_BeamSprite = PrecacheModel("materials/sprites/laserbeam.vmt");
    g_HaloSprite = PrecacheModel("materials/sprites/glow01.vmt");
    
    for(new client=1; client <= MaxClients; client++)
    {
        LastFiredTime[client] = GetGameTime();
    }
}

//=======================================================================
//                                 Lasting Supplys
//=======================================================================

public Action:TempHealthTimer(Handle:timer, any:userid)
{
    for(new client=1; client <= MaxClients; client++)
    {
        if(ValidPlayer(client, true))
        {
            if(War3_GetRace(client) == thisRaceID)
            {
                new skill = War3_GetSkillLevel(client, thisRaceID, SKILL_LASTING_SUPPLYS);
                if(skill > 0)
                { 
                    new Float:temphealth = GetSurvivorTempHealth(client);
                    new permanenthealth = GetClientHealth(client);
                    
                    if ((temphealth + permanenthealth) <= DecayHPLimit[skill]) {
                        SetEntPropFloat(client, Prop_Send, "m_healthBufferTime", GetGameTime()); // just reset that timer :)
                        
                        SetSurvivorTempHealth(client, 0.0);
                        SetEntityHealth(client, Min(RoundToCeil(temphealth + permanenthealth), 100));
                    }
                }
            }
        }
    }
}

Min(x, y)
{
    if (x > y)
        return y;
    
    return x;
}

//=======================================================================
//                                 Helping Hand
//=======================================================================

public Action:Event_ReviveBeginPre (Handle:event, const String:name[], bool:dontBroadcast)
{
    new client = GetClientOfUserId(GetEventInt(event,"userid"));

    if(ValidPlayer(client, true))
    {
        if(War3_GetRace(client) == thisRaceID)
        {
            new skill = War3_GetSkillLevel(client, thisRaceID, SKILL_HELPING_HAND);
            if(skill > 0)
            {
                SetConVarFloat(FindConVar("survivor_revive_duration"), g_flReviveTime * HelpingHandMulti[skill], false, false);
            }
            else
            {
                SetConVarFloat(FindConVar("survivor_revive_duration"), g_flReviveTime, false, false);
            }
        }
        else
        {
            SetConVarFloat(FindConVar("survivor_revive_duration"), g_flReviveTime, false, false);
        }
    }                
    return Plugin_Continue;
}

//=======================================================================
//                                 CPR
//=======================================================================

public OnWar3EventDeath(victim, attacker)
{
    if(ValidPlayer(victim) && GetClientTeam(victim) == TEAM_SURVIVORS)
    {
        GetClientAbsOrigin(victim, DeathPos[victim]);
        DeathPos[victim][2] += 10.0;
        
        CanRevive[victim] = true;
    }
}

public OnWar3EventSpawn(client)
{    
    CanRevive[client] = false;
}

public OnUltimateCommand(client, race, bool:pressed)
{
    if(ValidPlayer(client, true) && 
       race == thisRaceID && 
       pressed && 
       War3_SkillNotInCooldown(client, thisRaceID, ULT_REVIVE, true) && 
       !Silenced(client) &&
       GetClientTeam(client) == TEAM_SURVIVORS &&
       !War3_L4D_IsHelpless(client) &&
       !War3_IsPlayerIncapped(client))
    {
        new Float:pos[3];
        new Float:dis = 0.0;
        GetClientAbsOrigin(client, pos);
        
        for(new i=0; i < MAXPLAYERS; i++)
        {
            if (CanRevive[i])
            {
                dis = GetVectorDistance(pos, DeathPos[i]);
                
                if (dis <= ReviveRange)
                {
                    new iWeapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
                    SetEntProp(iWeapon, Prop_Send, "m_helpingHandState", 3);
                    
                    // The SDK call resets all your scores, so let's save and
                    // restore them after
                    
                    new m_checkpointMeleeKills = GetEntProp(i, Prop_Send, "m_checkpointMeleeKills");
                    new m_checkpointPZTankThrows = GetEntProp(i, Prop_Send, "m_checkpointPZTankThrows");
                    new m_missionBoomerBilesUsed = GetEntProp(i, Prop_Send, "m_missionBoomerBilesUsed");
                    new m_checkpointBoomerBilesUsed = GetEntProp(i, Prop_Send, "m_checkpointBoomerBilesUsed");
                    new m_checkpointReviveOtherCount = GetEntProp(i, Prop_Send, "m_checkpointReviveOtherCount");
                    new m_checkpointFirstAidShared = GetEntProp(i, Prop_Send, "m_checkpointFirstAidShared");
                    new m_checkpointPZJockeyDamage = GetEntProp(i, Prop_Send, "m_checkpointPZJockeyDamage");
                    new m_missionFirstAidShared = GetEntProp(i, Prop_Send, "m_missionFirstAidShared");
                    new m_checkpointPZChargerDamage = GetEntProp(i, Prop_Send, "m_checkpointPZChargerDamage");
                    new m_checkpointPZIncaps = GetEntProp(i, Prop_Send, "m_checkpointPZIncaps");
                    new m_checkpointDeaths = GetEntProp(i, Prop_Send, "m_checkpointDeaths");
                    new m_checkpointIncaps = GetEntProp(i, Prop_Send, "m_checkpointIncaps");
                    new m_checkpointPZSpitterDamage = GetEntProp(i, Prop_Send, "m_checkpointPZSpitterDamage");
                    new m_checkpointPZHunterDamage = GetEntProp(i, Prop_Send, "m_checkpointPZHunterDamage");
                    new m_missionMeleeKills = GetEntProp(i, Prop_Send, "m_missionMeleeKills");
                    new m_checkpointPZLongestSmokerGrab = GetEntProp(i, Prop_Send, "m_checkpointPZLongestSmokerGrab");
                    new m_checkpointPZTankPunches = GetEntProp(i, Prop_Send, "m_checkpointPZTankPunches");
                    new m_checkpointPZHung = GetEntProp(i, Prop_Send, "m_checkpointPZHung");
                    new m_missionDeaths = GetEntProp(i, Prop_Send, "m_missionDeaths");
                    new m_checkpointDamageTaken = GetEntProp(i, Prop_Send, "m_checkpointDamageTaken");
                    new m_missionDamageTaken = GetEntProp(i, Prop_Send, "m_missionDamageTaken");
                    new m_missionIncaps = GetEntProp(i, Prop_Send, "m_missionIncaps");
                    new m_checkpointPZPushes = GetEntProp(i, Prop_Send, "m_checkpointPZPushes");
                    new m_checkpointDefibrillatorsUsed = GetEntProp(i, Prop_Send, "m_checkpointDefibrillatorsUsed");
                    new m_checkpointPZTankDamage = GetEntProp(i, Prop_Send, "m_checkpointPZTankDamage");
                    new m_missionDefibrillatorsUsed = GetEntProp(i, Prop_Send, "m_missionDefibrillatorsUsed");
                    new m_checkpointPZPulled = GetEntProp(i, Prop_Send, "m_checkpointPZPulled");
                    new m_checkpointPZBoomerDamage = GetEntProp(i, Prop_Send, "m_checkpointPZBoomerDamage");
                    new m_checkpointPZVomited = GetEntProp(i, Prop_Send, "m_checkpointPZVomited");
                    new m_missionHeadshotAccuracy = GetEntProp(i, Prop_Send, "m_missionHeadshotAccuracy");
                    new m_checkpointPillsUsed = GetEntProp(i, Prop_Send, "m_checkpointPillsUsed");
                    new m_missionAdrenalinesUsed = GetEntProp(i, Prop_Send, "m_missionAdrenalinesUsed");
                    new m_checkpointAdrenalinesUsed = GetEntProp(i, Prop_Send, "m_checkpointAdrenalinesUsed");
                    new m_missionPipebombsUsed = GetEntProp(i, Prop_Send, "m_missionPipebombsUsed");
                    new m_checkpointPZSmokerDamage = GetEntProp(i, Prop_Send, "m_checkpointPZSmokerDamage");
                    new m_missionPillsUsed = GetEntProp(i, Prop_Send, "m_missionPillsUsed");
                    new m_missionAccuracy = GetEntProp(i, Prop_Send, "m_missionAccuracy");
                    new m_checkpointPipebombsUsed = GetEntProp(i, Prop_Send, "m_checkpointPipebombsUsed");
                    new m_checkpointDamageToTank = GetEntProp(i, Prop_Send, "m_checkpointDamageToTank");
                    new m_checkpointPZHighestDmgPounce = GetEntProp(i, Prop_Send, "m_checkpointPZHighestDmgPounce");
                    new m_checkpointHeadshots = GetEntProp(i, Prop_Send, "m_checkpointHeadshots");
                    new m_checkpointPZPounces = GetEntProp(i, Prop_Send, "m_checkpointPZPounces");
                    new m_checkpointPZLongestJockeyRide = GetEntProp(i, Prop_Send, "m_checkpointPZLongestJockeyRide");
                    new m_missionReviveOtherCount = GetEntProp(i, Prop_Send, "m_missionReviveOtherCount");
                    new m_checkpointDamageToWitch = GetEntProp(i, Prop_Send, "m_checkpointDamageToWitch");
                    new m_checkpointMolotovsUsed = GetEntProp(i, Prop_Send, "m_checkpointMolotovsUsed");
                    new m_checkpointPZNumChargeVictims = GetEntProp(i, Prop_Send, "m_checkpointPZNumChargeVictims");
                    new m_checkpointHeadshotAccuracy = GetEntProp(i, Prop_Send, "m_checkpointHeadshotAccuracy");
                    new m_checkpointPZBombed = GetEntProp(i, Prop_Send, "m_checkpointPZBombed");
                    new m_checkpointPZKills = GetEntProp(i, Prop_Send, "m_checkpointPZKills");
                    new m_missionMedkitsUsed = GetEntProp(i, Prop_Send, "m_missionMedkitsUsed");
                    new m_missionMolotovsUsed = GetEntProp(i, Prop_Send, "m_missionMolotovsUsed");
                    new m_checkpointMedkitsUsed = GetEntProp(i, Prop_Send, "m_checkpointMedkitsUsed");
                    new m_checkpointZombieKills = GetEntProp(i, Prop_Send, "m_checkpointZombieKills");
                    
                    // SDK Call
                    
                    Revive(i);
                    
                    new String:name[32];
                    GetClientName(client, name, sizeof(name));
                    
                    War3_ChatMessage(i, "You were revived by {lightgreen}%s{default}", name);
                    
                    // Restore the stats
                    
                    SetEntProp(i, Prop_Send, "m_checkpointZombieKills", m_checkpointZombieKills);
                    SetEntProp(i, Prop_Send, "m_checkpointMeleeKills", m_checkpointMeleeKills);
                    SetEntProp(i, Prop_Send, "m_checkpointPZTankThrows", m_checkpointPZTankThrows);
                    SetEntProp(i, Prop_Send, "m_missionBoomerBilesUsed", m_missionBoomerBilesUsed);
                    SetEntProp(i, Prop_Send, "m_checkpointBoomerBilesUsed", m_checkpointBoomerBilesUsed);
                    SetEntProp(i, Prop_Send, "m_checkpointReviveOtherCount", m_checkpointReviveOtherCount);
                    SetEntProp(i, Prop_Send, "m_checkpointFirstAidShared", m_checkpointFirstAidShared);
                    SetEntProp(i, Prop_Send, "m_checkpointPZJockeyDamage", m_checkpointPZJockeyDamage);
                    SetEntProp(i, Prop_Send, "m_missionFirstAidShared", m_missionFirstAidShared);
                    SetEntProp(i, Prop_Send, "m_checkpointPZChargerDamage", m_checkpointPZChargerDamage);
                    SetEntProp(i, Prop_Send, "m_checkpointPZIncaps", m_checkpointPZIncaps);
                    SetEntProp(i, Prop_Send, "m_checkpointDeaths", m_checkpointDeaths);
                    SetEntProp(i, Prop_Send, "m_checkpointIncaps", m_checkpointIncaps);
                    SetEntProp(i, Prop_Send, "m_checkpointPZSpitterDamage", m_checkpointPZSpitterDamage);
                    SetEntProp(i, Prop_Send, "m_checkpointPZHunterDamage", m_checkpointPZHunterDamage);
                    SetEntProp(i, Prop_Send, "m_missionMeleeKills", m_missionMeleeKills);
                    SetEntProp(i, Prop_Send, "m_checkpointPZLongestSmokerGrab", m_checkpointPZLongestSmokerGrab);
                    SetEntProp(i, Prop_Send, "m_checkpointPZTankPunches", m_checkpointPZTankPunches);
                    SetEntProp(i, Prop_Send, "m_checkpointPZHung", m_checkpointPZHung);
                    SetEntProp(i, Prop_Send, "m_missionDeaths", m_missionDeaths);
                    SetEntProp(i, Prop_Send, "m_checkpointDamageTaken", m_checkpointDamageTaken);
                    SetEntProp(i, Prop_Send, "m_missionDamageTaken", m_missionDamageTaken);
                    SetEntProp(i, Prop_Send, "m_missionIncaps", m_missionIncaps);
                    SetEntProp(i, Prop_Send, "m_checkpointPZPushes", m_checkpointPZPushes);
                    SetEntProp(i, Prop_Send, "m_checkpointDefibrillatorsUsed", m_checkpointDefibrillatorsUsed);
                    SetEntProp(i, Prop_Send, "m_checkpointPZTankDamage", m_checkpointPZTankDamage);
                    SetEntProp(i, Prop_Send, "m_missionDefibrillatorsUsed", m_missionDefibrillatorsUsed);
                    SetEntProp(i, Prop_Send, "m_checkpointPZPulled", m_checkpointPZPulled);
                    SetEntProp(i, Prop_Send, "m_checkpointPZBoomerDamage", m_checkpointPZBoomerDamage);
                    SetEntProp(i, Prop_Send, "m_checkpointPZVomited", m_checkpointPZVomited);
                    SetEntProp(i, Prop_Send, "m_missionHeadshotAccuracy", m_missionHeadshotAccuracy);
                    SetEntProp(i, Prop_Send, "m_checkpointPillsUsed", m_checkpointPillsUsed);
                    SetEntProp(i, Prop_Send, "m_missionAdrenalinesUsed", m_missionAdrenalinesUsed);
                    SetEntProp(i, Prop_Send, "m_checkpointAdrenalinesUsed", m_checkpointAdrenalinesUsed);
                    SetEntProp(i, Prop_Send, "m_missionPipebombsUsed", m_missionPipebombsUsed);
                    SetEntProp(i, Prop_Send, "m_checkpointPZSmokerDamage", m_checkpointPZSmokerDamage);
                    SetEntProp(i, Prop_Send, "m_missionPillsUsed", m_missionPillsUsed);
                    SetEntProp(i, Prop_Send, "m_missionAccuracy", m_missionAccuracy);
                    SetEntProp(i, Prop_Send, "m_checkpointPipebombsUsed", m_checkpointPipebombsUsed);
                    SetEntProp(i, Prop_Send, "m_checkpointDamageToTank", m_checkpointDamageToTank);
                    SetEntProp(i, Prop_Send, "m_checkpointPZHighestDmgPounce", m_checkpointPZHighestDmgPounce);
                    SetEntProp(i, Prop_Send, "m_checkpointHeadshots", m_checkpointHeadshots);
                    SetEntProp(i, Prop_Send, "m_checkpointPZPounces", m_checkpointPZPounces);
                    SetEntProp(i, Prop_Send, "m_checkpointPZLongestJockeyRide", m_checkpointPZLongestJockeyRide);
                    SetEntProp(i, Prop_Send, "m_missionReviveOtherCount", m_missionReviveOtherCount);
                    SetEntProp(i, Prop_Send, "m_checkpointDamageToWitch", m_checkpointDamageToWitch);
                    SetEntProp(i, Prop_Send, "m_checkpointMolotovsUsed", m_checkpointMolotovsUsed);
                    SetEntProp(i, Prop_Send, "m_checkpointPZNumChargeVictims", m_checkpointPZNumChargeVictims);
                    SetEntProp(i, Prop_Send, "m_checkpointHeadshotAccuracy", m_checkpointHeadshotAccuracy);
                    SetEntProp(i, Prop_Send, "m_checkpointPZBombed", m_checkpointPZBombed);
                    SetEntProp(i, Prop_Send, "m_checkpointPZKills", m_checkpointPZKills);
                    SetEntProp(i, Prop_Send, "m_missionMedkitsUsed", m_missionMedkitsUsed);
                    SetEntProp(i, Prop_Send, "m_missionMolotovsUsed", m_missionMolotovsUsed);
                    SetEntProp(i, Prop_Send, "m_checkpointMedkitsUsed", m_checkpointMedkitsUsed);
                    
                    new addxp = 300;
                    new String:reviveaward[64];
                    Format(reviveaward,sizeof(reviveaward),"%T","reviving a player",client);
                    
                    W3GiveXPGold(client, XPAwardByReviving, addxp, 0, reviveaward);
                    
                    War3_CooldownMGR(client, 360.0, thisRaceID, ULT_REVIVE);
                    break;
                }
            }
        }
    }
}

public Revive(dead)
{
    SDKCall(hRoundRespawn, dead);
    TeleportEntity(dead, DeathPos[dead], NULL_VECTOR, NULL_VECTOR);

    if(IsPlayerAlive(dead))
    {
        decl String:name[64];
        for(new i = 0; i < GetMaxEntities(); i++)
        {
            if(IsValidEntity(i))
            {
                GetEdictClassname(i, name, sizeof(name));
                if (StrEqual(name, "survivor_death_model", false) || StrEqual(name, "physics_prop_ragdoll", false))
                {
                    // I'm to lazy to remove the correct model, so just remove all
                    /*decl String:ModelName[128];
                    GetEntPropString(i, Prop_Data, "m_ModelName", ModelName, sizeof(ModelName));
                    
                    PrintToChatAll(ModelName);*/
                    
                    RemoveEdict(i);
                }
            }
        } 
        
        
        L4D_SetPlayerReviveCount(dead, 0);
        L4D_SetPlayerThirdStrikeState(dead, false);
            
        new temphpoffset = FindSendPropOffs("CTerrorPlayer", "m_healthBuffer");
        SetEntDataFloat(dead, temphpoffset, 30.0, true);
        SetEntityHealth(dead, 1);
        return true;
    }        
    return false;
}

//=======================================================================
//                                 REGENERATION AURA
//=======================================================================

public Event_Fire(Handle:event, const String:name[], bool:dontBroadcast)
{
    new client = GetClientOfUserId(GetEventInt(event, "userid"));
    
    if(ValidPlayer(client, true) && War3_GetRace(client) == thisRaceID)
    {
        LastFiredTime[client] = GetGameTime();
    }
}

public Action:RegenTeamTimer(Handle:timer, any:userid)
{
    for(new client=1; client <= MaxClients; client++)
    {
        if(ValidPlayer(client, true))
        {
            if(War3_GetRace(client) == thisRaceID)
            {
                new skill = War3_GetSkillLevel(client, thisRaceID, SKILL_AOE_REGEN);
                if(skill > 0 && !War3_L4D_IsHelpless(client) && !War3_IsPlayerIncapped(client) && LastFiredTime[client] + HasntFiredForSecs[skill] <= GetGameTime() )
                { 
                    new Float:TeammatePosition[3];
                    new Float:CasterPosition[3];
                    GetClientAbsOrigin(client, CasterPosition);

                    new Float:vec[3];
                    GetClientAbsOrigin(client, vec);
                    vec[2] += 10;
                    
                    TE_SetupBeamRingPoint(vec, 10.0, AoeRegenRange, g_BeamSprite, g_HaloSprite, 0, 60, 1.0, 3.0, 0.5, AoERegenColor, 10, 0);
                    TE_SendToAll();
                    
                    for(new teammate=1; teammate <= MaxClients; teammate++)
                    {
                        if(ValidPlayer(teammate, true) && GetClientTeam(teammate) == TEAM_SURVIVORS)
                        {
                            GetClientAbsOrigin(teammate, TeammatePosition);
                            new Float:dis = GetVectorDistance(CasterPosition, TeammatePosition);
                            if (dis < AoeRegenRange) 
                            {
                                new Float:temphealth = GetSurvivorTempHealth(teammate);
                                new permanenthealth = GetClientHealth(teammate);
                                
                                new real_health = RoundToCeil(temphealth) + permanenthealth;
                                
                                if (real_health < 100 && real_health + 2 <= 100)
                                {
                                    SetSurvivorTempHealth(teammate, temphealth + 2.0);
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}