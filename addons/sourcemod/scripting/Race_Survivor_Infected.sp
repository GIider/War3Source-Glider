#pragma semicolon 1

#include "W3SIncs/War3Source_Interface"
#include <sdkhooks>

public Plugin:myinfo = 
{
    name = "War3Source Race - L4D Survivor Infected race",
    author = "Glider",
    description = "As usual... a race",
    version = "1.0",
};

//=======================================================================
//                             VARIABLES
//=======================================================================

#define SOUND_VOMIT        "player/boomer/vomit/attack/bv1.wav"
#define PARTICLE_VOMIT        "boomer_vomit"

static Handle:sdkCallVomitOnPlayer =     INVALID_HANDLE;
static Handle:sdkCallBileJarPlayer =     INVALID_HANDLE;
static Handle:sdkCallBileJarInfected =     INVALID_HANDLE;

new thisRaceID;
new SKILL_POISONOUS_BLOOD, SKILL_RADIATION, SKILL_CLIMB, ULT_PUKE;

new Float:ToxicRegen[5] = {0.0, 0.45, 0.5, 0.55, 0.6};
new g_iRadiationLight[MAXPLAYERS]; // Ent Index for your radiation light
new Handle:AttackTracerTimer[MAXPLAYERS] = INVALID_HANDLE;

new RadiationDamage[5] = {0, 4, 6, 8, 10};
static Float:RadiationRange = 150.0;
static Float:UltCooldown = 45.0;
static Float:VomitRange = 180.0;

new Float:ClimbSpeedSkill[5] = {0.0, 40.0, 50.0, 60.0, 70.0};

#define Pai 3.14159265358979323846 
#define State_None 0
#define State_Climb 1
#define State_OnAir 2

#define ZOMBIECLASS_SURVIVOR    9

#define JumpSpeed 300.0 
#define gbodywidth 20.0 
#define bodylength 70.0

new Colon[MAXPLAYERS];
new bool:FirstRun[MAXPLAYERS];
new Float:BodyNormal[MAXPLAYERS][3];
new Float:Angle[MAXPLAYERS];
new State[MAXPLAYERS];
new Float:BodyPos[MAXPLAYERS][3];
new Float:LastPos[MAXPLAYERS][3];
new Float:SafePos[MAXPLAYERS][3];
new Float:BodyWidth[MAXPLAYERS];
new Float:JumpTime[MAXPLAYERS];
new Float:LastTime[MAXPLAYERS];
new Float:Intervual[MAXPLAYERS];
new Float:ClimbSpeed[MAXPLAYERS];
new Float:PlayBackRate[MAXPLAYERS];
new Float:StuckIndicator[MAXPLAYERS]; 

//=======================================================================
//                                 INIT
//=======================================================================

public OnWar3PluginReady(){
    thisRaceID = War3_CreateNewRace("Infected Survivor", "infsurv");
    SKILL_POISONOUS_BLOOD = War3_AddRaceSkill(thisRaceID, "Poisonous Blood", "Standing in spitter acid slowly gives temp health.\n0.45/0.5/0.55/0.6 HP per hit", false, 4);
    SKILL_RADIATION = War3_AddRaceSkill(thisRaceID, "Radiation", "You are highly contaminated... Infected take damage just by being around you!\n4/6/8/10 damage per second in a range of 150 units.", false, 4);
    SKILL_CLIMB = War3_AddRaceSkill(thisRaceID, "Climb (+use)", "Press +use on a wall to begin climbing on it with a speed of 40/50/60/70", false, 4);
    ULT_PUKE = War3_AddRaceSkill(thisRaceID, "Puke (Ultimate)", "Puke on your enemys. CD: 45s", true, 1);
    War3_CreateRaceEnd(thisRaceID);
} 

public OnPluginStart()
{
    if(War3_GetGame() != Game_L4D && War3_GetGame() != Game_L4D2)
        SetFailState("Only works in the L4D engine! %i", War3_GetGame());
    
    CreateTimer(1.0, RadiationTimer, _, TIMER_REPEAT);
    
    PrepSDKCalls();
    
    HookEvent("player_bot_replace", player_bot_replace );     
    HookEvent("player_jump", player_jump);
    HookEvent("jockey_ride", EventStopVictim);
    HookEvent("charger_carry_start", EventStopVictim);
    HookEvent("tongue_grab",  EventStopVictim);
    HookEvent("lunge_pounce", EventStopVictim);
    
    HookEvent("round_start", EventRoundEnd);
    HookEvent("round_end", EventRoundEnd);
    HookEvent("finale_win", EventRoundEnd);
    HookEvent("mission_lost", EventRoundEnd);
    HookEvent("map_transition", EventRoundEnd);    
    
    HookEvent("revive_begin", EventStopUserid);
    HookEvent("player_ledge_grab",  EventStopUserid);
    HookEvent("player_incapacitated_start", EventStopUserid);
    
    ResetAllState();
}

public OnMapStart()
{
    War3_PrecacheParticle(PARTICLE_VOMIT);
    War3_AddCustomSound(SOUND_VOMIT);
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

    StartPrepSDKCall(SDKCall_Player);
    PrepSDKCall_SetFromConf(ConfigFile, SDKConf_Signature, "CTerrorPlayer_OnHitByVomitJar");
    PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
    sdkCallBileJarPlayer = EndPrepSDKCall();
    
    if (sdkCallBileJarPlayer == INVALID_HANDLE)
    {
        SetFailState("Cant initialize CTerrorPlayer_OnHitByVomitJar SDKCall");
        return;
    }
    
    StartPrepSDKCall(SDKCall_Entity);
    PrepSDKCall_SetFromConf(ConfigFile, SDKConf_Signature, "Infected_OnHitByVomitJar");
    PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
    sdkCallBileJarInfected = EndPrepSDKCall();
    
    if (sdkCallBileJarInfected == INVALID_HANDLE)
    {
        SetFailState("Cant initialize Infected_OnHitByVomitJar SDKCall");
        return;
    }
    
    CloseHandle(ConfigFile);
}

//=======================================================================
//                             RADIATION
//=======================================================================

public Action:RadiationTimer(Handle:timer, any:userid)
{
    for(new client=1; client <= MaxClients; client++)
    {
        if(ValidPlayer(client, true) && War3_GetRace(client) == thisRaceID)
        {
            new skill = War3_GetSkillLevel(client, thisRaceID, SKILL_RADIATION);
            if(skill > 0)
            { 
                new Float:SurvivorPos[3];
                new Float:EnemyPos[3];
                new damage = RadiationDamage[skill];
                
                GetClientAbsOrigin(client, SurvivorPos);
    
                // check special infected
                for(new i=1; i <= MaxClients; i++)
                {
                    if(ValidPlayer(i, true) && GetClientTeam(i) == TEAM_INFECTED)
                    {
                        GetClientAbsOrigin(i, EnemyPos);
                        
                        if(GetVectorDistance(SurvivorPos, EnemyPos) <= RadiationRange)
                        {
                            War3_DealDamage(i, damage, client, DMG_RADIATION, "radiation");
                        }
                    }
                }
                
                // check common infected
                new entity = -1;
                while ((entity = FindEntityByClassname(entity, "infected")) != INVALID_ENT_REFERENCE) 
                {
                    GetEntPropVector(entity, Prop_Send, "m_vecOrigin", EnemyPos);
                    
                    if(GetVectorDistance(SurvivorPos, EnemyPos) <= RadiationRange)
                    {
                        //new ragdoll = GetEntProp(entity, Prop_Send, "m_bClientSideRagdoll");
                        //if (ragdoll != 1)
                        //{
                        War3_DealDamage(entity, damage, client, DMG_RADIATION, "radiation");
                        //}
                    }
                }
                // check witch... harhar how evil :D
                entity = -1;
                while ((entity = FindEntityByClassname(entity, "witch")) != INVALID_ENT_REFERENCE) 
                {
                    GetEntPropVector(entity, Prop_Send, "m_vecOrigin", EnemyPos);
                    
                    if(GetVectorDistance(SurvivorPos, EnemyPos) <= RadiationRange)
                    {
                        War3_DealDamage(entity, damage, client, DMG_RADIATION, "radiation");
                    }
                }
            }
        }
    }
}

//=======================================================================
//                             POISONOUS BLOOD
//=======================================================================

public OnW3TakeDmgAllPre(victim,attacker,Float:damage){
    if(ValidPlayer(victim, true))
    {
        if(War3_GetRace(victim) == thisRaceID)
        {
            new skill = War3_GetSkillLevel(victim, thisRaceID, SKILL_POISONOUS_BLOOD);
            if (skill > 0)
            {
                if (W3GetDamageType() & DMG_RADIATION)
                {
                    War3_DamageModPercent(0.0);
                    
                    new Float:temphealth = GetSurvivorTempHealth(victim);
                    new permanenthealth = GetClientHealth(victim);

                    if (temphealth + permanenthealth < 100)
                    {
                        new Float:HealthToAdd = ToxicRegen[skill];
                        new Float:NewTempHealth = temphealth + HealthToAdd;
                        if ((permanenthealth + NewTempHealth) <= 100)
                        {
                            SetSurvivorTempHealth(victim, NewTempHealth);
                        }
                    }
                }
            }
        }
    }
}

checkLightEffect(client)
{
    if(ValidPlayer(client, true) && War3_GetRace(client) == thisRaceID && GetClientTeam(client) == TEAM_SURVIVORS)
    {
        new skill = War3_GetSkillLevel(client, thisRaceID, SKILL_RADIATION);
        if (skill > 0 )
        {
            decl String:className[64];
            if(IsValidEdict(g_iRadiationLight[client]))
                GetEdictClassname(g_iRadiationLight[client], className, sizeof(className));
            
            if(!StrEqual(className, "light_dynamic"))
            {
                g_iRadiationLight[client] = AttachLight(client, NULL_VECTOR, "0 255 0 255", "5", 80.0, "eyes");
                
                SetVariantString("OnUser1 !self:Distance:120:0.1:-1");
                AcceptEntityInput(g_iRadiationLight[client], "AddOutput");
                AcceptEntityInput(g_iRadiationLight[client], "FireUser1");
            }
        }
        else 
        {
            KillLightEntity(client);
        }
    }
    else 
    {
        KillLightEntity(client);
    }
}

public OnWar3EventSpawn(client)
{
    if(ValidPlayer(client, true))
    {
        checkLightEffect(client);
        Stop(client);
    }
}

public OnWar3EventDeath(victim, attacker)
{
    if(ValidPlayer(victim))
    {
        if(War3_GetRace(victim) == thisRaceID)
            KillLightEntity(victim);

        Stop(victim);
    }
}

public OnRaceChanged(client, oldrace, newrace)
{
    if(newrace != thisRaceID)
    {
        KillLightEntity(client);
        Stop(client);
    }
    else
    {
        checkLightEffect(client);
    }
}

public OnSkillLevelChanged(client, race, skill, newskilllevel)
{
    checkLightEffect(client);
    if(skill == SKILL_CLIMB && newskilllevel == 0)
        Stop(client);
}

KillLightEntity(client)
{
    decl String:className[64];
    if(IsValidEdict(g_iRadiationLight[client]))
    {
        GetEdictClassname(g_iRadiationLight[client], className, sizeof(className));
    
        if(StrEqual(className, "light_dynamic"))
        {
            AcceptEntityInput(g_iRadiationLight[client], "kill");
        }
    }
}

//=======================================================================
//                             PUKE
//=======================================================================

public OnUltimateCommand(client,race,bool:pressed)
{
    if(ValidPlayer(client, true) && 
       race == thisRaceID && 
       pressed && 
       War3_SkillNotInCooldown(client, thisRaceID, ULT_PUKE, true) && 
       !Silenced(client) &&
       GetClientTeam(client) == TEAM_SURVIVORS &&
       !War3_L4D_IsHelpless(client) &&
       !War3_IsPlayerIncapped(client))
    {    
        new skill = War3_GetSkillLevel(client, thisRaceID, ULT_PUKE);
        if (skill > 0)
        {
            decl Float:z[3];
            GetClientEyePosition(client,z);
            z[2] = z[2]-2;
            
            AttachThrowAwayParticle(client, PARTICLE_VOMIT, NULL_VECTOR, "eyes", 5.0);
            EmitSoundToAll(SOUND_VOMIT, 0, SNDCHAN_WEAPON, SNDLEVEL_TRAFFIC, SND_NOFLAGS, SNDVOL_NORMAL, 100, _, z, NULL_VECTOR, false, 0.0);

            if (AttackTracerTimer[client] == INVALID_HANDLE)
            {
                AttackTracerTimer[client] = CreateTimer(0.1, TraceAttackTimer, client, TIMER_REPEAT);
            }
            else
            {
                CloseHandle(AttackTracerTimer[client]);
                AttackTracerTimer[client] = INVALID_HANDLE;
                AttackTracerTimer[client] = CreateTimer(0.1, TraceAttackTimer, client, TIMER_REPEAT);
            }

            CreateTimer(3.5, StopTimer, client);
            War3_CooldownMGR(client, UltCooldown, thisRaceID, ULT_PUKE);
        }
    }
}

public Action:TraceAttackTimer(Handle:timer, any:client)
{
    if (ValidPlayer(client, true)) {
        TraceAttack(client, true);
    }
}
public Action:StopTimer(Handle:timer, any:client)
{
    if (AttackTracerTimer[client] != INVALID_HANDLE)
    {
        CloseHandle(AttackTracerTimer[client]);
        AttackTracerTimer[client] = INVALID_HANDLE;
    }
}

//////////////////////////

TraceAttack(client, bool:bHullTrace)
{
    decl Float:vPos[3], Float:vAng[3], Float:vEnd[3];

    GetClientEyePosition(client, vPos);
    GetClientEyeAngles(client, vAng);

    new Handle:trace = TR_TraceRayFilterEx(vPos, vAng, MASK_SHOT, RayType_Infinite, ExcludeSelf_Filter, client);
    if( TR_DidHit(trace) )
    {
        TR_GetEndPosition(vEnd, trace);
    }
    else
    {
        CloseHandle(trace);
        return;
    }

    if( bHullTrace )
    {
        CloseHandle(trace);
        decl Float:vMins[3], Float:vMaxs[3];
        vMins = Float: { -15.0, -15.0, -15.0 };
        vMaxs = Float: { 15.0, 15.0, 15.0 };
        trace = TR_TraceHullFilterEx(vPos, vEnd, vMins, vMaxs, MASK_SHOT, ExcludeSelf_Filter, client);
        
        if( !TR_DidHit(trace) )
        {
            CloseHandle(trace);
            return;
        }
    }

    TR_GetEndPosition(vEnd, trace);
    if( GetVectorDistance(vPos, vEnd) > VomitRange )
    {
        CloseHandle(trace);
        return;
    }

    new entity = TR_GetEntityIndex(trace);
    CloseHandle(trace);

    if( ValidPlayer(entity, true) && GetClientTeam(entity) == TEAM_INFECTED )
    {
        VomitPlayer(entity, client);
    }
    else
    {
    
        if (War3_IsL4DZombieEntity(entity))
        {
            VomitEntity(entity, client);
        }
    }
}


public bool:ExcludeSelf_Filter(entity, contentsMask, any:client)
{
    // ignore player aswell as biled entitys
    if( entity == client || (GetEntProp(entity, Prop_Send, "m_glowColorOverride") == -4713783))
    {
        return false;
    }
    
    return true;
}

VomitPlayer(target, sender)
{
    if (!IsPlayerGhost(target))
    {
        SDKCall(sdkCallBileJarPlayer, target, sender, true);
    }
}

VomitEntity(entity, sender)
{
    SDKCall(sdkCallBileJarInfected, entity, sender, true);
}

//=======================================================================
//                          CLIMB CLIMB CLIMB
//=======================================================================

public OnPostThinkPost(client)
{
    if(ValidPlayer(client, true) && State[client] == State_Climb)
        SetEntProp(client, Prop_Send, "m_iAddonBits", 0);
}

public Action:EventRoundEnd(Handle:event, const String:name[], bool:dontBroadcast)
{
    ResetAllState();
}

ResetAllState()
{
    for(new i=1; i<=MaxClients; i++)
    {
        Stop(i);
    }
}

public EventStopVictim(Handle:event, const String:name[], bool:dontBroadcast)
{
    new victim = GetClientOfUserId(GetEventInt(event, "victim"));
    Interrupt(victim);
}

public EventStopUserid(Handle:event, const String:name[], bool:dontBroadcast)
{
    new victim = GetClientOfUserId(GetEventInt(event, "userid")); 
    Interrupt(victim);
}

public player_bot_replace(Handle:Spawn_Event, const String:Spawn_Name[], bool:Spawn_Broadcast)
{
    new client = GetClientOfUserId(GetEventInt(Spawn_Event, "player"));
    new bot = GetClientOfUserId(GetEventInt(Spawn_Event, "bot"));
    Stop(client);
    Stop(bot); 
}

public Action:player_jump(Handle:hEvent, const String:name[], bool:dontBroadcast)
{
    new client = GetClientOfUserId(GetEventInt(hEvent, "userid"));
    
    if(!CanUse(client))
        return;
    
    SDKUnhook(client, SDKHook_PreThink, PreThink);
    SDKUnhook(client, SDKHook_SetTransmit, OnSetTransmitClient);
    
    State[client] = State_OnAir;
    SDKHook(client, SDKHook_PreThink, PreThink); // watch it.
    
    decl Float:pos[3];
    GetClientAbsOrigin(client, pos);
    CopyVector(pos, SafePos[client]); // keep the original pos around in case the client gets stuck
    
    LastTime[client] = GetEngineTime();
    JumpTime[client] = LastTime[client];
    
    return;
}

/*
* if a player can use climb 
*/
bool:CanUse(client)
{
    if(ValidPlayer(client, true) && !IsFakeClient(client))
    {
        if(War3_GetRace(client) == thisRaceID)
        {
            new skill= War3_GetSkillLevel(client, thisRaceID, SKILL_CLIMB);
            return skill >= 0;
        }
    }
    
    return false;
}
/* 
* interrupt a player's climb
*/
Interrupt(client)
{
    if(State[client] == State_Climb) //if it 's climbing , force it jump and stop climb.
    {
        Jump(client, false, 50.0);
        Stop(client);
    }
    else if(State[client] == State_OnAir) //not climbing but on air, stop it.
    {
        Stop(client);
    }
    
}
/* 
* stop a player from climb mode
*/
Stop(client)
{
    if(State[client] == State_None) return;
    if(Colon[client] > 0 && IsValidEdict(Colon[client]) && IsValidEntity(Colon[client]) )  // remove dummy body
    {
        AcceptEntityInput(Colon[client], "kill");
        Colon[client] = 0;
        
        if(ValidPlayer(client, true))
        {
            GotoFirstPerson(client); 
            VisiblePlayer(client, true);
            SetEntityMoveType(client, MOVETYPE_WALK);
        }
    }
    
    State[client] = State_None;
    SDKUnhook(client, SDKHook_PreThink, PreThink); //stop watching it
    SDKUnhook(client, SDKHook_SetTransmit, OnSetTransmitClient);  //other people can see it's real body.
    SDKUnhook(client, SDKHook_PostThinkPost, OnPostThinkPost);
}
/* 
* get into climb mode
*/
Start(client)
{
    decl Float:vAngles[3];
    decl Float:vOrigin[3];
    decl Float:hit[3];
    decl Float:normal[3];
    decl Float:up[3];
    GetClientEyePosition(client,vOrigin);
    GetClientEyeAngles(client, vAngles);     
     
    GetRay(client,  vOrigin  ,  vAngles , hit, normal,0.0-gbodywidth); 
    if(GetVectorDistance(hit, vOrigin)<gbodywidth*2.0)   //calc distince between body and surfece, if it is close enough, then get into climb mode.
    {
        SetVector(up, 0.0, 0.0, 1.0);
        new Float:f=GetAngle(normal, up)*180/Pai;
        if(f<10.0 || f>170.0) //the surfece is horizontal, can not climb
        {
            return;
        }
        //code below get into climb mode
        
        CopyVector(normal,BodyNormal[client]); 
        CopyVector(hit, BodyPos[client]);
     
        Angle[client]=0.0;
        CopyVector(normal ,BodyNormal[3]);
     
        new c=CreateColon(client);  //create dummy body
        Colon[client]=c; 
        SetEntityMoveType(client, MOVETYPE_NONE); 
        GotoThirdPerson(client); 
        VisiblePlayer(client, false);
        SDKUnhook(client, SDKHook_SetTransmit, OnSetTransmitClient);
        SDKHook(client, SDKHook_SetTransmit, OnSetTransmitClient); //other player can not see it's real body

        SDKUnhook(client, SDKHook_PreThink, PreThink); 
        SDKHook(client, SDKHook_PreThink, PreThink);  // watch it.
        
        SDKUnhook(client, SDKHook_PostThinkPost, OnPostThinkPost);
        SDKHook(client, SDKHook_PostThinkPost, OnPostThinkPost);
        State[client]=State_Climb;
        FirstRun[client]=true;
        
        new Float:velocity[3] = {0.0, 0.0, 0.0};
        TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, velocity);
    }
}

/* 
* jump from climb mode  
*/
Jump(client, bool:check=true, Float:speed=JumpSpeed)
{
    new Float:time=GetEngineTime(); 
    if(check)
    {
        if(time-JumpTime[client] < 0.5)
        {
            W3Hint(client, HINT_SKILL_STATUS, 1.0, "Can't jump off this quickly!");
            return;
        }
    }
     if(Colon[client] > 0) //remove dummy body
    {
        AcceptEntityInput(Colon[client], "kill");
        Colon[client] = 0;
    }
    SDKUnhook(client, SDKHook_SetTransmit, OnSetTransmitClient);
    if(!ValidPlayer(client, true)) 
        return;
    
    GotoFirstPerson(client);
    VisiblePlayer(client, true);
    SetEntityMoveType(client, MOVETYPE_WALK);  
    decl Float:vAngles[3];
    decl Float:vOrigin[3];
    decl Float:vec[3];
    decl Float:pos[3];
    GetClientEyePosition(client,vOrigin);
    CopyVector(BodyNormal[client], vec);
    NormalizeVector(vec, vec);
    ScaleVector(vec, BodyWidth[client]);
    AddVectors(vOrigin, vec, pos);
    
    GetClientEyeAngles(client, vAngles);
    GetAngleVectors(vAngles, vec, NULL_VECTOR,NULL_VECTOR);
    NormalizeVector(vec, vec);
    ScaleVector(vec, speed);
    TeleportEntity(client, pos, NULL_VECTOR, vec); // jump into her's look direction
    CopyVector(pos, LastPos[client]);
    JumpTime[client]=time;
    StuckIndicator[client]=0.0;
    State[client]=State_OnAir;                   //state switch to onair
}
public Action:OnSetTransmitClient (climber, client)
{
    if(climber != client)
    {
        new teamClimber=GetClientTeam(climber);
        new teamClient=GetClientTeam(client);
        if(teamClimber==TEAM_INFECTED && teamClient== TEAM_SURVIVORS)
            return Plugin_Handled; 
        return Plugin_Handled; 
    }
    else return Plugin_Continue;
}
public PreThink(client)
{
    if(ValidPlayer(client, true))
    {
        new Float:time=GetEngineTime( );
        new Float:intervual=time-LastTime[client]; 
        Intervual[client]=intervual;
        if(State[client]==State_OnAir)OnAir(client); // player is on air 
        else if(State[client]==State_Climb)Climb(client, intervual); // player is climbing
        LastTime[client]=time;
    }
    else
    {
        Stop(client);
    }

}
/* 
* when a play is jump into air  
*/
OnAir(client)
{
    if(ValidPlayer(client, true) && War3_GetRace(client) == thisRaceID && War3_GetSkillLevel(client, thisRaceID, SKILL_CLIMB) > 0)
    {
        new flag=GetEntityFlags(client);  //FL_ONGROUND
        if(flag & FL_ONGROUND) // on ground , so stop
        {
            Stop(client);
            return;
        }
        new button=GetClientButtons(client);
        if((button & IN_USE) )   // press use key, then start climb
        {
            Start(client); 
        }    
        //code below determine if a player is stucked after jump.
        new Float:time=GetEngineTime();
        if(time>JumpTime[client]+1.0)return;
        decl Float:pos[3];
        GetClientAbsOrigin(client, pos);
        StuckIndicator[client]+=GetVectorDistance(pos, LastPos[client]);
        CopyVector(pos, LastPos[client]);
        if(time>JumpTime[client]+0.5 && StuckIndicator[client]<10.0)
        {
            TeleportEntity(client, SafePos[client], NULL_VECTOR,NULL_VECTOR); 
            W3Hint(client, HINT_SKILL_STATUS, 1.0, "You appear to be stuck");
            Stop(client);
        } 
    }
}
/* 
* when a play is climbing ,this function calculate the player's movement, the dummy body's animation
*/
Climb(client, Float:intervual)
{
    new clone=Colon[client];
    if(clone>0)
    { 
        decl Float:colonPos[3];
        decl Float:clientPos[3];
        decl Float:bodyPos[3]; 
        decl Float:headOffset[3]; 
        decl Float:footOffset[3];
        decl Float:bodyTouchPos[3];
        decl Float:headTouchPos[3];
        decl Float:footTouchPos[3];            
        decl Float:moveDir[3];    
        decl Float:cloneAnge[3];
        decl Float:bodyNormal[3];
        decl Float:eyeNormal[3];
        decl Float:footNormal[3];
        decl Float:normal[3];
        decl Float:temp[3];
        decl Float:up[3];
        SetVector(up, 0.0, 0.0, 1.0); 
        new button=GetClientButtons(client);
         
         
        new Float:playrate=0.0;    
        new bool:needprocess=false;
        new bool:moveforward;
        new bool:moveback;
        if(button & IN_FORWARD )
        {
            needprocess=true; 
            moveforward=true;
        }
        else if(button & IN_BACK )
        {
            needprocess=true; 
            moveback=true;
        }
        if(button & IN_MOVELEFT )
        {
             
            Angle[client]+=intervual*90.0;
            playrate=PlayBackRate[client]*0.5;
            needprocess=true;
        }
        else if(button & IN_MOVERIGHT )
        {
             
            Angle[client]-=intervual*90.0;
            playrate=PlayBackRate[client]*0.5;
            needprocess=true;
        }
        if( button & IN_JUMP || button & IN_ATTACK || button & IN_ATTACK2)
        {
            Jump(client);
                 
            return;
        }
 
        while(needprocess  || FirstRun[client])
        {
            FirstRun[client]=false;
            CopyVector(BodyPos[client], bodyPos);  
            CopyVector(BodyNormal[client], normal);
            CopyVector(normal, cloneAnge);
            ScaleVector(cloneAnge, -1.0);
            GetVectorAngles(cloneAnge, cloneAnge); 
            cloneAnge[2]=0.0-Angle[client]; 
             
            new Float:f=GetAngle(BodyNormal[client], up)*180/Pai;
            if(f<10.0 || f>170.0)
            {
                Jump(client, false, 0.0);
                 
                return;
            }
            
        
            SetVector(headOffset, 0.0, 0.0, 1.0); 
            GetProjection(normal, up, headOffset);  
            RotateVector(normal, headOffset, AngleCovert(Angle[client]), headOffset); 
            CopyVector(headOffset, footOffset);
            NormalizeVector(headOffset, headOffset);
            NormalizeVector(footOffset, footOffset);
            ScaleVector(footOffset, 0.0-bodylength*0.5);
            ScaleVector(headOffset, bodylength*0.5);
            
            AddVectors(bodyPos, headOffset, headTouchPos);
            AddVectors(bodyPos, footOffset, footTouchPos);    
            
            new bool:b=GetRaySimple(client, headTouchPos, footTouchPos, temp);
            if(b)
            { 
                break;
            }
            
            CopyVector(footTouchPos, colonPos);
            
            new Float:disBody=GetRay(client, bodyPos, cloneAnge , bodyTouchPos, bodyNormal, 0.0-BodyWidth[client]);  
            new Float:disHead=GetRay(client, headTouchPos, cloneAnge , headTouchPos, eyeNormal, 0.0-BodyWidth[client]);  
            new Float:disFoot=GetRay(client, footTouchPos, cloneAnge , footTouchPos, footNormal, 0.0-BodyWidth[client]);  


            
            if(disBody>BodyWidth[client]*2.0)
            {
                Jump(client, false, 50.0);
                return;
            }
            new bool:needrotatenormal=false;
            if(disHead>BodyWidth[client] )
            {
                disHead=BodyWidth[client] ;
                needrotatenormal=true;
            }
            if(disFoot>BodyWidth[client] )
            {
                disFoot=BodyWidth[client]  ;
                needrotatenormal=true;
            }
            new Float:ft=disHead-disFoot;
            
            if(needrotatenormal)
            {
         
                ft=ArcSine(ft/SquareRoot( ft*ft +bodylength*0.5*bodylength*0.5 ));
                GetVectorCrossProduct(bodyNormal, headOffset, temp); 
                RotateVector(temp, normal, ft*0.5, normal); 
                CopyVector(normal, normal);
            }
            else
            {
                CopyVector(bodyNormal, normal);
            }
            
            CopyVector(headOffset ,moveDir);
            NormalizeVector(moveDir, moveDir); 
            ScaleVector(moveDir, ClimbSpeed[client]*intervual);  
            
            CopyVector(bodyTouchPos, bodyPos); 
            
            if(moveforward)
            {
                playrate=PlayBackRate[client]; 
                AddVectors(colonPos, moveDir, colonPos);
                AddVectors(bodyPos, moveDir, bodyPos);
            }
            else if(moveback)
            {
             
                playrate=0.0-PlayBackRate[client];
                SubtractVectors(colonPos, moveDir,colonPos );
                SubtractVectors(bodyPos, moveDir, bodyPos);
             
            }
            
            CopyVector(bodyPos,clientPos);
            clientPos[2]-=bodylength*0.5;
            TeleportEntity(client, clientPos, NULL_VECTOR, NULL_VECTOR); 
            TeleportEntity(clone,  colonPos, cloneAnge, NULL_VECTOR); 
            CopyVector(bodyPos, BodyPos[client] );  
            CopyVector(normal, BodyNormal[client] );  
            break;
        }
        SetEntPropFloat(clone, Prop_Send, "m_flPlaybackRate", playrate);
    }
    else
    {
        Stop(client);
    }
    return;
}
/**
 * create a dummy body
 */
CreateColon(client)
{
    decl Float:vAngles[3];
    decl Float:vOrigin[3];
    GetClientAbsOrigin(client,vOrigin);
    GetClientEyeAngles(client, vAngles);     
    decl String:playerModel[42];
 
    GetEntPropString(client, Prop_Data, "m_ModelName", playerModel, sizeof(playerModel)); 
    new clone = CreateEntityByName("prop_dynamic"); 
    SetEntityModel(clone, playerModel);  
 
    decl Float:vPos[3], Float:vAng[3];
    vPos[0] = -0.0; 
    vPos[1] = -0.0;
    vPos[2] = -30.0;
    
    vAng[2] = -90.0;
    vAng[0] = -90.0;
    vAng[1] =0.0;
 
    TeleportEntity(clone,  vOrigin, vAngles, NULL_VECTOR); 
    new iAnim = GetModelInfo(client, playerModel, ClimbSpeed[client], PlayBackRate[client], BodyWidth[client]); 
    
    SetEntProp(clone, Prop_Send, "m_nSequence", iAnim);
    SetEntPropFloat(clone, Prop_Send, "m_flPlaybackRate", 1.0);   
    
    SetEntPropFloat(clone, Prop_Send, "m_fadeMinDist", 10000.0); 
    SetEntPropFloat(clone, Prop_Send, "m_fadeMaxDist", 20000.0); 
    
    return clone;
}

GetModelInfo(client, String:model[], &Float:speedvalue , &Float:playbackrate, &Float:bodywidth)
{
    /* Should these ever break, just do the following:
     * 
     * Add this code:
     * 
     * new m=GetEntProp(client, Prop_Send, "m_nSequence" );    
     * PrintToChatAll("animation is %d", m);
     * 
     * Climb on a ladder with the character it broke on and run the code
     * -> tada, you got the new number
     */
    
    new anim=0;    
    new Float:S=30.0;
    bodywidth=gbodywidth;
    if(StrContains(model, "survivor_teenangst")!=-1)
        anim = 514;
    else if(StrContains(model, "survivor_manager")!=-1)
        anim = 514;
    else if(StrContains(model, "survivor_namvet")!=-1)
        anim = 514;
    else if(StrContains(model, "survivor_biker")!=-1)
        anim = 517; 
    else if(StrContains(model, "gambler")!=-1)
        anim = 605;
     else if(StrContains(model, "producer")!=-1)
         anim = 614;
    else if(StrContains(model, "coach")!=-1)
        anim = 606;
     else if(StrContains(model, "mechanic")!=-1)
         anim = 610;
    
    speedvalue = ClimbSpeedSkill[War3_GetSkillLevel(client, thisRaceID, SKILL_CLIMB)];
    
    playbackrate = 1.0+(speedvalue-S)/S;
    return anim;
}

 
VisiblePlayer(client, bool:visible=true)
{
    if(visible)
    {
        SetEntityRenderMode(client, RENDER_NORMAL);
        SetEntityRenderColor(client, 255, 255, 255, 255);         
    }
    else
    {
        SetEntityRenderMode(client, RENDER_TRANSCOLOR);
        SetEntityRenderColor(client, 0, 0, 0, 0);
    } 
}

new Float:RayVec[3];
/* 
* Calculate a ray start from pos1 to pos2, 
* output: hitpos is collision positon 
*/
bool:GetRaySimple(client, Float:pos1[3] , Float:pos2[3], Float:hitpos[3])
{
    new Handle:trace ;
    new bool:hit=false;  
    trace= TR_TraceRayFilterEx(pos1, pos2, MASK_SOLID, RayType_EndPoint, TraceRayDontHitSelfAndColoe, client); 
    if(TR_DidHit(trace))
    {            
         
        TR_GetEndPosition(hitpos, trace); 
        hit=true;
    }
    CloseHandle(trace); 
    return hit;
}
/* 
* Calculate a ray start from pos, 
* output: hitpos is collision positon, normal is the collision plane's normal vector.
* return:distance between pos and hitpos
*/
Float:GetRay(client, Float:pos[3] , Float:angle[3], Float:hitpos[3], Float:normal[3], Float:offset=0.0)
{
    new Handle:trace ;
    new Float:ret=9999.0;
    trace= TR_TraceRayFilterEx(pos, angle, MASK_SOLID, RayType_Infinite, TraceRayDontHitSelfAndColoe, client); 
    if(TR_DidHit(trace))
    {            
        CopyVector(pos, RayVec);
        TR_GetEndPosition(hitpos, trace);
        TR_GetPlaneNormal(trace, normal);
        NormalizeVector(normal, normal); 
        if(offset!=0.0)
        {
            decl Float:t[3];
            GetAngleVectors(angle, t, NULL_VECTOR, NULL_VECTOR );
            NormalizeVector(t, t);
            ScaleVector(t, offset);
            AddVectors(hitpos, t, hitpos); 
        }
        ret=GetVectorDistance(RayVec,hitpos);
        
    }
    CloseHandle(trace); 
    return ret;
}

CopyVector(Float:source[3], Float:target[3])
{
    target[0]=source[0];
    target[1]=source[1];
    target[2]=source[2];
}
SetVector(Float:target[3], Float:x, Float:y, Float:z)
{
    target[0]=x;
    target[1]=y;
    target[2]=z;
}
public bool:DontHitSelf(entity, mask, any:data)
{
    if(entity == data) 
    {
        return false; 
    }
    return true;
}
Float:AngleCovert(Float:angle)
{
    return angle/180.0*Pai;
}
/* 
* angle between x1 and x2
*/
Float:GetAngle(Float:x1[3], Float:x2[3])
{
    return ArcCosine(GetVectorDotProduct(x1, x2)/(GetVectorLength(x1)*GetVectorLength(x2)));
}
/* 
* get vector t's projection on a plane, the plane's normal vector is n, r is the result
*/
GetProjection(Float:n[3], Float:t[3], Float:r[3])
{
    new Float:A=n[0];
    new Float:B=n[1];
    new Float:C=n[2];
    
    new Float:a=t[0];
    new Float:b=t[1];
    new Float:c=t[2];
    
    new Float:p=-1.0*(A*a+B*b+C*c)/(A*A+B*B+C*C);
    r[0]=A*p+a;
    r[1]=B*p+b;
    r[2]=C*p+c; 
    //AddVectors(p, r, r);
}
/* 
* rotate vector vec around vector direction alfa degrees
*/
RotateVector(Float:direction[3], Float:vec[3], Float:alfa, Float:result[3])
{
  /*
   on rotateVector (v, u, alfa)
  -- rotates vector v around u alfa degrees
  -- returns rotated vector 
  -----------------------------------------
  u.normalize()
  alfa = alfa*pi()/180 -- alfa in rads
  uv = u.cross(v)
  vect = v + sin (alfa) * uv + 2*power(sin(alfa/2), 2) * (u.cross(uv))
  return vect
    end
   */
       decl Float:v[3];
    CopyVector(vec,v);
    
    decl Float:u[3];
    CopyVector(direction,u);
    NormalizeVector(u,u);
    
    decl Float:uv[3];
    GetVectorCrossProduct(u,v,uv);
    
    decl Float:sinuv[3];
    CopyVector(uv, sinuv);
    ScaleVector(sinuv, Sine(alfa));
    
    decl Float:uuv[3];
    GetVectorCrossProduct(u,uv,uuv);
    ScaleVector(uuv, 2.0*Pow(Sine(alfa*0.5), 2.0));    
    
    AddVectors(v, sinuv, result);
    AddVectors(result, uuv, result);
} 

public bool:TraceRayDontHitSelfAndColoe(entity, mask, any:data)
{
    if(entity == data) 
    {
        return false; 
    }
    else if(data>=1 && data<=MaxClients)
    {
        if(entity==Colon[data])
        {
            return false; 
        }
    }
    return true;
}