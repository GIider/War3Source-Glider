#pragma semicolon 1

#include "W3SIncs/War3Source_Interface"

public Plugin:myinfo = 
{
    name = "War3Source Race - L4D Survivor Firestarter",
    author = "Glider",
    description = "The Survivor Firestarter race for War3Source.",
    version = "1.0",
}; 

//=======================================================================
//                             VARIABLES
//=======================================================================

new thisRaceID;
new SKILL_BURNING_MAN, SKILL_FIRE_ARMOR, SKILL_BOOTS, ULT_FIREWAVE;

new Float:ULT_COOLDOWN = 60.0;

new Float:IncendiaryAmount[5]={0.0, 0.25, 0.5, 0.75, 1.0};
new Float:FireResistance[5]={1.0,0.75,0.5,0.25,0.0};
new Float:SpeedIncrease[5]={1.0,1.06,1.12,1.18,1.23};
new Float:FireWaveRange = 1000.0;

new clientParticle[MAXPLAYERS][2];
new clientLight[MAXPLAYERS][2];

new String:UltimateSnd[]="weapons/molotov/fire_ignite_1.wav"; 

//=======================================================================
//                                 INIT
//=======================================================================

public OnWar3PluginReady(){
    thisRaceID = War3_CreateNewRace("Firestarter", "firestarter");
    SKILL_BURNING_MAN = War3_AddRaceSkill(thisRaceID, "Incendiary Ammunition", "When you refill your ammo you gain 25/50/75/100% incendiary ammo", false, 4);
    SKILL_FIRE_ARMOR = War3_AddRaceSkill(thisRaceID, "Fire Armor", "25/50/75/100% resistance to fire damage", false, 4);
    SKILL_BOOTS = War3_AddRaceSkill(thisRaceID, "Fiery boots", "Run 6/12/18/23% faster", false, 4);
    ULT_FIREWAVE = War3_AddRaceSkill(thisRaceID, "Fire Wave", "Cast a fire wave that deals 10 damage and sets enemys 1000 units close to you ablaze. CD: 60s", true, 1);
    
    War3_CreateRaceEnd(thisRaceID);
}

public OnPluginStart()
{
    if(War3_GetGame() != Game_L4D && War3_GetGame() != Game_L4D2)
        SetFailState("Only works in the L4D engine! %i", War3_GetGame());
    
    HookEvent("ammo_pickup", Event_AmmoPickup);
    HookEvent("player_use", Event_PlayerUse);
    
    CreateTimer(0.1, KeepOnFireTimer, _, TIMER_REPEAT);
}

public Action:KeepOnFireTimer(Handle:timer, any:userid)
{
    for(new client=1; client <= MaxClients; client++)
    {
        if(ValidPlayer(client, true))
        {
            if(War3_GetRace(client) == thisRaceID)
            {
                IgniteEntity(client, 0.1);
            }
        }
    }
}

public OnMapStart()
{
    War3_PrecacheParticle("fire_small_flameouts");
    War3_PrecacheParticle("gas_explosion_initialburst");
    
    War3_AddCustomSound(UltimateSnd);
}

givePlayerBuffs(client)
{
    if (ValidPlayer(client, true))
    {
        if(War3_GetRace(client) == thisRaceID)
        {
            new skill_mspd = War3_GetSkillLevel(client, thisRaceID, SKILL_BOOTS);
            if (skill_mspd > 0 && (GetClientTeam(client) == TEAM_SURVIVORS))
            {
                War3_SetBuff(client, fMaxSpeed, thisRaceID, SpeedIncrease[skill_mspd]);
                
                // Check if this guy already has a particle.
                // If he has one we just assume has the second one aswell...
                decl String:className[64];
                if(IsValidEdict(clientParticle[client][0]))
                    GetEdictClassname(clientParticle[client][0], className, sizeof(className));
                
                if(!StrEqual(className, "info_particle_system"))
                {
                    clientParticle[client][0] = AttachParticle(client, "fire_small_flameouts", NULL_VECTOR, "lfoot");
                    clientParticle[client][1] = AttachParticle(client, "fire_small_flameouts", NULL_VECTOR, "rfoot");
                    
                    clientLight[client][0] = AttachLight(client, NULL_VECTOR, "225 30 0 255", "5", 55.0, "lfoot");
                    clientLight[client][1] = AttachLight(client, NULL_VECTOR, "225 30 0 255", "5", 55.0, "rfoot");
                }
            }
            else 
                KillEntitys(client);
        }
    }
}

public OnWar3EventSpawn(client)
{    
    givePlayerBuffs(client);
}

public OnWar3EventDeath(victim, attacker)
{
    if(War3_GetRace(victim) == thisRaceID)
        KillEntitys(victim);
}

public OnRaceChanged(client, oldrace, newrace)
{
    if(newrace != thisRaceID)
    {
        War3_SetBuff(client,fMaxSpeed,thisRaceID,1.0);
        KillEntitys(client);
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

KillEntitys(client)
{
    decl String:className[64];
    if(IsValidEdict(clientParticle[client][0]))
    {
        GetEdictClassname(clientParticle[client][0], className, sizeof(className));
    
        if(StrEqual(className, "info_particle_system"))
        {
            AcceptEntityInput(clientParticle[client][0], "kill");
            AcceptEntityInput(clientParticle[client][1], "kill");
            
            clientParticle[client][0] = 0;
            clientParticle[client][1] = 0;
                        
            
            AcceptEntityInput(clientLight[client][0], "kill");
            AcceptEntityInput(clientLight[client][1], "kill");
            
            clientLight[client][0] = 0;
            clientLight[client][1] = 0;
        }
    }
}

//=======================================================================
//                                 Incendiary Ammo
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
                new skill = War3_GetSkillLevel(client, thisRaceID, SKILL_BURNING_MAN);
                if (skill > 0)
                {
                    new oldgun = GetPlayerWeaponSlot(client, 0); //get the players primary weapon
                    if (IsValidEdict(oldgun))
                    {
                        FireAmmoRoutine(client, oldgun, skill);
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
        new skill = War3_GetSkillLevel(client, thisRaceID, SKILL_BURNING_MAN);
        if (skill > 0)
        {
            new oldgun = GetPlayerWeaponSlot(client, 0); //get the players primary weapon
            if (IsValidEdict(oldgun))
            {
                FireAmmoRoutine(client, oldgun, skill);
            }
        }
    }
}

FireAmmoRoutine(client, oldgun, skill)
{
    new ammo = GetEntProp(oldgun, Prop_Send, "m_nUpgradedPrimaryAmmoLoaded");
    if (ammo == 0)
    {    
        decl String:currentgunname[64];
        GetEdictClassname(oldgun, currentgunname, sizeof(currentgunname)); //get the primary weapon name
        
        AddFireAmmo(client, GetMaxMagSize(currentgunname), skill);
    }
    else
    {
        W3Hint(client, HINT_LOWEST, 1.0, "You still have special ammo left!");
    }
}

stock Action:AddFireAmmo(client, ammo, skill)
{
    new ammo_to_add = RoundToCeil(ammo * IncendiaryAmount[skill]);
        
    CheatCommand(client, "upgrade_add", "INCENDIARY_AMMO");
    SetSpecialAmmoInPlayerGun(client, ammo_to_add);

    return Plugin_Continue;
}

//=======================================================================
//                                 Fire Armor
//=======================================================================


public OnW3TakeDmgAllPre(victim,attacker,Float:damage){
    if(ValidPlayer(victim, true))
    {
        if(War3_GetRace(victim) == thisRaceID)
        {
            new resistance_skill = War3_GetSkillLevel(victim, thisRaceID, SKILL_FIRE_ARMOR);
            if (W3GetDamageType() & DMG_BURN)
                War3_DamageModPercent(FireResistance[resistance_skill]);
        }
    }
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
//                                 Fire Wave
//=======================================================================


public OnUltimateCommand(client,race,bool:pressed)
{
    if(ValidPlayer(client, true) && 
       race == thisRaceID && 
       pressed && 
       War3_SkillNotInCooldown(client, thisRaceID, ULT_FIREWAVE, true) && 
       !Silenced(client) &&
       GetClientTeam(client) == TEAM_SURVIVORS &&
       !War3_L4D_IsHelpless(client) &&
       !War3_IsPlayerIncapped(client))
    {    
        new skill = War3_GetSkillLevel(client, thisRaceID, ULT_FIREWAVE);
        if (skill > 0)
        {
            new iWeapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
            SetEntProp(iWeapon, Prop_Send, "m_helpingHandState", 3);
            
            new entity = -1;
            new Float:VictimPosition[3];
            new Float:CasterPosition[3];
            decl String:ModelName[128];
            //GetClientAbsOrigin(client, CasterPosition);
            GetClientEyePosition(client, CasterPosition);
            
            while ((entity = FindEntityByClassname(entity, "infected")) != INVALID_ENT_REFERENCE) 
            {
                // Great... Zombies in Hazmat suits!
                GetEntPropString(entity, Prop_Data, "m_ModelName", ModelName, sizeof(ModelName));
                if (!StrEqual(ModelName, "models/infected/common_male_ceda.mdl"))
                {
                    GetEntPropVector(entity, Prop_Send, "m_vecOrigin", VictimPosition);
                    VictimPosition[2] += 30; // also testing
                    new Float:dis = GetVectorDistance(CasterPosition, VictimPosition);
                    
                    if (dis < (FireWaveRange * 0.5))
                    {
                        War3_DealDamage(entity, 10, client, 8, "firewave");
                    }
                }
            }
            
            while ((entity = FindEntityByClassname(entity, "witch")) != INVALID_ENT_REFERENCE) 
            {
                GetEntPropVector(entity, Prop_Send, "m_vecOrigin", VictimPosition);
                new Float:dis = GetVectorDistance(CasterPosition, VictimPosition);
                
                if (dis < (FireWaveRange * 0.5))
                {
                    War3_DealDamage(entity, 10, client, 8, "firewave");
                }
            }
            
            // check special infected
            for(new i=1; i <= MaxClients; i++)
            {
                if(ValidPlayer(i, true) && GetClientTeam(i) == TEAM_INFECTED)
                {
                    GetClientAbsOrigin(i, VictimPosition);
                    new Float:dis = GetVectorDistance(CasterPosition, VictimPosition);
                    
                    if (dis < (FireWaveRange * 0.5))
                    {
                        War3_DealDamage(i, 10, client, 8, "firewave");
                    }
                }
            }
            
            EmitSoundToAll(UltimateSnd, client);
            
            decl Float:fPos[3];
                    
            GetEntPropVector(client, Prop_Send, "m_vecOrigin", fPos);
            fPos[2] += 50.0;
            
            ThrowAwayParticle("gas_explosion_pump", fPos, 2.5); 
            ThrowAwayLightEmitter(fPos, "225 30 0 255", "5", 800.0, 0.4);
            
            War3_CooldownMGR(client, ULT_COOLDOWN, thisRaceID, ULT_FIREWAVE);
        }
    }
}
