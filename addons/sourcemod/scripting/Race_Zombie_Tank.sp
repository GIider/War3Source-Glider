#pragma semicolon 1

#include "W3SIncs/War3Source_Interface"
#include <sdkhooks>

public Plugin:myinfo = 
{
    name = "War3Source Race - L4D Zombie Tank",
    author = "Glider",
    description = "The Zombie Tank race for War3Source.",
    version = "1.0",
};

//=======================================================================
//                             VARIABLES
//=======================================================================

#define MODEL_GASCAN    "models/props_junk/gascan001a.mdl"
#define MODEL_PROPANE    "models/props_junk/propanecanister001a.mdl"

new thisRaceID;
new SKILL_REGEN, SKILL_WIFE, SKILL_LIFE_FORCE, SKILL_SCIENCE;

new Float:HealthIncrease[5] = {0.0, 0.25, 0.5, 0.75, 1.0};
new Float:RegenAmount[5] = {0.0, 0.0025, 0.005, 0.0075, 0.01};
new Float:ScienceChance[5] = {0.0, 0.3, 0.4, 0.5, 0.6};
new Float:WifeChance[5] = {0.0, 0.1, 0.2, 0.3, 0.4};
new Float:g_fTimeToRegenerate[MAXPLAYERS];

new bool:bHasSpawnedWife[MAXPLAYERS];

new MAX_TANK_HEALTH = 4000;
new const Float:NO_REGEN_FOR_X_SECONDS = 5.0;

//=======================================================================
//                                 INIT
//=======================================================================

public OnWar3PluginReady(){
    thisRaceID = War3_CreateNewRace("[ZOMBIE] Tank", "tank");
    SKILL_REGEN = War3_AddRaceSkill(thisRaceID, "Regeneration", "Regenerates your health by 0.25/0.5/0.75/1% for each survivor that is not incapped or death each second.\nRegeneration is disabled while burning and divided by the amount of tanks.\nWhen you get hit regeneration is stopped for 5 seconds.", false, 4);
    SKILL_WIFE = War3_AddRaceSkill(thisRaceID, "Worried Wife", "10/20/30/40% chance to spawn a witch when you spawn. Has no effect on Survival", false, 4);
    SKILL_LIFE_FORCE = War3_AddRaceSkill(thisRaceID, "Life Force", "You have 25/50/75/100% more health. This amount is divided by the amount of tanks.", false, 4);
    SKILL_SCIENCE = War3_AddRaceSkill(thisRaceID, "Rock-it Science", "30/40/50/60% chance that a thrown rock will explode.", false, 4);
    
    War3_CreateRaceEnd(thisRaceID);
}

public OnPluginStart()
{
    if(War3_GetGame() != Game_L4D && War3_GetGame() != Game_L4D2)
        SetFailState("Only works in the L4D engine! %i", War3_GetGame());
    
    CreateTimer(1.0, RegenTimer, _, TIMER_REPEAT);
    
    // should prolly hook this >_>
    MAX_TANK_HEALTH = GetConVarInt(FindConVar("z_tank_health"));
}

public OnMapStart()
{
    PrecacheModel(MODEL_GASCAN, true);
    PrecacheModel(MODEL_PROPANE, true);
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
        W3ResetPlayerColor(client, thisRaceID);
    }
}

giveBuffs(client)
{
    if (ValidPlayer(client) && GetClientTeam(client) == TEAM_INFECTED && War3_GetRace(client) == thisRaceID)
    {
        g_fTimeToRegenerate[client] = GetGameTime();
        bHasSpawnedWife[client] = false;
            
        new skill_life = War3_GetSkillLevel(client, thisRaceID, SKILL_LIFE_FORCE);
        if(skill_life > 0)
        {
            SetEntityHealth(client, GetNewTankMaxHealth(client));
        }
        
        decl String:GameName[16];
        GetConVarString(FindConVar("mp_gamemode"), GameName, sizeof(GameName));
            
        if ( !StrEqual(GameName, "survival", false) )
        {
            new skill_wife = War3_GetSkillLevel(client, thisRaceID, SKILL_WIFE);
            if(skill_wife > 0)
            {
                if (GetRandomFloat(0.0, 1.0) <= WifeChance[skill_wife])
                {
                    War3_ChatMessage(0, "A tank's wife is joining him on the battlefield.");
                    StripAndExecuteClientCommand(client, "z_spawn", "witch auto");
                    bHasSpawnedWife[client] = true;
                }
            }
        }
    }
}

StripAndExecuteClientCommand(client, const String:command[], const String:arguments[]) {
    new flags = GetCommandFlags(command);
    SetCommandFlags(command, flags & ~FCVAR_CHEAT);
    FakeClientCommand(client, "%s %s", command, arguments);
    SetCommandFlags(command, flags);
}

public OnW3TakeDmgAllPre(victim,attacker,Float:damage){
    if(ValidPlayer(victim))
    {
        g_fTimeToRegenerate[victim] = GetGameTime() + NO_REGEN_FOR_X_SECONDS;
    }
}


GetNewTankMaxHealth(client)
{
    new skill = War3_GetSkillLevel(client, thisRaceID, SKILL_LIFE_FORCE);
    if(skill > 0 ) 
    {
        new Float:health_increase = 1.0 + (HealthIncrease[skill] / GetAmountOfTanks());
        return RoundFloat(MAX_TANK_HEALTH * health_increase);
    }
    
    return MAX_TANK_HEALTH;
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
                        SpecialRock(pos, 1);
                }
            }
        }
    }
}

SpecialRock(Float:pos[3], type)
{
    new entity = CreateEntityByName("prop_physics");
    if (IsValidEntity(entity))
    {
        pos[2] += 10.0;
        if (type == 0)
            DispatchKeyValue(entity, "model", MODEL_GASCAN);
        else
            DispatchKeyValue(entity, "model", MODEL_PROPANE);
        DispatchSpawn(entity);
        SetEntData(entity, GetEntSendPropOffs(entity, "m_CollisionGroup"), 1, 1, true);
        TeleportEntity(entity, pos, NULL_VECTOR, NULL_VECTOR);
        AcceptEntityInput(entity, "break");
    }
}

//=======================================================================
//                              Regeneration
//=======================================================================

public Action:RegenTimer(Handle:timer, any:userid)
{
    new alive_survivors;
    for(new client=1; client <= MaxClients; client++)
    {
        if(ValidPlayer(client, true) && GetClientTeam(client) == TEAM_SURVIVORS)
        {
            if (!War3_L4D_IsHelpless(client) && !War3_IsPlayerIncapped(client))
            {
                alive_survivors++;
            }
        }
    }
    
    for(new client=1; client <= MaxClients; client++)
    {
        if(ValidPlayer(client, true))
        {
            if(War3_GetRace(client) == thisRaceID)
            {
                new skill_regen = War3_GetSkillLevel(client, thisRaceID, SKILL_REGEN);
                new flags = GetEntityFlags(client);

                if(skill_regen > 0 && !(flags & FL_ONFIRE) && GetGameTime() >= g_fTimeToRegenerate[client])
                { 
                    new tank_max_health = GetNewTankMaxHealth(client);
                    new Float:regen_percentage = (RegenAmount[skill_regen] * alive_survivors) / GetAmountOfTanks();

                    new hp_regenerated = RoundToCeil(tank_max_health * regen_percentage);
                    new tank_health = GetClientHealth(client);
                    
                    new new_health = Min(tank_max_health, hp_regenerated + tank_health);

                    //PrintToChatAll("Old Health: %i. New Health: %i. Calculated Heal: %i", tank_health, new_health, hp_regenerated);
                    SetEntityHealth(client, new_health);
                    
                    if (new_health != tank_health) {
                        W3Hint(client, HINT_SKILL_STATUS, 1.0, "Regenerated %i health", new_health - tank_health);
                    }
                    
                    //War3_ChatMessage(0, "Tank regenerating");
                }
                else
                {
                    //War3_ChatMessage(0, "Tank not regenerating");
                }
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