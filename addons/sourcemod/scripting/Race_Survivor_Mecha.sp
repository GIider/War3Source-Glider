
#pragma semicolon 1

#include "W3SIncs/War3Source_Interface"
#include <sdkhooks>

public Plugin:myinfo = 
{
    name = "War3Source Race - L4D Survivor Mecha",
    author = "Glider",
    description = "The Survivor Mecha race for War3Source.",
    version = "1.0",
}; 



//=======================================================================
//                             VARIABLES
//=======================================================================

#define SOUND_FLAME        "ambient/gas/steam2.wav"

new thisRaceID;
new SKILL_GRAVITY, SKILL_LEGS, SKILL_GUNS, ULT_JETPACK;

new Float:SpeedBuff[5]={0.7, 0.8, 0.9, 1.0, 1.1};
new Float:GravityBuff[5]={1.0, 0.9, 0.8, 0.7, 0.6};
new Float:AmmoRegen[5]={0.0, 0.02, 0.03, 0.04, 0.05};

new MechaBackpack[MAXPLAYERS][2];
new JetPackB1Flame[MAXPLAYERS][3];
new JetPackB2Flame[MAXPLAYERS][3];
new bool:IsFlying[MAXPLAYERS];

new LastButton[MAXPLAYERS]; 
new Float:LastTime[MAXPLAYERS]; 
new Float:Gravity[MAXPLAYERS];
new Float:Fuel[MAXPLAYERS]; 
new Float:LostPos[MAXPLAYERS][3];
new Float:MaxFuel = 350.0;
new Float:FuelChargeRate = 1.0;

new g_iVelocity ;
//=======================================================================
//                                 INIT
//=======================================================================

public OnWar3PluginReady(){
    thisRaceID = War3_CreateNewRace("Mecha", "mecha");
    SKILL_GRAVITY = War3_AddRaceSkill(thisRaceID, "Mecha gravity booster", "This skill gives you 10/20/30/40% less gravity", false, 4);
    SKILL_LEGS = War3_AddRaceSkill(thisRaceID, "Mecha legs", "You start out with 70% movement speed.\nThis skill enhances it to 80/90/100/110", false, 4);
    SKILL_GUNS = War3_AddRaceSkill(thisRaceID, "Mecha guns", "You automatically reload 2/3/4/5% of your magazine each second", false, 4);
    ULT_JETPACK = War3_AddRaceSkill(thisRaceID, "Mecha jetpack", "Toggles your self-recharging jetpack. Can only be started while standing on the ground!", true, 1);
    
    War3_CreateRaceEnd(thisRaceID);
}

public OnPluginStart()
{
    if(War3_GetGame() != Game_L4D && War3_GetGame() != Game_L4D2)
        SetFailState("Only works in the L4D engine! %i", War3_GetGame());
    
    CreateTimer(1.0, ChargeGunTimer, _, TIMER_REPEAT);
    CreateTimer(0.1, ChargeFuelTimer, _, TIMER_REPEAT);
    CreateTimer(1.0, NotificationTimer, _, TIMER_REPEAT);
    
    g_iVelocity = FindSendPropOffs("CBasePlayer", "m_vecVelocity[0]");
}

public OnMapStart()
{
    War3_AddCustomSound(SOUND_FLAME);
}

//=======================================================================
//                                 Mecha Legs
//=======================================================================
 
RemoveAttachments(client)
{
    decl String:className[64];
    if(IsValidEdict(MechaBackpack[client][0]))
    {
        GetEdictClassname(MechaBackpack[client][0], className, sizeof(className));
        if(StrEqual(className, "prop_dynamic"))
        {
            AcceptEntityInput(MechaBackpack[client][0], "kill");
            AcceptEntityInput(MechaBackpack[client][1], "kill");
            
            AcceptEntityInput(JetPackB1Flame[client][0], "kill");
            AcceptEntityInput(JetPackB1Flame[client][1], "kill");
            AcceptEntityInput(JetPackB1Flame[client][2], "kill");
            
            AcceptEntityInput(JetPackB2Flame[client][0], "kill");
            AcceptEntityInput(JetPackB2Flame[client][1], "kill");
            AcceptEntityInput(JetPackB2Flame[client][2], "kill");
                        
            MechaBackpack[client][0] = 0;
            MechaBackpack[client][1] = 0;
            
            JetPackB1Flame[client][0] = 0;
            JetPackB1Flame[client][1] = 0;
            JetPackB1Flame[client][2] = 0;
                        
            JetPackB2Flame[client][0] = 0;
            JetPackB2Flame[client][1] = 0;
            JetPackB2Flame[client][2] = 0;
        }
    }
}

giveBuffedGravity(client)
{
    new skill_grav = War3_GetSkillLevel(client, thisRaceID, SKILL_GRAVITY);
    War3_SetBuff(client, fLowGravitySkill, thisRaceID, GravityBuff[skill_grav]);
}

givePlayerBuffs(client)
{
    if(ValidPlayer(client, true) && GetClientTeam(client) == TEAM_SURVIVORS)
    {
        if(War3_GetRace(client) == thisRaceID)
        {
            new skill_mspd = War3_GetSkillLevel(client, thisRaceID, SKILL_LEGS);
            new Float:speed_buff = SpeedBuff[skill_mspd];
            
            if (speed_buff <= 1.0) 
                War3_SetBuff(client, fSlow, thisRaceID, speed_buff);
            else 
                War3_SetBuff(client, fMaxSpeed, thisRaceID, speed_buff);
            
            giveBuffedGravity(client);

            decl String:className[64];
            if(IsValidEdict(MechaBackpack[client][0]))
                GetEdictClassname(MechaBackpack[client][0], className, sizeof(className));
            
            if(!StrEqual(className, "prop_dynamic"))
            {
                MechaBackpack[client][0] = CreateJetPack(client, 0);
                MechaBackpack[client][1] = CreateJetPack(client, 1);
                
                AttachFlame(MechaBackpack[client][0], JetPackB1Flame[client]);
                AttachFlame(MechaBackpack[client][1], JetPackB2Flame[client]);
                
                if (War3_GetSkillLevel(client, thisRaceID, ULT_JETPACK) > 0)
                {
                    AcceptEntityInput(JetPackB1Flame[client][0], "TurnOn");
                    AcceptEntityInput(JetPackB2Flame[client][0], "TurnOn");
                }
            }
        }
    }
}

public OnWar3EventSpawn(client)
{
    if(War3_GetRace(client) == thisRaceID)
    {
        givePlayerBuffs(client);
        StopFlying(client);
    }
}

public OnWar3EventDeath(victim, attacker)
{
    if(War3_GetRace(victim) == thisRaceID)
    {
        RemoveAttachments(victim);
        StopFlying(victim);
    }
}

public OnRaceChanged(client, oldrace, newrace)
{
    if(newrace != thisRaceID && oldrace == thisRaceID)
    {
        War3_SetBuff(client, fSlow, thisRaceID, 1.0);
        War3_SetBuff(client, fMaxSpeed, thisRaceID, 1.0);
        War3_SetBuff(client, fLowGravitySkill, thisRaceID, 1.0);
        RemoveAttachments(client);
        StopFlying(client);
    }
    else if (newrace == thisRaceID)
    {    
        givePlayerBuffs(client);
    }
}

public OnSkillLevelChanged(client, race, skill, newskilllevel)
{
    if (race == thisRaceID)
    {
        givePlayerBuffs(client);
    
        if (skill == ULT_JETPACK && newskilllevel > 0)
        {
            AcceptEntityInput(JetPackB1Flame[client][0] , "TurnOn");
            AcceptEntityInput(JetPackB2Flame[client][0] , "TurnOn");
        }
    }
}

//=======================================================================
//                                 Jetpack Notifier
//=======================================================================

public Action:NotificationTimer(Handle:timer, any:userid)
{
    for(new client=1; client <= MaxClients; client++)
    {
        if(ValidPlayer(client, true))
        {
            if(War3_GetRace(client) == thisRaceID)
            {
                new len = 0;
                decl String:message[50];
                
                new skill = War3_GetSkillLevel(client, thisRaceID, ULT_JETPACK);
                if (skill > 0)
                {
                    new fuel_status = RoundToCeil(Fuel[client] / MaxFuel * 100.0);
                    len += Format(message[len], sizeof(message)-len, "FUEL STATUS: %i percent", fuel_status);
                    
                    if (IsFlying[client])
                    {
                        len += Format(message[len], sizeof(message)-len, " (FLYING)");
                    }
                }
                
                W3Hint(client, HINT_COOLDOWN_COUNTDOWN, 1.0, message);
            }
        }
    }
}

public OnW3TakeDmgAllPre(victim,attacker,Float:damage){
    if(ValidPlayer(victim, true))
    {
        if(War3_GetRace(victim) == thisRaceID)
        {
            decl String:className[64];
            GetEntityNetClass(attacker, className, sizeof(className));
            
            if(StrEqual(className, "Tank") && IsFlying[victim])
            {
                StopFlying(victim);
            }
        }
    }
}

//=======================================================================
//                                 Mecha Guns
//=======================================================================


public Action:ChargeGunTimer(Handle:timer, any:userid)
{
    for(new client=1; client <= MaxClients; client++)
    {
        if(ValidPlayer(client, true))
        {
            if(War3_GetRace(client) == thisRaceID)
            {
                new skill = War3_GetSkillLevel(client, thisRaceID, SKILL_GUNS);
                if (skill > 0) {
                    decl String:weapon[64];
                    new primary = GetPlayerWeaponSlot(client, 0);
                    
                    if (IsValidEntity(primary) && !GetEntProp(primary, Prop_Send, "m_bInReload")) {
                        GetEdictClassname(primary, weapon, sizeof(weapon));
                        
                        if(!StrEqual(weapon, "weapon_grenade_launcher") && !StrEqual(weapon, "weapon_rifle_m60")) {
                            new current_ammo = GetEntProp(primary, Prop_Send, "m_iClip1");
                            new max_mag_size = GetMaxMagSize(weapon);
                            
                            new ammo_missing = max_mag_size - current_ammo;
                            if (current_ammo < max_mag_size) {
                                new backup_ammo = GetCurrentBackupAmmo(client);
                                
                                // This is how much we could theoretically regen
                                new ammo_to_regen = RoundToCeil(max_mag_size * AmmoRegen[skill]);
                                
                                // This is how much we can actually regen, in case we have less backup available or we need less than we can regen
                                new new_ammo = Min(Min(backup_ammo, ammo_to_regen), ammo_missing);
                                
                                //PrintToChatAll("Removing ammo: %i - %i = %i", backup_ammo, new_ammo, backup_ammo - new_ammo);
                                SetBackupAmmo(client, backup_ammo - new_ammo);
                                
                                //PrintToChatAll("Setting your ammo from %i to %i", current_ammo, current_ammo + new_ammo);
                                SetEntProp(primary, Prop_Send, "m_iClip1", current_ammo + new_ammo);
                            }
                        }
                    }
                }
            }
        }
    }
}

//=======================================================================
//                                 Mecha Jetpack
//=======================================================================

/* I'M TOO LAZY TO CORRECT THE SPELLING ERRORS AND SHIT IN THE JETPACK CODE.
 * I JUST STOLE IT FROM panxiaohai, THEN TWEAKED IT (CHANGED THE WAY
 * YOU CONTROL THE JETPACK SINCE I DIDN'T LIKE THE ORIGINAL, REMOVED SOME
 * THINGS, ADDED SOME THINGS YADDA YADDA)
 */

public Action:ChargeFuelTimer(Handle:timer, any:userid)
{
    for(new client=1; client <= MaxClients; client++)
    {
        if(ValidPlayer(client, true))
        {
            if(War3_GetRace(client) == thisRaceID)
            {
                if (Fuel[client] < MaxFuel)
                {
                    if (IsFlying[client])
                    {
                        Fuel[client] += FuelChargeRate * 0.5;
                    }
                    else
                    {
                        Fuel[client] += FuelChargeRate;
                    }
                } 
                
                if (Fuel[client] > MaxFuel)
                {
                    Fuel[client] = MaxFuel;
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
       War3_SkillNotInCooldown(client, thisRaceID, ULT_JETPACK, true) && 
       !Silenced(client) &&
       GetClientTeam(client) == TEAM_SURVIVORS &&
       !War3_L4D_IsHelpless(client) &&
       !War3_IsPlayerIncapped(client))
    {    
        new skill = War3_GetSkillLevel(client, thisRaceID, ULT_JETPACK);
        if (skill > 0 && Fuel[client] > 0.0)
        {
            IsFlying[client] = !IsFlying[client];
            
            if (IsFlying[client])
            {
                new flag=GetEntityFlags(client);
                if(flag & FL_ONGROUND)  
                {        
                    // Launch them off the ground! - doesn't really work since we change the movement type right after
                    decl Float:cVel[3];
                    cVel[0] = 0.0;
                    cVel[1] = 0.0;
                    cVel[2] = 3000.0;
                    
                    TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, cVel);
                    
                    SetEntityMoveType(client, MOVETYPE_FLYGRAVITY);
                    SDKHook( client, SDKHook_PreThink,  PreThink);
                    
                    Gravity[client]=0.01;
                    AcceptEntityInput(JetPackB1Flame[client][1], "TurnOn");     
                    AcceptEntityInput(JetPackB2Flame[client][1], "TurnOn");     
                    new Float:vecPos[3];
                    GetClientAbsOrigin(client, vecPos);
                    EmitSoundToAll(SOUND_FLAME, client, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, 0.5, SNDPITCH_NORMAL, -1, vecPos, NULL_VECTOR, true, 0.0);
                    
                    //GotoThirdPersonVisible(client);
                }
                else
                {
                    IsFlying[client] = !IsFlying[client];
                    W3Hint(client, HINT_SKILL_STATUS, 3.0, "You need to stand on the ground to activate the jetpack!");
                }
            }
            else
            {
                StopFlying(client);
            }
        }
    }
}

StopFlying(client)
{
    IsFlying[client] = false;
    SDKUnhook( client, SDKHook_PreThink,  PreThink);
    
    StopSound(client, SNDCHAN_AUTO, SOUND_FLAME);
    AcceptEntityInput(JetPackB1Flame[client][1], "TurnOff");
    AcceptEntityInput(JetPackB1Flame[client][2], "TurnOff");
    AcceptEntityInput(JetPackB2Flame[client][1], "TurnOff");
    AcceptEntityInput(JetPackB2Flame[client][2], "TurnOff");
    
    SetEntityMoveType(client, MOVETYPE_WALK); 
    giveBuffedGravity(client);
    
    //GotoFirstPerson(client); 
}

public PreThink(client)
{
    if (ValidPlayer(client, true))
    {
        if (War3_L4D_IsHelpless(client) || War3_IsPlayerIncapped(client))
        {
            StopFlying(client);
        }
        else
        {
            new Float:time=GetEngineTime( );
            new Float:intervual=time-LastTime[client]; 
            new button=GetClientButtons(client); 
            Fly(client,button , intervual); 
            LastTime[client]=time; 
            LastButton[client]=button;     
        }
    }
}

Fly(client, button, Float:intervual)
{            
    decl Float:clientAngle[3]; 
    decl Float:clientPos[3];  
    decl Float:temp[3]; 
    decl Float:volicity[3]; 
    decl Float:pushForce[3]; 
    decl Float:pushForceVertical[3]; 
    new Float:liftForce=50.0; 
    new Float:speedLimit=100.0;
    new Float:fuelUsed=1.5;
    new Float:gravity=0.001;
    new Float:gravityNormal=0.01;
    GetEntDataVector(client, g_iVelocity, volicity);
    GetClientEyeAngles(client, clientAngle);
    GetClientAbsOrigin(client, clientPos);
    CopyVector(clientPos,LostPos[client]);
    clientAngle[0]=0.0;
    
    SetVector(pushForce, 0.0, 0.0, 0.0);
    SetVector(pushForceVertical, 0.0, 0.0,  0.0);
    new bool:up=false;
    new bool:down=false;
    new bool:move=false;
    new controlmode=1;
    new flame=0;
    if((button & IN_JUMP) ) 
    { 
        SetVector(pushForceVertical, 0.0, 0.0, 15.0);
        up=true;
        if(!(LastButton[client] & IN_JUMP))
        {
            flame=1; 
        }
        if(gravity>0.0)gravity=-0.01;
        gravity=Gravity[client]-1.0*intervual; 
    }
    else
    {
        if((LastButton[client] & IN_JUMP))
        {
            flame=2;
        }
    }
    if((button & IN_DUCK) && !up) 
    { 
        SetVector(pushForceVertical, 0.0, 0.0, -15.0);
        down=true; 
        if(gravity<0.0)gravity=0.01;
        gravity=Gravity[client]+1.0*intervual;  
    }

    if(button & IN_FORWARD)// && !up)
    { 
        GetAngleVectors(clientAngle, temp, NULL_VECTOR, NULL_VECTOR);
        NormalizeVector(temp,temp); 
        AddVectors(pushForce,temp,pushForce); 
        move=true;
    }
    else if(button & IN_BACK) // && !up)
    {
        GetAngleVectors(clientAngle, temp, NULL_VECTOR, NULL_VECTOR);
        NormalizeVector(temp,temp); 
        SubtractVectors(pushForce, temp, pushForce); 
        move=true;
    }
    if(button & IN_MOVELEFT)// && !up)
    { 
        GetAngleVectors(clientAngle, NULL_VECTOR, temp, NULL_VECTOR);
        NormalizeVector(temp,temp); 
        SubtractVectors(pushForce,temp,pushForce);
        move=true;
    }
    else if(button & IN_MOVERIGHT) //&& !up)
    {
        GetAngleVectors(clientAngle, NULL_VECTOR, temp, NULL_VECTOR);
        NormalizeVector(temp,temp); 
        AddVectors(pushForce,temp,pushForce);
        move=true;
    }
    if(move && up)
    {
        ScaleVector(pushForceVertical, 0.3);
        ScaleVector(pushForce, 1.5);
    }
    //NormalizeVector(pushForce, pushForce); 
    if(up || down)
    { 
        speedLimit*=1.5;
        liftForce*=2.0;
    }
     
    AddVectors(pushForceVertical,pushForce,pushForce);
    NormalizeVector(pushForce, pushForce);
    //ShowDir(client, clientPos, pushForce, 0.06);
    //PrintToChatAll("v %f", GetVectorLength(volicity));
    ScaleVector(pushForce,liftForce*intervual);
    if(!(up || down))
    {             
        if(FloatAbs(volicity[2])>40.0)gravity=volicity[2]*intervual;
        else gravity=gravityNormal;
        
        if(controlmode==0)
        {
            if(volicity[2] >30.0)volicity[2]-=200.0*intervual; 
            else if(volicity[2] <-10.0)volicity[2]+=200.0*intervual; 
        }
        
    }
    new Float:v=GetVectorLength(volicity);
    if(controlmode==0)
    {
        
        if(v>speedLimit)
        {
            NormalizeVector(volicity,volicity);
            ScaleVector(volicity, speedLimit);
        }
        AddVectors(volicity,pushForce,volicity);
        War3_SetBuff(client, fLowGravitySkill, thisRaceID, 0.01);
        TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, volicity);
    }
    else 
    {
        if(gravity>0.5)gravity=0.5;
        if(gravity<-0.5)gravity=-0.5; 
        
        
        if(v>speedLimit)
        {
            NormalizeVector(volicity,volicity);
            ScaleVector(volicity, speedLimit);
            TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, volicity);
            gravity=gravityNormal ;
        }
        War3_SetBuff(client, fLowGravitySkill, thisRaceID, gravity);
        Gravity[client]=gravity;
    }
    
    Fuel[client]-=fuelUsed;        
    if(Fuel[client]<=0.0)
    {
        W3Hint(client, HINT_SKILL_STATUS, 1.0, "RAN OUT OF FUEL!!");
        StopFlying(client);
    }
    
    if(flame==1)
    {
        AcceptEntityInput(JetPackB1Flame[client][1], "TurnOn");    
        AcceptEntityInput(JetPackB1Flame[client][2], "TurnOn");    
        AcceptEntityInput(JetPackB2Flame[client][1], "TurnOn");    
        AcceptEntityInput(JetPackB2Flame[client][2], "TurnOn");    
        new Float:vecPos[3];
        GetClientAbsOrigin(client, vecPos);
        StopSound(client, SNDCHAN_AUTO, SOUND_FLAME);
        EmitSoundToAll(SOUND_FLAME, client, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0, SNDPITCH_NORMAL, -1, vecPos, NULL_VECTOR, true, 0.0);
            
    }
    else if(flame==2)
    {
        AcceptEntityInput(JetPackB1Flame[client][2], "TurnOff");
        AcceptEntityInput(JetPackB2Flame[client][2], "TurnOff");
        new Float:vecPos[3];
        GetClientAbsOrigin(client, vecPos);
        StopSound(client, SNDCHAN_AUTO, SOUND_FLAME);
        EmitSoundToAll(SOUND_FLAME, client, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, 0.5, SNDPITCH_NORMAL, -1, vecPos, NULL_VECTOR, true, 0.0);
    }  
}

// number must be 1 or 2
CreateJetPack(client, number)
{
    new Float:pos[3];
    new Float:ang[3];
    GetClientEyePosition(client, pos);
    GetClientAbsAngles(client, ang);
    new jetpack=CreateEntityByName("prop_dynamic_override"); 
    DispatchKeyValue(jetpack, "model", "models/props_equipment/oxygentank01.mdl");  
    DispatchSpawn(jetpack); 
    SetEntProp(jetpack, Prop_Data, "m_takedamage", 0, 1);  
    SetEntityMoveType(jetpack, MOVETYPE_NOCLIP);    
    SetEntProp(jetpack, Prop_Data, "m_CollisionGroup", 2); 
    AttachJetPack(jetpack, client);     
    decl Float:ang3[3];
    SetVector(ang3, 0.0, 0.0, 1.0); 
    GetVectorAngles(ang3, ang3); 
    CopyVector(ang,ang3);

    ang3[2] += 270.0; 
    ang3[1] -= 10.0;
    
    if (number == 1)
        SetVector(pos,  0.0,  -5.0,  4.0);
    else
        SetVector(pos, 0.0, -5.0, -4.0);
    
    DispatchKeyValueVector(jetpack, "origin", pos);  
    DispatchKeyValueVector(jetpack, "Angles", ang3); 
    TeleportEntity(jetpack, pos, NULL_VECTOR, ang3);     
 
    SetEntProp(jetpack, Prop_Send, "m_iGlowType", 3 ); //3
    SetEntProp(jetpack, Prop_Send, "m_nGlowRange", 0 ); //0
    SetEntProp(jetpack, Prop_Send, "m_glowColorOverride", 1); //1    
    
    SDKHook(jetpack, SDKHook_SetTransmit, Hook_SetTransmit);
    
    return     jetpack;
}

public Action:Hook_SetTransmit(jetpack, client)
{ 
    if ((jetpack == MechaBackpack[client][0]) || (jetpack == MechaBackpack[client][1]))
    {
        if(!IsFlying[client])  
        {
            return Plugin_Handled; 
        }
        
        // Make it invisible to the user when he's crouching
        /*new flags = GetEntityFlags(client);
        if((flags & FL_DUCKING) && (!IsFlying[client]))  
        {
            return Plugin_Handled; 
        }*/
        /*else
        {
            if (War3_GetSkillLevel(client, thisRaceID, ULT_JETPACK) > 0)
            {
                AcceptEntityInput(JetPackB1Flame[client][0], "TurnOn");
                AcceptEntityInput(JetPackB2Flame[client][0], "TurnOn");
            }
        }*/
    }
    
    return Plugin_Continue;
}

AttachJetPack(ent, owner)
{
    if(ValidPlayer(owner, true) && GetClientTeam(owner) == TEAM_SURVIVORS)
    {
        decl String:sTemp[16];
        Format(sTemp, sizeof(sTemp), "target%d", owner);
        DispatchKeyValue(owner, "targetname", sTemp);
        SetVariantString(sTemp);
        AcceptEntityInput(ent, "SetParent", ent, ent, 0);
        SetVariantString("medkit");
        AcceptEntityInput(ent, "SetParentAttachment");
    }     
}

AttachFlame( ent, flames[3] )
{
    decl String:flame_name[128];
    Format(flame_name, sizeof(flame_name), "target%d", ent);
    new flame = CreateEntityByName("env_steam");
    DispatchKeyValue( ent,"targetname", flame_name);
    DispatchKeyValue(flame,"parentname", flame_name);
    DispatchKeyValue(flame,"SpawnFlags", "1");
    DispatchKeyValue(flame,"Type", "0");
 
    DispatchKeyValue(flame,"InitialState", "1");
    DispatchKeyValue(flame,"Spreadspeed", "1");
    DispatchKeyValue(flame,"Speed", "250");
    DispatchKeyValue(flame,"Startsize", "2");
    DispatchKeyValue(flame,"EndSize", "4");
    DispatchKeyValue(flame,"Rate", "555");
    DispatchKeyValue(flame,"RenderColor", "10 52 99"); 
    DispatchKeyValue(flame,"JetLength", "20"); 
    DispatchKeyValue(flame,"RenderAmt", "180");
    
    DispatchSpawn(flame);     
    SetVariantString(flame_name);
    AcceptEntityInput(flame, "SetParent", flame, flame, 0);
    
    new Float:origin[3];
    SetVector(origin,  -2.0, 0.0,  26.0);
    decl Float:ang[3];
    SetVector(ang, 0.0, 0.0, 1.0); 
    GetVectorAngles(ang, ang); 
    TeleportEntity(flame, origin, ang,NULL_VECTOR);    
    AcceptEntityInput(flame, "TurnOff");
    
 
    new flame2 = CreateEntityByName("env_steam");
    DispatchKeyValue( ent,"targetname", flame_name);
    DispatchKeyValue(flame2,"parentname", flame_name);
    DispatchKeyValue(flame2,"SpawnFlags", "1");
    DispatchKeyValue(flame2,"Type", "0");
 
    DispatchKeyValue(flame2,"InitialState", "1");
    DispatchKeyValue(flame2,"Spreadspeed", "1");
    DispatchKeyValue(flame2,"Speed", "300");
    DispatchKeyValue(flame2,"Startsize", "3");
    DispatchKeyValue(flame2,"EndSize", "10");
    DispatchKeyValue(flame2,"Rate", "555");
    DispatchKeyValue(flame2,"RenderColor", "50 30 255");//"16 85 160" 
    DispatchKeyValue(flame2,"JetLength", "50"); 
    DispatchKeyValue(flame2,"RenderAmt", "180");
    
    DispatchSpawn(flame2);     
    SetVariantString(flame_name);
    AcceptEntityInput(flame2, "SetParent", flame2, flame2, 0);
    TeleportEntity(flame2, origin, ang,NULL_VECTOR);
    AcceptEntityInput(flame2, "TurnOff");
    
    new flame3 = CreateEntityByName("env_steam");
    DispatchKeyValue( ent,"targetname", flame_name);
    DispatchKeyValue(flame3,"SpawnFlags", "1");
    DispatchKeyValue(flame3,"Type", "0");
    DispatchKeyValue(flame3,"InitialState", "1");
    DispatchKeyValue(flame3,"Spreadspeed", "10");
    DispatchKeyValue(flame3,"Speed", "350");
    DispatchKeyValue(flame3,"Startsize", "5");
    DispatchKeyValue(flame3,"EndSize", "15");
    DispatchKeyValue(flame3,"Rate", "555");
    DispatchKeyValue(flame3,"RenderColor", "242 55 55"); 
    DispatchKeyValue(flame3,"JetLength", "70"); 
    DispatchKeyValue(flame3,"RenderAmt", "180");
    
    DispatchSpawn(flame3);     
    SetVariantString(flame_name);
    AcceptEntityInput(flame3, "SetParent", flame2, flame2, 0);
    TeleportEntity(flame3, origin, ang,NULL_VECTOR);
    AcceptEntityInput(flame3, "TurnOff");    
    
    flames[0]=flame;
    flames[1]=flame2; 
    flames[2]=flame3; 
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

Min(x, y)
{
    if (x > y)
        return y;
    
    return x;
}