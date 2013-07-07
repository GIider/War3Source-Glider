#pragma semicolon 1

#include "W3SIncs/War3Source_Interface"

public Plugin:myinfo = 
{
    name = "War3Source Race - L4D Survivor Expert",
    author = "Glider",
    description = "The Survivor Expert race for War3Source.",
    version = "1.0",
};

//=======================================================================
//                             VARIABLES
//=======================================================================

#define PARTICLE_AMMOPILE "weapon_pipebomb_blinking_light"
#define PARTICLE_LAUNCHER "gas_explosion_pump"
#define MAXENTITYS 2048
new Float:ULT_COOLDOWN = 180.0;
new Float:ABILITY_COOLDOWN = 25.0;

new thisRaceID;
new SKILL_SUPER_SENSE, ABILITY_GRENADELAUNCHER, SKILL_INCREASED_AMMO, ULTIMATE_AMMOSHARER;

new Float:GrenadeRange = 600.0;
new GrenadeDamage[5]={0, 75, 100, 125, 150};
new Float:SenseDistance[5]={0.0, 100.0, 200.0, 300.0, 400.0};
new Float:ExtraAmmo[5]={1.0, 1.1, 1.2, 1.3, 1.4};
new bool:EntityWasMarked[MAXENTITYS][MAXPLAYERS];
new bool:PlayerWasMarked[MAXENTITYS][MAXPLAYERS];

new g_iVelocity;
new GrenadeLauncher[MAXPLAYERS+1];

new String:GrenadeSnd[]="weapons/grenade_launcher/grenadefire/grenade_launcher_explode_1.wav";
new String:GrenadeShootSnd[]="weapons/grenade_launcher/grenadefire/grenade_launcher_fire_1.wav";

//=======================================================================
//                                 INIT
//=======================================================================

public OnWar3PluginReady(){
    thisRaceID = War3_CreateNewRace("Weapon Expert", "expert");
    SKILL_SUPER_SENSE = War3_AddRaceSkill(thisRaceID, "Super Sense", "Mark nearby infected in a radius of 100/200/300/400 units.\nOnly half as efficient on Special Infected and does not mark Witches at all!", false, 4);
    SKILL_INCREASED_AMMO = War3_AddRaceSkill(thisRaceID, "Increased Ammo", "You take 10/20/30/40% more ammo from a ammopile.", false, 4);
    ABILITY_GRENADELAUNCHER = War3_AddRaceSkill(thisRaceID, "Grenade Launcher (+zoom)", "Enables you to fire grenades by pressing +zoom with a Assault Rifle or Automatic Shotgun.\nDeals 75/100/125/150 damage in the center with a linear falloff.\n CD: 25, consumes a magazine", false, 4);
    ULTIMATE_AMMOSHARER = War3_AddRaceSkill(thisRaceID, "Create Ammopile", "Creates a ammo pile that lasts for 20 seconds. CD: 180s", true, 1);
    
    War3_CreateRaceEnd(thisRaceID);
}

public OnPluginStart()
{
    if(War3_GetGame() != Game_L4D && War3_GetGame() != Game_L4D2)
        SetFailState("Only works in the L4D engine! %i", War3_GetGame());
    
    g_iVelocity = FindSendPropOffs("CBasePlayer","m_vecVelocity[0]");
    CreateTimer(0.1, SuperSenseTimer, _, TIMER_REPEAT);
    
    HookEvent("grenade_bounce", grenade_bounce);
    HookEvent("player_use", Event_PlayerUse);
    HookEvent("ammo_pickup", Event_AmmoPickup);
}

public OnMapStart()
{
    PrecacheModel("models/w_models/weapons/w_HE_grenade.mdl", true);
    War3_AddCustomSound(GrenadeSnd);
    War3_AddCustomSound(GrenadeShootSnd);
    War3_PrecacheParticle(PARTICLE_AMMOPILE);
    War3_PrecacheParticle(PARTICLE_LAUNCHER);
}

//=======================================================================
//                                 INCREASED AMMO
//=======================================================================

public Event_PlayerUse(Handle:event, const String:name[], bool:dontBroadcast)
{
    new client = GetClientOfUserId(GetEventInt(event,"userid"));
    new iEntity = GetEventInt(event, "targetid");    

    if (IsValidEntity(iEntity))
    {
        decl String:entityName[64];
        GetEdictClassname(iEntity, entityName, sizeof(entityName));

        if (StrEqual(entityName, "weapon_ammo_spawn"))
        {
            if(War3_GetRace(client) == thisRaceID)
            {
                new skill = War3_GetSkillLevel(client, thisRaceID, SKILL_INCREASED_AMMO);
                if (skill > 0)
                {
                    new oldgun = GetPlayerWeaponSlot(client, 0); //get the players primary weapon
                    if (IsValidEdict(oldgun))
                    {
                        decl String:currentgunname[64];
                        GetEdictClassname(oldgun, currentgunname, sizeof(currentgunname)); //get the primary weapon name
                        
                        new max_ammo = GetMaxBackupAmmo(currentgunname);
                        new new_max_ammo = RoundToCeil(max_ammo * ExtraAmmo[skill]);
        
                        if (!StrEqual(currentgunname, "weapon_grenade_launcher")) {
                            SetBackupAmmo(client, new_max_ammo);
                        }
                    }
                }
            }
        }
    }
}

public Event_AmmoPickup(Handle:event, const String:name[], bool:dontBroadcast)
{
    new client = GetClientOfUserId(GetEventInt(event,"userid"));
    if(War3_GetRace(client) == thisRaceID)
    {
        new skill = War3_GetSkillLevel(client, thisRaceID, SKILL_INCREASED_AMMO);
        if (skill > 0)
        {
            new oldgun = GetPlayerWeaponSlot(client, 0); //get the players primary weapon
            if (IsValidEdict(oldgun))
            {
                decl String:currentgunname[64];
                GetEdictClassname(oldgun, currentgunname, sizeof(currentgunname)); //get the primary weapon name
                
                new max_ammo = GetMaxBackupAmmo(currentgunname);
                new new_max_ammo = RoundToCeil(max_ammo * ExtraAmmo[skill]);

                if (!StrEqual(currentgunname, "weapon_grenade_launcher")) {
                    SetBackupAmmo(client, new_max_ammo);
                }
            }
        }
    }
}

public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon)
{
    if(War3_GetRace(client) == thisRaceID)
    {
        new skill = War3_GetSkillLevel(client, thisRaceID, ABILITY_GRENADELAUNCHER);
        if (skill > 0 && buttons & IN_ZOOM && !War3_L4D_IsHelpless(client) && !War3_IsPlayerIncapped(client))
        {
            new iWeapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
            new primary = GetPlayerWeaponSlot(client, 0);
            
            if (IsValidEntity(primary) && iWeapon == primary) {
                decl String:currentgunname[64];
                GetEdictClassname(primary, currentgunname, sizeof(currentgunname)); //get the primary weapon name

                if (War3_SkillNotInCooldown(client, thisRaceID, ABILITY_GRENADELAUNCHER, true))
                {
                    if (StrEqual(currentgunname, "weapon_rifle", false) || StrEqual(currentgunname, "weapon_rifle_ak47", false) || 
                        StrEqual(currentgunname, "weapon_rifle_desert", false) || StrEqual(currentgunname, "weapon_autoshotgun", false) || 
                        StrEqual(currentgunname, "weapon_shotgun_spas", false))
                    {
                        new ammo_cost = GetMaxMagSize(currentgunname);
                        new current_ammo = GetEntProp(iWeapon, Prop_Send, "m_iClip1");
                        
                        if (ammo_cost <= current_ammo) {
                            SetEntProp(iWeapon, Prop_Send, "m_iClip1", 0);
                            
                            Fire1(client);
                            EmitSoundToAll(GrenadeShootSnd, client);//, _, SNDLEVEL_ROCKET, SND_CHANGEVOL, SNDLEVEL_ROCKET);
                            War3_CooldownMGR(client, ABILITY_COOLDOWN, thisRaceID, ABILITY_GRENADELAUNCHER);
                        }
                        else {
                            W3Hint(client, HINT_COOLDOWN_COUNTDOWN, 1.0, "Your magazine needs to be full!");
                        }
                    }
                }
            }
        }
    }
    
    return Plugin_Continue;
}

//=======================================================================
//                                 SUPER SENSE
//=======================================================================

public OnWar3EventDeath(victim, attacker)
{
    if (ValidPlayer(victim) && GetClientTeam(victim) == TEAM_INFECTED)
    {
        SetEntProp(victim, Prop_Send, "m_iGlowType", 0);
    }
}

public Action:SuperSenseTimer(Handle:timer, any:userid)
{
    for(new client=1; client <= MaxClients; client++)
    {
        if(ValidPlayer(client, true) && (GetClientTeam(client) == TEAM_SURVIVORS) && War3_GetRace(client) == thisRaceID)
        {
            new skill = War3_GetSkillLevel(client, thisRaceID, SKILL_SUPER_SENSE);
            if(skill > 0)
            { 
                new Float:ExpertPos[3];
                new Float:EnemyPos[3];
                new Float:maxDistance = SenseDistance[skill];
                        
                GetClientAbsOrigin(client, ExpertPos);
    
                // check special infected
                for(new i=1; i <= MaxClients; i++)
                {
                    if(ValidPlayer(i, true) && GetClientTeam(i) == TEAM_INFECTED)
                    {
                        new Float:specialisbiled = GetEntPropFloat(i, Prop_Send, "m_vomitFadeStart");
                        if (specialisbiled != 0.0 && specialisbiled + 5.0 > GetGameTime())
                        {
                            //PlayerWasMarked[i][client] = false;
                            SetEntProp(i, Prop_Send, "m_iGlowType", 0);
                            continue;
                        }
                        
                        GetClientAbsOrigin(i, EnemyPos);
                        if(GetVectorDistance(ExpertPos, EnemyPos) <= (maxDistance / 2))
                        {
                            if (PlayerWasMarked[i][client] == false)
                            {
                                PlayerWasMarked[i][client] = true;

                                SetEntProp(i, Prop_Send, "m_glowColorOverride", 255);
                                SetEntProp(i, Prop_Send, "m_iGlowType", 3);
                            }
                        }
                        else
                        {
                            if (PlayerWasMarked[i][client] == true)
                            {
                                PlayerWasMarked[i][client] = false;
                                SetEntProp(i, Prop_Send, "m_iGlowType", 0);
                            }
                        }
                    }
                }
                
                // check common infected
                new entity = -1;
                while ((entity = FindEntityByClassname(entity, "infected")) != INVALID_ENT_REFERENCE) 
                {
                    // don't mark death commons
                    new ragdoll = GetEntProp(entity, Prop_Send, "m_bClientSideRagdoll");
                    if (ragdoll == 1)
                    {
                        // useless, why would we reuse this entity for any indexing
                        //EntityWasMarked[entity] = false;
                        SetEntProp(entity, Prop_Send, "m_iGlowType", 0);
                        continue;
                    }
                    
                    // don't mess with biled commons
                    new biled = GetEntProp(entity, Prop_Send, "m_glowColorOverride");
                    if (biled == -4713783)
                    {
                        continue;
                    }
                    
                    new hp = GetEntityHP(entity);
                    
                    if (hp > 0)
                    {
                        GetEntPropVector(entity, Prop_Send, "m_vecOrigin", EnemyPos);
                        
                        if(GetVectorDistance(ExpertPos, EnemyPos) <= maxDistance)
                        {
                            if (EntityWasMarked[entity][client] == false)
                            {
                                EntityWasMarked[entity][client] = true;
                                SetEntProp(entity, Prop_Send, "m_glowColorOverride", 255);
                                SetEntProp(entity, Prop_Send, "m_iGlowType", 3);
                            }
                        }
                        else
                        {
                            if (EntityWasMarked[entity][client] == true)
                            {
                                EntityWasMarked[entity][client] = false;
                                SetEntProp(entity, Prop_Send, "m_iGlowType", 0);
                            }
                        }
                    }
                }
            }
        }
    }
}

public OnW3TakeDmgAllPre(victim,attacker,Float:damage){
    if(ValidPlayer(victim, true))
    {
        if(GetClientTeam(victim) == TEAM_INFECTED)
        {
            
            if (GetEntityHP(victim) < damage)
            {
                SetEntProp(victim, Prop_Send, "m_iGlowType", 0);
            }
        }
    }
}

//=======================================================================
//                                 GRENADE LAUNCHER
//=======================================================================

Fire1(userid)
{
    decl Float:pos[3];
    decl Float:angles[3];
    decl Float:velocity[3];
    new Float:force = 500.0;
    GetClientEyePosition(userid, pos);
     
    GetClientEyeAngles(userid, angles);
    GetEntDataVector(userid, g_iVelocity, velocity);
    
    angles[0]-=5.0;
    
    velocity[0] = force * Cosine(DegToRad(angles[1])) * Cosine(DegToRad(angles[0]));
    velocity[1] = force * Sine(DegToRad(angles[1])) * Cosine(DegToRad(angles[0]));
    velocity[2] = force * Sine(DegToRad(angles[0])) * -1.0;

    //new Float:force=GetConVarFloat(w_laugch_force);

    GetAngleVectors(angles, velocity, NULL_VECTOR, NULL_VECTOR);
    NormalizeVector(velocity, velocity);
    ScaleVector(velocity, force);
    
    {
        new Float:B=-3.1415926/2.0;
        decl Float:vec[3];
        decl Float:vec2[3];
        GetAngleVectors(angles,vec, NULL_VECTOR, NULL_VECTOR);
        GetAngleVectors(angles,vec2, NULL_VECTOR, NULL_VECTOR);
        new Float:x0=vec[0];
        new Float:y0=vec[1];
        new Float:x1=x0*Cosine(B)-y0*Sine(B);
        new Float:y1=x0*Sine(B)+y0*Cosine(B);
        vec[0]=x1;
        vec[1]=y1;
        vec[2]=0.0;
        NormalizeVector(vec,vec);
        NormalizeVector(vec2,vec2);
        ScaleVector(vec, 8.0);
        ScaleVector(vec2, 20.0);
        AddVectors(pos, vec, pos);
        //AddVectors(pos, vec2, pos);
    }

    //pos[0]+=velocity[0]*0.1;
    //pos[1]+=velocity[1]*0.1;
    //pos[2]+=velocity[2]*0.1;

    new ent = 0;

    ent=CreateEntityByName("grenade_launcher_projectile");
    DispatchKeyValue(ent, "model", "models/w_models/weapons/w_HE_grenade.mdl");  

    SetEntPropEnt(ent, Prop_Data, "m_hOwnerEntity", userid)    ;            

    DispatchSpawn(ent);  
    TeleportEntity(ent, pos, NULL_VECTOR, velocity);
    ActivateEntity(ent);

    //AcceptEntityInput(ent, "Ignite", userid, userid);
    SetEntityGravity(ent, 0.4);
    
    //SetEntProp(ent, Prop_Data, "m_bIsLive", 1);
    //SetEntProp(ent, Prop_Send, "m_bIsLive", 1);
        
 
    if(GrenadeLauncher[userid] > 0 && IsValidEntity(GrenadeLauncher[userid]))
    {
        RemoveEdict(GrenadeLauncher[userid]);
    }
    GrenadeLauncher[userid]=ent;
    return;
}

public Action:grenade_bounce(Handle:h_Event, const String:s_Name[], bool:b_DontBroadcast)
{
    new client = GetClientOfUserId(GetEventInt(h_Event, "userid"));
    
    if(GrenadeLauncher[client] > 0 && IsValidEntity(GrenadeLauncher[client]))
    {
        new Float:CasterPosition[3];    
        new Float:VictimPosition[3];
        new Float:EffectPosition[3];
        
        GetEntPropVector(GrenadeLauncher[client], Prop_Send, "m_vecOrigin", CasterPosition);
        GetEntPropVector(GrenadeLauncher[client], Prop_Send, "m_vecOrigin", EffectPosition);
        EffectPosition[2] += 40.0;
        
        EmitSoundToAll(GrenadeSnd, GrenadeLauncher[client]);
        War3_L4D_Explode(client, CasterPosition, 1); 
        
        /*new skill = War3_GetSkillLevel(client, thisRaceID, ABILITY_GRENADELAUNCHER);
        if (GetRandomFloat(0.0, 1.0) <= InfernoChance[skill])
        {
            War3_L4D_Explode(client, CasterPosition, 0); 
        }
        */
        
        GetEntPropVector(GrenadeLauncher[client], Prop_Send, "m_vecOrigin", EffectPosition);
        EffectPosition[2] += 40.0;
        
        ThrowAwayParticle(PARTICLE_LAUNCHER, EffectPosition, 2.5); 
        ThrowAwayLightEmitter(EffectPosition, "225 30 0 255", "5", 500.0, 0.4);
        EmitSoundToAll(GrenadeSnd, GrenadeLauncher[client]);

        //new skill = War3_GetSkillLevel(client, thisRaceID, ABILITY_GRENADELAUNCHER);
        
        new entity = -1;
        new skill = War3_GetSkillLevel(client, thisRaceID, ABILITY_GRENADELAUNCHER);
        new damage;
        while ((entity = FindEntityByClassname(entity, "infected")) != INVALID_ENT_REFERENCE) 
        {
            GetEntPropVector(entity, Prop_Send, "m_vecOrigin", VictimPosition);
            new Float:dis = GetVectorDistance(CasterPosition, VictimPosition);
            
            if (dis < (GrenadeRange))
            {
                damage =  RoundToCeil(GrenadeDamage[skill] * (1 - (dis / GrenadeRange)));
                
                if ( damage >= GetEntityHP(entity) )
                {
                    new Float:DirectionVector[3];
                    VictimPosition[2] += 65.0;
                    
                    SubtractVectors(VictimPosition, CasterPosition, DirectionVector);
                    NormalizeVector(DirectionVector, DirectionVector);
                    
                    ScaleVector(DirectionVector, 12000.0);
                    
                    SetEntPropVector(entity, Prop_Send, "m_gibbedLimbForce", DirectionVector);
                    SetEntProp(entity, Prop_Send, "m_iRequestedWound1", 24);
                    
                    //SetEntPropVector(entity, Prop_Send, "m_gibbedLimbForce", testVector);
                    //SetEntProp(entity, Prop_Send, "m_iRequestedWound1", 24);
                }
                War3_DealDamage(entity, damage, client, 1, "skill_nadelauncher");
            }
        } 
        
        while ((entity = FindEntityByClassname(entity, "witch")) != INVALID_ENT_REFERENCE) 
        {
            GetEntPropVector(entity, Prop_Send, "m_vecOrigin", VictimPosition);
            new Float:dis = GetVectorDistance(CasterPosition, VictimPosition);
            
            if (dis < (GrenadeRange))
            {
                damage =  RoundToCeil(GrenadeDamage[skill] * (1 - (dis / GrenadeRange)));
                War3_DealDamage(entity, damage, client, 1, "skill_nadelauncher");
            }
        }
        
        // check special infected
        for(new i=1; i <= MaxClients; i++)
        {
            if(ValidPlayer(i, true) && GetClientTeam(i) == TEAM_INFECTED)
            {
                GetClientAbsOrigin(i, VictimPosition);
                new Float:dis = GetVectorDistance(CasterPosition, VictimPosition);
                
                if (dis < (GrenadeRange))
                {
                    damage =  RoundToCeil(GrenadeDamage[skill] * (1 - (dis / GrenadeRange)));
                    War3_DealDamage(i, damage, client, 1, "skill_nadelauncher");
                }
            }
        }
        
        
        if(GrenadeLauncher[client] > 0 && IsValidEntity(GrenadeLauncher[client]))
        {
            AcceptEntityInput(GrenadeLauncher[client], "break");
            RemoveEdict(GrenadeLauncher[client]);
        }
        
        GrenadeLauncher[client] = 0;
        
    }
}

public OnUltimateCommand(client,race,bool:pressed)
{
    if(ValidPlayer(client, true) && 
       race == thisRaceID && 
       pressed && 
       War3_SkillNotInCooldown(client, thisRaceID, ULTIMATE_AMMOSHARER, true) && 
       !Silenced(client) &&
       GetClientTeam(client) == TEAM_SURVIVORS &&
       !War3_L4D_IsHelpless(client) &&
       !War3_IsPlayerIncapped(client))
    {    
        new skill = War3_GetSkillLevel(client, thisRaceID, ULTIMATE_AMMOSHARER);
        if (skill > 0)
        {
            new iWeapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
            SetEntProp(iWeapon, Prop_Send, "m_helpingHandState", 3);
                        
            new Float:location[3];
            War3_GetAimEndPoint(client, location);
            /*
            if (!Misc_TraceClientViewToLocation(client, location)) {
                GetClientAbsOrigin(client, location);
            }*/
            
            Do_CreateEntity("weapon_ammo_spawn", location);
            ThrowAwayLightEmitter(location, "255 250 90 255", "5", 110.0, 20.0);

            //location[2] += 7;
            //ThrowAwayParticle(PARTICLE_AMMOPILE, location, 20.0);
            
            War3_CooldownMGR(client, ULT_COOLDOWN, thisRaceID, ULTIMATE_AMMOSHARER);
        }
    }
}

Do_CreateEntity(const String:name[], Float:location[3]) {
    new entity = CreateEntityByName(name);

    DispatchSpawn(entity);
    ActivateEntity(entity);
    TeleportEntity(entity, location, NULL_VECTOR, NULL_VECTOR);
    
    SetVariantString("OnUser1 !self:Kill::20.0:-1");
    AcceptEntityInput(entity, "AddOutput");
    AcceptEntityInput(entity, "FireUser1");
    
    L4D2_SetEntGlow(entity, L4D2Glow_Constant, 10000, 0, {255, 250, 90}, true);
}
