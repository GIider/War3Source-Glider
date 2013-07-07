#pragma semicolon 1

#include "W3SIncs/War3Source_Interface"
#include <sdkhooks>

public Plugin:myinfo = 
{
    name = "War3Source Race - L4D Survivor Support",
    author = "Glider",
    description = "The Survivor Support race for War3Source.",
    version = "1.0",
}; 

//=======================================================================
//                             VARIABLES
//=======================================================================

#define AMMO_MDL "models/props/terror/ammo_stack.mdl"
#define AMMO_RANGE 350.0
#define LASER_RANGE 350.0
#define RADIANCE_RANGE 150.0
#define ULT_COOLDOWN 360.0
#define LASER_TIMER 90.0

new const BEAM_COLOR[4] = {255, 0, 0, 255};

new g_iBackpackEntity[MAXPLAYERS] = INVALID_ENT_REFERENCE;
new g_iAmountOfLasersights[MAXPLAYERS];
new Float:g_fDamageTaken[MAXPLAYERS];

new thisRaceID;
new SKILL_AMMO, SKILL_LASER, SKILL_RADIANCE, ULT_SWIFT_RECOVERY;

new Float: fAmmoRegenRate[5] = {0.0, 0.005, 0.01, 0.015, 0.02};
new iMaxLasers[5] = {0, 1, 2, 3, 4};
new Float: fTimeBeforeDamageDecrease[5] = {0.0, 1.0, 2.0, 3.0, 4.0};

// Tempents
new g_BeamSprite;
new g_HaloSprite;

//=======================================================================
//                                 INIT
//=======================================================================

public OnWar3PluginReady(){
    thisRaceID = War3_CreateNewRace("Support", "support");
    SKILL_AMMO = War3_AddRaceSkill(thisRaceID, "Ammo Backpack", "Regenerate 0.5/1/1.5/2% ammo every 5 seconds for everyone around you.\nYou get twice the amount.", false, 4);
    SKILL_LASER = War3_AddRaceSkill(thisRaceID, "Laser Sights", "You get lasersights to give away every 90 seconds.\nWith this you can store up to 1/2/3/4 lasersights", false, 4);
    SKILL_RADIANCE = War3_AddRaceSkill(thisRaceID, "Radiance", "You deal the total damage you took in the last 1/2/3/4 seconds back in an AoE", false, 4);
    ULT_SWIFT_RECOVERY = War3_AddRaceSkill(thisRaceID, "Swift Recovery", "Everybodys temporary health is exchanged for permanent health. CD: 360s", true, 1);
    War3_CreateRaceEnd(thisRaceID);
}

public OnPluginStart()
{
    if(War3_GetGame() != Game_L4D && War3_GetGame() != Game_L4D2)
        SetFailState("Only works in the L4D engine! %i", War3_GetGame());
    
    CreateTimer(5.0, RegenAmmoTimer, _, TIMER_REPEAT);
    CreateTimer(LASER_TIMER, GiveSupportLaserSightsTimer, _, TIMER_REPEAT);
    CreateTimer(5.0, GiveLaserAwayTimer, _, TIMER_REPEAT);
    
    CreateTimer(1.0, DamageDealingTimer, _, TIMER_REPEAT);
}

public OnMapStart()
{
    g_BeamSprite = PrecacheModel("materials/sprites/laserbeam.vmt");
    g_HaloSprite = PrecacheModel("materials/sprites/glow01.vmt");
    
    PrecacheModel(AMMO_MDL);
}


// FUCKING ATTACHMENTS
///////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////

public OnWar3EventSpawn(client)
{
    if(ValidPlayer(client, true) && War3_GetRace(client) == thisRaceID)
    {
        giveAttachments(client);
        g_iAmountOfLasersights[client] = 0;
        g_fDamageTaken[client] = 0.0;
    }
}

public OnWar3EventDeath(victim, attacker)
{
    if(ValidPlayer(victim) && War3_GetRace(victim) == thisRaceID)
    {
        removeAttachments(victim);
        g_iAmountOfLasersights[victim] = 0;
        g_fDamageTaken[victim] = 0.0;
    }
}

public OnRaceChanged(client, oldrace, newrace)
{
    if(newrace != thisRaceID && oldrace == thisRaceID)
    {
        removeAttachments(client);
        g_iAmountOfLasersights[client] = 0;
        g_fDamageTaken[client] = 0.0;
    }
    else if (newrace == thisRaceID && oldrace != thisRaceID)
    {    
        giveAttachments(client);
        g_iAmountOfLasersights[client] = 0;
        g_fDamageTaken[client] = 0.0;
    }
}

public OnSkillLevelChanged(client, race, skill, newskilllevel)
{
    if (race == thisRaceID)
    {
        if (skill == SKILL_AMMO && newskilllevel > 0)
            giveAttachments(client);
        else if (skill == SKILL_AMMO && newskilllevel == 0)
            removeAttachments(client);
        
        if (skill == SKILL_LASER && iMaxLasers[newskilllevel] > g_iAmountOfLasersights[client]) {
            g_iAmountOfLasersights[client] = iMaxLasers[newskilllevel];
        }
    }
}

giveAttachments(client) {
    if(ValidPlayer(client, true) && GetClientTeam(client) == TEAM_SURVIVORS)
    {
        new skill = War3_GetSkillLevel(client, thisRaceID, SKILL_AMMO);
        if (skill > 0) {
            decl String:className[64];
            if(IsValidEdict(g_iBackpackEntity[client]))
                GetEdictClassname(g_iBackpackEntity[client], className, sizeof(className));
            
            if(!StrEqual(className, "prop_dynamic"))
                g_iBackpackEntity[client] = CreateBackpack(client);
        }
    }
}

removeAttachments(client) {
    if(IsValidEdict(g_iBackpackEntity[client]))
    {
        decl String:className[64];
        GetEdictClassname(g_iBackpackEntity[client], className, sizeof(className));
        
        if(StrEqual(className, "prop_dynamic"))
        {
            AcceptEntityInput(g_iBackpackEntity[client], "kill");
            
            g_iBackpackEntity[client] = INVALID_ENT_REFERENCE;
            
        }
    }
}

CopyVector(Float:source[3], Float:target[3])
{
    target[0]=source[0];
    target[1]=source[1];
    target[2]=source[2];
}

CreateBackpack(client)
{
    new Float:ang[3];
    GetClientAbsAngles(client, ang);
    
    new backpack = CreateEntityByName("prop_dynamic_override"); 
    DispatchKeyValue(backpack, "model", AMMO_MDL);  
    DispatchSpawn(backpack); 
    SetEntProp(backpack, Prop_Data, "m_takedamage", 0, 1);  
    SetEntityMoveType(backpack, MOVETYPE_NOCLIP);
    SetEntProp(backpack, Prop_Data, "m_CollisionGroup", 2); 
    
    ModifyEntityAttach(backpack, client, "medkit");

    decl Float:ang3[3];
    CopyVector(ang, ang3);

    ang3[2] += 90.0; 
    ang3[1] -= 90.0;
        
    DispatchKeyValueVector(backpack, "Angles", ang3); 
 
    SetEntProp(backpack, Prop_Send, "m_iGlowType", 3 );
    SetEntProp(backpack, Prop_Send, "m_nGlowRange", 0 );
    SetEntProp(backpack, Prop_Send, "m_glowColorOverride", 1);
    
    SDKHook(backpack, SDKHook_SetTransmit, Hook_SetTransmit);
    
    return backpack;
}

public Action:Hook_SetTransmit(backpack, client)
{ 
    if (backpack == g_iBackpackEntity[client])
    {
        return Plugin_Handled; 
    }
    
    return Plugin_Continue;
}

///////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////

public Action:RegenAmmoTimer(Handle:timer, any:userid)
{
    for(new client=1; client <= MaxClients; client++)
    {
        if(ValidPlayer(client, true) && War3_GetRace(client) == thisRaceID)
        {
            new Float:SupportPosition[3];
            GetClientEyePosition(client, SupportPosition);
            
            new String:name[64];
            GetClientName(client, name, sizeof(name));
            
            new skill = War3_GetSkillLevel(client, thisRaceID, SKILL_AMMO);
            if(skill > 0)
            { 
                for(new friendly=1; friendly <= MaxClients; friendly++)
                {
                    if(ValidPlayer(friendly, true) && GetClientTeam(friendly) == TEAM_SURVIVORS) 
                    {
                        new Float:FriendlyPosition[3];
                        GetClientEyePosition(friendly, FriendlyPosition);
                        
                        if (GetVectorDistance(SupportPosition, FriendlyPosition) <= AMMO_RANGE) {
                            decl String:weapon[64];
                            new primary = GetPlayerWeaponSlot(friendly, 0);
                            if (IsValidEntity(primary)) {
                                GetEdictClassname(primary, weapon, sizeof(weapon));
                            
                                if(!StrEqual(weapon, "weapon_grenade_launcher") && !StrEqual(weapon, "weapon_rifle_m60")) {
                                    new max_ammo = GetMaxBackupAmmo(weapon);
                                    new current_ammo = GetCurrentBackupAmmo(friendly);
                                    
                                    if(current_ammo < max_ammo) {
                                        new Float:ammo_regen_rate = fAmmoRegenRate[skill];
                                        
                                        if (client == friendly) {
                                            ammo_regen_rate *= 2;
                                        }
                                        
                                        new ammo_to_regen = Max(RoundToFloor(ammo_regen_rate * max_ammo), 1);    
                                        new final_new_ammo = Min(max_ammo, current_ammo + ammo_to_regen);
                                        
                                        new ammo_regenerated = final_new_ammo - current_ammo;
                                        
                                        SetBackupAmmo(friendly, final_new_ammo);
                                        
                                        if (friendly == client) {
                                            if (ammo_regenerated > 1)
                                                W3Hint(client, HINT_SKILL_STATUS, 1.0, "You got %i bullets", ammo_regenerated);
                                            else 
                                                W3Hint(client, HINT_SKILL_STATUS, 1.0, "You got %i bullet", ammo_regenerated);
                                        }
                                        else {
                                            if (ammo_regenerated > 1)
                                                W3Hint(friendly, HINT_SKILL_STATUS, 1.0, "You got %i bullets thanks to %s", ammo_regenerated, name);
                                            else
                                                W3Hint(friendly, HINT_SKILL_STATUS, 1.0, "You got %i bullet thanks to %s", ammo_regenerated, name);
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

Min(x, y)
{
    if (x > y)
        return y;
    
    return x;
}

Max(x, y)
{
    if (x > y)
        return x;
    
    return y;
}

///////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////

public Action:GiveSupportLaserSightsTimer(Handle:timer, any:userid)
{
    for(new client=1; client <= MaxClients; client++)
    {
        if(ValidPlayer(client, true) && War3_GetRace(client) == thisRaceID)
        {
            new skill = War3_GetSkillLevel(client, thisRaceID, SKILL_LASER);
            if(skill > 0)
            { 
                if (g_iAmountOfLasersights[client] < iMaxLasers[skill]) {
                    g_iAmountOfLasersights[client]++;
                    
                    if (!giveAwayLaser(client)) {
                        W3Hint(client, HINT_SKILL_STATUS, 1.0, "You got another lasersight! You now have %i in stock", g_iAmountOfLasersights[client]);
                    }
                }
            }
        }
    }
}

public Action:GiveLaserAwayTimer(Handle:timer, any:userid)
{
    for(new client=1; client <= MaxClients; client++)
    {
        giveAwayLaser(client);
    }
}

giveAwayLaser(support) {
    if(ValidPlayer(support, true) && War3_GetRace(support) == thisRaceID)
    {
        new String:name[64];
        GetClientName(support, name, sizeof(name));
        
        for(new dummyvar=0; dummyvar < g_iAmountOfLasersights[support]; dummyvar++) {
            new friendly = findClosestWithoutLaser(support);
            
            if (ValidPlayer(friendly, true)) {
                new primary = GetPlayerWeaponSlot(friendly, 0);
                new upgrades = L4D2_GetWeaponUpgrades(primary);
                L4D2_SetWeaponUpgrades(primary, L4D2_WEPUPGFLAG_LASER + upgrades);
                
                if (friendly == support) {
                    W3Hint(support, HINT_SKILL_STATUS, 1.0, "You upgrade yourself with a lasersight!");
                }
                else {
                    W3Hint(friendly, HINT_SKILL_STATUS, 1.0, "You got a lasersight thanks to %s", name);
                    
                    new String:friendlyname[64];
                    GetClientName(friendly, friendlyname, sizeof(friendlyname));
                    W3Hint(support, HINT_SKILL_STATUS, 1.0, "You gave a lasersight to %s", friendlyname);
                }
                
                g_iAmountOfLasersights[support]--;
                return true;
            }
        }
    }
    
    return false;
}
    
findClosestWithoutLaser(support) {
    new Float:SupportPosition[3];
    GetClientEyePosition(support, SupportPosition);
    
    new Float:fClosestRange = 1000.0;
    new iClosestPlayer = 0;
    
    for(new friendly=1; friendly <= MaxClients; friendly++)
    {    
        if(ValidPlayer(friendly, true) && GetClientTeam(friendly) == TEAM_SURVIVORS) 
        {
            new Float:FriendlyPosition[3];
            GetClientEyePosition(friendly, FriendlyPosition);
            
            new primary = GetPlayerWeaponSlot(friendly, 0);
            if (IsValidEntity(primary) && !(L4D2_GetWeaponUpgrades(primary) & L4D2_WEPUPGFLAG_LASER)) {
                new Float:fDistance = GetVectorDistance(SupportPosition, FriendlyPosition);
    
                if (fDistance < fClosestRange && fDistance <= LASER_RANGE) {
                    fClosestRange = fDistance;
                    iClosestPlayer = friendly;
                }
            }    
        }
    }
    
    return iClosestPlayer;
}

///////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////

public OnUltimateCommand(client, race, bool:pressed)
{
    if(ValidPlayer(client, true) && 
       race == thisRaceID && 
       pressed && 
       War3_SkillNotInCooldown(client, thisRaceID, ULT_SWIFT_RECOVERY, true) && 
       !Silenced(client) &&
       GetClientTeam(client) == TEAM_SURVIVORS &&
       !War3_L4D_IsHelpless(client) &&
       !War3_IsPlayerIncapped(client))
    {    
        new skill = War3_GetSkillLevel(client, thisRaceID, ULT_SWIFT_RECOVERY);
        if(skill > 0)
        {
            new String:name[64];
            GetClientName(client, name, sizeof(name));
            new bool:bHasHelped;
            
            for(new i=0; i < MAXPLAYERS; i++)
            {
                if (ValidPlayer(i, true) && !War3_IsPlayerIncapped(i))
                {
                    new Float:temphealth = GetSurvivorTempHealth(i);
                    new permanenthealth = GetClientHealth(i);
                    
                    if(temphealth > 0.0) {
                        SetSurvivorTempHealth(i, 0.0);
                        SetEntityHealth(i, Min(RoundToCeil(temphealth + permanenthealth), 100));
                        
                        if(i != client)
                            W3Hint(i, HINT_SKILL_STATUS, 1.0, "%s has patched up your wounds", name);
                        else
                            W3Hint(i, HINT_SKILL_STATUS, 1.0, "You patched up your wounds.");
                        
                        bHasHelped = true;
                    }
                }
            }
            
            if (bHasHelped) {
                War3_CooldownMGR(client, ULT_COOLDOWN, thisRaceID, ULT_SWIFT_RECOVERY);
            }
            else {
                W3Hint(client, HINT_SKILL_STATUS, 1.0, "That wouldn't do anything!");
            }
        }
    }
}

///////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////

public OnW3TakeDmgAll(victim, attacker, Float:damage) {
    if (ValidPlayer(victim, true) && War3_GetRace(victim) == thisRaceID) {
        new skill = War3_GetSkillLevel(victim, thisRaceID, SKILL_RADIANCE);
        if(skill > 0)
        { 
            if((ValidPlayer(attacker) && GetClientTeam(attacker) == TEAM_INFECTED) || War3_IsL4DZombieEntity(attacker)) {
                g_fDamageTaken[victim] += damage;
                
                //War3_ChatMessage(victim, "Increasing your damage by %f", damage);
                
                new Handle:pack;
                CreateDataTimer(fTimeBeforeDamageDecrease[skill], RemoveDamageTimer, pack);
                WritePackCell(pack, victim);
                WritePackFloat(pack, damage);
            }
        }
    }
}

public Action:RemoveDamageTimer(Handle:timer, Handle:pack)
{
    new client;
    new Float:damage;
 
    ResetPack(pack);
    client = ReadPackCell(pack);
    damage = ReadPackFloat(pack);
    
    g_fDamageTaken[client] -= damage;

    if (g_fDamageTaken[client] < 0.0) {
        g_fDamageTaken[client] = 0.0;
    }

}

public Action:DamageDealingTimer(Handle:timer, any:userid)
{
    for(new client=1; client <= MaxClients; client++)
    {
        if(ValidPlayer(client, true) && War3_GetRace(client) == thisRaceID)
        {
            new skill = War3_GetSkillLevel(client, thisRaceID, SKILL_RADIANCE);
            if(skill > 0)
            { 
                new Float:SurvivorPos[3];
                new Float:EnemyPos[3];
                new damage = RoundToCeil(g_fDamageTaken[client]);
                
                if (damage < 0) {
                    damage = 0;
                    g_fDamageTaken[client] = 0.0;
                }
                
                if (damage > 0) {
                    W3Hint(client, HINT_SKILL_STATUS, 1.0, "Dealing %i damage due to radiance", damage);
                    
                    GetClientAbsOrigin(client, SurvivorPos);
        
                    // check special infected
                    for(new i=1; i <= MaxClients; i++)
                    {
                        if(ValidPlayer(i, true) && GetClientTeam(i) == TEAM_INFECTED)
                        {
                            GetClientAbsOrigin(i, EnemyPos);
                            
                            if(GetVectorDistance(SurvivorPos, EnemyPos) <= RADIANCE_RANGE)
                            {
                                War3_DealDamage(i, damage, client, DMG_RADIATION, "radiance");
                            }
                        }
                    }
                    
                    // check common infected
                    new entity = -1;
                    while ((entity = FindEntityByClassname(entity, "infected")) != INVALID_ENT_REFERENCE) 
                    {
                        GetEntPropVector(entity, Prop_Send, "m_vecOrigin", EnemyPos);
                        
                        if(GetVectorDistance(SurvivorPos, EnemyPos) <= RADIANCE_RANGE)
                        {
                            //new ragdoll = GetEntProp(entity, Prop_Send, "m_bClientSideRagdoll");
                            //if (ragdoll != 1)
                            //{
                            War3_DealDamage(entity, damage, client, DMG_RADIATION, "radiance");
                            //}
                        }
                    }
                    // check witch... harhar how evil :D
                    entity = -1;
                    while ((entity = FindEntityByClassname(entity, "witch")) != INVALID_ENT_REFERENCE) 
                    {
                        GetEntPropVector(entity, Prop_Send, "m_vecOrigin", EnemyPos);
                        
                        if(GetVectorDistance(SurvivorPos, EnemyPos) <= RADIANCE_RANGE)
                        {
                            War3_DealDamage(entity, damage, client, DMG_RADIATION, "radiance");
                        }
                    }
                    
                    SurvivorPos[2] += 20;
                    
                    TE_SetupBeamRingPoint(SurvivorPos, 0.0, RADIANCE_RANGE, g_BeamSprite, g_HaloSprite, 0, 60, 1.0, float(damage), 0.1, BEAM_COLOR, 50, 0);
                    TE_SendToAll();
                    
                }
            }
        }
    }
}
