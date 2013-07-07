#pragma semicolon 1

#include "W3SIncs/War3Source_Interface"
#include <sdkhooks>

public Plugin:myinfo = 
{
    name = "War3Source Race - L4D Survivor Super Medic",
    author = "Glider",
    description = "The Survivor Super Medic race for War3Source.",
    version = "1.0",
};

//=======================================================================
//                             VARIABLES
//=======================================================================

enum HealingType {
    Heal_Regenerative,
    Heal_BoostDamage,
}

new g_SubjectOfTheMedic[MAXPLAYERS];
new HealingType:g_HealingType[MAXPLAYERS];
new Float:g_UberchargeAmount[MAXPLAYERS];
new Float:g_TimeLastHooked[MAXPLAYERS];
new bool:g_IsUbercharging[MAXPLAYERS];

new thisRaceID;
new SKILL_MEDIC_REGEN, SKILL_KRITZKRIEG, SKILL_INCREASED_GOODS;
new ULT_UBERCHARGE;

#define PARTICLE_UBERBEAM        "lights_moving_straight_loop_4_b"
#define EFFECT_TIMER 0.5
#define REGEN_SUBJECT_TIMER 0.3
#define CHECK_VISIBILITY_TIMER 1.0
#define PAUSE_BETWEEN_HOOKS 2.5
#define ULT_COOLDOWN 60.0

new Float:HealingRate[5]={0.05, 0.1, 0.15, 0.2, 0.25};
new Float:BonusDamage[5]={1.1, 1.5, 2.0, 2.5, 3.0};

new Float:extraXP[5] = {1.0, 1.5, 2.0, 2.5, 3.0};
new Float:extraGold[5] = {1.0, 2.0, 3.0, 4.0, 5.0};

//=======================================================================
//                                 INIT
//=======================================================================

public OnWar3PluginReady(){
    thisRaceID = War3_CreateNewRace("Super Medic", "supermedic");
    War3_AddRaceSkill(thisRaceID, "Race specific information", "Press +use to lock on to a player with your imaginary medic gun!", false, 0);
    SKILL_MEDIC_REGEN = War3_AddRaceSkill(thisRaceID, "Medicgun Regen", "Allows you to heal a player for 0.05/0.1/0.15/0.2/0.25 hp per tick", false, 4);
    SKILL_KRITZKRIEG = War3_AddRaceSkill(thisRaceID, "Kritzkrieg", "Boosts the players damage by 50/100/150/200%", false, 4);
    SKILL_INCREASED_GOODS = War3_AddRaceSkill(thisRaceID, "Increased Goods", "Gives you 50/100/150/200% more XP and 100/200/300/400% more Gold when your buddy kills something", false, 4);
    ULT_UBERCHARGE = War3_AddRaceSkill(thisRaceID, "Ubercharge", "Use your übercharge to make you and your subject invulnerable!", true, 1);
    
    War3_CreateRaceEnd(thisRaceID);
}

public OnPluginStart()
{
    if(War3_GetGame() != Game_L4D && War3_GetGame() != Game_L4D2)
        SetFailState("Only works in the L4D engine! %i", War3_GetGame());

    CreateTimer(EFFECT_TIMER, DrawUberEffectTimer, _, TIMER_REPEAT);
    CreateTimer(REGEN_SUBJECT_TIMER, RegenSubjectTimer, _, TIMER_REPEAT);
    CreateTimer(CHECK_VISIBILITY_TIMER, CheckVisibilityTimer, _, TIMER_REPEAT);
}

public OnMapStart()
{
    War3_PrecacheParticle(PARTICLE_UBERBEAM);
    
    for(new client=1; client <= MaxClients; client++)
    {
        g_TimeLastHooked[client] = GetGameTime();
    }
}

public OnUltimateCommand(client, race, bool:pressed)
{
    if(ValidPlayer(client, true) && 
       race == thisRaceID && 
       pressed && 
       !Silenced(client) &&
       GetClientTeam(client) == TEAM_SURVIVORS &&
       !War3_L4D_IsHelpless(client) &&
       !War3_IsPlayerIncapped(client))
    {    
        new skill_ubercharge = War3_GetSkillLevel(client, thisRaceID, ULT_UBERCHARGE);
        
        new Handle:menu = CreateMenu(SelectMenu);
        SetMenuTitle(menu, "What do you want to use?");

        AddMenuItem(menu, "heal", "Heal my subject");
        AddMenuItem(menu, "boost", "Boost my subject");
    
        if(skill_ubercharge > 0)
        {
            if(War3_SkillNotInCooldown(client, thisRaceID, ULT_UBERCHARGE, true))
            {
                AddMenuItem(menu, "ubercharge", "ACTIVATE UBERCHARGE");
            }
        }
        
        SetMenuExitButton(menu, false);
        DisplayMenu(menu, client, 20);
    }
}

public SelectMenu(Handle:menu, MenuAction:action, param1, param2)
{
    if (action == MenuAction_Select)
    {
        new String:info[32];
        GetMenuItem(menu, param2, info, sizeof(info));
        if(StrEqual(info, "heal"))
        {
            g_HealingType[param1] = Heal_Regenerative;
            War3_ChatMessage(param1, "Now healing players");
        }
        else if(StrEqual(info, "boost"))
        {
            g_HealingType[param1] = Heal_BoostDamage;
            War3_ChatMessage(param1, "Now boosting players");
        }
        else if(StrEqual(info, "ubercharge"))
        {
            g_IsUbercharging[param1] = true;
            CreateTimer(10.0, ResetUltimate, param1);
            War3_CooldownMGR(param1, ULT_COOLDOWN, thisRaceID, ULT_UBERCHARGE);
            
            W3Hint(param1, HINT_DMG_RCVD, 1.0, "Ubercharge started");
        }
    }
    /* If the menu has ended, destroy it */
    else if (action == MenuAction_End)
    {
        CloseHandle(menu);
    }
}

public Action:ResetUltimate(Handle:timer, any:client)
{
    W3Hint(client, HINT_DMG_RCVD, 1.0, "Ubercharge stopped");
    g_IsUbercharging[client] = false;
}

public OnWar3EventSpawn(client)
{
    if(War3_GetRace(client) == thisRaceID)
    {
        g_SubjectOfTheMedic[client] = -1;
        g_TimeLastHooked[client] = GetGameTime();
    }
}
    
public OnWar3EventDeath(victim, attacker)
{
    if(War3_GetRace(victim) == thisRaceID)
    {
        g_SubjectOfTheMedic[victim] = -1;
    }
}

public OnRaceChanged(client, oldrace, newrace)
{
    if(newrace != thisRaceID && oldrace == thisRaceID)
    {
        g_SubjectOfTheMedic[client] = -1;
        SDKUnhook(client, SDKHook_PreThink, OnPreThink);
    }
    else if (newrace == thisRaceID)
    {
        SDKHook(client, SDKHook_PreThink, OnPreThink);
    }
}

public OnPreThink(client)
{
    if(War3_GetRace(client) == thisRaceID && ValidPlayer(g_SubjectOfTheMedic[client], true))
    {
        new iWeapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
        new primary = GetPlayerWeaponSlot(client, 0);
        
        // Player is holding his primary weapon
        if (iWeapon == primary)
        {
            new iButtons = GetClientButtons(client);
            
            if (iButtons & IN_ATTACK)
            {
                War3_ChatMessage(client, "{red}You stopped the medic beam!{default}");
                g_SubjectOfTheMedic[client] = -1;
            }
        }
    }
}

public OnWar3Event(W3EVENT:event, client)
{
    if(event == OnPreGiveXPGold)
    {
        new W3XPAwardedBy:awardevent = W3GetVar(EventArg1);
        new xp = W3GetVar(EventArg2);
        new gold = W3GetVar(EventArg3);
        
        new String:name[64];
        GetClientName(client, name, sizeof(name));
        
        if(awardevent == XPAwardByAssist || awardevent == XPAwardByKill)
        {
            for(new medic=1; medic <= MaxClients; medic++)
            {
                if(ValidPlayer(medic, true) && (War3_GetRace(medic) == thisRaceID) && ValidPlayer(g_SubjectOfTheMedic[medic], true) && g_SubjectOfTheMedic[medic] == client)
                {
                    new skill = War3_GetSkillLevel(medic, thisRaceID, SKILL_INCREASED_GOODS);
                    decl String:message[200];
                    new len = 0;
                    
                    new newxp = RoundToCeil(xp * extraXP[skill]);
                    new newgold =  RoundToCeil(gold * extraGold[skill]);
                    
                    len += Format(message[len], sizeof(message)-len, "assisting {lightgreen}%s{default}", name);
                    W3GiveXPGold(medic, XPAwardByGeneric, newxp, newgold, message);
                }
            }
        }
        
        // Else the killer gets more xp??
        W3SetVar(EventArg2, xp);
        W3SetVar(EventArg3, gold);
    }
}

public Action:CheckVisibilityTimer(Handle:timer, any:userid)
{
    for(new client=1; client <= MaxClients; client++)
    {
        if(ValidPlayer(client, true) && (War3_GetRace(client) == thisRaceID) && ValidPlayer(g_SubjectOfTheMedic[client], true))
        {
            if (IsNotVisible(client, g_SubjectOfTheMedic[client]))
            {
                War3_ChatMessage(client, "{red}Your medic beam broke off!{default}");
                g_SubjectOfTheMedic[client] = 0;
            }
        }
    }
}

bool:IsNotVisible(Medic, Subject)
{
    new Float:MedicPosition[3];
    GetEntPropVector(Medic, Prop_Send, "m_vecOrigin", MedicPosition);
    MedicPosition[2] += 35.0; 
    
    new Float:SubjectPosition[3];
    GetEntPropVector(Subject, Prop_Send, "m_vecOrigin", SubjectPosition);
    SubjectPosition[2] += 35.0; 
    
    return GetVectorDistance(MedicPosition, SubjectPosition) > 650.0;
}

public Action:RegenSubjectTimer(Handle:timer, any:userid)
{
    for(new client=1; client <= MaxClients; client++)
    {
        if(ValidPlayer(client, true) && (War3_GetRace(client) == thisRaceID) && ValidPlayer(g_SubjectOfTheMedic[client], true) && g_HealingType[client] == Heal_Regenerative)
        {
            new Float:temphealth = GetSurvivorTempHealth(g_SubjectOfTheMedic[client]);
            new permanenthealth = GetClientHealth(g_SubjectOfTheMedic[client]);
            
            new real_health = RoundToCeil(temphealth + permanenthealth);
            
            if (real_health < 100 && real_health + 2 <= 100)
            {
                new skill = War3_GetSkillLevel(client, thisRaceID, SKILL_MEDIC_REGEN);
                SetSurvivorTempHealth(g_SubjectOfTheMedic[client], temphealth + HealingRate[skill]);
                g_UberchargeAmount[client] += HealingRate[skill];
            }
            
            if(g_UberchargeAmount[client] > 100.0)
                g_UberchargeAmount[client] = 100.0;
        }
    }
}

public OnW3TakeDmgAllPre(victim, attacker, Float:damage)
{
    if(ValidPlayer(attacker, true))
    {
        for(new client=1; client <= MaxClients; client++)
        {
            if(ValidPlayer(client, true) && (War3_GetRace(client) == thisRaceID) && attacker == g_SubjectOfTheMedic[client] && g_HealingType[client] == Heal_BoostDamage && W3GetDamageType() ^ DMG_BURN)
            {
                if(ValidPlayer(victim, true) && GetClientTeam(victim) && TEAM_SURVIVORS) {
                    // do nothing lol
                }
                else {
                    new skill_kritz = War3_GetSkillLevel(client, thisRaceID, SKILL_KRITZKRIEG);
                    War3_DamageModPercent(BonusDamage[skill_kritz]);
                }
            }
        }
    }
    
    if(ValidPlayer(victim, true))
    {
        for(new client=1; client <= MaxClients; client++)
        {
            if(ValidPlayer(client, true) && (War3_GetRace(client) == thisRaceID) && victim == g_SubjectOfTheMedic[client] && g_IsUbercharging[client])
            {
                War3_DamageModPercent(0.0);
                W3Hint(client, HINT_DMG_RCVD, 1.0, "NO DAMAGE RECEIVED - YOU ARE BEING UBERCHARGED!");
            }
        }
        
        if (War3_GetRace(victim) == thisRaceID && g_IsUbercharging[victim]) {
            War3_DamageModPercent(0.0);
            W3Hint(victim, HINT_DMG_RCVD, 1.0, "NO DAMAGE RECEIVED - YOU ARE UBERCHARGING!");
        }
    }

}

public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon)
{
    if (ValidPlayer(client, true) && GetClientTeam(client) == TEAM_SURVIVORS && (War3_GetRace(client) == thisRaceID))
    {
        if (buttons & IN_USE && (g_TimeLastHooked[client] + PAUSE_BETWEEN_HOOKS < GetGameTime()))
        {
            new entity = GetClientAimedLocationData(client, NULL_VECTOR);
            if (ValidPlayer(entity, true) && GetClientTeam(entity) == TEAM_SURVIVORS && !IsNotVisible(client, entity))
            {
                new String:name[64];
                GetClientName(entity, name, sizeof(name));
                
                if (g_SubjectOfTheMedic[client] != entity) {
                    War3_ChatMessage(client, "You hooked your medicgun up to {lightgreen}%s{default}", name);
                    g_SubjectOfTheMedic[client] = entity;
                    g_TimeLastHooked[client] = GetGameTime();
    
                    GetClientName(client, name, sizeof(name));
                    War3_ChatMessage(entity, "{lightgreen}%s{default} has voluntered to be your medic", name);
                }
                else {
                    War3_ChatMessage(client, "Already boosting {lightgreen}%s{default}", name);
                }
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
    return entity > 0 && entity < MaxClients && entity != data;
}

public Action:DrawUberEffectTimer(Handle:timer, any:userid)
{
    for(new client=1; client <= MaxClients; client++)
    {
        if(ValidPlayer(client, true) && War3_GetRace(client) == thisRaceID)
        {
            if(ValidPlayer(g_SubjectOfTheMedic[client], true))
            {
                DrawUberBeam(client, g_SubjectOfTheMedic[client]);
            }
        }
    }
}

DrawUberBeam(medic, subject)
{  
    new String:start[32];
    new String:end[32];
    
    start = CreateControlPoint(medic);
    end = CreateControlPoint(subject);
    
    new Float:pos[3];
    GetClientEyePosition(medic, pos);
    pos[2] -= 20;
    
    new particle = CreateEntityByName("info_particle_system");
    DispatchKeyValue(particle, "effect_name", PARTICLE_UBERBEAM);
    DispatchKeyValue(particle, "cpoint1", start);
    DispatchKeyValue(particle, "cpoint2", end);
    DispatchKeyValue(particle, "cpoint3", start);
    DispatchSpawn(particle);
    ActivateEntity(particle); 
    TeleportEntity(particle, pos, NULL_VECTOR, NULL_VECTOR);
    AcceptEntityInput(particle, "start");    
    ModifyEntityAddDeathTimer(particle, EFFECT_TIMER);
}

String:CreateControlPoint(client)
{
    new Float:pos[3];
    GetClientEyePosition(client, pos);
    pos[2] -= 20;
    
    decl String:temp[32];
    new target = CreateEntityByName("info_particle_target");
    Format(temp, 32, "cptarget%d", target);
    DispatchKeyValue(target, "targetname", temp);    
    TeleportEntity(target, pos, NULL_VECTOR, NULL_VECTOR); 
    ActivateEntity(target); 
    
    ModifyEntityAttach(target, client);
    ModifyEntityAddDeathTimer(target, EFFECT_TIMER);
    return temp;
}