#pragma semicolon 1

#include "W3SIncs/War3Source_Interface"

public Plugin:myinfo =
{
    name = "War3Source Race - Skeleton King",
    author = "Glider",
    description = "The Skeleton King race for War3Source.",
    version = "1.0",
};

//=======================================================================
//                             VARIABLES
//=======================================================================

new thisRaceID;
new ABILITY_HELLFIRE, SKILL_VAMP_AURA, SKILL_CRITICAL, ULT_REINCARNATION;

new g_DamageStackCrit = -1;
new Float:g_fCritPercentage = 0.0;

new Float:fHellfireRange = 600.0;    
new Float:fHellfireCooldown = 25.0;
new iHellfireDamage[5] = {0, 4, 6, 8, 12};
new Float:fHellfireSlowPercentage[5] = {1.0, 0.95, 0.9, 0.85, 0.8};
new Float:iHellfireStunTime = 1.0;
new Float:fHellfireSlowTime = 2.0;
new HellfiredBy[MAXPLAYERS];

//new iHellfireSkullEntity[MAXPLAYERS];
//new Float:fHellfireSkullPosition[MAXPLAYERS][3];

new Float:fCritPercentage[5] = {1.0, 1.4, 1.8, 2.2, 2.6};

new Float:fAuraPercentage[5] = {0.0, 0.20, 0.25, 0.30, 0.35};

new Float:fSlowRange = 600.0;
new Float:fSlowTime;
new Float:fSlowPercentage = 0.75;
new Float:fUltCooldown[5] = {0.0, 210.0, 165.0, 120.0, 75.0};

#define REVIVE_DELAY 2.5
#define AURA_RANGE 1500.0

#define MDL_SKULL "models/player/gibs/gibs_burger.mdl" // "models/props_mvm/mvm_human_skull.mdl"
#define MDL_REAL_SKULL "models/props_mvm/mvm_human_skull.mdl"
#define MDL_TOMBSTONE_01 "models/props_halloween/tombstone_01.mdl"
#define MDL_TOMBSTONE_02 "models/props_halloween/tombstone_02.mdl"

#define PARTICLE_DEATH "mvm_hatch_destroy_smoke"

#define SND_LEVEL_UP_01 "war3source/skeletonking/skel_level_01.mp3"
#define SND_LEVEL_UP_02 "war3source/skeletonking/skel_level_02.mp3"
#define SND_LEVEL_UP_03 "war3source/skeletonking/skel_level_03.mp3"
#define SND_LEVEL_UP_04 "war3source/skeletonking/skel_level_04.mp3"
#define SND_LEVEL_UP_05 "war3source/skeletonking/skel_level_05.mp3"
#define SND_LEVEL_UP_06 "war3source/skeletonking/skel_level_06.mp3"
#define SND_LEVEL_UP_07 "war3source/skeletonking/skel_level_07.mp3"
#define SND_LEVEL_UP_08 "war3source/skeletonking/skel_level_08.mp3"

#define SND_SPAWN_01 "war3source/skeletonking/skel_spawn_01.mp3"
#define SND_SPAWN_02 "war3source/skeletonking/skel_spawn_02.mp3"
#define SND_SPAWN_03 "war3source/skeletonking/skel_spawn_03.mp3"
#define SND_SPAWN_04 "war3source/skeletonking/skel_spawn_04.mp3"

#define SND_HELLFIRE_01 "war3source/skeletonking/skel_ability_hellfire_01.mp3"
#define SND_HELLFIRE_02 "war3source/skeletonking/skel_ability_hellfire_02.mp3"
#define SND_HELLFIRE_03 "war3source/skeletonking/skel_ability_hellfire_03.mp3"

#define SND_REINCARNATION_01 "war3source/skeletonking/skel_ability_incarn_01.mp3"
#define SND_REINCARNATION_02 "war3source/skeletonking/skel_ability_incarn_02.mp3"
#define SND_REINCARNATION_03 "war3source/skeletonking/skel_ability_incarn_03.mp3"
#define SND_REINCARNATION_04 "war3source/skeletonking/skel_ability_incarn_04.mp3"
#define SND_REINCARNATION_05 "war3source/skeletonking/skel_ability_incarn_05.mp3"
#define SND_REINCARNATION_06 "war3source/skeletonking/skel_ability_incarn_06.mp3"
#define SND_REINCARNATION_07 "war3source/skeletonking/skel_ability_incarn_07.mp3"
#define SND_REINCARNATION_08 "war3source/skeletonking/skel_ability_incarn_08.mp3"
#define SND_REINCARNATION_09 "war3source/skeletonking/skel_ability_incarn_09.mp3"
#define SND_REINCARNATION_10 "war3source/skeletonking/skel_ability_incarn_10.mp3"
#define SND_REINCARNATION_11 "war3source/skeletonking/skel_ability_incarn_11.mp3"
#define SND_REINCARNATION_12 "war3source/skeletonking/skel_ability_incarn_12.mp3"

//=======================================================================
//                                 INIT
//=======================================================================

public OnWar3PluginReady()
{
    thisRaceID = War3_CreateNewRace("Skeleton King", "skeletonking");

    ABILITY_HELLFIRE = War3_AddRaceSkill(thisRaceID, "Hellfire Blast", "Fire a hellfire blast at an enemy, dealing 4/6/8/12 damage and stunning for 1s, then slowing with 5/10/15/20% for 2s. Used with +ability. Cooldown 25s", false, 4);
    SKILL_VAMP_AURA = War3_AddRaceSkill(thisRaceID, "Vampiric Aura", "Nearby melee units including you gain 20/25/30/35% damage back as HP (no overheal)", false, 4);
    SKILL_CRITICAL = War3_AddRaceSkill(thisRaceID, "Critical Strike", "You have a chance to deal 40/80/120/160% extra damage on a melee strike", false, 4);
    ULT_REINCARNATION = War3_AddRaceSkill(thisRaceID, "Reincarnation", "Respawns you where you died and slows down everyone in range by 25% for 4 seconds. Cooldown 210/165/120/75s", true, 4);

    War3_CreateRaceEnd(thisRaceID);
    
    War3_AddAuraSkillBuff(thisRaceID, SKILL_VAMP_AURA, fMeleeVampirePercentNoBuff, fAuraPercentage, 
                          "skelking_vamp", AURA_RANGE, false);
}

public OnPluginStart()
{
    if(War3_GetGame() != Game_TF)
    {
        SetFailState("Only works in the TF2 engine! %i", War3_GetGame());
    }
}

public OnMapStart()
{
    PrecacheModel(MDL_TOMBSTONE_01, true);
    PrecacheModel(MDL_TOMBSTONE_02, true);
    PrecacheModel(MDL_SKULL, true);
    PrecacheModel(MDL_REAL_SKULL, true);

    War3_PrecacheParticle(PARTICLE_DEATH);

    War3_PrecacheSound(SND_LEVEL_UP_01);
    War3_PrecacheSound(SND_LEVEL_UP_02);
    War3_PrecacheSound(SND_LEVEL_UP_03);
    War3_PrecacheSound(SND_LEVEL_UP_04);
    War3_PrecacheSound(SND_LEVEL_UP_05);
    War3_PrecacheSound(SND_LEVEL_UP_06);
    War3_PrecacheSound(SND_LEVEL_UP_07);
    War3_PrecacheSound(SND_LEVEL_UP_08);

    War3_PrecacheSound(SND_SPAWN_01);
    War3_PrecacheSound(SND_SPAWN_02);
    War3_PrecacheSound(SND_SPAWN_03);
    War3_PrecacheSound(SND_SPAWN_04);

    War3_PrecacheSound(SND_HELLFIRE_01);
    War3_PrecacheSound(SND_HELLFIRE_02);
    War3_PrecacheSound(SND_HELLFIRE_03);

    War3_PrecacheSound(SND_REINCARNATION_01);
    War3_PrecacheSound(SND_REINCARNATION_02);
    War3_PrecacheSound(SND_REINCARNATION_03);
    War3_PrecacheSound(SND_REINCARNATION_04);
    War3_PrecacheSound(SND_REINCARNATION_05);
    War3_PrecacheSound(SND_REINCARNATION_06);
    War3_PrecacheSound(SND_REINCARNATION_07);
    War3_PrecacheSound(SND_REINCARNATION_08);
    War3_PrecacheSound(SND_REINCARNATION_09);
    War3_PrecacheSound(SND_REINCARNATION_10);
    War3_PrecacheSound(SND_REINCARNATION_11);
    War3_PrecacheSound(SND_REINCARNATION_12);
}

//=======================================================================
//                                 FANCY THINGS
//=======================================================================

public OnWar3Event(W3EVENT:event, client)
{
    if (event == PlayerLeveledUp)
    {
        if (War3_GetRace(client) == thisRaceID)
        {
            decl String:buffer[52];
            Format(buffer, sizeof(buffer), "war3source/skeletonking/skel_level_0%i.mp3", GetRandomInt(1, 8));

            W3EmitSoundToAll(buffer, client);
        }
    }
}

//=======================================================================
//                                 VAMP AURA
//=======================================================================

public OnWar3EventSpawn(client)
{
    if (ValidPlayer(client))
    {
        War3_SetBuff(client, bStunned, thisRaceID, false);
        War3_SetBuff(client, fSlow, thisRaceID, 1.0);
    }
}

public OnWar3EventDeath(victim, attacker)
{
    if (ValidPlayer(victim))
    {
        War3_SetBuff(victim, bStunned, thisRaceID, false);
        War3_SetBuff(victim, fSlow, thisRaceID, 1.0);

        if (bCanRevive(victim))
        {
            CreateTimer(REVIVE_DELAY, Revive, victim);
            SpawnTombstone(victim);
        }
    }
}

public OnRaceChanged(client, oldrace, newrace)
{
    if (ValidPlayer(client) && newrace == thisRaceID && GetClientTeam(client) > 1)
    {
        decl String:buffer[52];
        Format(buffer, sizeof(buffer), "war3source/skeletonking/skel_spawn_0%i.mp3", GetRandomInt(1, 4));

        W3EmitSoundToAll(buffer, client);
    }
}

//=======================================================================
//                                 CRIT
//=======================================================================

public OnW3TakeDmgAllPre(victim, attacker, Float:damage)
{
    if (ValidPlayer(attacker, true) && War3_GetRace(attacker) == thisRaceID)
    {
        if (ValidPlayer(victim, true) && GetClientTeam(victim) != GetClientTeam(attacker) && attacker != victim)
        {
            new skill = War3_GetSkillLevel(attacker, thisRaceID, SKILL_CRITICAL);
            if (skill > 0)
            {
                new inflictor = W3GetDamageInflictor();
                if (attacker == inflictor || !IsValidEntity(inflictor))
                {
                    new String:weapon[64];
                    GetClientWeapon(attacker, weapon, sizeof(weapon));

                    if (W3IsDamageFromMelee(weapon))
                    {
                        new Float:fChanceModifier = W3ChanceModifier(attacker);
                        new Float:fChance = 0.15 * fChanceModifier;
                        if(GetRandomFloat(0.0, 1.0) <= fChance && !W3HasImmunity(victim, Immunity_Skills))
                        {
                            g_DamageStackCrit = W3GetDamageStack();
                            g_fCritPercentage = fCritPercentage[skill];

                            War3_DamageModPercent(g_fCritPercentage);
                        }
                    }
                }
            }
        }
    }
}

public OnWar3EventPostHurt(victim, attacker, dmg)
{
    if(ValidPlayer(victim) && ValidPlayer(attacker) && victim != attacker)
    {
        if(War3_GetRace(attacker) == thisRaceID)
        {
            if(g_DamageStackCrit == W3GetDamageStack())
            {
                g_DamageStackCrit = -1;
                W3PrintSkillDmgHintConsole(victim, attacker, RoundFloat(float(dmg) - dmg / g_fCritPercentage), SKILL_CRITICAL);
                W3FlashScreen(victim, RGBA_COLOR_RED);
            }
        }
    }
}

//=======================================================================
//                                 REVIVE
//=======================================================================

SpawnTombstone(client)
{
    new Float:pos[3];
    new Float:ang[3];
    GetClientAbsOrigin(client, pos);
    GetClientAbsAngles(client, ang);

    new tombstone = CreateEntityByName("prop_dynamic_override");
    if (GetRandomInt(0, 1) == 0)
    {
        DispatchKeyValue(tombstone, "model", MDL_TOMBSTONE_01);
    }
    else
    {
        DispatchKeyValue(tombstone, "model", MDL_TOMBSTONE_02);
    }
    DispatchSpawn( tombstone);

    ModifyEntityAddDeathTimer(tombstone, REVIVE_DELAY);

    SetEntProp(tombstone, Prop_Data, "m_takedamage", 0, 1);
    SetEntProp(tombstone, Prop_Data, "m_CollisionGroup", 2);
    SetEntityMoveType(tombstone, MOVETYPE_NOCLIP);

    DispatchKeyValueVector(tombstone, "origin", pos);
    DispatchKeyValueVector(tombstone, "Angles", ang);
    TeleportEntity(tombstone, pos, NULL_VECTOR, ang);

    ThrowAwayParticle(PARTICLE_DEATH, pos, REVIVE_DELAY);
}

public Action:Revive(Handle:timer, any:client)
{
    if (ValidPlayer(client) && bCanRevive(client) && !IsPlayerAlive(client))
    {
        War3_SpawnPlayer(client);

        new Float:fRespawnPos[3];
        new Float:fRespawnAngles[3];
        War3_CachedAngle(client, fRespawnAngles);
        War3_CachedPosition(client, fRespawnPos);

        TeleportEntity(client, fRespawnPos, fRespawnAngles, NULL_VECTOR);

        decl String:buffer[52];
        Format(buffer, sizeof(buffer), "war3source/skeletonking/skel_ability_incarn_%02i.mp3", GetRandomInt(1, 12));

        W3EmitSoundToAll(buffer, client);

        new Float:fVictimPos[3];
        for(new victim=1; victim <= MaxClients; victim++)
        {
            if(ValidPlayer(victim, true) && GetClientTeam(victim) != GetClientTeam(client))
            {
                GetClientAbsOrigin(victim, fVictimPos);
                new Float:fDistance = GetVectorDistance(fRespawnPos, fVictimPos);

                if (fDistance <= fSlowRange)
                {
                    War3_SetBuff(victim, fSlow, thisRaceID, fSlowPercentage);
                    CreateTimer(fSlowTime, UnslowEnemy, victim);
                }
            }
        }

        new skill = War3_GetSkillLevel(client, thisRaceID, ULT_REINCARNATION);
        War3_CooldownMGR(client, fUltCooldown[skill], thisRaceID, ULT_REINCARNATION, false, false);
    }
}

bool:bCanRevive(client)
{
    if(ValidPlayer(client) && War3_GetRace(client) == thisRaceID)
    {
        new skill = War3_GetSkillLevel(client, thisRaceID, ULT_REINCARNATION);

        if (skill > 0 && War3_SkillNotInCooldown(client, thisRaceID, ULT_REINCARNATION, true))
        {
            return true;
        }
    }

    return false;
}

//=======================================================================
//                                 HELLFIRE BLAST
//=======================================================================

public OnAbilityCommand(client, ability, bool:pressed)
{
    if(ValidPlayer(client, true) &&
            War3_GetRace(client) == thisRaceID &&
            pressed &&
            War3_SkillNotInCooldown(client, thisRaceID, ABILITY_HELLFIRE, true) &&
            !Silenced(client))
    {
        new skill = War3_GetSkillLevel(client, thisRaceID, ABILITY_HELLFIRE);
        if (skill > 0)
        {
            new Float:fPos[3];
            GetClientAbsOrigin(client,fPos);

            new target = War3_GetTargetInViewCone(client, fHellfireRange, false, 23.0, ImmunityCheck);
            if(ValidPlayer(target, true))
            {
                War3_SetBuff(target, bStunned, thisRaceID, true);
                CreateTimer(iHellfireStunTime, StopHellfireStun, target);

                War3_DealDamage(target, iHellfireDamage[skill], client, DMG_GENERIC, "hellfire");

                War3_CooldownMGR(client, fHellfireCooldown, thisRaceID, ABILITY_HELLFIRE,_ , _);

                decl String:buffer[54];
                Format(buffer, sizeof(buffer), "war3source/skeletonking/skel_ability_hellfire_0%i.mp3", GetRandomInt(1, 3));

                W3EmitSoundToAll(buffer, client);

            }
            else
            {
                W3MsgNoTargetFound(client, fHellfireRange);
            }
        }
    }
}

/*
 public OnAbilityCommand(client, ability, bool:pressed)
 {
 if(ValidPlayer(client, true) &&
 War3_GetRace(client) == thisRaceID &&
 pressed &&
 War3_SkillNotInCooldown(client, thisRaceID, ABILITY_HELLFIRE, true) &&
 !Silenced(client))
 {
 new skill = War3_GetSkillLevel(client, thisRaceID, ABILITY_HELLFIRE);
 if (skill > 0)
 {
 new Float:fPos[3];
 GetClientAbsOrigin(client,fPos);

 //new target = War3_GetTargetInViewCone(client, fHellfireRange, false, 23.0, ImmunityCheck);
 //            if(ValidPlayer(target, true))
 //            {
 //            War3_SetBuff(target, bStunned, thisRaceID, true);
 //        CreateTimer(iHellfireStunTime, StopHellfireStun, target);

 //    War3_DealDamage(target, iHellfireDamage[skill], client, DMG_GENERIC, "hellfire");

 //HellfiredBy[target] = client;
 War3_CooldownMGR(client, fHellfireCooldown, thisRaceID, ABILITY_HELLFIRE,_ , _);

 decl String:buffer[54];
 Format(buffer, sizeof(buffer), "war3source/skeletonking/skel_ability_hellfire_0%i.mp3", GetRandomInt(1, 3));

 W3EmitSoundToAll(buffer, client);

 //iHellfireTarget[client] = target;
 iHellfireSkullEntity[client] = doSickSpit(client);

 //            }
 //        else
 //    {
 //    W3MsgNoTargetFound(client, fHellfireRange);
 //    }
 }
 }
 }

 new bool:bIgnoreFirstKill[MAXPLAYERS];
 doSickSpit(client)
 {
 decl Float:pos[3];
 decl Float:ang[3];
 decl Float:vec[3];
 decl Float:pvec[3];

 new ent = CreateEntityByName("prop_physics_multiplayer");
 if(IsValidEntity(ent))
 {
 // Configure prop
 DispatchKeyValue(ent, "targetname", "zfperk");
 SetEntPropEnt(ent, Prop_Data, "m_hOwnerEntity", client);
 SetEntProp(ent, Prop_Data, "m_CollisionGroup", 1);
 //SetEntProp(ent, Prop_Data, "m_usSolidFlags", 0x18);
 //SetEntProp(ent, Prop_Data, "m_nSolidType", 6);
 SetEntPropFloat(ent, Prop_Data, "m_flFriction", 1000000.0);
 SetEntPropFloat(ent, Prop_Data, "m_massScale", 1.0);
 SetEntityMoveType(ent, MOVETYPE_VPHYSICS);
 SetEntityModel(ent, MDL_SKULL);
 SetEntityRenderColor(ent, 100, 200, 100, 255);

 // Spawn prop
 DispatchSpawn(ent);

 // Orient prop
 GetClientAbsOrigin(client, pos);
 GetClientEyeAngles(client, ang);
 //ang[0] += GetRandomFloat(-5.0, 5.0);  // Pitch
 //ang[1] += GetRandomFloat(-10.0, 10.0);  // Yaw
 GetAngleVectors(ang, vec, NULL_VECTOR, NULL_VECTOR);
 GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", pvec);
 ScaleVector(vec, 1100.0);
 AddVectors(pvec, vec, vec);
 TeleportEntity(ent, pos, ang, vec);

 GetEntPropVector(ent, Prop_Send, "m_vecOrigin", fHellfireSkullPosition[client]);
 }

 War3_ChatMessage(0, "SICK SPIT SPAWNED");
 bIgnoreFirstKill[client] = true;
 return ent;
 }

 stock bool:entClassnameContains(ent, String:strRefClassname[])
 {
 if (!IsValidEntity(ent))
 {
 return false;
 }

 decl String:strEntClassname[32];
 GetEdictClassname(ent, strEntClassname, sizeof(strEntClassname));
 return (StrContains(strEntClassname, strRefClassname, false) != -1);
 }

 public OnGameFrame()
 {
 decl Float:thisPos[3];
 decl Float:nextPos[3];
 decl Float:hitPos[3];
 decl Float:hitVec[3];

 for(new client = 1; client <= MaxClients; client++)
 {
 if(ValidPlayer(client))
 {
 if(entClassnameContains(iHellfireSkullEntity[client], "prop_physics_multiplayer"))
 {
 // Use current and previous position of given entity to calculate a 
 // predicted next position. Then, perform a traceray between the current
 // and predicted next position.
 GetEntPropVector(iHellfireSkullEntity[client], Prop_Send, "m_vecOrigin", thisPos);
 SubtractVectors(thisPos, fHellfireSkullPosition[client], nextPos);
 AddVectors(thisPos, nextPos, nextPos);

 //War3_ChatMessage(0, "Start: %f %f %f", thisPos[0], thisPos[1], thisPos[2]);
 //War3_ChatMessage(0, "End: %f %f %f", nextPos[0], nextPos[1], nextPos[2]);

 decl Float:vMins[3], Float:vMaxs[3];
 vMins = Float: {-1.0, -1.0, -1.0};
 vMaxs = Float: {1.0, 1.0, 1.0};

 new Handle:TraceEx = TR_TraceHullFilterEx(thisPos, nextPos, vMins, vMaxs, MASK_SHOT, ExcludeSelf_Filter, client);
 if(TR_DidHit(TraceEx))
 {
 TR_GetEndPosition(hitPos, TraceEx);
 TR_GetPlaneNormal(TraceEx, hitVec);

 new hitEntity = TR_GetEntityIndex(TraceEx);
 if(hitEntity == 0)
 {
 //RemoveEffectItem(client, ZFItemType:entIdx);
 if(!TR_PointOutsideWorld(hitPos))
 {
 if (bIgnoreFirstKill[client])
 {
 bIgnoreFirstKill[client] = false;
 
 }
 else {
 doSickHit(client, hitPos, hitVec);
 AcceptEntityInput(iHellfireSkullEntity[client], "kill");
 //fxBits(iHellfireSkullEntity[client]);    
 }
 }
 }
 else {
 War3_ChatMessage(0, "WE HIT %i", hitEntity);
 }
 CloseHandle(TraceEx);
 }

 }

 // Update position
 fHellfireSkullPosition[client][0] = thisPos[0];
 fHellfireSkullPosition[client][1] = thisPos[1];
 fHellfireSkullPosition[client][2] = thisPos[2];
 }
 }
 }

 doSickHit(client, Float:hitPos[3], Float:hitVec[3])
 {
 ThrowAwayParticle(PARTICLE_DEATH, hitPos, 3.0);

 }

 public bool:ExcludeSelf_Filter(ent, contentsMask, any:client)
 {
 return ent != client && ValidPlayer(ent, true);
 }

 */

public bool:ImmunityCheck(client)
{
    if(W3HasImmunity(client, Immunity_Abilities))
    {
        return false;
    }
    return true;
}

public Action:StopHellfireStun(Handle:timer, any:client)
{
    if (ValidPlayer(client, true))
    {
        War3_SetBuff(client, bStunned, thisRaceID, false);

        new caster = HellfiredBy[client];
        new skill = War3_GetSkillLevel(caster, thisRaceID, ABILITY_HELLFIRE);
        War3_SetBuff(client, fSlow, thisRaceID, fHellfireSlowPercentage[skill]);

        CreateTimer(fHellfireSlowTime, UnslowEnemy, client);
    }
}

public Action:UnslowEnemy(Handle:timer, any:client)
{
    if (ValidPlayer(client, true))
    {
        War3_SetBuff(client, fSlow, thisRaceID, 1.0);
    }
}

