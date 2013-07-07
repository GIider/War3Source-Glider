#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <sdktools_functions>
#include <sdkhooks>

#include "W3SIncs/War3Source_Interface"
#include "W3SIncs/War3Source_Race_Engineer"

public Plugin:myinfo = 
{
    name = "War3Source - Raceengine - Engineers Sentry",
    author = "Glider",
    description = "Manages the Sentry skill of the Engineer",
    version = "1.0",
}; 
 


// Sentry stats
new g_SentryMaxAmmo[MAXPLAYERS];
new g_SentryCurrentAmmo[MAXPLAYERS];
new Float:g_fSentryScanRange[MAXPLAYERS];
new SentryAmmo:g_SentryAmmoType[MAXPLAYERS];
new Float:g_fSentryAccuracy[MAXPLAYERS]; // Default was 0.20
new g_SentryAmountOfShots[MAXPLAYERS]; // How often a sentry shoots 
new g_SentryDamage[MAXPLAYERS];
new Float:g_fSentryFiringInterval[MAXPLAYERS]; // Default was 0.08

new g_eSentryEntity[MAXPLAYERS];
new bool:g_bHasActiveSentry[MAXPLAYERS] = false;
new SentryState:g_SentryState[MAXPLAYERS];

new Float:LastThinkTime[MAXPLAYERS+1]; 
new Float:FireOverHeatTime=10.0;

// Rename or something
new GunEnemy[MAXPLAYERS+1];
new Float:ScanTime=0.0;
new GunScanIndex[MAXPLAYERS+1];
new Float:GunFireTime[MAXPLAYERS+1];
new Float:GunFireTotolTime[MAXPLAYERS+1];
new Float:GunFireStopTime[MAXPLAYERS+1];

#define PARTICLE_MUZZLE_FLASH        "weapon_muzzle_flash_autoshotgun"  
#define PARTICLE_WEAPON_TRACER2        "weapon_tracers_50cal"//weapon_tracers_50cal" //"weapon_tracers_explosive" weapon_tracers_50cal
 
#define PARTICLE_BLOOD2        "blood_impact_headshot_01"

#define SOUND_IMPACT1        "physics/flesh/flesh_impact_bullet1.wav"  
#define SOUND_IMPACT2        "physics/concrete/concrete_impact_bullet1.wav"  
#define SOUND_FIRE        "weapons/50cal/50cal_shoot.wav"  
#define MODEL_GUN "models/w_models/weapons/w_minigun.mdl"
#define MODEL_GUN2 "models/w_models/weapons/50cal.mdl"

#define EnemyArraySize 300
new InfectedsArray[MAXPLAYERS][EnemyArraySize];
new InfectedCount[MAXPLAYERS];

public OnPluginStart()
{
    if(!GAMEL4DANY)
    {
        SetFailState("L4D Only");
    }
    
    HookEvent("witch_harasser_set", witch_harasser_set);
     
    HookEvent("round_start", round_end);
    HookEvent("round_end", round_end);
    HookEvent("finale_win", round_end);
    HookEvent("mission_lost", round_end);
    HookEvent("map_transition", round_end);
    
    ResetAllState();
}

public bool:InitNativesForwards()
{
    CreateNative("War3_Engineer_SpawnSentry", Native_SpawnSentry);
    CreateNative("War3_Engineer_HasSentry", Native_HasSentry);
    CreateNative("War3_Engineer_DestroySentry", Native_DestroySentry);
    CreateNative("War3_Engineer_IsSentry", Native_IsSentry);
    CreateNative("War3_Engineer_RefillSentry", Native_RefillSentry);
    CreateNative("War3_Engineer_CheckAmmo", Native_CheckAmmo);
    CreateNative("War3_Engineer_CheckMaxAmmo", Native_CheckMaxAmmo);
        
    return true;
}

public Native_SpawnSentry(Handle:plugin, numParams)
{
    new client = GetNativeCell(1);
    new damage = GetNativeCell(2);
    new Float:firingInterval = GetNativeCell(3);
    new SentryAmmo:ammotype = GetNativeCell(4);
    new MaxAmmo = GetNativeCell(5);
    new Float:ScanRange = GetNativeCell(6);
    new Float:SentryAccuracy = GetNativeCell(7);
    new SentryShots = GetNativeCell(8);
    
    SpawnSentry(client, damage, firingInterval, ammotype, MaxAmmo, ScanRange, SentryAccuracy, SentryShots);
}

public Native_HasSentry(Handle:plugin, numParams)
{
    new client = GetNativeCell(1);
    return g_bHasActiveSentry[client]; 
}

public Native_IsSentry(Handle:plugin, numParams)
{
    new entity = GetNativeCell(1);
    return FindGunIndex(entity) > 0; 
}

public Native_DestroySentry(Handle:plugin, numParams)
{
    new client = GetNativeCell(1);
    RemoveMachine(client);
}

public Native_CheckAmmo(Handle:plugin, numParams)
{
    new client = GetNativeCell(1);
    if (g_bHasActiveSentry[client]) {
        return g_SentryCurrentAmmo[client];
    }
    
    return 0;
}

public Native_CheckMaxAmmo(Handle:plugin, numParams)
{
    new client = GetNativeCell(1);
    
    if (g_bHasActiveSentry[client]) {
        return g_SentryMaxAmmo[client];
    }    
    
    return 0;
}

public Native_RefillSentry(Handle:plugin, numParams)
{
    new sentry = GetNativeCell(1);
    new owner = FindGunIndex(sentry);
    
    if (ValidPlayer(owner)) {
        g_SentryCurrentAmmo[owner] = g_SentryMaxAmmo[owner];
    }
}

// -----------------------------------------------------------------------
// Can you read it?
// I wish - it's MACHINE CODE
// ... haha that slaps me on the knee
// -----------------------------------------------------------------------

// ----------------------- Things ----------------------------------------

ResetAllState()
{
    ScanTime = 0.0;
    for(new i=1; i<=MaxClients; i++)
    {
        RemoveMachine(i);
        ClearEnemys(i);
    } 
}

ScanEnemys(client)
{    
    // Witches are always in spot 0 so all turrets focus on them!
    if(War3_IsWitch(InfectedsArray[client][0]))
    {
        InfectedCount[client] = 1;
    }
    else 
        InfectedCount[client] = 0;
    
    for(new i=1; i <= MaxClients; i++)
    {
        if(ValidPlayer(i, true) && GetClientTeam(i) == TEAM_INFECTED)
        {
            InfectedsArray[client][InfectedCount[client]++]=i;
        }
    }
    new ent = -1;
    while ((ent = FindEntityByClassname(ent,  "infected" )) != -1 && InfectedCount[client] < EnemyArraySize-1)
    {
        InfectedsArray[client][InfectedCount[client]++] = ent;
    } 
}

ClearEnemys(client)
{
    InfectedCount[client] = 0;
}

// ----------------------- Events ----------------------------------------

public OnMapStart()
{
    PrecacheModel(MODEL_GUN);
    PrecacheModel(MODEL_GUN2);
     
    PrecacheSound(SOUND_FIRE);
    PrecacheSound(SOUND_IMPACT1);    
    PrecacheSound(SOUND_IMPACT2);
    
    War3_PrecacheParticle(PARTICLE_MUZZLE_FLASH);
    
    War3_PrecacheParticle(PARTICLE_WEAPON_TRACER2);
    War3_PrecacheParticle(PARTICLE_BLOOD2);
}


// When somebody pisses off a witch all turrets should focus on the witch
public Action:witch_harasser_set(Handle:hEvent, const String:strName[], bool:DontBroadcast)
{
    new witch = GetEventInt(hEvent, "witchid"); 

    for(new i=0; i < MAXPLAYERS; i++)
    {
        GunEnemy[i]=witch;
        GunScanIndex[i]=0;
        InfectedsArray[i][0] = witch;    
    }
}

public OnWar3EventSpawn(client)
{    
    decl String:modelName[100];
    GetClientModel(client, modelName, sizeof(modelName));
    
    if (StrContains(modelName, "hulk", false) != -1)
    {    
        for(new i=0; i < MAXPLAYERS; i++)
        {
            GunEnemy[i]=client;
            GunScanIndex[i]=0;
            InfectedsArray[i][0] = client;    
        }
    }
}

public Action:round_end(Handle:event, const String:name[], bool:dontBroadcast)
{
    ResetAllState();
}

// ----------------------- ITS MACHINE CODE -----------------------------------


SpawnSentry(client, damage, Float:interval, SentryAmmo:ammotype, MaxAmmo, Float:ScanRange, Float:SentryAccuracy, SentryShots)
{
    if(ValidPlayer(client, true))
    {
        g_bHasActiveSentry[client] = true;
        g_eSentryEntity[client] = SpawnMiniGun(client); 
        g_SentryState[client] = State_Scan;  
        g_fSentryScanRange[client] = ScanRange;
        g_SentryAmmoType[client] = ammotype;
        LastThinkTime[client] = GetEngineTime();
        g_SentryDamage[client] = damage;
        g_fSentryFiringInterval[client] = interval;
        g_fSentryAccuracy[client] = SentryAccuracy;
        g_SentryAmountOfShots[client] = SentryShots;
        
        GunScanIndex[client] = 0;
        GunEnemy[client] = 0;
        GunFireTime[client] = 0.0;
        GunFireStopTime[client] = 0.0;
        GunFireTotolTime[client] = 0.0;
        g_SentryCurrentAmmo[client] = MaxAmmo;
        g_SentryMaxAmmo[client] = MaxAmmo;
        
        SDKUnhook(g_eSentryEntity[client], SDKHook_Think,  PreThinkGun); 
        SDKHook(g_eSentryEntity[client], SDKHook_Think,  PreThinkGun); 

        ScanEnemys(client);
        
    }
}


RemoveMachine(client)
{
    g_bHasActiveSentry[client] = false;
    
    if(g_SentryState[client] == State_None)
        return; 
    
    g_SentryState[client] = State_None;
    SDKUnhook(g_eSentryEntity[client], SDKHook_Think, PreThinkGun);   
    
    new Float:fPos[3];
    GetEntPropVector(g_eSentryEntity[client], Prop_Send, "m_vecOrigin", fPos);    
    if(g_eSentryEntity[client] > 0 && IsValidEdict(g_eSentryEntity[client]) && IsValidEntity(g_eSentryEntity[client]))
        AcceptEntityInput((g_eSentryEntity[client]), "Kill");
    
    g_eSentryEntity[client] = 0;
    
    //War3_L4D_Explode(client, fPos, 1);
}

SpawnMiniGun(client)
{
    decl Float:VecOrigin[3], Float:VecAngles[3], Float:VecDirection[3]; 

    new gun = CreateEntityByName( "prop_minigun_l4d1"); 
    SetEntityModel(gun, MODEL_GUN);
    //GunType[client] = 0;
    
    DispatchSpawn(gun);
     
    GetClientAbsOrigin(client, VecOrigin);
    GetClientEyeAngles(client, VecAngles);
    GetAngleVectors(VecAngles, VecDirection, NULL_VECTOR, NULL_VECTOR);
    VecOrigin[0] += VecDirection[0] * 45;
    VecOrigin[1] += VecDirection[1] * 45;
    VecOrigin[2] += VecDirection[2] * 1;   
    VecAngles[0] = 0.0;
    VecAngles[2] = 0.0;
    DispatchKeyValueVector(gun, "Angles", VecAngles);
 
    TeleportEntity(gun, VecOrigin, NULL_VECTOR, NULL_VECTOR);
    
    SetEntProp(gun, Prop_Send, "m_iTeamNum", 2);
    //SetEntProp(client, Prop_Data, "m_CollisionGroup", 2);   
    
    SetEntProp(gun, Prop_Send, "m_iGlowType", 3);
    SetEntProp(gun, Prop_Send, "m_nGlowRange", 0);
    SetEntProp(gun, Prop_Send, "m_nGlowRangeMin", 1);
    
    SetEntProp(gun, Prop_Send, "m_glowColorOverride", 0 + (100 * 256) + 0);    
    
    return gun;
}

public PreThinkGun(gun)
{    
    new index = FindGunIndex(gun);    
    if(index!=-1)
    {
        new Float:time = GetEngineTime();
        new Float:interval = time - LastThinkTime[index];
        LastThinkTime[index] = time; 
        
        if(g_SentryState[index] == State_Scan) 
        {    
            ScanAndShootEnemy(index, time, interval); 
        }
    }
}

ScanAndShootEnemy(client, Float:time, Float:intervual)
{
    new sentry = g_eSentryEntity[client]; 
    if(sentry < 0 || !IsValidEdict(sentry) || !IsValidEntity(sentry)) {
        PrintToChatAll("Scanner hat eine kaputte Sentry entdeckt");
        RemoveMachine(client);
    }
    
    if(g_SentryState[client] == State_Sleep)
    {
        SetEntProp(sentry, Prop_Send, "m_firing", 0);
        return;
    }
    
    decl Float:sentrypos[3];
    decl Float:sentryangle[3];
    decl Float:hitpos[3];
    decl Float:temp[3];
    decl Float:shotangle[3];
    decl Float:gunDir[3];
     
    GetEntPropVector(sentry, Prop_Send, "m_vecOrigin", sentrypos);    
    GetEntPropVector(sentry, Prop_Send, "m_angRotation", sentryangle);    
    
    GetAngleVectors(sentryangle, gunDir, NULL_VECTOR, NULL_VECTOR );
    NormalizeVector(gunDir, gunDir);
    CopyVector(gunDir, temp);    
    /*if(GunType[client]==0)ScaleVector(temp, 20.0);
    else ScaleVector(temp, 50.0);*/
    ScaleVector(temp, 20.0);
    AddVectors(sentrypos, temp ,sentrypos);
    GetAngleVectors(sentryangle, NULL_VECTOR, NULL_VECTOR, temp );
    NormalizeVector(temp, temp);
    ScaleVector(temp, 43.0);
    AddVectors(sentrypos, temp, sentrypos);

    if(time - ScanTime > 1.0)
    {
        ScanTime = time;
        ScanEnemys(client); 
    }

    new newenemy=GunEnemy[client];

    if( IsValidEnemy(newenemy) )
    {
        newenemy = IsEnemyVisible(sentry, newenemy, g_fSentryScanRange[client], sentrypos, hitpos,shotangle);        
    }
    else 
        newenemy=0;
 
    if(InfectedCount[client] > 0 && newenemy == 0)
    {
        if(GunScanIndex[client] >= InfectedCount[client])
        {
            GunScanIndex[client]=0;
        }
        GunEnemy[client] = InfectedsArray[client][GunScanIndex[client]];
        GunScanIndex[client]++;
        newenemy = 0;
    }
    
    if(newenemy == 0)
    {
        SetEntProp(sentry, Prop_Send, "m_firing", 0);
        return;
    }
    
    decl Float:enemyDir[3]; 
    decl Float:newGunAngle[3]; 
    if(newenemy > 0)
    {
        SubtractVectors(hitpos, sentrypos, enemyDir);                
    }
    else
    {
        CopyVector(gunDir, enemyDir); 
        enemyDir[2]=0.0; 
    }
    NormalizeVector(enemyDir,enemyDir);     
    
    decl Float:targetAngle[3]; 
    GetVectorAngles(enemyDir, targetAngle);
    new Float:diff0=AngleDiff(targetAngle[0], sentryangle[0]);
    new Float:diff1=AngleDiff(targetAngle[1], sentryangle[1]);
    
    
    new Float:turn0=45.0*Sign(diff0)*intervual;
    new Float:turn1=180.0*Sign(diff1)*intervual;
    if(FloatAbs(turn0) >= FloatAbs(diff0))
    {
        turn0 = diff0;
    }
    if(FloatAbs(turn1) >= FloatAbs(diff1))
    {
        turn1 = diff1;
    }
     
    newGunAngle[0] = sentryangle[0] + turn0;
    newGunAngle[1] = sentryangle[1] + turn1; 
     
    newGunAngle[2]=0.0; 
    
    DispatchKeyValueVector(sentry, "Angles", newGunAngle);
    new overheated = GetEntProp(sentry, Prop_Send, "m_overheated");
    
    GetAngleVectors(newGunAngle, gunDir, NULL_VECTOR, NULL_VECTOR); 
    if(overheated == 0)
    {
        if( newenemy > 0 && FloatAbs(diff1) < 40.0)
        { 
            if(time >= GunFireTime[client] && g_SentryCurrentAmmo[client] > 0)
            {
                GunFireTime[client] = time + g_fSentryFiringInterval[client];
                
                for(new i=0; i < g_SentryAmountOfShots[client]; i++) {
                    if(g_SentryCurrentAmmo[client] == 0)
                    {
                        PrintHintText(client, "Sentry ran out of ammo!");
                        //RemoveMachine(client);
                        break;
                    }
                    SentryDoShoot(client, sentry, sentrypos, newGunAngle); 
                    g_SentryCurrentAmmo[client]--;
                }
                GunFireStopTime[client] = time + 0.05;     
            } 
        } 
    }
    new Float:heat=GetEntPropFloat(sentry, Prop_Send, "m_heat"); 
    
    if(time<GunFireStopTime[client])
    {
 
        GunFireTotolTime[client]+=intervual;
        heat=GunFireTotolTime[client]/FireOverHeatTime;
        if(heat>=1.0)heat=1.0;
        SetEntProp(sentry, Prop_Send, "m_firing", 1);         
        SetEntPropFloat(sentry, Prop_Send, "m_heat", heat);
    }
    else 
    {
        SetEntProp(sentry, Prop_Send, "m_firing", 0);     
        heat=heat-intervual/4.0;
        if(heat<0.0)
        {
            heat=0.0;
            SetEntProp(sentry, Prop_Send, "m_overheated", 0);
            SetEntPropFloat(sentry, Prop_Send, "m_heat", 0.0 );
        }
        else SetEntPropFloat(sentry, Prop_Send, "m_heat", heat ); 
        GunFireTotolTime[client]=FireOverHeatTime*heat; 
    }
    return;
}


IsEnemyVisible(gun, ent, Float:range, Float:gunpos[3], Float:hitpos[3], Float:angle[3])
{    
    if(ent<=0) return 0;
    
    GetEntPropVector(ent, Prop_Send, "m_vecOrigin", hitpos);
    hitpos[2]+=35.0; 

    SubtractVectors(hitpos, gunpos, angle);
    GetVectorAngles(angle, angle); 
    new Handle:trace=TR_TraceRayFilterEx(gunpos, angle, MASK_SHOT, RayType_Infinite, TraceRayDontHitSelf, gun);      
    new newenemy=0;
     
    if(TR_DidHit(trace))
    {         
        TR_GetEndPosition(hitpos, trace);
        newenemy=TR_GetEntityIndex(trace);  
        if(GetVectorDistance(gunpos, hitpos)>range)newenemy=0;     
    }
    else
    {
        newenemy=ent;
    }
    CloseHandle(trace); 
    if(newenemy > 0)
    {
        if(ValidPlayer(newenemy, true) && GetClientTeam(newenemy) == TEAM_INFECTED)
        {
            return newenemy;
        }
        else if(War3_IsL4DZombieEntity(newenemy))
        {
            return newenemy;
        }
    } 
    return -1;
}

SentryDoShoot(client, gun, Float:gunpos[3], Float:shotangle[3])
{         
 
    ThrowAwayLightEmitter(gunpos, "237 215 90 255", "5", 400.0, 0.2);
    
    decl Float:temp[3];
    decl Float:ang[3];
    GetAngleVectors(shotangle, temp, NULL_VECTOR,NULL_VECTOR); 
    NormalizeVector(temp, temp); 
     
    new Float:acc = g_fSentryAccuracy[client];
    temp[0] += GetRandomFloat(-1.0, 1.0) * acc;
    temp[1] += GetRandomFloat(-1.0, 1.0) * acc;
    temp[2] += GetRandomFloat(-1.0, 1.0) * acc;
    GetVectorAngles(temp, ang);

    new Handle:trace= TR_TraceRayFilterEx(gunpos, ang, MASK_SHOT, RayType_Infinite, TraceRayDontHitSelf, gun); 
    new enemy=0;    
     
    if(TR_DidHit(trace))
    {            
        decl Float:hitpos[3];         
        TR_GetEndPosition(hitpos, trace);        
        enemy=TR_GetEntityIndex(trace); 
        
        new bool:blood=false;
        if(enemy>0)
        {            
            decl String:classname[32];
            GetEdictClassname(enemy, classname, 32);    
            if(enemy >=1 && enemy<=MaxClients)
            {
                if(GetClientTeam(enemy)==TEAM_SURVIVORS) {enemy=0;}    
                blood=true;
            }
            else if(StrEqual(classname, "infected") || StrEqual(classname, "witch" ) ){ }     
            else enemy=0;
        } 
        if(enemy>0)
        {
            if(client>0 &&IsPlayerAlive(client))client=client+0;
            else client=0;
            
            if (g_SentryAmmoType[client] == Incendiary) {
                War3_DealDamage(enemy, g_SentryDamage[client], client, DMG_BURN, "Sentry");
            }
            else if (g_SentryAmmoType[client] == Explosive) {
                War3_DealDamage(enemy, g_SentryDamage[client], client, DMG_BLAST, "Sentry");
            }
            else {
                War3_DealDamage(enemy, g_SentryDamage[client], client, DMG_GENERIC, "Sentry");
            }
            
            decl Float:Direction[3];
            GetAngleVectors(ang, Direction, NULL_VECTOR, NULL_VECTOR);
            ScaleVector(Direction, -1.0);
            GetVectorAngles(Direction,Direction);
            if (blood) {
                new particle = ThrowAwayParticle(PARTICLE_BLOOD2, hitpos, 0.1);
                TeleportEntity(particle, NULL_VECTOR, Direction, NULL_VECTOR);
            }
            
            EmitSoundToAll(SOUND_IMPACT1, 0,  SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS,1.0, SNDPITCH_NORMAL, -1,hitpos, NULL_VECTOR,true, 0.0);
        }
        else
        {        
            decl Float:Direction[3];
            Direction[0] = GetRandomFloat(-1.0, 1.0);
            Direction[1] = GetRandomFloat(-1.0, 1.0);
            Direction[2] = GetRandomFloat(-1.0, 1.0);
            TE_SetupSparks(hitpos,Direction,1,3);
            TE_SendToAll();
            EmitSoundToAll(SOUND_IMPACT2, 0,  SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS,1.0, SNDPITCH_NORMAL, -1,hitpos, NULL_VECTOR,true, 0.0);

        }
         
        
        ShowMuzzleFlash(gunpos, ang);
        ShowTrack(gunpos, hitpos); 
        //if(GunType[index]==1)EmitSoundToAll(SOUND_FIRE, 0,  SNDCHAN_WEAPON, SNDLEVEL_NORMAL, SND_NOFLAGS,1.0, SNDPITCH_NORMAL, -1,gunpos, NULL_VECTOR,true, 0.0);
    }
    
    CloseHandle(trace);  
     
}


// ----------------------- Flashy effects -------------------------------------

ShowMuzzleFlash(Float:pos[3],  Float:angle[3])
{  
    new particle = ThrowAwayParticle(PARTICLE_MUZZLE_FLASH, pos, 0.1);
    TeleportEntity(particle, NULL_VECTOR, angle, NULL_VECTOR);
}

ShowTrack( Float:pos[3], Float:endpos[3] )
{  
    decl String:temp[32];
    new target = CreateEntityByName("info_particle_target");
    Format(temp, 32, "cptarget%d", target);
    DispatchKeyValue(target, "targetname", temp);    
    TeleportEntity(target, endpos, NULL_VECTOR, NULL_VECTOR); 
    ActivateEntity(target); 
    
    ModifyEntityAddDeathTimer(target, 0.1);
 
    new particle = CreateEntityByName("info_particle_system");
    DispatchKeyValue(particle, "effect_name", PARTICLE_WEAPON_TRACER2);
    DispatchKeyValue(particle, "cpoint1", temp);
    DispatchSpawn(particle);
    ActivateEntity(particle); 
    TeleportEntity(particle, pos, NULL_VECTOR, NULL_VECTOR);
    AcceptEntityInput(particle, "start");    
    ModifyEntityAddDeathTimer(particle, 0.1);
}

// ----------------------- Helpers ----------------------------------------

FindGunIndex(gun)
{
    for(new i=0; i < MAXPLAYERS; i++)
    {
        if(g_eSentryEntity[i] == gun)
        {
            return i;
        }
    }
    return -1;
}

// Helper for those annoying traces
public bool:TraceRayDontHitSelf(entity, mask, any:data)
{
    return !(entity == data);
} 

// Helpers for working with vectors
CopyVector(Float:source[3], Float:target[3])
{
    target[0]=source[0];
    target[1]=source[1];
    target[2]=source[2];
}

Float:AngleDiff(Float:a, Float:b)
{
    new Float:d=0.0;
    if(a>=b)
    {
        d=a-b;
        if(d>=180.0)d=d-360.0;
    }
    else
    {
        d=a-b;
        if(d<=-180.0)d=360+d;
    }
    return d;
}
Float:Sign(Float:v)
{
    if (v == 0.0)
        return 0.0;
    else if(v > 0.0)
        return 1.0;

    else return -1.0;
}

bool:IsValidEnemy(enemy)
{    
    if( enemy <= 0)
        return false;
    
    if( enemy <= MaxClients)
    {
        if(ValidPlayer(enemy, true) && GetClientTeam(enemy) == TEAM_INFECTED)
        {
            return true;
        } 
    }
    else if( IsValidEntity(enemy) && IsValidEdict(enemy))
    {
        decl String:classname[32];
        GetEdictClassname(enemy, classname,32);
        if(StrEqual(classname, "infected", true) )
        {
            new flag=GetEntProp(enemy, Prop_Send, "m_bIsBurning");
            if(flag == 1)
            {
                return false;
            }
            return true;            
        }
        else if (StrEqual(classname, "witch", true))
        {
            return true;
        }
    } 
    
    return false;
}