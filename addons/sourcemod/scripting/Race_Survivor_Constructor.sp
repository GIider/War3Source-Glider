#pragma semicolon 1    ///WE RECOMMEND THE SEMICOLON

#include <sdkhooks>
#include "W3SIncs/War3Source_Interface"

public Plugin:myinfo = 
{
    name = "War3Source Race - Constructor",
    author = "Glider",
    description = "The Constructor race for War3Source.",
    version = "1.0",
};

//=======================================================================
//                             VARIABLES
//=======================================================================

#define MODEL_MINIGUN       "models/w_models/weapons/w_minigun.mdl"

new thisRaceID;
new SKILL_PROPS, SKILL_MAX_PROPS, ULT_SPECIAL_PROPS;
new ULT_CONSTRUCTION;

new g_SpecialItemIndex[MAXPLAYERS + 1];
new Handle:g_hSpawnedItemsArray[MAXPLAYERS + 1] = INVALID_HANDLE;
new MaxItems[5]={0, 15, 20, 25, 30};

new bool:HasDefensiveBuff[MAXPLAYERS];
new bool:HasOffensiveBuff[MAXPLAYERS];

//=======================================================================
//                                 INIT
//=======================================================================

public OnWar3PluginReady(){
    thisRaceID = War3_CreateNewRace("Constructor", "constructor");
    SKILL_PROPS = War3_AddRaceSkill(thisRaceID, "Additional Items", "Unlock more things to build.", false, 4);
    SKILL_MAX_PROPS = War3_AddRaceSkill(thisRaceID, "Max Items", "You can spawn 15/20/25/30 items.", false, 4);
    ULT_CONSTRUCTION = War3_AddRaceSkill(thisRaceID, "Construction (+ultimate)", "Bring up your constructing menu!", false, 1);
    ULT_SPECIAL_PROPS = War3_AddRaceSkill(thisRaceID, "Special Items", "Unlocks the special items category. \nCan only spawn one at a time (Minigun/Defensive Floor/Offensive Floor/Explosive Barrel)", true, 4);
    
    War3_CreateRaceEnd(thisRaceID);
}

public OnPluginStart()
{
    if(War3_GetGame() != Game_L4D && War3_GetGame() != Game_L4D2)
        SetFailState("Only works in the L4D engine! %i", War3_GetGame());
    
    for(new i=1; i <= MAXPLAYERS; i++) {
        g_hSpawnedItemsArray[i] = CreateArray();
    }
    
    HookEvent("round_end", Event_RoundEnd);
}

public OnMapStart()
{
    for(new i = 1; i <= MAXPLAYERS; i++) {
        ClearArray(g_hSpawnedItemsArray[i]);
    }
    
    PrecacheModel("models/props_downtown/staircase01.mdl", true);
    PrecacheModel("models/props_exteriors/stairs_house_01.mdl", true);
    PrecacheModel("models/props_exteriors/wood_stairs_120.mdl", true);
    PrecacheModel("models/props_exteriors/wood_stairs_120_swamp.mdl", true);
    PrecacheModel("models/props_exteriors/wood_stairs_wide_48.mdl", true);
    PrecacheModel("models/props_fortifications/barricade001_128_reference.mdl", true);
    PrecacheModel("models/props_fortifications/barricade001_64_reference.mdl", true);
    PrecacheModel("models/props_fortifications/barricade_gate001_64_reference.mdl", true);
    PrecacheModel("models/props_fortifications/concrete_barrier001_128_reference.mdl", true);
    PrecacheModel("models/props_fortifications/concrete_barrier001_96_reference.mdl", true);
    PrecacheModel("models/props_fortifications/police_barrier001_128_reference.mdl", true);
    PrecacheModel("models/props_furniture/piano.mdl", true);
    PrecacheModel("models/props_interiors/couch.mdl", true);
    PrecacheModel("models/props_interiors/stair_metal_02.mdl", true);
    PrecacheModel("models/props_interiors/stair_treads_straight.mdl", true);
    PrecacheModel("models/props_mall/atrium_stairs.mdl", true);
    PrecacheModel("models/props_misc/fairground_tent_open.mdl", true);
    PrecacheModel("models/props_unique/hospital05_rooftop_stair01", true);
    PrecacheModel("models/props_unique/hospital05_rooftop_stair02", true);
    PrecacheModel("models/props_urban/fence_gate002_256.mdl", true);
    PrecacheModel("models/props_urban/fire_escape_wide_upper.mdl", true);
    PrecacheModel("models/props_urban/hotel_stairs001.mdl", true);
    PrecacheModel("models/props_urban/hotel_stairs002.mdl", true);
    PrecacheModel("models/props_vehicles/racecar_stage_floor.mdl", true);

    // level 0
    PrecacheModel("models/props_misc/triage_tent.mdl", true);
    PrecacheModel("models/props_unique/airport/temp_barricade.mdl", true);
    
    // police 1-4
    PrecacheModel("models/props_street/police_barricade.mdl", true);
    PrecacheModel("models/props_street/police_barricade2.mdl", true);
    PrecacheModel("models/props_street/police_barricade3.mdl", true);
    PrecacheModel("models/props_street/police_barricade4.mdl", true);
    
    PrecacheModel("models/props_industrial/barrel_fuel.mdl", true);
    PrecacheModel("models/props_industrial/barrel_fuel_partb.mdl", true);
    PrecacheModel("models/props_industrial/barrel_fuel_parta.mdl", true);
        
    PrecacheModel(MODEL_MINIGUN, true);
}

public Action:Event_RoundEnd(Handle:event, const String:name[], bool:dontBroadcast)
{
    for(new i = 1; i <= MAXPLAYERS; i++) {
        DeleteMySpawns(i);
        ClearArray(g_hSpawnedItemsArray[i]);
        
        new specialitem = g_SpecialItemIndex[i];
        if (specialitem != 0 && IsDynamicProp(specialitem)) {
            RemoveEdict(specialitem);
        }
    }
}

public OnClientDisconnect(client) {
    DeleteMySpawns(client);
    ClearArray(g_hSpawnedItemsArray[client]);
    new specialitem = g_SpecialItemIndex[client];
    if (specialitem != 0 && IsDynamicProp(specialitem)) {
        RemoveEdict(specialitem);
    }
}

public OnWar3EventDeath(victim, attacker)
{
    if(ValidPlayer(victim, true))
    {
        DeleteMySpawns(victim);
        ClearArray(g_hSpawnedItemsArray[victim]);
        new specialitem = g_SpecialItemIndex[victim];
        if (specialitem != 0 && IsDynamicProp(specialitem)) {
            RemoveEdict(specialitem);
        }
    }
}


public OnRaceChanged(client, oldrace, newrace)
{
    if(oldrace == thisRaceID)
    {
        DeleteMySpawns(client);
        ClearArray(g_hSpawnedItemsArray[client]);
        new specialitem = g_SpecialItemIndex[client];
        if (specialitem != 0 && IsDynamicProp(specialitem)) {
            RemoveEdict(specialitem);
        }
    }
}

/*public OnEntityCreated(entity, const String:classname[])
{
    if (StrEqual(classname, "infected", false))
    {
        SDKHook(entity, SDKHook_Touch, Touchy);
    }
}

public Touchy(entity, other)
{
    PrintToChatAll("touchy touchy");
}*/

public GiveBuffDefensive(entity, other)
{
    if (ValidPlayer(other, true) && GetClientTeam(other) == TEAM_SURVIVORS)
    {
        HasDefensiveBuff[other] = true;
        War3_ChatMessage(other, "Your defence rose by 25 percent!");
    }
}

public RemoveBuffDefensive(entity, other)
{
    if (ValidPlayer(other, true) && GetClientTeam(other) == TEAM_SURVIVORS)
    {
        HasDefensiveBuff[other] = false;
        War3_ChatMessage(other, "Your defence is back to normal");
    }
}

public GiveBuffOffensive(entity, other)
{
    if (ValidPlayer(other, true) && GetClientTeam(other) == TEAM_SURVIVORS)
    {
        HasOffensiveBuff[other] = true;
        War3_ChatMessage(other, "Your offense rose by 25 percent!");
    }
}

public RemoveBuffOffensive(entity, other)
{
    if (ValidPlayer(other, true) && GetClientTeam(other) == TEAM_SURVIVORS)
    {
        HasOffensiveBuff[other] = false;
        War3_ChatMessage(other, "Your offense is back to normal");
    }
}

public DoElectricDamage(entity, other)
{
    for(new i = 1; i <= MAXPLAYERS; i++) {
        if (g_SpecialItemIndex[i] == entity)
            if (ValidPlayer(other, true) || War3_IsL4DZombieEntity(other))
            {
                War3_DealDamage(other, 5, i, DMG_SHOCK, "skill_electric_fence");
            }
    }
}

public OnEntityDestroyed(entity)
{
    // better safe than sorry :)
    // sdk hooks docu says this isn't necessary but fuck them
    // i got server crashes when I didn't do that :|
    if (IsValidEntity(entity) && IsValidEdict(entity) && IsDynamicProp(entity)) {
        SDKUnhook(entity, SDKHook_StartTouch, GiveBuffDefensive);
        SDKUnhook(entity, SDKHook_EndTouch, RemoveBuffDefensive);
        SDKUnhook(entity, SDKHook_StartTouch, GiveBuffOffensive);
        SDKUnhook(entity, SDKHook_EndTouch, RemoveBuffOffensive);
        SDKUnhook(entity, SDKHook_StartTouch, DoElectricDamage);
        
        for(new i = 1; i <= MAXPLAYERS; i++) {
            new foundindex = FindValueInArray(g_hSpawnedItemsArray[i], entity);
            if(foundindex >= 0) {
                RemoveFromArray(g_hSpawnedItemsArray[i], foundindex);
                War3_ChatMessage(i, "You have %i items left.", GetArraySize(g_hSpawnedItemsArray[i]));
            }
            
            if (entity == g_SpecialItemIndex[i])
                g_SpecialItemIndex[i] = 0;
        }
    }
}

public OnW3TakeDmgAllPre(victim, attacker, Float:damage)
{
    if(ValidPlayer(victim, true) && GetClientTeam(victim) == TEAM_SURVIVORS)
    {
        if(HasDefensiveBuff[victim] == true)
        {
            War3_DamageModPercent(0.75);
        }
    }
    if(ValidPlayer(attacker, true) && GetClientTeam(attacker) == TEAM_SURVIVORS)
    {
        if(HasOffensiveBuff[attacker] == true)
        {
            War3_DamageModPercent(1.25);
        }
    }
}

//=======================================================================
//                          ARRAY STUFF
//=======================================================================


public DeleteMySpawns(client) {
    while(GetArraySize(g_hSpawnedItemsArray[client]))
    {
        new item = GetArrayCell(g_hSpawnedItemsArray[client], 0);
        if(IsValidEntity(item))
        {
            RemoveEdict(item);
        }
    
        RemoveFromArray(g_hSpawnedItemsArray[client], 0);
    }
}

//=======================================================================
//                          Construction Menu
//=======================================================================

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
        new skill = War3_GetSkillLevel(client, thisRaceID, ULT_CONSTRUCTION);
        if (skill > 0)
        {
            DisplayMainBuildMenu(client);
        }
    }
}

//====================================
//           MAIN MENU
//====================================

DisplayMainBuildMenu(client)
{
    new Handle:menu = CreateMenu(MenuHandler_MainBuildMenu);
    SetMenuTitle(menu, "Construction Menu");
    
    AddMenuItem(menu, "0", "Construction");
    AddMenuItem(menu, "1", "Rotation");
    AddMenuItem(menu, "2", "Destruction");
    
    new skill = War3_GetSkillLevel(client, thisRaceID, ULT_SPECIAL_PROPS);
    if (skill > 0) {
        AddMenuItem(menu, "3", "Special");
    }

    DisplayMenu(menu, client, 20);
}

public MenuHandler_MainBuildMenu(Handle:menu, MenuAction:action, param1, param2)
{
    if (action == MenuAction_Select)
    {
        switch (param2)
        {
            case 0:
            {
                DisplayConstructionMenu(param1);
            }
            case 1:
            {
                DisplayRotationMenu(param1);
            }
            case 2:
            {
                DisplayDestructionMenu(param1);
            }
            case 3:
            {
                DisplaySpecialMenu(param1);
            }
        }
    }
    else if (action == MenuAction_End) {
        CloseHandle(menu);
    }
}

//====================================
//          CONSTRUCTION MENU
//====================================

DisplayConstructionMenu(client)
{
    new Handle:menu = CreateMenu(MenuHandler_ConstructionMenu);
    SetMenuTitle(menu, "CONSTRUCTION");

    AddMenuItem(menu, "0", "Fences");
    AddMenuItem(menu, "1", "Stairs");
    AddMenuItem(menu, "2", "Fun (Breakable)");
    
    SetMenuExitBackButton(menu, true);
    DisplayMenu(menu, client, 15);
}

DisplayWallMenu(client)
{
    new Handle:menu = CreateMenu(MenuHandler_WallMenu);
    SetMenuTitle(menu, "WALLS");
    
    new skill = War3_GetSkillLevel(client, thisRaceID, SKILL_PROPS);
    if ( skill >= 4) 
    {
        AddMenuItem(menu, "models/props_street/police_barricade4.mdl", "Police Barride (4)");
        AddMenuItem(menu, "models/props_urban/fence_gate002_256.mdl", "Regular Fence (Wide, No Support) (4)");
    }
    if ( skill >= 3) 
    {
        AddMenuItem(menu, "models/props_street/police_barricade3.mdl", "Police Barride (3)");
        AddMenuItem(menu, "models/props_fortifications/barricade_gate001_64_reference.mdl", "Regular Fence (Small, No Support) (3)");
    }
    if ( skill >= 2) 
    {
        AddMenuItem(menu, "models/props_street/police_barricade2.mdl", "Police Barride (2)");
        AddMenuItem(menu, "models/props_fortifications/barricade001_128_reference.mdl", "Regular Fence (Wide, Support) (2)");
    }
    if ( skill >= 1) 
    {
        AddMenuItem(menu, "models/props_street/police_barricade.mdl", "Police Barride (1)");
        AddMenuItem(menu, "models/props_fortifications/barricade001_64_reference.mdl", "Regular Fence (Small, Support) (1)");
    }
    
    AddMenuItem(menu, "models/props_fortifications/police_barrier001_128_reference.mdl", "Police Barrier (0)");
    AddMenuItem(menu, "models/props_unique/airport/temp_barricade.mdl", "Basic Fence (0)");
    AddMenuItem(menu, "models/props_misc/fairground_tent_open.mdl", "Small Tent (0)");
    
    SetMenuExitBackButton(menu, true);
    DisplayMenu(menu, client, 15);
}

DisplayFunMenu(client)
{
    new Handle:menu = CreateMenu(MenuHandler_FunMenu);
    SetMenuTitle(menu, "FUN");
    
    new skill = War3_GetSkillLevel(client, thisRaceID, SKILL_PROPS);
    if ( skill >= 4) 
    {
        AddMenuItem(menu, "models/props_misc/triage_tent.mdl", "Big Tent (4)");
    }
    if ( skill >= 2) 
    {
        AddMenuItem(menu, "models/props_furniture/piano.mdl", "Piano (1)");
        AddMenuItem(menu, "models/props_fortifications/concrete_barrier001_128_reference.mdl", "Concrete Barrier (1)");
    }
    if ( skill >= 1) 
    {
        AddMenuItem(menu, "models/props_interiors/couch.mdl", "Couch (0)");
    }
    
    SetMenuExitBackButton(menu, true);
    DisplayMenu(menu, client, 15);
}

DisplayStairsMenu(client)
{
    new Handle:menu = CreateMenu(MenuHandler_StairsMenu);
    SetMenuTitle(menu, "STAIRS");
    
    new skill = War3_GetSkillLevel(client, thisRaceID, SKILL_PROPS);
    if ( skill >= 3) 
    {
        AddMenuItem(menu, "models/props_urban/fire_escape_wide_upper.mdl", "Fire Escape Stairs");
        AddMenuItem(menu, "models/props_urban/hotel_stairs001.mdl", "Hotel Stair(1)");
        AddMenuItem(menu, "models/props_urban/hotel_stairs002.mdl", "Hotel Stair(2)");
        AddMenuItem(menu, "models/props_exteriors/stairs_house_01.mdl", "House Stairs");
    }
    if ( skill >= 2) 
    {
        AddMenuItem(menu, "models/props_exteriors/wood_stairs_120.mdl", "Wood stair");
        AddMenuItem(menu, "models/props_exteriors/wood_stairs_120_swamp.mdl", "Swamp stair");
        AddMenuItem(menu, "models/props_interiors/stair_metal_02.mdl", "Metal stair");
        AddMenuItem(menu, "models/props_interiors/stair_treads_straight.mdl", "Big Wood stair");
    }

    AddMenuItem(menu, "models/props_exteriors/wood_stairs_wide_48.mdl", "Wide Wooden Stairs");
    
    SetMenuExitBackButton(menu, true);
    DisplayMenu(menu, client, 15);
}

public MenuHandler_ConstructionMenu(Handle:menu, MenuAction:action, param1, param2)
{
    if (action == MenuAction_Select)
    {
        switch (param2)
        {
            case 0:
                DisplayWallMenu(param1);
            case 1:
                DisplayStairsMenu(param1);
            case 2:
                DisplayFunMenu(param1);
        }
    }
    else if (action == MenuAction_Cancel) {
        DisplayMainBuildMenu(param1);
    }
    else if (action == MenuAction_End) {
        CloseHandle(menu);
    }
}

public MenuHandler_StairsMenu(Handle:menu, MenuAction:action, param1, param2)
{
    if (action == MenuAction_Select)
    {
        if(ValidPlayer(param1, true)) {
            decl String:prop_name[128];
            GetMenuItem(menu, param2, prop_name, sizeof(prop_name));
            
            MenuSpawnProp(param1, prop_name);
            
            DisplayStairsMenu(param1);
        }
    }
    else if (action == MenuAction_Cancel) {
        DisplayMainBuildMenu(param1);
    }
    else if (action == MenuAction_End) {
        CloseHandle(menu);
    }
}

public MenuHandler_FunMenu(Handle:menu, MenuAction:action, param1, param2)
{
    if (action == MenuAction_Select)
    {
        if(ValidPlayer(param1, true)) {
            decl String:prop_name[128];
            GetMenuItem(menu, param2, prop_name, sizeof(prop_name));
            
            MenuSpawnProp(param1, prop_name, true);
            
            DisplayFunMenu(param1);
        }
    }
    else if (action == MenuAction_Cancel) {
        DisplayMainBuildMenu(param1);
    }
    else if (action == MenuAction_End) {
        CloseHandle(menu);
    }
}

public MenuHandler_WallMenu(Handle:menu, MenuAction:action, param1, param2)
{
    if (action == MenuAction_Select)
    {
        if(ValidPlayer(param1, true)) {
            decl String:prop_name[128];
            GetMenuItem(menu, param2, prop_name, sizeof(prop_name));
            
            MenuSpawnProp(param1, prop_name);
            
            DisplayWallMenu(param1);
        }
    }
    else if (action == MenuAction_Cancel) {
        DisplayMainBuildMenu(param1);
    }
    else if (action == MenuAction_End) {
        CloseHandle(menu);
    }
}

stock MenuSpawnProp(param1, const String:prop_name[], breakable=false)
{
    new skill = War3_GetSkillLevel(param1, thisRaceID, SKILL_MAX_PROPS);
    new size = GetArraySize(g_hSpawnedItemsArray[param1]);
    new maxitems = MaxItems[skill];
    if (size < maxitems) {
        SpawnProp(param1, prop_name, breakable);
        War3_ChatMessage(param1, "You spawned %i/%i items", size + 1, maxitems);
    }
    else {
        War3_ChatMessage(param1, "You reached the max of %i items!", maxitems);
    }
}

stock SpawnProp( client, const String:prop[], breakable=false)
{
    new index = -1;
    index = CreateEntity( prop );
    
    if ( index != -1 )
    {
        decl Float:min[3], Float:max[3];
        GetEntPropVector( index, Prop_Send, "m_vecMins", min );
        GetEntPropVector( index, Prop_Send, "m_vecMaxs", max );
        
        decl Float:position[3], Float:ang_eye[3], Float:ang_ent[3], Float:normal[3];
        if ( GetClientAimedLocationData( client, position, ang_eye, normal ) == -1 )
        {
            RemoveEdict( index );
            PrintToChatAll( "Can't find a location to place" );
            return;
        }
        
        NegateVector( normal );
        GetVectorAngles( normal, ang_ent );
        ang_ent[0] += 90.0;
        
        // the created entity will face a default direction based on ground normal
        
        // avoid some model burying under ground/in wall
        // don't forget the normal was negated
        position[0] -= normal[0] * min[2];
        position[1] -= normal[1] * min[2];
        position[2] -= normal[2] * min[2];

        SetEntProp( index, Prop_Send, "m_nSolidType", 6 );
        
        DispatchKeyValueVector( index, "Origin", position );
        DispatchKeyValueVector( index, "Angles", ang_ent );
        
        DispatchSpawn( index );
        // we need to make a prop_dynamic entity collide
        // don't know why but the following code work
        AcceptEntityInput(index, "DisableCollision");
        AcceptEntityInput(index, "EnableCollision");
        AcceptEntityInput(index, "TurnOn");
        
        if (breakable)
        {
            SetEntProp(index, Prop_Data, "m_takedamage", 2);
            SetEntProp(index, Prop_Data, "m_iHealth", 255);
            SetEntityRenderColor(index, 170, 150, 50, 255);
        }
        
        PushArrayCell(g_hSpawnedItemsArray[client], index);
    }
}

//====================================
//          ROTATION MENU
//====================================

DisplayRotationMenu(client)
{
    new Handle:menu = CreateMenu(MenuHandler_RotationMenu);
    SetMenuTitle(menu, "ROTATION");
    
    AddMenuItem(menu, "0", "1");
    AddMenuItem(menu, "1", "5");
    AddMenuItem(menu, "2", "15");
    AddMenuItem(menu, "3", "45");
    AddMenuItem(menu, "4", "90");
    AddMenuItem(menu, "5", "180");
    AddMenuItem(menu, "6", "270");

    SetMenuExitBackButton(menu, true);
    DisplayMenu(menu, client, 15);
}

public MenuHandler_RotationMenu(Handle:menu, MenuAction:action, param1, param2)
{
    if (action == MenuAction_Select)
    {
        if(ValidPlayer(param1, true)) {
            new angle;
            switch (param2)
            {
                case 0:
                    angle = 1;
                case 1:
                    angle = 5;
                case 2:
                    angle = 15;
                case 3:
                    angle = 45;
                case 4:
                    angle = 90;
                case 5:
                    angle = 180;
                case 6:
                    angle = 270;
            }
    
            new index = GetClientAimedLocationData( param1, NULL_VECTOR, NULL_VECTOR, NULL_VECTOR );
            new foundindex = -1;
            if (index == g_SpecialItemIndex[param1])
                foundindex = 1;
            else 
                foundindex = FindValueInArray(g_hSpawnedItemsArray[param1], index);
            
            if(foundindex >= 0) {
                decl Float:angles[3];
                GetEntPropVector( index, Prop_Data, "m_angRotation", angles );
                RotateYaw( angles, float(angle) );
                
                DispatchKeyValueVector( index, "Angles", angles );
            }
            
            DisplayRotationMenu(param1);
        }
    }    
    else if (action == MenuAction_Cancel) {
        DisplayMainBuildMenu(param1);
    }
    else if (action == MenuAction_End) {
        CloseHandle(menu);
    }
}

//====================================
//           DESTRUCTION MENU
//====================================

DisplayDestructionMenu(client)
{
    new Handle:menu = CreateMenu(MenuHandler_DestructionMenu);
    SetMenuTitle(menu, "DESTRUCTION");
    
    AddMenuItem(menu, "0", "Destroy what you're looking at");
    AddMenuItem(menu, "1", "Destroy all spawned items");

    new skill = War3_GetSkillLevel(client, thisRaceID, ULT_SPECIAL_PROPS);
    if (skill > 0) {
        AddMenuItem(menu, "2", "Destroy your special item");
    }
    
    SetMenuExitBackButton(menu, true);
    DisplayMenu(menu, client, 15);
}

public MenuHandler_DestructionMenu(Handle:menu, MenuAction:action, param1, param2)
{
    if (action == MenuAction_Select)
    {
        if(ValidPlayer(param1, true)) {
            switch (param2)
            {
                case 0:
                {
                    new index = GetClientAimedLocationData( param1, NULL_VECTOR, NULL_VECTOR, NULL_VECTOR );
                    new foundindex = FindValueInArray(g_hSpawnedItemsArray[param1], index);
                    if(foundindex >= 0) {
                        RemoveFromArray(g_hSpawnedItemsArray[param1], foundindex);
                        RemoveEdict(index);
                        War3_ChatMessage(param1, "You have %i items left.", GetArraySize(g_hSpawnedItemsArray[param1]));
                    }
                    else {
                        War3_ChatMessage(param1, "Couldn't find a item, that belongs to you, where you're looking at.");
                    }
                    
                    DisplayDestructionMenu(param1);
                }
                case 1:
                {
                    DeleteMySpawns(param1);
                    War3_ChatMessage(param1, "All your items were deleted successfully.");
                    DisplayDestructionMenu(param1);
                }
                case 2:
                {
                    new specialitem = g_SpecialItemIndex[param1];
                    if (specialitem != 0 && IsDynamicProp(specialitem)) {
                        RemoveEdict(specialitem);
                        War3_ChatMessage(param1, "Item destroyed!");
                    }
                    else {
                        War3_ChatMessage(param1, "You don't have a valid special item!");
                    }
                    DisplayDestructionMenu(param1);
                }
            }
        }
    }    
    else if (action == MenuAction_Cancel) {
        DisplayMainBuildMenu(param1);
    }
    else if (action == MenuAction_End) {
        CloseHandle(menu);
    }
}

//====================================
//          SPECIAL MENU
//====================================

DisplaySpecialMenu(client)
{
    if (g_SpecialItemIndex[client] != 0 && IsDynamicProp(g_SpecialItemIndex[client])) {
        War3_ChatMessage(client, "Delete your old special item first!");
        return;
    }
    
    new Handle:menu = CreateMenu(MenuHandler_SpecialMenu);
    SetMenuTitle(menu, "SPECIAL");
    
    new skill = War3_GetSkillLevel(client, thisRaceID, ULT_SPECIAL_PROPS);
    if ( skill >= 1) 
    {
        AddMenuItem(menu, "0", "Minigun");
    }
    if ( skill >= 2) 
    {
        AddMenuItem(menu, "1", "Defensive Floor");
    }
    if ( skill >= 3) 
    {
        AddMenuItem(menu, "2", "Offensive Floor");
    }
    if ( skill >= 4) 
    {
        AddMenuItem(menu, "3", "Explosive Barrel");
    }

    SetMenuExitBackButton(menu, true);
    DisplayMenu(menu, client, 15);
}

public MenuHandler_SpecialMenu(Handle:menu, MenuAction:action, param1, param2)
{
    if (action == MenuAction_Select)
    {    
        new index;
        switch (param2)
        {
            case 0:
            {
                // Spawn Minigun
                index = SpawnMinigun(param1);
                g_SpecialItemIndex[param1] = index;
            }
            case 1:
            {
                // Spawn Defensive Floor
                index = SpawnSpecialProp(param1, "models/props_vehicles/racecar_stage_floor.mdl");
                g_SpecialItemIndex[param1] = index;
                
                SDKHook(index, SDKHook_StartTouch, GiveBuffDefensive);
                SDKHook(index, SDKHook_EndTouch, RemoveBuffDefensive);
            }
            case 2:
            {
                // Spawn Offensive Floor
                index = SpawnSpecialProp(param1, "models/props_vehicles/racecar_stage_floor.mdl");
                g_SpecialItemIndex[param1] = index;
                
                SDKHook(index, SDKHook_StartTouch, GiveBuffOffensive);
                SDKHook(index, SDKHook_EndTouch, RemoveBuffOffensive);
            }
            case 3:
            {
                // Spawn Explosve Barrel
                new ent = CreateEntityByName("prop_fuel_barrel"); //Special prop type for the barrel
                DispatchKeyValue(ent, "model", "models/props_industrial/barrel_fuel.mdl");
                DispatchKeyValue(ent, "BasePiece", "models/props_industrial/barrel_fuel_partb.mdl");
                DispatchKeyValue(ent, "FlyingPiece01", "models/props_industrial/barrel_fuel_parta.mdl"); //FlyingPiece01 - FlyingPiece04 are supported
                DispatchKeyValue(ent, "DetonateParticles", "weapon_pipebomb"); //Particles to use, weapon_vomitjar might work haven't tested
                DispatchKeyValue(ent, "FlyingParticles", "barrel_fly"); //Particles to use, I have never successfully gotten a list of L4D2 particle names yet
                DispatchKeyValue(ent, "DetonateSound", "BaseGrenade.Explode"); //Scene File name that will be used as sound when barrel explodes
                
                decl Float:min[3], Float:max[3];
                GetEntPropVector( ent, Prop_Send, "m_vecMins", min );
                GetEntPropVector( ent, Prop_Send, "m_vecMaxs", max );
                
                decl Float:position[3], Float:ang_eye[3], Float:ang_ent[3], Float:normal[3];
                if ( GetClientAimedLocationData( param1, position, ang_eye, normal ) == -1 )
                {
                    RemoveEdict( ent );
                }
                else
                {    
                    NegateVector( normal );
                    GetVectorAngles( normal, ang_ent );
                    ang_ent[0] += 90.0;
                    
                    // the created entity will face a default direction based on ground normal
                    
                    // avoid some model burying under ground/in wall
                    // don't forget the normal was negated
                    position[0] -= normal[0] * min[2];
                    position[1] -= normal[1] * min[2];
                    position[2] -= normal[2] * min[2];
                    
                    DispatchKeyValueVector( ent, "Origin", position );
                    DispatchKeyValueVector( ent, "Angles", ang_ent );
                    
                    DispatchSpawn(ent); 
                    
                    g_SpecialItemIndex[param1] = ent;
                    /*index = SpawnSpecialProp(param1, "models/props_unique/airport/temp_barricade.mdl");
                    SetEntityRenderColor(index, 0, 0, 255, 255);
                    g_SpecialItemIndex[param1] = index;
                    
                    SDKHook(index, SDKHook_StartTouch, DoElectricDamage);*/
                }
            }
        }
        
        DisplayMainBuildMenu(param1);
    }
    else if (action == MenuAction_Cancel) {
        DisplayMainBuildMenu(param1);
    }
    else if (action == MenuAction_End) {
        CloseHandle(menu);
    }
}

public SpawnSpecialProp( client, const String:prop[])
{
    new index = -1;
    index = CreateEntity( prop );
    
    if ( index != -1 )
    {
        decl Float:min[3], Float:max[3];
        GetEntPropVector( index, Prop_Send, "m_vecMins", min );
        GetEntPropVector( index, Prop_Send, "m_vecMaxs", max );
        
        decl Float:position[3], Float:ang_eye[3], Float:ang_ent[3], Float:normal[3];
        if ( GetClientAimedLocationData( client, position, ang_eye, normal ) == -1 )
        {
            RemoveEdict( index );
            return -1;
        }
        
        NegateVector( normal );
        GetVectorAngles( normal, ang_ent );
        ang_ent[0] += 90.0;
        
        // the created entity will face a default direction based on ground normal
        
        // avoid some model burying under ground/in wall
        // don't forget the normal was negated
        position[0] -= normal[0] * min[2];
        position[1] -= normal[1] * min[2];
        position[2] -= normal[2] * min[2];

        SetEntProp( index, Prop_Send, "m_nSolidType", 6 );
        
        DispatchKeyValueVector( index, "Origin", position );
        DispatchKeyValueVector( index, "Angles", ang_ent );
        
        DispatchSpawn( index );
        // we need to make a prop_dynamic entity collide
        // don't know why but the following code work
        AcceptEntityInput( index, "DisableCollision" );
        AcceptEntityInput( index, "EnableCollision" );
        AcceptEntityInput(index, "TurnOn");
        
        return index;
    }
    
    return -1;
}

//=======================================================================
//                          Misc functions
//=======================================================================

//---------------------------------------------------------
// get position, angles and normal of aimed location if the parameters are not NULL_VECTOR
// return the index of entity you aimed
//---------------------------------------------------------
GetClientAimedLocationData( client, Float:position[3], Float:angles[3], Float:normal[3] )
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
        TR_GetPlaneNormal( trace, normal );
        angles[0] = _angles[0];
        angles[1] = _angles[1];
        angles[2] = _angles[2];

        index = TR_GetEntityIndex( trace );
    }
    CloseHandle( trace );
    
    return index;
}

//---------------------------------------------------------
// do a specific rotation on the given angles
//---------------------------------------------------------
RotateYaw( Float:angles[3], Float:degree )
{
    decl Float:direction[3], Float:normal[3];
    GetAngleVectors( angles, direction, NULL_VECTOR, normal );
    
    new Float:sin = Sine( degree * 0.01745328 );     // Pi/180
    new Float:cos = Cosine( degree * 0.01745328 );
    new Float:a = normal[0] * sin;
    new Float:b = normal[1] * sin;
    new Float:c = normal[2] * sin;
    new Float:x = direction[2] * b + direction[0] * cos - direction[1] * c;
    new Float:y = direction[0] * c + direction[1] * cos - direction[2] * a;
    new Float:z = direction[1] * a + direction[2] * cos - direction[0] * b;
    direction[0] = x;
    direction[1] = y;
    direction[2] = z;
    
    GetVectorAngles( direction, angles );

    decl Float:up[3];
    GetVectorVectors( direction, NULL_VECTOR, up );

    new Float:roll = GetAngleBetweenVectors( up, normal, direction );
    angles[2] += roll;
}

//---------------------------------------------------------
// calculate the angle between 2 vectors
// the direction will be used to determine the sign of angle (right hand rule)
// all of the 3 vectors have to be normalized
//---------------------------------------------------------
Float:GetAngleBetweenVectors( const Float:vector1[3], const Float:vector2[3], const Float:direction[3] )
{
    decl Float:vector1_n[3], Float:vector2_n[3], Float:direction_n[3], Float:cross[3];
    NormalizeVector( direction, direction_n );
    NormalizeVector( vector1, vector1_n );
    NormalizeVector( vector2, vector2_n );
    new Float:degree = ArcCosine( GetVectorDotProduct( vector1_n, vector2_n ) ) * 57.29577951;   // 180/Pi
    GetVectorCrossProduct( vector1_n, vector2_n, cross );
    
    if ( GetVectorDotProduct( cross, direction_n ) < 0.0 )
    {
        degree *= -1.0;
    }

    return degree;
}

//---------------------------------------------------------
// the filter function for TR_TraceRayFilterEx
//---------------------------------------------------------
public bool:TraceEntityFilterPlayers( entity, contentsMask, any:data )
{
    return entity > MaxClients && entity != data;
}

//---------------------------------------------------------
// spawn a minigun
// the field of fire arc is sticked after you spawned it
// so place it well, or delete it and respawn it with a better angle
//---------------------------------------------------------

public SpawnMinigun( client )
{    
    new index = CreateEntityByName( "prop_minigun" );
    SetEntityModel( index, MODEL_MINIGUN );
    if ( index != -1 )
    {
        decl Float:position[3], Float:angles[3];
        if ( GetClientAimedLocationData( client, position, angles, NULL_VECTOR ) == -1 )
        {
            RemoveEdict( index );
        }
        angles[0] = 0.0;
        angles[2] = 0.0;
        DispatchKeyValueVector( index, "Origin", position );
        DispatchKeyValueVector( index, "Angles", angles );
        DispatchKeyValueFloat( index, "MaxPitch",  40.00 );
        DispatchKeyValueFloat( index, "MinPitch", -30.00 );
        DispatchKeyValueFloat( index, "MaxYaw",    360.00 );
        DispatchSpawn( index );
        DispatchSpawn(index);
    }
    
    return index;
}

//---------------------------------------------------------
// spawn a given entity type and assign it a model
//---------------------------------------------------------
CreateEntity( const String:model[] = "" )
{
    new index = CreateEntityByName( "prop_dynamic_override" );
    if ( index == -1 )
    {
        return -1;
    }

    if ( strlen( model ) != 0 )
    {
        if ( !IsModelPrecached( model ) )
        {
            PrintToChatAll("THIS SHOULD NOT HAPPEN: %s", model);
            PrecacheModel( model );
        }
        SetEntityModel( index, model );
    }

    return index;
}

bool:IsDynamicProp(iEntity) 
{
    if (!IsValidEntity(iEntity))
        return false;
    
    decl String:classname[64];
    GetEdictClassname(iEntity, classname, sizeof(classname));
    return (StrEqual(classname, "prop_dynamic") || StrEqual(classname, "prop_minigun") || StrEqual(classname, "prop_fuel_barrel"));
}