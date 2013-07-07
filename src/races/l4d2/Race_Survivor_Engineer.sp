#pragma semicolon 1    ///WE RECOMMEND THE SEMICOLON

#include <sdkhooks>
#include "W3SIncs/War3Source_Interface"
#include "W3SIncs/War3Source_Race_Engineer"

public Plugin:myinfo = 
{
    name = "War3Source Race - Engineer",
    author = "Glider",
    description = "The Engineer race for War3Source.",
    version = "1.0",
}; 

//=======================================================================
//                             VARIABLES
//=======================================================================

#define ULT_COOLDOWN 45.0
#define REFILL_RANGE 100.0

new thisRaceID;
new SKILL_AMMO, SKILL_DAMAGE, SKILL_RANGE;
new ULT_REFILL;

new AmmoBonus[5] = {0, 50, 100, 150, 200};
new DamageBonus[5] = {0, 20, 40, 60, 80};
new Float:RangeBonus[5] = {1.0, 1.25, 1.5, 1.75, 2.0};

new g_iRefillingSentry[MAXPLAYERS]; 

//=======================================================================
//                                 INIT
//=======================================================================

public OnWar3PluginReady(){
    thisRaceID = War3_CreateNewRace("Engineer", "engineer");
    War3_AddRaceSkill(thisRaceID, "Race specific information", "Press your ultimate key to spawn a sentry depending on your current primary weapon!\nHaving incendiary or explosive ammo changes your Sentrys ammo type.\nHaving a Lasersight attached doubles the accuracy!", false, 0);
    SKILL_AMMO = War3_AddRaceSkill(thisRaceID, "+Sentry Ammo", "50/100/150/200 extra bullets for your sentry", false, 4);
    SKILL_DAMAGE = War3_AddRaceSkill(thisRaceID, "+Sentry Damage", "20/40/60/80 damage per hit more for your sentry", false, 4);
    SKILL_RANGE = War3_AddRaceSkill(thisRaceID, "+Sentry Range", "25/50/75/100% more range for your sentry", false, 4);
    ULT_REFILL = War3_AddRaceSkill(thisRaceID, "Refill (+use)", "Let's you refill a sentry for free! CD: 120 seconds", true, 1);
    
    War3_CreateRaceEnd(thisRaceID);
}

public OnPluginStart()
{
    if(War3_GetGame() != Game_L4D && War3_GetGame() != Game_L4D2)
        SetFailState("Only works in the L4D engine! %i", War3_GetGame());
    
    CreateTimer(1.0, NotificationTimer, _, TIMER_REPEAT);
}

public Action:NotificationTimer(Handle:timer, any:userid)
{
    for(new client=1; client <= MaxClients; client++)
    {
        if(ValidPlayer(client, true) && War3_GetRace(client) == thisRaceID && War3_Engineer_HasSentry(client))
        {
            decl String:Message[500];
            Format(Message, sizeof(Message), "Sentry ammo count: %i\\%i", War3_Engineer_CheckAmmo(client), War3_Engineer_CheckMaxAmmo(client));
                
            W3Hint(client, HINT_COOLDOWN_COUNTDOWN, 1.0, Message);
        }
    }
}

public OnRaceChanged(client, oldrace, newrace)
{
    if(oldrace == thisRaceID)
    {
        War3_Engineer_DestroySentry(client);
    }
}

public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon)
{
    if(ValidPlayer(client, true) && 
        War3_GetRace(client) == thisRaceID && 
       !Silenced(client) &&
       War3_SkillNotInCooldown(client, thisRaceID, ULT_REFILL, true) && 
       GetClientTeam(client) == TEAM_SURVIVORS &&
       !War3_L4D_IsHelpless(client) &&
       !War3_L4D_HasProgressBar(client) &&
       !War3_IsPlayerIncapped(client))
    {
        new ult_refill = War3_GetSkillLevel(client, thisRaceID, ULT_REFILL);
        if (ult_refill > 0 && buttons & IN_USE) {
            new entity = GetClientAimedLocationData(client, NULL_VECTOR);
            if (War3_Engineer_IsSentry(entity) && !War3_L4D_HasProgressBar(client)) {
                
                new Float:SentryPosition[3];
                new Float:EngineerPosition[3];
                
                GetClientEyePosition(client, EngineerPosition);
                GetEntPropVector(entity, Prop_Send, "m_vecOrigin", SentryPosition);
                
                new Float:dis = GetVectorDistance(SentryPosition, EngineerPosition);
                
                if (dis <= (REFILL_RANGE))
                {
                    new iWeapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
                    SetEntProp(iWeapon, Prop_Send, "m_helpingHandState", 3);
                    
                    PrintHintText(client, "Refilling a sentry...");
                    
                    SetEntPropEnt(client, Prop_Send, "m_useActionTarget", client);
                    SetEntPropEnt(client, Prop_Send, "m_useActionOwner", client);
                    War3_L4D_ActivateProgressBar(client, 5.0);
                    
                    g_iRefillingSentry[client] = entity;
                }
            }
        }
    }

    return Plugin_Continue;    
}

public HasFinishedProgress(client, progress_id) {
    new sentry = g_iRefillingSentry[client];
    if (War3_Engineer_IsSentry(sentry)) {
        War3_Engineer_RefillSentry(g_iRefillingSentry[client]);
        PrintHintText(client, "You refilled a sentry!");
        
        War3_CooldownMGR(client, ULT_COOLDOWN, thisRaceID, ULT_REFILL);
    }
} 

GetClientAimedLocationData( client, Float:position[3])
{
    new index = -1;
    
    decl Float:_origin[3], Float:_angles[3];
    GetClientEyePosition( client, _origin );
    GetClientEyeAngles( client, _angles );

    new Handle:trace = TR_TraceRayFilterEx( _origin, _angles, MASK_SOLID_BRUSHONLY, RayType_Infinite, TraceEntityFilterPlayers, client);
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

public OnUltimateCommand(client,race,bool:pressed)
{
    if(ValidPlayer(client, true) && 
       race == thisRaceID && 
       pressed && 
       !Silenced(client) &&
       GetClientTeam(client) == TEAM_SURVIVORS &&
       !War3_L4D_IsHelpless(client) &&
       !War3_IsPlayerIncapped(client))
    {
        if( !War3_Engineer_HasSentry(client) ) {
            new iWeapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
            new primary = GetPlayerWeaponSlot(client, 0);
            
            if (iWeapon == primary) {
                new String:weaponname[64];
                GetClientWeapon(client, weaponname, sizeof(weaponname));
                
                if (StrEqual(weaponname, "weapon_grenade_launcher")) {
                    PrintHintText(client, "A grenade launcher sentry? Are you mad!?");
                    return;
                }
                if (StrEqual(weaponname, "weapon_m60")) {
                    PrintHintText(client, "A M60 sentry? Are you mad!?");
                    return;
                }
                
                new weapon_upgrade = L4D2_GetWeaponUpgrades(primary);
                new String:AmmoTypeString[15] = "Regular";
                
                if (weapon_upgrade & L4D2_WEPUPGFLAG_INCENDIARY) {
                    AmmoTypeString = "Incendiary";
                }
                else if (weapon_upgrade & L4D2_WEPUPGFLAG_EXPLOSIVE) {
                    AmmoTypeString = "Explosive";
                }
                
                new ammo = GetCurrentBackupAmmo(client) + GetEntProp(iWeapon, Prop_Send, "m_iClip1");
                new Float:FiringSpeed = GetFiringSpeedFromWeapon(weaponname);
                new Damage = GetDamageFromWeapon(weaponname);
                new Float:ScanRange = GetRangeFromWeapon(weaponname);
                new Float:Accuracy = GetAccuracyFromWeapon(weaponname);
                new AmountOfShots = GetAmountOfShotsFromWeapon(weaponname);
                
                if (weapon_upgrade & L4D2_WEPUPGFLAG_LASER) {
                    Accuracy *= 0.2; 
                }
                
                new skill_ammo = War3_GetSkillLevel(client, thisRaceID, SKILL_AMMO);
                new skill_damage = War3_GetSkillLevel(client, thisRaceID, SKILL_DAMAGE);
                new skill_range = War3_GetSkillLevel(client, thisRaceID, SKILL_RANGE);
                
                Damage = DamageBonus[skill_damage] + Damage;
                ammo = AmmoBonus[skill_ammo] + ammo;
                ScanRange = RangeBonus[skill_range] * ScanRange;
                
                decl String:StatString[500];
                
                Format(StatString, sizeof(StatString), "Spawn a Sentry with these stats?\nDamage: %i\nAmmo Type: %s\nFiring speed. %f\nRange: %f\nAmmo: %i\nAccuracy: %f\nAmount of Shots: %i", Damage, AmmoTypeString, FiringSpeed, ScanRange, ammo, Accuracy, AmountOfShots);
                
                new Handle:menu = CreateMenu(MenuHandlerCreate);
                SetMenuTitle(menu, StatString);
                AddMenuItem(menu, "yes", "Yes");
                AddMenuItem(menu, "no", "No");
                SetMenuExitButton(menu, false);
                DisplayMenu(menu, client, 20);
                
            }
        } 
        else {
            new Handle:menu = CreateMenu(MenuHandlerDestroy); 
            SetMenuTitle(menu, "Blow up your sentry?");
            AddMenuItem(menu, "yes", "Yes");
            AddMenuItem(menu, "no", "No");
            SetMenuExitButton(menu, false);
            DisplayMenu(menu, client, 20);
        }
    }
}



public MenuHandlerDestroy(Handle:menu, MenuAction:action, param1, param2)
{
    if (action == MenuAction_Select)
    {
        if (param2 == 0) {
            War3_Engineer_DestroySentry(param1);
        }
    }
    else if (action == MenuAction_End)
    {
        CloseHandle(menu);
    }
}


public MenuHandlerCreate(Handle:menu, MenuAction:action, param1, param2)
{
    if (action == MenuAction_Select)
    {
        if (param2 == 0) {
            new flags = GetEntityFlags(param1);
    
            if (!(flags & FL_ONGROUND)) {
                PrintHintText(param1, "You need to stand on the ground to spawn a Sentry!");
                return;
            }
            
            new iWeapon = GetEntPropEnt(param1, Prop_Send, "m_hActiveWeapon");
            new primary = GetPlayerWeaponSlot(param1, 0);
            
            if (iWeapon == primary) {
                new String:weaponname[64];
                GetClientWeapon(param1, weaponname, sizeof(weaponname));
                
                new SentryAmmo:ammotype = Regular;
                new weapon_upgrade = L4D2_GetWeaponUpgrades(primary);
                
                if (weapon_upgrade & L4D2_WEPUPGFLAG_INCENDIARY) {
                    ammotype = Incendiary;
                }
                else if (weapon_upgrade & L4D2_WEPUPGFLAG_EXPLOSIVE) {
                    ammotype = Explosive;
                }
                
                new ammo = GetCurrentBackupAmmo(param1) + GetEntProp(iWeapon, Prop_Send, "m_iClip1");
                new Float:FiringSpeed = GetFiringSpeedFromWeapon(weaponname);
                new Damage = GetDamageFromWeapon(weaponname);
                new Float:ScanRange = GetRangeFromWeapon(weaponname);
                new Float:Accuracy = GetAccuracyFromWeapon(weaponname);
                new AmountOfShots = GetAmountOfShotsFromWeapon(weaponname);
                
                if (weapon_upgrade & L4D2_WEPUPGFLAG_LASER) {
                    Accuracy *= 0.2; 
                }
                
                new skill_ammo = War3_GetSkillLevel(param1, thisRaceID, SKILL_AMMO);
                new skill_damage = War3_GetSkillLevel(param1, thisRaceID, SKILL_DAMAGE);
                new skill_range = War3_GetSkillLevel(param1, thisRaceID, SKILL_RANGE);
                
                Damage = DamageBonus[skill_damage] + Damage;
                ammo = AmmoBonus[skill_ammo] + ammo;
                ScanRange = RangeBonus[skill_range] * ScanRange;
                
                War3_Engineer_SpawnSentry(param1, Damage, FiringSpeed, ammotype, ammo, ScanRange, Accuracy, AmountOfShots);
                
                SDKHooks_DropWeapon(param1, iWeapon, NULL_VECTOR,NULL_VECTOR);
                AcceptEntityInput(iWeapon, "Kill");
            }
        }
    }
    else if (action == MenuAction_End)
    {
        CloseHandle(menu);
    }
}
