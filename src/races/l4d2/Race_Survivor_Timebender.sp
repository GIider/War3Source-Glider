#pragma semicolon 1

#include "W3SIncs/War3Source_Interface"

public Plugin:myinfo = 
{
    name = "War3Source Race - L4D Survivor Timebender",
    author = "Glider",
    description = "The Survivor Timebender race for War3Source.",
    version = "1.0",
};

//=======================================================================
//                             VARIABLES
//=======================================================================

new thisRaceID;
new SKILL_DOUBLE_JUMP, SKILL_TIMERIFT, SKILL_HASTE, ULT_ZEDTIME;
 
new bool:g_bHasDoubleJumped[MAXPLAYERS];
new bool:g_bIsJumping[MAXPLAYERS];
new Float:g_fPressedJump[MAXPLAYERS];

new Float:TimeRiftEvasionChance[5]={0.0, 3.75, 7.5, 11.25, 15.0};
new Float:DoubleJumpHeight[5]={0.0, 218.75, 237.5, 256.25, 275.0};
new Float:ReloadSpeed[5]={1.0, 0.89285, 0.7857, 0.67855, 0.5714};

new Float:ULT_COOLDOWN = 30.0;

static const String:Sound1[] = "./ui/menu_countdown.wav";

//offsets
new g_iNextPAttO        = -1;
new g_iActiveWO            = -1;
new g_iShotStartDurO    = -1;
new g_iShotInsertDurO    = -1;
new g_iShotEndDurO        = -1;
new g_iPlayRateO        = -1;
new g_iShotRelStateO    = -1;
new g_iNextAttO            = -1;
new g_iTimeIdleO        = -1;
new g_iVMStartTimeO        = -1;
new g_iViewModelO        = -1;

const Float:g_fl_AutoS = 0.666666;
const Float:g_fl_AutoI = 0.4;
const Float:g_fl_AutoE = 0.675;
const Float:g_fl_SpasS = 0.5;
const Float:g_fl_SpasI = 0.375;
const Float:g_fl_SpasE = 0.699999;
const Float:g_fl_PumpS = 0.5;
const Float:g_fl_PumpI = 0.5;
const Float:g_fl_PumpE = 0.6;

new String:EvasionSnd[]="ambient/energy/zap2.wav";

//=======================================================================
//                                 INIT
//=======================================================================

public OnWar3PluginReady(){
    thisRaceID = War3_CreateNewRace("Timebender", "timebender");
    SKILL_DOUBLE_JUMP = War3_AddRaceSkill(thisRaceID, "Double Jump (+jump)", "Enables you to perform a second jump with a speed of 218/237/256/275", false, 4);
    SKILL_TIMERIFT = War3_AddRaceSkill(thisRaceID, "Timerift", "3.75/7.5/11.25/15% chance to evade damage from friendlys or zombies", false, 4);
    SKILL_HASTE= War3_AddRaceSkill(thisRaceID, "Haste", "Reload faster", false, 4);
    ULT_ZEDTIME = War3_AddRaceSkill(thisRaceID, "Zed Time", "You slow down the flow of time. CD: 30s", true, 1);

    War3_CreateRaceEnd(thisRaceID);
}

public OnPluginStart()
{
    if(War3_GetGame() != Game_L4D && War3_GetGame() != Game_L4D2)
        SetFailState("Only works in the L4D engine! %i", War3_GetGame());
    
    HookEvent("weapon_reload", Event_Reload);
    
    //get offsets
    g_iNextPAttO        =    FindSendPropInfo("CBaseCombatWeapon","m_flNextPrimaryAttack");
    g_iActiveWO            =    FindSendPropInfo("CBaseCombatCharacter","m_hActiveWeapon");
    g_iShotStartDurO    =    FindSendPropInfo("CBaseShotgun","m_reloadStartDuration");
    g_iShotInsertDurO    =    FindSendPropInfo("CBaseShotgun","m_reloadInsertDuration");
    g_iShotEndDurO        =    FindSendPropInfo("CBaseShotgun","m_reloadEndDuration");
    g_iPlayRateO        =    FindSendPropInfo("CBaseCombatWeapon","m_flPlaybackRate");
    g_iShotRelStateO    =    FindSendPropInfo("CBaseShotgun","m_reloadState");
    g_iNextAttO            =    FindSendPropInfo("CTerrorPlayer","m_flNextAttack");
    g_iTimeIdleO        =    FindSendPropInfo("CTerrorGun","m_flTimeWeaponIdle");
    g_iViewModelO        =    FindSendPropInfo("CTerrorPlayer","m_hViewModel");
    g_iVMStartTimeO        =    FindSendPropInfo("CTerrorViewModel","m_flLayerStartTime");
}

public OnMapStart()
{
    PrecacheSound(Sound1, true);
    
    War3_PrecacheParticle("impact_explosive_ammo_small");
    War3_PrecacheParticle("electrical_arc_01_system");
    
    War3_AddCustomSound(EvasionSnd);
}

//=======================================================================
//                                 Haste
//=======================================================================

public Event_Reload (Handle:event, const String:name[], bool:dontBroadcast)
{
    new client = GetClientOfUserId(GetEventInt(event,"userid"));
    if(War3_GetRace(client) == thisRaceID && War3_GetSkillLevel(client, thisRaceID, SKILL_HASTE))
        AdrenReload(client);
}

// ////////////////////////////////////////////////////////////////////////////
//On the start of a reload
AdrenReload (client)
{
    if (GetClientTeam(client) == TEAM_SURVIVORS)
    {
        new iEntid = GetEntDataEnt2(client, g_iActiveWO);
        if (IsValidEntity(iEntid) == false) return;
    
        decl String:stClass[32];
        GetEntityNetClass(iEntid,stClass,32);

        //for non-shotguns
        if (StrContains(stClass,"shotgun",false) == -1)
        {
            MagStart(iEntid, client);
            return;
        }

        else if (StrContains(stClass,"autoshotgun",false) != -1)
        {
            new Handle:hPack = CreateDataPack();
            WritePackCell(hPack, client);
            WritePackCell(hPack, iEntid);
            CreateTimer(0.1,Timer_AutoshotgunStart,hPack);
            return;
        }
        else if (StrContains(stClass,"shotgun_spas",false) != -1)
        {
            new Handle:hPack = CreateDataPack();
            WritePackCell(hPack, client);
            WritePackCell(hPack, iEntid);
            CreateTimer(0.1,Timer_SpasShotgunStart,hPack);
            return;
        }
        else if (StrContains(stClass,"pumpshotgun",false) != -1 || StrContains(stClass,"shotgun_chrome",false) != -1)
        {
            new Handle:hPack = CreateDataPack();
            WritePackCell(hPack, client);
            WritePackCell(hPack, iEntid);
            CreateTimer(0.1,Timer_PumpshotgunStart,hPack);
            return;
        }
    }
}

MagStart (iEntid, client)
{
    new Float:flGameTime = GetGameTime();
    new Float:flNextTime_ret = GetEntDataFloat(iEntid,g_iNextPAttO);
    
    new Float:flNextTime_calc = ( flNextTime_ret - flGameTime ) * ReloadSpeed[War3_GetSkillLevel(client, thisRaceID, SKILL_HASTE)] ;
    SetEntDataFloat(iEntid, g_iPlayRateO, 1.0/ReloadSpeed[War3_GetSkillLevel(client, thisRaceID, SKILL_HASTE)], true);
    CreateTimer( flNextTime_calc, Timer_MagEnd, iEntid);
    
    new Handle:hPack = CreateDataPack();
    WritePackCell(hPack, client);
    
    new Float:flStartTime_calc = flGameTime - ( flNextTime_ret - flGameTime ) * ( 1 - ReloadSpeed[War3_GetSkillLevel(client, thisRaceID, SKILL_HASTE)] ) ;
    WritePackFloat(hPack, flStartTime_calc);
    
    if ( (flNextTime_calc - 0.4) > 0 )
        CreateTimer( flNextTime_calc - 0.4 , Timer_MagEnd2, hPack);
    
    flNextTime_calc += flGameTime;
    
    SetEntDataFloat(iEntid, g_iTimeIdleO, flNextTime_calc, true);
    SetEntDataFloat(iEntid, g_iNextPAttO, flNextTime_calc, true);
    SetEntDataFloat(client, g_iNextAttO, flNextTime_calc, true);
    
}

public Action:Timer_AutoshotgunStart (Handle:timer, Handle:hPack)
{
    KillTimer(timer);
    if (IsServerProcessing() == false)
        return Plugin_Stop;

    ResetPack(hPack);
    new iCid = ReadPackCell(hPack);
    new iEntid = ReadPackCell(hPack);
    CloseHandle(hPack);
    hPack = CreateDataPack();
    WritePackCell(hPack, iCid);
    WritePackCell(hPack, iEntid);

    if (iCid <= 0
        || iEntid <= 0
        || IsValidEntity(iCid)==false
        || IsValidEntity(iEntid)==false
        || IsClientInGame(iCid)==false)
        return Plugin_Stop;

    SetEntDataFloat(iEntid,    g_iShotStartDurO,    g_fl_AutoS*ReloadSpeed[War3_GetSkillLevel(iCid, thisRaceID, SKILL_HASTE)],    true);
    SetEntDataFloat(iEntid,    g_iShotInsertDurO,    g_fl_AutoI*ReloadSpeed[War3_GetSkillLevel(iCid, thisRaceID, SKILL_HASTE)],    true);
    SetEntDataFloat(iEntid,    g_iShotEndDurO,        g_fl_AutoE*ReloadSpeed[War3_GetSkillLevel(iCid, thisRaceID, SKILL_HASTE)],    true);

    SetEntDataFloat(iEntid, g_iPlayRateO, 1.0/ReloadSpeed[War3_GetSkillLevel(iCid, thisRaceID, SKILL_HASTE)], true);

    CreateTimer(0.3,Timer_ShotgunEnd,hPack,TIMER_REPEAT);
    
    return Plugin_Stop;
}

public Action:Timer_SpasShotgunStart (Handle:timer, Handle:hPack)
{
    KillTimer(timer);
    if (IsServerProcessing()==false)
        return Plugin_Stop;

    ResetPack(hPack);
    new iCid = ReadPackCell(hPack);
    new iEntid = ReadPackCell(hPack);
    CloseHandle(hPack);
    hPack = CreateDataPack();
    WritePackCell(hPack, iCid);
    WritePackCell(hPack, iEntid);

    if (iCid <= 0
        || iEntid <= 0
        || IsValidEntity(iCid)==false
        || IsValidEntity(iEntid)==false
        || IsClientInGame(iCid)==false)
        return Plugin_Stop;

    SetEntDataFloat(iEntid,    g_iShotStartDurO,    g_fl_SpasS*ReloadSpeed[War3_GetSkillLevel(iCid, thisRaceID, SKILL_HASTE)],    true);
    SetEntDataFloat(iEntid,    g_iShotInsertDurO,    g_fl_SpasI*ReloadSpeed[War3_GetSkillLevel(iCid, thisRaceID, SKILL_HASTE)],    true);
    SetEntDataFloat(iEntid,    g_iShotEndDurO,        g_fl_SpasE*ReloadSpeed[War3_GetSkillLevel(iCid, thisRaceID, SKILL_HASTE)],    true);

    SetEntDataFloat(iEntid, g_iPlayRateO, 1.0/ReloadSpeed[War3_GetSkillLevel(iCid, thisRaceID, SKILL_HASTE)], true);

    CreateTimer(0.3,Timer_ShotgunEnd,hPack,TIMER_REPEAT);

    return Plugin_Stop;
}

public Action:Timer_PumpshotgunStart (Handle:timer, Handle:hPack)
{
    KillTimer(timer);
    if (IsServerProcessing()==false)
        return Plugin_Stop;

    ResetPack(hPack);
    new iCid = ReadPackCell(hPack);
    new iEntid = ReadPackCell(hPack);
    CloseHandle(hPack);
    hPack = CreateDataPack();
    WritePackCell(hPack, iCid);
    WritePackCell(hPack, iEntid);

    if (iCid <= 0
        || iEntid <= 0
        || IsValidEntity(iCid)==false
        || IsValidEntity(iEntid)==false
        || IsClientInGame(iCid)==false)
        return Plugin_Stop;

    SetEntDataFloat(iEntid,    g_iShotStartDurO,    g_fl_PumpS*ReloadSpeed[War3_GetSkillLevel(iCid, thisRaceID, SKILL_HASTE)],    true);
    SetEntDataFloat(iEntid,    g_iShotInsertDurO,    g_fl_PumpI*ReloadSpeed[War3_GetSkillLevel(iCid, thisRaceID, SKILL_HASTE)],    true);
    SetEntDataFloat(iEntid,    g_iShotEndDurO,        g_fl_PumpE*ReloadSpeed[War3_GetSkillLevel(iCid, thisRaceID, SKILL_HASTE)],    true);

    SetEntDataFloat(iEntid, g_iPlayRateO, 1.0/ReloadSpeed[War3_GetSkillLevel(iCid, thisRaceID, SKILL_HASTE)], true);

    CreateTimer(0.3,Timer_ShotgunEnd,hPack,TIMER_REPEAT);
    
    return Plugin_Stop;
}

public Action:Timer_ShotgunEnd (Handle:timer, Handle:hPack)
{
    ResetPack(hPack);
    new iCid = ReadPackCell(hPack);
    new iEntid = ReadPackCell(hPack);

    if (IsServerProcessing()==false
        || iCid <= 0
        || iEntid <= 0
        || IsValidEntity(iCid)==false
        || IsValidEntity(iEntid)==false
        || IsClientInGame(iCid)==false)
    {
        KillTimer(timer);
        return Plugin_Stop;
    }

    if (GetEntData(iEntid,g_iShotRelStateO)==0)
    {
        SetEntDataFloat(iEntid, g_iPlayRateO, 1.0, true);

        new Float:flTime=GetGameTime()+0.2;
        SetEntDataFloat(iCid,    g_iNextAttO,    flTime,    true);
        SetEntDataFloat(iEntid,    g_iTimeIdleO,    flTime,    true);
        SetEntDataFloat(iEntid,    g_iNextPAttO,    flTime,    true);

        KillTimer(timer);
        CloseHandle(hPack);
        return Plugin_Stop;
    }

    return Plugin_Continue;
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
//=======================================================================
//                                 Time Rift
//=======================================================================

public OnW3TakeDmgAllPre(victim,attacker,Float:damage){
    if(ValidPlayer(victim,true))
    {
        if(War3_GetRace(victim) == thisRaceID)
        {
            if(ValidPlayer(attacker) && GetClientTeam(attacker) == TEAM_SURVIVORS && IsFakeClient(attacker))
            {
                // Feels like I'm doing... NOTHING AT ALL!
            }
            else if (ValidPlayer(attacker) || War3_IsL4DZombieEntity(attacker))
            {
                new skill = War3_GetSkillLevel(victim, thisRaceID, SKILL_TIMERIFT);
                if (GetRandomFloat(0.0, 100.0) < TimeRiftEvasionChance[skill])
                {
                    EmitSoundToAll(EvasionSnd, victim);
                    
                    decl Float:fPos[3];
                    GetEntPropVector(victim, Prop_Send, "m_vecOrigin", fPos);
                    fPos[2] += 5.0;
                    ThrowAwayParticle("electrical_arc_01_system", fPos, 1.0);
                    ThrowAwayLightEmitter(fPos, "150 220 230 255", "5", 250.0, 1.0);
                    
                    War3_DamageModPercent(0.0);
                }
            }
        }
    }
}

//=======================================================================
//                                 Zed Time
//=======================================================================

public Action:ZedBlendBack(Handle:Timer, Handle:h_pack)
{
    decl i_Ent;
    ResetPack(h_pack, false);
    i_Ent = ReadPackCell(h_pack);
    CloseHandle(h_pack);
    if(IsValidEdict(i_Ent))
    {
        AcceptEntityInput(i_Ent, "Stop");
    }
    else
    {
        PrintToServer("[SM] i_Ent is not a valid edict!");
    }    
}    

public OnUltimateCommand(client, race, bool:pressed)
{
    if(ValidPlayer(client, true) && 
       race == thisRaceID && 
       pressed && 
       War3_SkillNotInCooldown(client, thisRaceID, ULT_ZEDTIME, true) && 
       !Silenced(client) &&
       GetClientTeam(client) == TEAM_SURVIVORS &&
       !War3_L4D_IsHelpless(client) &&
       !War3_IsPlayerIncapped(client))
    {    
        new skill = War3_GetSkillLevel(client, thisRaceID, ULT_ZEDTIME);
        if(skill > 0)
        {
            new iWeapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
            SetEntProp(iWeapon, Prop_Send, "m_helpingHandState", 3);            
            
            decl i_Ent, Handle:h_pack;
            i_Ent = CreateEntityByName("func_timescale");
            DispatchKeyValue(i_Ent, "desiredTimescale", "0.2");
            DispatchKeyValue(i_Ent, "acceleration", "1.0");
            DispatchKeyValue(i_Ent, "minBlendRate", "1.0");
            DispatchKeyValue(i_Ent, "blendDeltaMultiplier", "2.0");
            DispatchSpawn(i_Ent);
            AcceptEntityInput(i_Ent, "Start");
            h_pack = CreateDataPack();
            WritePackCell(h_pack, i_Ent);
            CreateTimer(1.0, ZedBlendBack, h_pack);
            
            EmitSoundToAll(Sound1, client);
            War3_CooldownMGR(client, ULT_COOLDOWN, thisRaceID, ULT_ZEDTIME);
        }
    }
}

//=======================================================================
//                                 Double Jump
//=======================================================================

enum VelocityOverride {
    
    VelocityOvr_None = 0,
    VelocityOvr_Velocity,
    VelocityOvr_OnlyWhenNegative,
    VelocityOvr_InvertReuseVelocity
};

stock Client_Push(client, Float:clientEyeAngle[3], Float:power, VelocityOverride:override[3]=VelocityOvr_None, skill)
{
    decl    Float:forwardVector[3],
            Float:newVel[3];
    
    GetAngleVectors(clientEyeAngle, forwardVector, NULL_VECTOR, NULL_VECTOR);
    NormalizeVector(forwardVector, forwardVector);
    ScaleVector(forwardVector, power);
    
    GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", newVel);
    
    for(new i=0;i<3;i++){
        switch(override[i]){
            case VelocityOvr_Velocity:{
                newVel[i] = 0.0;
            }
            case VelocityOvr_OnlyWhenNegative:{                
                if(newVel[i] < 0.0){
                    newVel[i] = 0.0;
                }
            }
            case VelocityOvr_InvertReuseVelocity:{                
                if(newVel[i] < 0.0){
                    newVel[i] *= -1.0;
                }
            }
        }
        
        newVel[i] += forwardVector[i];
    }
    
    newVel[2] = DoubleJumpHeight[skill];
    
    TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, newVel);
}

public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon){
    
    if(War3_GetRace(client) == thisRaceID) 
    {
        new skill = War3_GetSkillLevel(client, thisRaceID, SKILL_DOUBLE_JUMP);
        if(skill > 0)
        {
        
            if(!ValidPlayer(client, true) || IsFakeClient(client))
                return Plugin_Continue;
            
            if (GetEntityMoveType(client) == MOVETYPE_LADDER) 
            {
                return Plugin_Continue;
            }
            
            new flags = GetEntityFlags(client);
    
            if(buttons & IN_JUMP)
            {
                if (!g_bIsJumping[client])
                {
                    g_fPressedJump[client] = GetGameTime() + 0.20;
                    g_bIsJumping[client] = true;
                }
                        
                if (!(flags & FL_ONGROUND) && g_fPressedJump[client] <= GetGameTime())
                    if (!g_bHasDoubleJumped[client])
                    {
                        decl Float:clientEyeAngles[3];
                        GetClientEyeAngles(client,clientEyeAngles);
    
                        decl Float:fPos[3];
                        GetEntPropVector(client, Prop_Send, "m_vecOrigin", fPos);
                        fPos[2] += 5.0;
                        ThrowAwayParticle("impact_explosive_ammo_small", fPos, 1.0);
                        
                        // Enables user to escape fall damage
                        //new Float:EmptyVector[3] = {0.0, 0.0, 0.0};
                        //TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, EmptyVector);
                        
                        Client_Push(client, clientEyeAngles, 0.0, 
                                    VelocityOverride:{VelocityOvr_None,VelocityOvr_None,VelocityOvr_None},
                                    skill);
                                        
                        g_bHasDoubleJumped[client] = true;
                    }
            }
            else if (flags & FL_ONGROUND)
            {
                g_bIsJumping[client] = false;
                g_bHasDoubleJumped[client] = false;
            }
        }
    }
    
    return Plugin_Continue;
}