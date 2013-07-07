#pragma semicolon 1

#include "W3SIncs/War3Source_Interface"
#include <sdkhooks>

public Plugin:myinfo = 
{
    name = "War3Source Race - L4D Survivor Dynomite",
    author = "Glider",
    description = "The Survivor Dynomite race for War3Source.",
    version = "1.0",
}; 

//=======================================================================
//                             VARIABLES
//=======================================================================

#define MODEL_TNT "models/props/terror/exploding_ammo.mdl"
#define PARTICLE_TNT "weapon_pipebomb_blinking_light"
#define PARTICLE_FIRENADE "aircraft_destroy_engine1"
#define SOUND_REMOTE "weapons/hegrenade/beep.wav"
#define TNT_DMG_MODIFIER 250.0

static const    GRENADE_LAUNCHER_OFFSET_IAMMO    = 68;

new thisRaceID;
new SKILL_ARMOR, SKILL_RELOAD, SKILL_FIRE, ULT_TNT;

new Float:fFireChance[5] = {0.0, 0.05, 0.1, 0.15, 0.2};
new Float:fReducedDamage[5] = {1.0, 0.8, 0.6, 0.4, 0.2};
new Float:fReloadSpeed[5]={1.0, 0.9, 0.8, 0.7, 0.6};

new g_iRemoteExplosive[MAXPLAYERS];
new Float:ExplosionTime[MAXPLAYERS];

new Float:UltCooldown = 60.0;

new ammoOffset;

//offsets
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
    thisRaceID = War3_CreateNewRace("Dynomite", "dynomite");
    War3_AddRaceSkill(thisRaceID, "Race specific information", "Dynomite can reload his grenade launcher at an ammo pile", false, 0);
    SKILL_ARMOR = War3_AddRaceSkill(thisRaceID, "Smartbombs", "Your grenades do 20/40/60/80% less damage to survivors", false, 4);
    SKILL_RELOAD = War3_AddRaceSkill(thisRaceID, "Rapid Reload", "You reload your grenade launcher 10/20/30/40% faster", false, 4);
    SKILL_FIRE = War3_AddRaceSkill(thisRaceID, "Fire Grenades", "5/10/15/20% chance to get a fire grenade");
    ULT_TNT = War3_AddRaceSkill(thisRaceID, "Remote Explosives", "Place remote explosives with your ult key, press it again to detonate them. CD: 60s", true, 1);
    
    War3_CreateRaceEnd(thisRaceID);
}

public OnPluginStart()
{
    if(War3_GetGame() != Game_L4D && War3_GetGame() != Game_L4D2)
        SetFailState("Only works in the L4D engine! %i", War3_GetGame());
    
    ammoOffset = FindSendPropInfo("CTerrorPlayer", "m_iAmmo");
    HookEvent("weapon_reload", EventWeaponReload);
    HookEvent("ammo_pile_weapon_cant_use_ammo", EventAmmoGet);
    
    //get offsets
    g_iNextPAttO        =    FindSendPropInfo("CBaseCombatWeapon","m_flNextPrimaryAttack");
    g_iActiveWO            =    FindSendPropInfo("CBaseCombatCharacter","m_hActiveWeapon");
    g_iPlayRateO        =    FindSendPropInfo("CBaseCombatWeapon","m_flPlaybackRate");
    g_iNextAttO            =    FindSendPropInfo("CTerrorPlayer","m_flNextAttack");
    g_iTimeIdleO        =    FindSendPropInfo("CTerrorGun","m_flTimeWeaponIdle");
    g_iViewModelO        =    FindSendPropInfo("CTerrorPlayer","m_hViewModel");
    g_iVMStartTimeO        =    FindSendPropInfo("CTerrorViewModel","m_flLayerStartTime");
    
    CreateTimer(0.3, BeepTimer, _, TIMER_REPEAT);
}

public Action:BeepTimer(Handle:timer, any:userid)
{
    for(new client=1; client <= MaxClients; client++)
    {
        if(ValidPlayer(client) && War3_GetRace(client) == thisRaceID)
        {
            new entity = g_iRemoteExplosive[client];
            if (entity > 0 && IsValidEntity(entity))
            {
                //War3_ChatMessage(0, "Would beep");
                EmitSoundToAll(SOUND_REMOTE, entity); 
            }
        }
    }
}

public OnMapStart()
{
    PrecacheModel(MODEL_TNT, true);
    
    War3_PrecacheParticle(PARTICLE_TNT);
    War3_PrecacheParticle(PARTICLE_FIRENADE);
    
    War3_AddCustomSound(SOUND_REMOTE);
    
    for(new client=1; client <= MaxClients; client++)
    {
        g_iRemoteExplosive[client] = -1;
    }
}

//=======================================================================
//                           AMMO
//=======================================================================

public Action:EventAmmoGet(Handle:hEvent, const String:strName[], bool:DontBroadcast)
{
    new client = GetClientOfUserId(GetEventInt(hEvent, "userid")); 
    new weapon = GetPlayerWeaponSlot(client, 0);
    new iWeapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
    
    if (iWeapon == weapon)
    {
        decl String:currentgunname[64];
        GetEdictClassname(iWeapon, currentgunname, sizeof(currentgunname)); 
        
        if (StrEqual(currentgunname, "weapon_grenade_launcher", false))
        {
            if(War3_GetRace(client) == thisRaceID)
            {
                SetEntData(client, ammoOffset + GRENADE_LAUNCHER_OFFSET_IAMMO, GetMaxBackupAmmo("weapon_grenade_launcher"));
            }
        }
    }
}
                    
public Action:EventWeaponReload(Handle:hEvent, const String:strName[], bool:DontBroadcast)
{
    new client = GetClientOfUserId(GetEventInt(hEvent, "userid")); 
    new weapon = GetPlayerWeaponSlot(client, 0);
    new iWeapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
    
    if (iWeapon == weapon)
    {
        decl String:currentgunname[64];
        GetEdictClassname(iWeapon, currentgunname, sizeof(currentgunname)); 
        
        if (StrEqual(currentgunname, "weapon_grenade_launcher", false))
        {
            if(War3_GetRace(client) == thisRaceID)
            {
                new skill =  War3_GetSkillLevel(client, thisRaceID, SKILL_RELOAD);
                if (skill > 0)
                {
                    AdrenReload(client);
                }
                
                new fireskill =  War3_GetSkillLevel(client, thisRaceID, SKILL_FIRE);
                if (fireskill > 0)
                {
                    if (GetRandomFloat(0.0, 1.0) <= fFireChance[fireskill])
                    {
                        new Float:fPosition[3];
                        GetClientAbsOrigin(client, fPosition);
                        
                        fPosition[2] += 10.0;
                        ThrowAwayParticle("gas_explosion_pump", fPosition, 1.0); 
                        IgniteEntity(client, 1.0);
                        
                        CheatCommand(client, "upgrade_add", "INCENDIARY_AMMO");
                    }
                }
            }
        }
    }
}  

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
    }
}

MagStart (iEntid, client)
{
    new Float:flGameTime = GetGameTime();
    new Float:flNextTime_ret = GetEntDataFloat(iEntid,g_iNextPAttO);
    
    new Float:flNextTime_calc = ( flNextTime_ret - flGameTime ) * fReloadSpeed[War3_GetSkillLevel(client, thisRaceID, SKILL_RELOAD)] ;
    SetEntDataFloat(iEntid, g_iPlayRateO, 1.0/fReloadSpeed[War3_GetSkillLevel(client, thisRaceID, SKILL_RELOAD)], true);
    CreateTimer( flNextTime_calc, Timer_MagEnd, iEntid);
    
    new Handle:hPack = CreateDataPack();
    WritePackCell(hPack, client);
    
    new Float:flStartTime_calc = flGameTime - ( flNextTime_ret - flGameTime ) * ( 1 - fReloadSpeed[War3_GetSkillLevel(client, thisRaceID, SKILL_RELOAD)] ) ;
    WritePackFloat(hPack, flStartTime_calc);
    
    if ( (flNextTime_calc - 0.4) > 0 )
        CreateTimer( flNextTime_calc - 0.4 , Timer_MagEnd2, hPack);
    
    flNextTime_calc += flGameTime;
    
    SetEntDataFloat(iEntid, g_iTimeIdleO, flNextTime_calc, true);
    SetEntDataFloat(iEntid, g_iNextPAttO, flNextTime_calc, true);
    SetEntDataFloat(client, g_iNextAttO, flNextTime_calc, true);
    
}

stock CheatCommand(client, String:command[], String:arguments[]="")
{
    new userflags = GetUserFlagBits(client);
    SetUserFlagBits(client, ADMFLAG_ROOT);
    new flags = GetCommandFlags(command);
    SetCommandFlags(command, flags & ~FCVAR_CHEAT);
    FakeClientCommand(client, "%s %s", command, arguments);
    SetCommandFlags(command, flags);
    SetUserFlagBits(client, userflags);
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
//                           TNT
//=======================================================================

public OnUltimateCommand(client,race,bool:pressed)
{
    if(ValidPlayer(client, true) && 
       race == thisRaceID && 
       pressed && 
       War3_SkillNotInCooldown(client, thisRaceID, ULT_TNT, true) && 
       !Silenced(client) &&
       GetClientTeam(client) == TEAM_SURVIVORS &&
       !War3_L4D_IsHelpless(client) &&
       !War3_IsPlayerIncapped(client))
    {    
        new skill = War3_GetSkillLevel(client, thisRaceID, ULT_TNT);
        if(skill > 0)
        {
            if(g_iRemoteExplosive[client] == -1)
            {
                new flags = GetEntityFlags(client);
                if(flags & FL_ONGROUND)
                {
                    // Plant a new one
                    new Float:CasterPosition[3];
                    GetClientAbsOrigin(client, CasterPosition);
                    
                    new entity = CreateEntityByName("prop_dynamic_override");
                    if (IsValidEntity(entity))
                    {
                        DispatchKeyValue(entity, "model", MODEL_TNT);
        
                        DispatchSpawn(entity);
                        TeleportEntity(entity, CasterPosition, NULL_VECTOR, NULL_VECTOR);
        
                        SetEntProp(entity, Prop_Data, "m_takedamage", 0, 1);  
                        SetEntityMoveType(entity, MOVETYPE_NOCLIP);    
                        SetEntProp(entity, Prop_Data, "m_CollisionGroup", 2); 
        
                        //CreateW3SParticle(PARTICLE_TNT, CasterPosition)
                        CasterPosition[2] += 10;
                        AttachParticle(entity, PARTICLE_TNT, CasterPosition, "");
                        
                        g_iRemoteExplosive[client] = entity;
                        
                        //War3_CooldownMGR(client, UltCooldown, thisRaceID, ULT_TNT);
                    }
                }
            }
            else
            {
                // Detonate!
                new Float:CasterPosition[3];
                GetEntPropVector(g_iRemoteExplosive[client], Prop_Send, "m_vecOrigin", CasterPosition);

                // Remember the explosion time so we can up the damage
                // for the next few ticks of damage that were caused
                // by this player. This should get almost all the damage
                // caused by the ultimate. It might be that similiar damage
                // like propane next to your tnt might also get enhanced
                War3_L4D_Explode(client, CasterPosition, 1);
                ExplosionTime[client] = GetEngineTime() + 0.003;
                
                AcceptEntityInput(g_iRemoteExplosive[client], "kill");
                
                g_iRemoteExplosive[client] = -1;
                
                War3_CooldownMGR(client, UltCooldown, thisRaceID, ULT_TNT);
            }
        }
        
    }
}

public OnRaceChanged(client, oldrace, newrace)
{
    if(newrace != thisRaceID)
    {
        if (g_iRemoteExplosive[client] > 0 && IsValidEntity(g_iRemoteExplosive[client]))
        {
            AcceptEntityInput(g_iRemoteExplosive[client], "kill");
        }
    }
}

public OnW3TakeDmgAllPre(victim, attacker, Float:damage)
{
    if (ValidPlayer(attacker, true) && War3_GetRace(attacker) == thisRaceID)
    {
        if (ExplosionTime[attacker] > GetEngineTime())
        {
            new inflictor = W3GetDamageInflictor();
            if (inflictor != attacker && ((War3_IsL4DZombieEntity(victim)) || (ValidPlayer(victim) && GetClientTeam(victim) == TEAM_INFECTED)))
            {
                War3_DamageModPercent(TNT_DMG_MODIFIER);
            }
        }
        
        if (ValidPlayer(victim, true) && GetClientTeam(victim) == TEAM_SURVIVORS && attacker != victim)
        {
            new skill = War3_GetSkillLevel(attacker, thisRaceID, SKILL_ARMOR);
            if (skill > 0 && (W3GetDamageType() & (DMG_BLAST | DMG_AIRBOAT)))
            {
                new inflictor = W3GetDamageInflictor();
                decl String:currentgunname[64];
                GetEdictClassname(inflictor, currentgunname, sizeof(currentgunname));
                
                if (StrEqual(currentgunname, "grenade_launcher_projectile"))
                {
                    War3_DamageModPercent(fReducedDamage[skill]);
                }
            }
        }
    }
}