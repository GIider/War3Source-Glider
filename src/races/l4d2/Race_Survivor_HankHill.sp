#pragma semicolon 1    ///WE RECOMMEND THE SEMICOLON

#include <sdkhooks>
#include "W3SIncs/War3Source_Interface"


public Plugin:myinfo = 
{
    name = "War3Source Race - Hank Hill",
    author = "Glider",
    description = "The Hank Hill race for War3Source.",
    version = "1.0",
};

#define PROPANE_RANGE 150.0
#define MODEL_PROPANE "models/props_junk/propanecanister001a.mdl"

//=======================================================================
//                             VARIABLES
//=======================================================================

new thisRaceID;
new SKILL_SPAWN, SKILL_RAGE, SKILL_PROPANE;
new ULT_KABOOM;

new PropaneDamage[5] = {0, 1, 2, 3, 4};
new Float:SpawnChance[5] = {0.0, 0.625, 1.25, 1.875, 2.5};
new Float:RageChance[5] = {0.0, 10.0, 15.0, 20.0, 25.0};
new Float:UltCooldown = 60.0;
new bool:bIsRaging[MAXPLAYERS];

new Float:RageSpeedBuff = 1.25;
new Float:RageDamageBuff = 1.5;

#define KABOOM_RANGE 1000.0

// Tempents
new g_BeamSprite;
new g_HaloSprite;

new String:UltimateSnd[]="war3source/hankhill/ass.mp3";
new String:HankSnd[]="war3source/hankhill/imhank.mp3";
new String:SellSnd[]="war3source/hankhill/sell.mp3";

//=======================================================================
//                                 INIT
//=======================================================================

public OnWar3PluginReady(){
    thisRaceID = War3_CreateNewRace("Hank Hill", "hankhill");
    SKILL_SPAWN = War3_AddRaceSkill(thisRaceID, "Salesmanship", "Enables you to sell propane and propane accessoires at a chance of 0.625/1.25/1.875/2.5%.\nDouble the chance for special infected.", false, 4);
    SKILL_RAGE = War3_AddRaceSkill(thisRaceID, "I'm gonna kick your ass", "When you get hit there's a chance to go into rage mode, increasing your speed and damage. Chance is 10/15/20/25%", false, 4);
    SKILL_PROPANE = War3_AddRaceSkill(thisRaceID, "Strickland Propane", "Propane in range deals 1/2/3/4 points of damage per second.", false, 4);
    ULT_KABOOM = War3_AddRaceSkill(thisRaceID, "DANG IT BOBBEH!", "You blow up all propane in range CD: 60s", true, 1);
    
    War3_CreateRaceEnd(thisRaceID);
}

public OnPluginStart()
{
    if(War3_GetGame() != Game_L4D && War3_GetGame() != Game_L4D2)
        SetFailState("Only works in the L4D engine! %i", War3_GetGame());
    
    CreateTimer(1.0, PropaneTimer, _, TIMER_REPEAT);
}

public OnMapStart()
{    
    PrecacheModel(MODEL_PROPANE, true);
    
    War3_AddCustomSound(UltimateSnd);
    War3_AddCustomSound(HankSnd);
    War3_AddCustomSound(SellSnd);
    
    g_BeamSprite = PrecacheModel("materials/sprites/laserbeam.vmt");
    g_HaloSprite = PrecacheModel("materials/sprites/glow01.vmt");
}

//=======================================================================
//                                 Strickland Propane
//=======================================================================

public Action:PropaneTimer(Handle:timer, any:userid)
{
    for(new client=1; client <= MaxClients; client++)
    {
        if(ValidPlayer(client, true) && War3_GetRace(client) == thisRaceID)
        {
            new skill = War3_GetSkillLevel(client, thisRaceID, SKILL_PROPANE);
            if(skill > 0)
            { 
                new entity = -1;
                new damage = PropaneDamage[skill];
                
                new Float:SurvivorPos[3];
                new Float:EnemyPos[3];
                new Float:PropanePosition[3];
                
                GetClientAbsOrigin(client, SurvivorPos);    
                decl String:ModelName[128];
                
                while ((entity = FindEntityByClassname(entity, "prop_physics")) != INVALID_ENT_REFERENCE) 
                {
                    GetEntPropString(entity, Prop_Data, "m_ModelName", ModelName, sizeof(ModelName));
                    if (StrEqual(ModelName, MODEL_PROPANE))
                    {
                        GetEntPropVector(entity, Prop_Send, "m_vecOrigin", PropanePosition);
                        new Float:dis = GetVectorDistance(SurvivorPos, PropanePosition);
                        
                        if (dis <= KABOOM_RANGE)
                        {
                            // check special infected
                            for(new i=1; i <= MaxClients; i++)
                            {
                                if(ValidPlayer(i, true) && GetClientTeam(i) == TEAM_INFECTED)
                                {
                                    GetClientAbsOrigin(i, EnemyPos);
                                    
                                    if(GetVectorDistance(PropanePosition, EnemyPos) <= PROPANE_RANGE)
                                    {
                                        War3_DealDamage(i, damage, client, DMG_RADIATION, "propane");
                                    }
                                }
                            }
                            
                            // check common infected
                            new centity = -1;
                            while ((centity = FindEntityByClassname(centity, "infected")) != INVALID_ENT_REFERENCE) 
                            {
                                GetEntPropVector(centity, Prop_Send, "m_vecOrigin", EnemyPos);
                                
                                if(GetVectorDistance(PropanePosition, EnemyPos) <= PROPANE_RANGE)
                                {
                                    War3_DealDamage(centity, damage, client, DMG_RADIATION, "propane");
                                }
                            }
                            // check witch... harhar how evil :D
                            centity = -1;
                            while ((centity = FindEntityByClassname(centity, "witch")) != INVALID_ENT_REFERENCE) 
                            {
                                GetEntPropVector(centity, Prop_Send, "m_vecOrigin", EnemyPos);
                                
                                if(GetVectorDistance(PropanePosition, EnemyPos) <= PROPANE_RANGE)
                                {
                                    War3_DealDamage(centity, damage, client, DMG_RADIATION, "propane");
                                }
                            }
                            
                            PropanePosition[2] += 10.0;
                            TE_SetupBeamRingPoint(PropanePosition, 10.0, PROPANE_RANGE, g_BeamSprite, g_HaloSprite, 0, 60, 1.0, 3.0, 0.5, {255, 0, 0, 255}, 10, 0);
                            TE_SendToAll();
                        }
                    }
                }
            }
        }
    }
}

//=======================================================================
//                                 ULT: RAGE
//=======================================================================

public OnW3TakeDmgAllPre(victim, attacker, Float:damage)
{
    if(War3_SurvivorHittingZombie(victim, attacker))
    {
        if (bIsRaging[attacker] && !(ValidPlayer(victim, true) && GetClientTeam(victim) == TEAM_SURVIVORS))
        {
            War3_DamageModPercent(RageDamageBuff);
        }
    }
    
    if (damage >= 1.0 && ValidPlayer(victim, true) && War3_GetRace(victim) == thisRaceID && !bIsRaging[victim] && ((ValidPlayer(attacker) && GetClientTeam(attacker) == TEAM_INFECTED) || War3_IsL4DZombieEntity(attacker))) {
        new skill = War3_GetSkillLevel(victim, thisRaceID, SKILL_RAGE);
        if (GetRandomFloat(0.0, 100.0) <= RageChance[skill]) {
            bIsRaging[victim] = true;
            War3_SetBuff(victim, fMaxSpeed, thisRaceID, RageSpeedBuff);
            
            EmitSoundToAll(UltimateSnd, victim);
            CreateTimer(10.0, ResetUltimate, victim);
            PrintHintText(victim, "You started raging!");
        }
    }
}

public OnWar3EventDeath(victim, attacker)
{
    if(War3_GetRace(victim) == thisRaceID)
    {
        DisableRage(victim);
    }
    
    if( (ValidPlayer(attacker, true)) && (War3_GetRace(attacker) == thisRaceID))
    {
        new skill = War3_GetSkillLevel(attacker, thisRaceID, SKILL_SPAWN);
        if (skill > 0)
        {
            new Float:chance = SpawnChance[skill];
            if(!War3_IsCommonInfected(victim))
                chance *= 2.0;
            
            if (GetRandomFloat(0.0, 100.0) <= chance)
            {
                SpawnPropane(victim);
                EmitSoundToAll(SellSnd, attacker);
            }
        }
    }
}

public OnUltimateCommand(client,race,bool:pressed)
{
    if(ValidPlayer(client, true) && 
       race == thisRaceID && 
       pressed && 
       War3_SkillNotInCooldown(client, thisRaceID, ULT_KABOOM, true) && 
       !Silenced(client) &&
       GetClientTeam(client) == TEAM_SURVIVORS &&
       !War3_L4D_IsHelpless(client) &&
       !War3_IsPlayerIncapped(client) &&
       bIsRaging[client] == false)
    {    
        new skill = War3_GetSkillLevel(client, thisRaceID, ULT_KABOOM);
        if (skill > 0)
        {
            decl String:ModelName[128];
            new bool:bHasExploded = false;
            new entity = -1;
            new Float:CasterPosition[3];
            new Float:PropanePosition[3];
            GetClientEyePosition(client, CasterPosition);
            
            while ((entity = FindEntityByClassname(entity, "prop_physics")) != INVALID_ENT_REFERENCE) 
            {
                GetEntPropString(entity, Prop_Data, "m_ModelName", ModelName, sizeof(ModelName));
                if (StrEqual(ModelName, MODEL_PROPANE))
                {
                    GetEntPropVector(entity, Prop_Send, "m_vecOrigin", PropanePosition);
                    new Float:dis = GetVectorDistance(CasterPosition, PropanePosition);
                    
                    if (dis <= KABOOM_RANGE)
                    {
                        ExplodeThisEntity(client, entity);
                        bHasExploded = true;
                    }
                }
            }
            
            if (bHasExploded) {
                War3_CooldownMGR(client, UltCooldown, thisRaceID, ULT_KABOOM);
            }
            else {
                W3Hint(client, HINT_SKILL_STATUS, 1.0, "No propane in range!");
            }
        }
    }
}

public Action:ResetUltimate(Handle:timer, any:client)
{
    W3Hint(client, HINT_LOWEST, 1.0, "Your rage fades away");
    DisableRage(client);
}

DisableRage(client)
{
    bIsRaging[client] = false;
    War3_SetBuff(client, fMaxSpeed, thisRaceID, 1.0);
}

public OnWar3EventSpawn(client)
{    
    DisableRage(client);
}

public OnRaceChanged(client, oldrace, newrace)
{
    if(newrace != thisRaceID)
    {
        DisableRage(client);
    }
    if(newrace == thisRaceID)
    {
        EmitSoundToAll(HankSnd, client);
    }
}

public OnSkillLevelChanged(client, race, skill, newskilllevel)
{
    if(skill == SKILL_RAGE && newskilllevel == 0)
    {    
        DisableRage(client);
    }
}

//=======================================================================
//                             PROPANE SPAWNER SKILL
//=======================================================================

/**
 * Spawn a propane tank at the location of entity
 */
SpawnPropane(entity)
{
    new Float:f_Origin[3];
    
    if (War3_IsL4DZombieEntity(entity))
    {
        GetEntPropVector(entity, Prop_Send, "m_vecOrigin", f_Origin);
        f_Origin[2] += 25.0;
    }
    else if (ValidPlayer(entity))
        GetClientEyePosition(entity, f_Origin);
    else
        return;
    
    new i_Ent = CreateEntityByName("prop_physics");
    //DispatchKeyValue(i_Ent, "physdamagescale", "0.0");
    DispatchKeyValue(i_Ent, "model", MODEL_PROPANE);
    DispatchSpawn(i_Ent);
    TeleportEntity(i_Ent, f_Origin, NULL_VECTOR, NULL_VECTOR);
    SetEntityMoveType(i_Ent, MOVETYPE_VPHYSICS);
}

public ExplodeThisEntity(client, entity)
{
    new pointHurt = CreateEntityByName("point_hurt");
    if(IsValidEntity(pointHurt))
    {
        DispatchKeyValue(entity, "targetname", "war3_hurtme");
        DispatchKeyValue(pointHurt, "Damagetarget","war3_hurtme");
        DispatchKeyValue(pointHurt, "Damage", "10000");
        DispatchKeyValue(pointHurt, "DamageType", "1");
        DispatchKeyValue(pointHurt, "classname", "war3_point_hurt");
        DispatchSpawn(pointHurt);
        
        AcceptEntityInput(pointHurt, "Hurt", client);
        DispatchKeyValue(entity, "targetname", "war3_donthurtme");
        RemoveEdict(pointHurt);
        //PrintToChatAll("Exploded %f", GetEngineTime());
    }
}