#pragma semicolon 1

#include "W3SIncs/War3Source_Interface"
#include <sdkhooks>

public Plugin:myinfo = 
{
    name = "War3Source Race - L4D Zombie Boomer",
    author = "Glider",
    description = "The Zombie Boomer race for War3Source.",
    version = "1.0",
};

//=======================================================================
//                             VARIABLES
//=======================================================================

new thisRaceID;
new SKILL_BILE_FEET, SKILL_NECROMANCER, SKILL_HANDSHAKE, SKILL_NINJA_BOOMER,
    SKILL_HANDLE_WITH_CARE, ULT_BIG_BROTHER;

static Handle:sdkCallVomitOnPlayer =     INVALID_HANDLE;

new Float:SpeedIncrease[5]={1.0,1.06,1.12,1.18,1.23};
new Float:HealthIncrease[5]={1.0,1.25,1.5,1.75,2.0};
new Float:BileChance[5] = {0.0, 0.1, 0.2, 0.3, 0.4};
new Float:Invisibility[5] = {1.0, 0.95, 0.85, 0.75, 0.65};
new Float:HandleChance[5] = {0.02, 0.04, 0.06, 0.08};

//=======================================================================
//                                 INIT
//=======================================================================

public OnWar3PluginReady(){
    thisRaceID = War3_CreateNewRace("[ZOMBIE] Boomer", "boomer");
    SKILL_BILE_FEET = War3_AddRaceSkill(thisRaceID, "Bile Feet", "Increases speed by 6/12/18/23%", false, 4);
    SKILL_NINJA_BOOMER = War3_AddRaceSkill(thisRaceID, "Ninja Boomer", "Gives you 5/15/35/45% Transparency", false, 4);
    SKILL_NECROMANCER = War3_AddRaceSkill(thisRaceID, "Necromancy", "Increases zombie health by 25/50/75/100%", false, 4);
    SKILL_HANDSHAKE = War3_AddRaceSkill(thisRaceID, "Handshake", "10/20/30/40% chance to bile when you melee", false, 4);
    SKILL_HANDLE_WITH_CARE = War3_AddRaceSkill(thisRaceID, "Handle with care", "2/4/6/8% chance to explode upon death", false, 4);
    ULT_BIG_BROTHER = War3_AddRaceSkill(thisRaceID, "Big Brother", "10% chance when puking on somebody to call a tank.", true, 1);

    War3_CreateRaceEnd(thisRaceID);
}

public OnPluginStart()
{
    if(War3_GetGame() != Game_L4D && War3_GetGame() != Game_L4D2)
        SetFailState("Only works in the L4D engine! %i", War3_GetGame());
    
    HookEventEx("player_now_it", War3Source_PlayerBoomedEvent);
    PrepSDKCalls();
}

static PrepSDKCalls()
{
    new Handle:ConfigFile = LoadGameConfigFile("l4d2addresses");
    
    StartPrepSDKCall(SDKCall_Player);
    PrepSDKCall_SetFromConf(ConfigFile, SDKConf_Signature, "CTerrorPlayer_OnVomitedUpon");
    PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer);
    PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
    sdkCallVomitOnPlayer = EndPrepSDKCall();
    
    if (sdkCallVomitOnPlayer == INVALID_HANDLE)
    {
        SetFailState("Cant initialize OnVomitedUpon SDKCall");
        return;
    }

    CloseHandle(ConfigFile);
}

public War3Source_PlayerBoomedEvent(Handle:event,const String:name[],bool:dontBroadcast)
{
    new victim = GetClientOfUserId(GetEventInt(event, "userid"));
    new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
    
    new bool:by_boomer = GetEventBool(event, "by_boomer");
    
    if( by_boomer && ValidPlayer(victim) && ValidPlayer(attacker) )
    { 
        if( War3_GetRace(attacker) == thisRaceID && War3_SkillNotInCooldown(attacker, thisRaceID, ULT_BIG_BROTHER, true))
        { 
            if (GetAmountOfTanks() == 0) {
                new skill_brother = War3_GetSkillLevel(attacker, thisRaceID, ULT_BIG_BROTHER);
                if (skill_brother > 0 && GetRandomFloat(0.0, 1.0) <= 0.1)
                {
                    War3_ChatMessage(0, "A Boomer has called for his big brother...");
                    StripAndExecuteClientCommand(attacker, "z_spawn", "tank auto");
                    War3_CooldownMGR(attacker, 60.0, thisRaceID, ULT_BIG_BROTHER);
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

public OnWar3EventDeath(victim, attacker)
{
    if(ValidPlayer(victim) && (GetClientTeam(victim) == TEAM_INFECTED) && War3_GetRace(victim) == thisRaceID)
    { 
        new skill_care = War3_GetSkillLevel(victim, thisRaceID, SKILL_HANDLE_WITH_CARE);
        if (skill_care > 0 && GetRandomFloat(0.0, 1.0) <= HandleChance[skill_care])
        {
            new Float:VictimPosition[3];
            GetClientEyePosition(victim, VictimPosition);
                
            new entity = CreateEntityByName("prop_physics");
            if (IsValidEntity(entity))
            {
                DispatchKeyValue(entity, "model", MODEL_PROPANE);
                DispatchSpawn(entity);
                SetEntData(entity, GetEntSendPropOffs(entity, "m_CollisionGroup"), 1, 1, true);
                TeleportEntity(entity, VictimPosition, NULL_VECTOR, NULL_VECTOR);
                AcceptEntityInput(entity, "break");
            }

            War3_ChatMessage(0, "Killed a explosive Boomer!");
        }
        
    }
}

public OnWar3EventSpawn(client)
{    
    givePlayerBuffs(client);
}

// BILE FEET

givePlayerBuffs(client)
{
    if (ValidPlayer(client, true) && GetClientTeam(client) == TEAM_INFECTED)
    {
        if(War3_GetRace(client) == thisRaceID)
        {
            new skill_mspd = War3_GetSkillLevel(client, thisRaceID, SKILL_BILE_FEET);
            if (skill_mspd > 0)
            {
                War3_SetBuff(client, fMaxSpeed, thisRaceID, SpeedIncrease[skill_mspd]);
            }
            
            new skill_trans = War3_GetSkillLevel(client, thisRaceID, SKILL_NINJA_BOOMER);
            if (skill_trans > 0)
            {
                War3_SetBuff(client, fInvisibilitySkill, thisRaceID, Invisibility[skill_trans]);
            }
            
        }
    }
}

public OnRaceChanged(client, oldrace, newrace)
{
    if(newrace != thisRaceID)
    {
        War3_SetBuff(client, fMaxSpeed, thisRaceID, 1.0);
        War3_SetBuff(client, fInvisibilitySkill, thisRaceID, 1.0);
    }
    else
    {    
        givePlayerBuffs(client);
    }
}

public OnSkillLevelChanged(client, race, skill, newskilllevel)
{
    givePlayerBuffs(client);
}

// NECROMANCY 

public OnEntityCreated(entity, const String:classname[])
{
    if (StrEqual(classname, "infected"))
    {
        for(new i=1; i <= MaxClients; i++)
        {
            if(ValidPlayer(i, true) && GetClientTeam(i) == TEAM_INFECTED && War3_GetRace(i) == thisRaceID && !IsPlayerGhost(i))
            {
                new skill_necro = War3_GetSkillLevel(i, thisRaceID, SKILL_NECROMANCER);
                if (skill_necro > 0)
                {
                    new Handle:pack;
                    
                    CreateDataTimer(0.1, BuffCommonTimer, pack);
                    WritePackCell(pack, entity);
                    WritePackCell(pack, i);
                }
            }
        }
    }
}

public Action:BuffCommonTimer(Handle:timer, Handle:pack)
{
    new client, entity;
 
    ResetPack(pack);
    entity = ReadPackCell(pack);
    client = ReadPackCell(pack);
    
    new skill_necro = War3_GetSkillLevel(client, thisRaceID, SKILL_NECROMANCER);
    
    if (War3_IsCommonInfected(entity)) {
        new common_health = GetEntProp(entity, Prop_Data, "m_iHealth");
        
        if(common_health > 0) {                        
            new increased_common_health = RoundToCeil(common_health * HealthIncrease[skill_necro]);
            
            SetEntProp(entity, Prop_Data, "m_iHealth", increased_common_health);
        }
    }
}

// Handshake

public OnW3TakeDmgAllPre(victim,attacker,Float:damage){
    if(ValidPlayer(victim, true) && ValidPlayer(attacker, true))
    {
        if(War3_GetRace(attacker) == thisRaceID && GetClientTeam(victim) == TEAM_SURVIVORS)
        {
            new skill = War3_GetSkillLevel(attacker, thisRaceID, SKILL_HANDSHAKE);
            if (skill > 0 && GetRandomFloat(0.0, 1.0) <= BileChance[skill])
            {
                VomitPlayer(victim, attacker);
            }
        }
    }
}

VomitPlayer(target, sender)
{
    SDKCall(sdkCallVomitOnPlayer, target, sender, true);
}
