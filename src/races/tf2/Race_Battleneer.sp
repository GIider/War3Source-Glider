#pragma semicolon 1

#include "W3SIncs/War3Source_Interface"
#include <tf2>
#include <tf2_objects>
#include <tf2_build_working>
#include <ztf2grab>

public Plugin:myinfo =
{
    name = "War3Source Race - Battleneer",
    author = "Glider",
    description = "The Battleneer race for War3Source.",
    version = "1.0",
};

//=======================================================================
//                             VARIABLES
//=======================================================================

// fix broken regeneration code

new thisRaceID;  
new SKILL_DEVICE, SKILL_SYNERGY, ABILITY_WARP, ULTIMATE_GRAVGUN;

new bool: bCanWarpIn;
new const Float:fWarpCooldown = 60.0;
new Float:fDeviceRange[5] = {0.0, 50.0, 100.0, 150.0, 200.0};

new Float:SynergyModifierUpgrade[5] = {0.0, 0.05, 0.05, 0.1, 0.1};
new Float:SynergyModifierHealth[5] = {0.0, 0.04, 0.06, 0.08, 0.1};
new Float:SynergyModifierMetal[5] = {0.0, 0.05, 0.05, 0.05, 0.05};
new Float:SynergyModifierShells[5] = {0.0, 0.04, 0.05, 0.05, 0.06};
new Float:SynergyModifierRocket[5] = {0.0, 0.05, 0.05, 0.1, 0.1};

#define DEATH_TIMER 120.0
#define BUSTER_RANGE 250.0

//=======================================================================
//                                 INIT
//=======================================================================

public OnWar3PluginReady() {
    thisRaceID = War3_CreateNewRace("Battleneer", "Battleneer");

    SKILL_DEVICE = War3_AddRaceSkill(thisRaceID, "Anti-Espionage-Device", "You uncloak spys around you", false, 4);
    SKILL_SYNERGY = War3_AddRaceSkill(thisRaceID, "Synergy", "Damage you deal repairs your buildings", false, 4);
    ABILITY_WARP = War3_AddRaceSkill(thisRaceID, "Warp-In (+ability)", "You can spawn buildings that despawn after 2 minutes. CD: 60s", false, 4);
    ULTIMATE_GRAVGUN = War3_AddRaceSkill(thisRaceID, "Gravity Gun", "Pick up your buildings and carry them around", true, 1);
    War3_CreateRaceEnd(thisRaceID);
}

public OnPluginStart()
{
    if(War3_GetGame() != Game_TF)
        SetFailState("Only works in the TF2 engine! %i", War3_GetGame());

    CreateTimer(1.0, UncloakTimer, _, TIMER_REPEAT);
    
    HookEventEx("mvm_begin_wave", eCanWarp);
    HookEventEx("mvm_mission_complete", eCantWarp);
    HookEventEx("mvm_wave_complete", eCantWarp);
    HookEventEx("teamplay_restart_round", eCantWarp);
    HookEventEx("stats_resetround", eCantWarp);
    
    ControlZtf2grab();
}

//=======================================================================
//                                 Stocks
//=======================================================================

stock bool:BuildingIsBusy(ent)
{
    if(GetEntProp(ent, Prop_Send, "m_bHasSapper") ||
       GetEntProp(ent, Prop_Send, "m_bBuilding") || 
       GetEntProp(ent, Prop_Send, "m_bPlacing") || 
       GetEntProp(ent, Prop_Send, "m_bCarried")) 
        return true;

    return false;
}

public bool:TF2_EdictNameEqual(entity, String:name[])
{
    if(entity > 0)
    {
        if(IsValidEdict(entity))
        {
            new String:edictName[64];
            GetEdictClassname(entity, edictName, sizeof(edictName));
            return StrEqual(edictName, name);
        }
    }
    return false;
}

stock Min(x, y)
{
    if (x < y)
        return x;
    
    return y;
}

SynergyBuildings(builder, skill, Float:damage)
{
    new ent = 0;
    
    new buildinglist[1000];
    new buildingsfound = 0;
    
    while((ent = FindEntityByClassname(ent, "obj_sentrygun")) > 0)
    {
        buildinglist[buildingsfound] = ent;
        buildingsfound++;
    }
    
    while((ent = FindEntityByClassname(ent, "obj_dispenser")) > 0)
    {
        buildinglist[buildingsfound] = ent;
        buildingsfound++;
    }
    
    while((ent = FindEntityByClassname(ent, "obj_teleporter")) > 0)
    {
        buildinglist[buildingsfound] = ent;
        buildingsfound++;
    }

    for(new i=0 ; i < buildingsfound; i++)
    {
        ent = buildinglist[i];
        if(!IsValidEdict(ent)) continue;
        
        new obj_builder = GetEntPropEnt(ent, Prop_Send, "m_hBuilder");
        if(!ValidPlayer(obj_builder)) continue;

        if (obj_builder == builder)
        {
            // INTERESTING FOR ALL OBJECTS
            new SkillAddUpgrade = RoundToCeil(SynergyModifierUpgrade[skill] * damage);
            new SkillAddHealth = RoundToCeil(SynergyModifierHealth[skill] * damage);
            
            if(BuildingIsBusy(ent)) continue;
            
            // Stuff that applies to every building
            new CurrentHealth = GetEntProp(ent, Prop_Send, "m_iHealth");
            new MaxHealth = GetEntProp(ent, Prop_Send, "m_iMaxHealth"); 
            new NewHealth = Min(MaxHealth, CurrentHealth + SkillAddHealth);

            if(NewHealth != CurrentHealth)
            {
                SetVariantInt(NewHealth - CurrentHealth);
                AcceptEntityInput(ent, "AddHealth");
            }
            
            if(TF2_EdictNameEqual(ent, "obj_sentrygun"))
            {                
                new CurrentLevel = GetEntProp(ent, Prop_Send, "m_iUpgradeLevel");
                new IsMiniSentry = GetEntProp(ent, Prop_Send, "m_bMiniBuilding");

                // UPGRADE
                if (IsMiniSentry == 0)
                {
                    new CurrentUpgrade = GetEntProp(ent, Prop_Send, "m_iUpgradeMetal"); // GetEntData(ent,FindSendPropOffs("CObjectSentrygun", "m_iUpgradeMetal"), 4);
                    new NewUpgrade = 0;
                    
                    if ((CurrentLevel < TF2_MaxUpgradeLevel ) && (CurrentUpgrade <= TF2_MaxUpgradeMetal))
                    {
                        NewUpgrade = Min(TF2_MaxUpgradeMetal, CurrentUpgrade + SkillAddUpgrade);
                    }

                    SetEntProp(ent, Prop_Send, "m_iUpgradeMetal", NewUpgrade);
                }
                
                // AMMO

                new AddShells = RoundToCeil(SynergyModifierShells[skill] * damage);
                new AddRockets = RoundToCeil(SynergyModifierRocket[skill] * damage);

                new maxAmmo = 0;
                new maxRockets = 0;
                
                if (IsMiniSentry == 1)
                {
                    maxAmmo = TF2_MaxSentryShells[0];
                }
                else
                {
                    maxAmmo = TF2_MaxSentryShells[CurrentLevel];
                    maxRockets = TF2_MaxSentryRockets[CurrentLevel];
                }
                
                new ammo = GetEntProp(ent, Prop_Send, "m_iAmmoShells");
                                
                new NewAmmo = Min(maxAmmo, ammo + AddShells);
                SetEntProp(ent, Prop_Send, "m_iAmmoShells", NewAmmo);
                
                if (maxRockets > 0)
                {
                    new rockets = GetEntProp(ent, Prop_Send, "m_iAmmoRockets");
                    new NewRockets = Min(maxRockets, rockets + AddRockets);
                    
                    SetEntProp(ent, Prop_Send, "m_iAmmoRockets", NewRockets);
                }
            }
            
            else if(TF2_EdictNameEqual(ent, "obj_dispenser"))
            {
                new CurrentLevel = GetEntProp(ent, Prop_Send, "m_iHighestUpgradeLevel"); // GetEntData(ent,FindSendPropOffs("CObjectDispenser","m_iHighestUpgradeLevel"),4);
               
                // Upgrade

                new CurrentUpgrade = GetEntProp(ent, Prop_Send, "m_iUpgradeMetal"); // GetEntData(ent,FindSendPropOffs("CObjectDispenser","m_iUpgradeMetal"),4);

                new NewUpgrade = 0;
                if ((CurrentLevel < TF2_MaxUpgradeLevel ) && (CurrentUpgrade <= TF2_MaxUpgradeMetal))
                {
                    NewUpgrade = Min(TF2_MaxUpgradeMetal, CurrentUpgrade + SkillAddUpgrade);
                }

                SetEntProp(ent, Prop_Send, "m_iUpgradeMetal", NewUpgrade);

                // Metal
                
                new SkillAddMetal = RoundToCeil(SynergyModifierMetal[skill] * damage);
                new CurrentMetal = GetEntProp(ent, Prop_Send, "m_iAmmoMetal"); // GetEntData(ent,FindSendPropOffs("CObjectDispenser","m_iAmmoMetal"),4);
                new NewMetal = Min(TF2_MaxDispenserMetal, CurrentMetal + SkillAddMetal);
                        
                SetEntProp(ent, Prop_Send, "m_iAmmoMetal", NewMetal);

            }
            else if(TF2_EdictNameEqual(ent, "obj_teleporter"))
            {
                new CurrentLevel = GetEntProp(ent, Prop_Send, "m_iHighestUpgradeLevel"); // GetEntData(ent,FindSendPropOffs("CObjectTeleporter","m_iHighestUpgradeLevel"),4);
                
                // UPGRADING
                
                new CurrentUpgrade = GetEntProp(ent, Prop_Send, "m_iUpgradeMetal"); // GetEntData(ent,FindSendPropOffs("CObjectTeleporter","m_iUpgradeMetal"),4);

                new NewUpgrade = 0;
                
                if ((CurrentLevel < TF2_MaxUpgradeLevel ) && (CurrentUpgrade <= TF2_MaxUpgradeMetal))
                {
                    NewUpgrade = Min(TF2_MaxUpgradeMetal, CurrentUpgrade + SkillAddUpgrade);
                }

                SetEntProp(ent, Prop_Send, "m_iUpgradeMetal", NewUpgrade);
            }
        }
    }
}

//=======================================================================
//                                  Events
//=======================================================================

public eCanWarp(Handle:event,const String:name[],bool:dontBroadcast)
{
    bCanWarpIn = true;
    for(new i=0; i < MAXPLAYERS; i++)
    {
        if(ValidPlayer(i))
        {
            War3_CooldownReset(i, thisRaceID, ABILITY_WARP);
        }
    }
}

public eCantWarp(Handle:event,const String:name[],bool:dontBroadcast)
{
    bCanWarpIn = false;
    for(new i=0; i < MAXPLAYERS; i++)
    {
        if(ValidPlayer(i))
        {
            War3_CooldownReset(i, thisRaceID, ABILITY_WARP);
        }
    }
}

//=======================================================================
//                                  Warp In
//=======================================================================

public OnClientDisconnect(client)
{
    if(War3_GetRace(client) == thisRaceID)
    {
        new ent = -1;
        new obj_builder;
        while((ent = FindEntityByClassname(ent, "obj_sentrygun")) > 0)
        {
            obj_builder = GetEntPropEnt(ent, Prop_Send, "m_hBuilder");
            
            if(obj_builder == client)
            {
                AcceptEntityInput(ent, "kill");
            }
        }
        
        while((ent = FindEntityByClassname(ent, "obj_dispenser")) > 0)
        {
            obj_builder = GetEntPropEnt(ent, Prop_Send, "m_hBuilder");
            
            if(obj_builder == client)
            {
                AcceptEntityInput(ent, "kill");
            }
        }
        
        while((ent = FindEntityByClassname(ent, "obj_teleporter")) > 0)
        {
            obj_builder = GetEntPropEnt(ent, Prop_Send, "m_hBuilder");
            
            if(obj_builder == client)
            {
                AcceptEntityInput(ent, "kill");
            }
        }
    }
}

public OnAbilityCommand(client, ability,bool:pressed)
{
    if(ValidPlayer(client, true) && War3_GetRace(client) == thisRaceID && pressed)
    {
        new skill = War3_GetSkillLevel(client, thisRaceID, ABILITY_WARP);
        if(skill > 0)
        {
            if(bCanWarpIn)
            {
                if(War3_SkillNotInCooldown(client, thisRaceID, ABILITY_WARP, true) && !Silenced(client))
                {
                    DisplayBuildMenu(client);
                }
            }
            else
            {
                W3Hint(client, HINT_SKILL_STATUS, 2.0, "You can't warp in outside a round!");
            }
        }
    }
}

DisplayBuildMenu(client)
{
    new Handle:menu = CreateMenu(MenuHandler_WallMenu);
    SetMenuTitle(menu, "Warp-In");
    
    new skill = War3_GetSkillLevel(client, thisRaceID, ABILITY_WARP);
    if ( skill == 4) 
    {
        AddMenuItem(menu, "Sentry", "Sentry Gun (Level 3)");
        AddMenuItem(menu, "Dispenser", "Dispenser (Level 3)");
    }
    if ( skill == 3) 
    {
        AddMenuItem(menu, "Sentry", "Sentry Gun (Level 2)");
        AddMenuItem(menu, "Dispenser", "Dispenser (Level 2)");
    }
    if ( skill == 2) 
    {
        AddMenuItem(menu, "Sentry", "Sentry Gun (Level 1)");
        AddMenuItem(menu, "Dispenser", "Dispenser (Level 1)");
    }
    if ( skill == 1) 
    {
        AddMenuItem(menu, "Sentry", "Sentry Gun (Mini)");
        AddMenuItem(menu, "Dispenser", "Dispenser (Level 1)");
    }
    
    SetMenuExitBackButton(menu, true);
    DisplayMenu(menu, client, 15);
}

public MenuHandler_WallMenu(Handle:menu, MenuAction:action, param1, param2)
{
    if (action == MenuAction_Select)
    {
        if(ValidPlayer(param1, true)) {
            decl String:sChoice[128];
            GetMenuItem(menu, param2, sChoice, sizeof(sChoice));
            
            MenuSpawnBuilding(param1, sChoice);
            
        }
    }
    else if (action == MenuAction_End) {
        CloseHandle(menu);
    }
}

bool:CanSpawn(client)
{
    new flags = GetEntityFlags(client);

    if (!(flags & FL_ONGROUND))
    {
        return false;
    }

    return true;
}

stock MenuSpawnBuilding(client, const String:objType[])
{
    if(!CanSpawn(client))
    {
        W3Hint(client, HINT_SKILL_STATUS, 2.0, "You can't spawn here");
        return;
    }
    
    new skill = War3_GetSkillLevel(client, thisRaceID, ABILITY_WARP);

    new Float:fCasterPos[3];
    GetClientAbsOrigin(client,fCasterPos);

    new Float:TeleportPos[3];
    GetClientAbsOrigin(client,TeleportPos);
    TeleportPos[2] += 140.0;
    
    new Float:angl[3];
    GetClientAbsAngles(client, angl);
    angl[0] = 0.0;
    //angl[1] = 0.0;
    angl[2] = 0.0;
         
    if(StrEqual(objType, "Sentry"))
    {
        if(skill == 1)
        {
            ModifyEntityAddDeathTimer(BuildMiniSentry(client, fCasterPos, angl, 1), DEATH_TIMER);
        }
        else
        {
            ModifyEntityAddDeathTimer(BuildSentry(client, fCasterPos, angl, skill - 1), DEATH_TIMER);
        }
    }
    else if (StrEqual(objType, "Dispenser"))
    {
        if(skill == 1)
        {
            skill = 2;
        }
         
        ModifyEntityAddDeathTimer(BuildDispenser(client, fCasterPos, angl, skill - 1), DEATH_TIMER);
    }
    
    TeleportEntity(client,TeleportPos,NULL_VECTOR,NULL_VECTOR); 
    War3_CooldownMGR(client, fWarpCooldown, thisRaceID, ABILITY_WARP, false);
}

//=======================================================================
//                                 Uncloak
//=======================================================================

public Action:UncloakTimer(Handle:timer,any:userid)
{
    new Float:CasterPosition[3];
    new Float:VictimPosition[3];
    for(new client=1; client <= MaxClients; client++)
    {
        if(ValidPlayer(client) && War3_GetRace(client) == thisRaceID)
        {
            new skill = War3_GetSkillLevel(client, thisRaceID, SKILL_DEVICE);
            if(skill > 0)
            {
                GetClientAbsOrigin(client, CasterPosition);
                new engiteam = GetClientTeam(client);
                for(new spy=1; spy <= MaxClients; spy++)
                {
                    if(ValidPlayer(spy, true) && GetClientTeam(spy) != engiteam)
                    {
                        GetClientAbsOrigin(spy, VictimPosition);
                        new Float:dis = GetVectorDistance(CasterPosition, VictimPosition);
                        
                        if (dis < fDeviceRange[skill])
                        {
                           TF2_RemoveCondition(spy, TFCond_Disguised);
                           TF2_RemoveCondition(spy, TFCond_Cloaked);
                           TF2_RemoveCondition(spy, TFCond_Disguising);
                           TF2_RemoveCondition(spy, TFCond_DeadRingered);
                        }
                    }
                }
            }
        }
    }
}

//=======================================================================
//                                 SYNERGY
//=======================================================================

public OnW3TakeDmgAllPre(victim, attacker, Float:damage)
{
    if(ValidPlayer(attacker, true) && (War3_GetRace(attacker) == thisRaceID) && ValidPlayer(victim) && attacker != victim)
    {
        new inflictor = W3GetDamageInflictor();
        if(inflictor == attacker)
        {
            new skill = War3_GetSkillLevel(attacker, thisRaceID, SKILL_SYNERGY);
            if (skill > 0)
            {
                SynergyBuildings(attacker, skill, damage);
            }
        }
    }
}

//=======================================================================
//                                 GRAVITY GUN
//=======================================================================


public OnWar3EventSpawn(client)
{
    InitSkills(client, War3_GetRace(client));
}

public OnSkillLevelChanged(client, race, skill, newskilllevel)
{
    InitSkills(client, race);
}

public OnWar3EventDeath(victim, client, deathrace)
{
    ResetSkills(victim, deathrace);
    
    if(IsFakeClient(victim))
    {
        decl String:name[32];
        GetClientName(victim, name, sizeof(name));
        
        if(StrEqual(name, "Sentry Buster"))
        {
            new ent = -1;
            
            decl Float:fVictimPos[3];
            decl Float:fBuildingPos[3];
            GetClientAbsOrigin(victim, fVictimPos);
            
            while((ent = FindEntityByClassname(ent, "obj_sentrygun")) > 0)
            {
                GetEntPropVector(ent, Prop_Send, "m_vecOrigin", fBuildingPos);
                
                if(!GetEntProp(ent, Prop_Send, "m_bCarried") && GetVectorDistance(fBuildingPos, fVictimPos) <= BUSTER_RANGE)
                {
                    AcceptEntityInput(ent, "kill");
                }
            }
            
            while((ent = FindEntityByClassname(ent, "obj_dispenser")) > 0)
            {
                GetEntPropVector(ent, Prop_Send, "m_vecOrigin", fBuildingPos);
                
                if(!GetEntProp(ent, Prop_Send, "m_bCarried") && GetVectorDistance(fBuildingPos, fVictimPos) <= BUSTER_RANGE)
                {
                    AcceptEntityInput(ent, "kill");
                }
            }
            
            while((ent = FindEntityByClassname(ent, "obj_teleporter")) > 0)
            {
                GetEntPropVector(ent, Prop_Send, "m_vecOrigin", fBuildingPos);
                
                if(!GetEntProp(ent, Prop_Send, "m_bCarried") && GetVectorDistance(fBuildingPos, fVictimPos) <= BUSTER_RANGE)
                {
                    AcceptEntityInput(ent, "kill");
                }
            }
        }
    }
}

public OnRaceChanged(client, oldrace, newrace)
{
    ResetSkills(client, oldrace);
    InitSkills(client, newrace);
}

InitSkills(client, race)
{
    if(race == thisRaceID)
    {
        new skill = War3_GetSkillLevel(client, thisRaceID, ULTIMATE_GRAVGUN);
        if (skill > 0)
        {
            GiveGravgun(client, 0.0);
        }
        else
        {
            TakeGravgun(client);
        }
    }
}

ResetSkills(client, race)
{
    if(race == thisRaceID)
    {
        TakeGravgun(client);
    }
}

public OnUltimateCommand(client, race, bool:pressed)
{
    if(ValidPlayer(client, true) && race == thisRaceID && !Silenced(client))
    {
        if(pressed)
        {
            PickupObject(client);
        }
        else
        {
            DropObject(client); 
        }
    }
}
