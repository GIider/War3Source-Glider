#pragma semicolon 1

#include "W3SIncs/War3Source_Interface"
#include <sdkhooks>

public Plugin:myinfo = 
{
    name = "War3Source Race - L4D Zombie Blazing Tank",
    author = "Glider",
    description = "The Zombie Blazing Tank race for War3Source.",
    version = "1.0",
};

//=======================================================================
//                             VARIABLES
//=======================================================================

#define MODEL_GASCAN    "models/props_junk/gascan001a.mdl"

new thisRaceID;
new SKILL_REGEN, SKILL_SPEED, SKILL_SCIENCE;

new Float:fRegenModifier[5] = {0.0, 0.5, 1.0, 1.5, 2.0};
new Float:ScienceChance[5] = {0.0, 0.3, 0.4, 0.5, 0.6};
new Float:fSpeedModifier[5]={1.0, 1.1, 1.2, 1.3, 1.4};

new MAX_TANK_HEALTH = 4000;
new const Float:BLAZING_TANK_HP_MODIFIER = 0.5;

//=======================================================================
//                                 INIT
//=======================================================================

public OnWar3PluginReady(){
    thisRaceID = War3_CreateNewRace("[ZOMBIE] Blazing Tank", "blaztank");
    SKILL_REGEN = War3_AddRaceSkill(thisRaceID, "Regeneration", "You regenerate 5/10/15/20% of fire damage you take", false, 4);
    SKILL_SPEED = War3_AddRaceSkill(thisRaceID, "Blazing Saddles", "Run 10/20/30/40%% faster", false, 4);
    SKILL_SCIENCE = War3_AddRaceSkill(thisRaceID, "Rock-it Science", "30/40/50/60% chance that a thrown rock will burst into flames.", false, 4);
    
    War3_CreateRaceEnd(thisRaceID);
}

public OnPluginStart()
{
    if(War3_GetGame() != Game_L4D && War3_GetGame() != Game_L4D2)
        SetFailState("Only works in the L4D engine! %i", War3_GetGame());
    
    // should prolly hook this >_>
    MAX_TANK_HEALTH = RoundToCeil(GetConVarInt(FindConVar("z_tank_health")) * BLAZING_TANK_HP_MODIFIER);
    
    CreateTimer(0.1, KeepOnFireTimer, _, TIMER_REPEAT);
}

public OnMapStart()
{
    PrecacheModel(MODEL_GASCAN, true);
}

public Action:KeepOnFireTimer(Handle:timer, any:userid)
{
    for(new client=1; client <= MaxClients; client++)
    {
        if(ValidPlayer(client, true))
        {
            if(War3_GetRace(client) == thisRaceID)
            {
                War3_DealDamage(client, 1, client, 8, "blazingtank");
            }
        }
    }
}

//=======================================================================
//                              Life Force
//=======================================================================

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
        War3_SetBuff(client, fMaxSpeed, thisRaceID, 1.0);
    }
}

public OnSkillLevelChanged(client, race, skill, newskilllevel)
{
    if (ValidPlayer(client) && GetClientTeam(client) == TEAM_INFECTED && War3_GetRace(client) == thisRaceID)
    {
        if (skill == SKILL_SPEED)
        {
            War3_SetBuff(client, fMaxSpeed, thisRaceID, fSpeedModifier[newskilllevel]);
            //War3_ChatMessage(0, "Client now has a speed of %f", fSpeedModifier[newskilllevel]);
        }
    }
}

giveBuffs(client)
{
    if (ValidPlayer(client) && GetClientTeam(client) == TEAM_INFECTED && War3_GetRace(client) == thisRaceID)
    {
        SetEntityHealth(client, MAX_TANK_HEALTH);
            
        decl String:GameName[16];
        GetConVarString(FindConVar("mp_gamemode"), GameName, sizeof(GameName));
        
        new skill = War3_GetSkillLevel(client, thisRaceID, SKILL_SPEED);
        War3_SetBuff(client, fMaxSpeed, thisRaceID, fSpeedModifier[skill]);
        
        //War3_ChatMessage(0, "Client now has a speed of %f", fSpeedModifier[skill]);
        
        W3SetPlayerColor(client, thisRaceID, 255, 0, 0, _, GLOW_ULTIMATE);
        War3_DealDamage(client, 1, client, 8, "blazingtank");
    }
}

public OnW3TakeDmgAllPre(victim,attacker,Float:damage){
    if(ValidPlayer(victim, true) && War3_GetRace(victim) == thisRaceID && (W3GetDamageType() & DMG_BURN))
    {
        War3_DamageModPercent(0.0);
        
        new skill = War3_GetSkillLevel(victim, thisRaceID, SKILL_REGEN);
        if (skill > 0)
        {
            new hp_regenerated =  RoundToCeil(damage * fRegenModifier[skill]) + 10;
            new tank_health = GetClientHealth(victim);
            new new_health = Min(MAX_TANK_HEALTH, hp_regenerated + tank_health);
            
            if (new_health > tank_health ) {
                SetEntityHealth(victim, new_health);
                W3Hint(victim, HINT_SKILL_STATUS, 1.0, "Regenerated %i health", new_health - tank_health);
            }
        }
    }
}

Min(x, y)
{
    if (x < y)
        return x;
    
    return y;
}
//=======================================================================
//                              Rock-it Science
//=======================================================================

public OnEntityDestroyed(entity)
{
    if (IsValidEdict(entity))
    {
        decl String:className[64];
        GetEdictClassname(entity, className, sizeof(className));
        
        if (StrEqual(className, "tank_rock"))
        {
            new hOwnerEntity = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
                    
            if (ValidPlayer(hOwnerEntity) && War3_GetRace(hOwnerEntity) == thisRaceID)
            {
                new skill = War3_GetSkillLevel(hOwnerEntity, thisRaceID, SKILL_SCIENCE);
                if (skill > 0)
                {
                    decl Float:pos[3];
                    GetEntPropVector(entity, Prop_Send, "m_vecOrigin", pos);
                    
                    if (GetRandomFloat(0.0, 1.0) <= ScienceChance[skill])
                        SpecialRock(pos);
                }
            }
        }
    }
}

SpecialRock(Float:pos[3])
{
    new entity = CreateEntityByName("prop_physics");
    if (IsValidEntity(entity))
    {
        pos[2] += 10.0;
        DispatchKeyValue(entity, "model", MODEL_GASCAN);
        DispatchSpawn(entity);
        SetEntData(entity, GetEntSendPropOffs(entity, "m_CollisionGroup"), 1, 1, true);
        TeleportEntity(entity, pos, NULL_VECTOR, NULL_VECTOR);
        AcceptEntityInput(entity, "break");
    }
}