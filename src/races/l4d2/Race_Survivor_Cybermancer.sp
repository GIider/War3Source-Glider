#pragma semicolon 1

#include "W3SIncs/War3Source_Interface"

public Plugin:myinfo = 
{
    name = "War3Source Race - L4D Survivor Cybermancer",
    author = "Glider",
    description = "The Survivor Cybermancer race for War3Source.",
    version = "1.0",
}; 

//=======================================================================
//                             VARIABLES
//=======================================================================

new thisRaceID;
new SKILL_EXPLOSIVE_AMMO, SKILL_BLOCK, SKILL_CYBER_LEGS, ULT_DRAGON_BREATH;

new Float:ULT_COOLDOWN = 45.0;

new Float:CyberLegsJumpZ[5]={0.0, 300.0, 350.0, 400.0, 450.0};
new Float:CyberLegsJumpXY[5]={1.0, 1.125, 1.25, 1.375, 1.5};
new Float:ExplosiveAmount[5]={0.0, 0.25, 0.5, 0.75, 1.0};
new Float:BlockChance[5]={0.0,0.05,0.1,0.15,0.2};
new Float:SpeedIncrease[5]={1.0,1.05,1.11,1.17,1.22};

new String:UltimateSnd[]="weapons/grenade_launcher/grenadefire/grenade_launcher_explode_1.wav";
new String:UltimateParticle[]="sline_sparks";
new String:UltimateParticle2[]="impact_explosive_ammo_large";
new String:BlockParticle[]="sparks_generic_random";

//=======================================================================
//                                 INIT
//=======================================================================

public OnWar3PluginReady(){
    thisRaceID = War3_CreateNewRace("Divine Cybermancer", "cybermancer");
    SKILL_EXPLOSIVE_AMMO = War3_AddRaceSkill(thisRaceID, "Armor Piercing Ammunition", "When you refill your ammo you gain 25/50/75/100% explosive ammo", false, 4);
    SKILL_BLOCK = War3_AddRaceSkill(thisRaceID, "Block", "You have a 5/10/25/20% chance to block all damage when wielding a melee weapon", false, 4);
    SKILL_CYBER_LEGS = War3_AddRaceSkill(thisRaceID, "Cyber Legs", "Run 5/11/17/22% faster.\nCrouch and jump at the same time to jump 300/350/400/450 units higher!", false, 4);
    ULT_DRAGON_BREATH = War3_AddRaceSkill(thisRaceID, "Dragon Breath", "Explode a common infected you're looking at and teleport to its position. CD: 45s", true, 1);
    
    War3_CreateRaceEnd(thisRaceID);
}

public OnPluginStart()
{
    if(War3_GetGame() != Game_L4D && War3_GetGame() != Game_L4D2)
        SetFailState("Only works in the L4D engine! %i", War3_GetGame());
    
    HookEvent("ammo_pickup", Event_AmmoPickup);
    HookEvent("player_use", Event_PlayerUse);
}

public OnMapStart()
{
    War3_PrecacheParticle(UltimateParticle);
    War3_PrecacheParticle(UltimateParticle2);
    War3_PrecacheParticle(BlockParticle);
    
    War3_AddCustomSound(UltimateSnd);
}

//=======================================================================
//                           Cyber Legs
//=======================================================================


givePlayerBuffs(client)
{
    if(War3_GetRace(client) == thisRaceID)
    {
        new skill_mspd = War3_GetSkillLevel(client, thisRaceID, SKILL_CYBER_LEGS);
        if (skill_mspd > 0 && (GetClientTeam(client) == TEAM_SURVIVORS))
        {
            War3_SetBuff(client, fMaxSpeed, thisRaceID, SpeedIncrease[skill_mspd]);
        }
    }
}

public OnWar3EventSpawn(client)
{    
    givePlayerBuffs(client);
}

public OnRaceChanged(client, oldrace, newrace)
{
    if(newrace != thisRaceID)
    {
        War3_SetBuff(client,fMaxSpeed,thisRaceID,1.0);
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

public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon)
{
    if (ValidPlayer(client, true))
    {
        if(War3_GetRace(client) == thisRaceID && !War3_L4D_IsHelpless(client) && !War3_IsPlayerIncapped(client))
        {
            new skill_mspd = War3_GetSkillLevel(client, thisRaceID, SKILL_CYBER_LEGS);
            if (skill_mspd > 0)
            {
                new flags = GetEntityFlags(client);
                if (((buttons & IN_JUMP) && (buttons & IN_DUCK)) && (flags & FL_ONGROUND))
                {
                    decl Float:cVel[3];
                    cVel[0] = GetEntPropFloat(client, Prop_Send, "m_vecVelocity[0]") * CyberLegsJumpXY[skill_mspd];
                    cVel[1] = GetEntPropFloat(client, Prop_Send, "m_vecVelocity[1]") * CyberLegsJumpXY[skill_mspd];
                    cVel[2] = CyberLegsJumpZ[skill_mspd]; // upspeed, the higher this is, the higher is the jump
                    TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, cVel);
                }
            }
        }
    }

    return Plugin_Continue;    
}

//=======================================================================
//                                 Explosive Ammo
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
                new skill = War3_GetSkillLevel(client, thisRaceID, SKILL_EXPLOSIVE_AMMO);
                if (skill > 0)
                {
                    new oldgun = GetPlayerWeaponSlot(client, 0); //get the players primary weapon
                    if (IsValidEdict(oldgun))
                    {
                        ExplosiveAmmoRoutine(client, oldgun, skill);
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
        new skill = War3_GetSkillLevel(client, thisRaceID, SKILL_EXPLOSIVE_AMMO);
        if (skill > 0)
        {
            new oldgun = GetPlayerWeaponSlot(client, 0); //get the players primary weapon
            if (IsValidEdict(oldgun))
            {
                ExplosiveAmmoRoutine(client, oldgun, skill);
            }
        }
    }
}

ExplosiveAmmoRoutine(client, oldgun, skill)
{
    new ammo = GetEntProp(oldgun, Prop_Send, "m_nUpgradedPrimaryAmmoLoaded");
    if (ammo == 0)
    {    
        decl String:currentgunname[64];
        GetEdictClassname(oldgun, currentgunname, sizeof(currentgunname)); //get the primary weapon name
        
        AddExplosiveAmmo(client, GetMaxMagSize(currentgunname), skill);
    }
    else
    {
        W3Hint(client, HINT_LOWEST, 1.0, "You still have special ammo left!");
    }
}

stock Action:AddExplosiveAmmo(client, ammo, skill)
{
    new ammo_to_add = RoundToCeil(ammo * ExplosiveAmount[skill]);
        
    CheatCommand(client, "upgrade_add", "EXPLOSIVE_AMMO");
    SetSpecialAmmoInPlayerGun(client, ammo_to_add);

    return Plugin_Continue;
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

stock SetSpecialAmmoInPlayerGun(client, amount)
{
    if (!client) client = 1;
    
    new gunent = GetPlayerWeaponSlot(client, 0);
    if (IsValidEdict(gunent) && amount > 0)
    {
        new Handle:datapack = CreateDataPack();
        WritePackCell(datapack, gunent);
        WritePackCell(datapack, amount);
        CreateTimer(0.1, SetGunSpecialAmmo, datapack);
    }
}

public Action:SetGunSpecialAmmo(Handle:timer, Handle:datapack)
{
    ResetPack(datapack);
    new ent = ReadPackCell(datapack);
    new amount = ReadPackCell(datapack);
    CloseHandle(datapack);
    
    //DebugPrintToAll("Delayed ammo Setting in gun %i to %i", ent, amount);
    SetEntProp(ent, Prop_Send, "m_nUpgradedPrimaryAmmoLoaded", amount, 1);
}

//=======================================================================
//                                 Block 
//=======================================================================

public OnW3TakeDmgAllPre(victim,attacker,Float:damage){
    if(ValidPlayer(victim, true))
    {
        if(War3_GetRace(victim) == thisRaceID)
        {
            if(ValidPlayer(attacker) && GetClientTeam(attacker) == TEAM_SURVIVORS && IsFakeClient(attacker))
            {
                // Feels like I'm doing... NOTHING AT ALL!
            }
            else if (ValidPlayer(attacker) || War3_IsL4DZombieEntity(attacker))
            {
                new block_skill = War3_GetSkillLevel(victim, thisRaceID, SKILL_BLOCK);
                if (block_skill > 0)
                {
                    new String:name[64];
                    GetClientWeapon(victim, name, sizeof(name));
                    
                    if (StrEqual(name, "weapon_melee"))
                    {
                        if(GetRandomFloat(0.0, 1.0) <= BlockChance[block_skill])
                        {
                            War3_DamageModPercent(0.0);
                            W3Hint(victim, HINT_LOWEST, 1.0, "You blocked the damage!");
                            
                            decl Float:EffectPosition[3];
                            GetClientEyePosition(victim, EffectPosition);
                            EffectPosition[2] -= 20.0;
                                
                            ThrowAwayParticle(BlockParticle, EffectPosition, 2.5);
                        }
                    }
                }
            }
        }
    }
}

//=======================================================================
//                                 Fire Wave
//=======================================================================

public OnUltimateCommand(client,race,bool:pressed)
{
    if(ValidPlayer(client, true) && 
       race == thisRaceID && 
       pressed && 
       War3_SkillNotInCooldown(client, thisRaceID, ULT_DRAGON_BREATH, true) && 
       !Silenced(client) &&
       GetClientTeam(client) == TEAM_SURVIVORS &&
       !War3_L4D_IsHelpless(client) &&
       !War3_IsPlayerIncapped(client))
    {    
        new skill = War3_GetSkillLevel(client, thisRaceID, ULT_DRAGON_BREATH);
        if (skill > 0)
        {
            decl Float:VictimPosition[3];
            decl Float:CasterPosition[3];
            decl Float:EffectPosition[3];
           
            GetClientEyePosition(client, CasterPosition);
            
            new entity = GetClientAimedLocationData(client, NULL_VECTOR);

            if (War3_IsCommonInfected(entity))
            {
                new iWeapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
                SetEntProp(iWeapon, Prop_Send, "m_helpingHandState", 3);
                
                GetEntPropVector(entity, Prop_Send, "m_vecOrigin", VictimPosition);
                GetEntPropVector(entity, Prop_Send, "m_vecOrigin", EffectPosition);
                
                new Float:ZombieVector[3];
                new Float:DirectionVector[3];
                GetEntPropVector(entity, Prop_Send, "m_vecOrigin", ZombieVector);
                ZombieVector[2] += 65.0;
                
                SubtractVectors(ZombieVector, CasterPosition, DirectionVector);
                NormalizeVector(DirectionVector, DirectionVector);
                
                ScaleVector(DirectionVector, 12000.0);
                
                SetEntPropVector(entity, Prop_Send, "m_gibbedLimbForce", DirectionVector);
                SetEntProp(entity, Prop_Send, "m_iRequestedWound1", 24);
                
                EffectPosition[2] += 50.0;
                
                ThrowAwayParticle(UltimateParticle, EffectPosition, 2.5); 
                ThrowAwayParticle(UltimateParticle2, EffectPosition, 2.5); 
                                
                ThrowAwayLightEmitter(EffectPosition, "225 30 0 255", "5", 400.0, 0.4);
                
                TeleportEntity(client, VictimPosition, NULL_VECTOR, NULL_VECTOR);
                War3_DealDamage(entity, 10000, client, 1, "dragonbreath");
                
                // stagger special infected around the impact location
                for(new i=1; i <= MaxClients; i++)
                {
                    if(ValidPlayer(i, true) && GetClientTeam(i) == TEAM_INFECTED)
                    {
                        GetClientAbsOrigin(i, VictimPosition);
                        new Float:dis = GetVectorDistance(CasterPosition, VictimPosition);
                        
                        if (dis < (150.0))
                        {
                            War3_DealDamage(i, 10, client, DMG_BLAST, "dragonbreath");
                        }
                    }
                }
                
                EmitSoundToAll(UltimateSnd, client);
                War3_CooldownMGR(client, ULT_COOLDOWN, thisRaceID, ULT_DRAGON_BREATH);
            }
        }
    }
}

GetClientAimedLocationData( client, Float:position[3])
{
    new index = -1;
    
    decl Float:_origin[3], Float:_angles[3];
    GetClientEyePosition( client, _origin );
    GetClientEyeAngles( client, _angles );

    new Handle:trace = TR_TraceRayFilterEx( _origin, _angles, MASK_SOLID_BRUSHONLY, RayType_Infinite, TraceEntityFilterPlayers );
    if( !TR_DidHit( trace ) )
    { 
        index = -1;
    }
    else
    {
        TR_GetEndPosition( position, trace );
        index = TR_GetEntityIndex( trace );
    }
    CloseHandle( trace );
    
    return index;
}

public bool:TraceEntityFilterPlayers( entity, contentsMask, any:data )
{
    return entity > MaxClients && entity != data;
}