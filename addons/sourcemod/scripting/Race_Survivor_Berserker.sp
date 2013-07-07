#pragma semicolon 1

#include "W3SIncs/War3Source_Interface"

public Plugin:myinfo = 
{
    name = "War3Source Race - L4D Survivor Berserker",
    author = "Glider",
    description = "The Survivor Berserker race for War3Source.",
    version = "1.0",
};

//=======================================================================
//                             VARIABLES
//=======================================================================

new thisRaceID;
new SKILL_RESISTANCE, SKILL_LEAP, SKILL_SPEED;
new ULT_TAUNT;

new bool:g_bHasDoubleJumped[MAXPLAYERS];
new bool:g_bIsJumping[MAXPLAYERS];
new Float:g_fPressedJump[MAXPLAYERS];

new Float:DamageResistance[5] = {1.0, 0.9375, 0.875, 0.8125, 0.75};
new Float:MeleeASPDBuff[5] = {1.0, 1.15, 1.3, 1.45, 1.5};
new Float:LeapStrength[5] = {0.0, 300.0, 333.0, 366.0, 399.0};

//=======================================================================
//                                 INIT
//=======================================================================

public OnWar3PluginReady(){
    thisRaceID = War3_CreateNewRace("Berserker", "berserker");
    SKILL_RESISTANCE = War3_AddRaceSkill(thisRaceID, "Damage Resistance", "You take 6.25/12.5/18.75/25% less damage.", false, 4);
    SKILL_LEAP = War3_AddRaceSkill(thisRaceID, "Leap (+jump)", "Press +jump again in midair to leap in the direction you're facing", false, 4);
    SKILL_SPEED = War3_AddRaceSkill(thisRaceID, "Blood rush", "Increase your melee attack speed by 15/30/45/50%", false, 4);
    ULT_TAUNT = War3_AddRaceSkill(thisRaceID, "Taunt", "You taunt the zombies, forcing them to attack you. CD: 90s", true, 1);
    
    War3_CreateRaceEnd(thisRaceID);
}

public OnPluginStart()
{
    if(War3_GetGame() != Game_L4D && War3_GetGame() != Game_L4D2)
        SetFailState("Only works in the L4D engine! %i", War3_GetGame());
}

public OnMapStart()
{
    War3_PrecacheParticle("impact_explosive_ammo_small");
    War3_PrecacheParticle("weapon_pipebomb_blinking_light");
}

//=======================================================================
//                                 Blood Rush
//=======================================================================

public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon)
{
    if (ValidPlayer(client, true) && GetClientTeam(client) == TEAM_SURVIVORS && (War3_GetRace(client) == thisRaceID))
    {
        new skill = War3_GetSkillLevel(client, thisRaceID, SKILL_SPEED);
        if (skill > 0)
        {
            if (buttons & IN_ATTACK)
            {
                new String:name[64];
                GetClientWeapon(client, name, sizeof(name));
                
                if (StrEqual(name, "weapon_melee"))
                {
                    AdjustWeaponSpeed(client, MeleeASPDBuff[skill], 1);
                }
            }
        }
            
        new skill_leap = War3_GetSkillLevel(client, thisRaceID, SKILL_LEAP);
        if(skill_leap > 0 && !War3_L4D_IsHelpless(client) && !War3_IsPlayerIncapped(client) && !IsFakeClient(client))
        {
            // Double jumping on ladders? No sir!
            if (GetEntityMoveType(client) == MOVETYPE_LADDER) 
            {
                return Plugin_Continue;
            }
            
            new flags = GetEntityFlags(client);
    
            if(buttons & IN_JUMP)
            {
                if (!g_bIsJumping[client])
                {
                    g_fPressedJump[client] = GetGameTime() + 0.20;
                    g_bIsJumping[client] = true;
                }
                        
                if (!(flags & FL_ONGROUND) && g_fPressedJump[client] <= GetGameTime())
                    if (!g_bHasDoubleJumped[client])
                    {    
                        decl Float:fPos[3];
                        GetEntPropVector(client, Prop_Send, "m_vecOrigin", fPos);
                        fPos[2] += 5.0;
                        ThrowAwayParticle("impact_explosive_ammo_small", fPos, 1.0);

                        new Float:vAngles[3], Float:vReturn[3]; 
                        GetClientEyeAngles(client, vAngles);

                        vReturn[0] = FloatMul( Cosine( DegToRad(vAngles[1])  ) , LeapStrength[skill_leap]);
                        vReturn[1] = FloatMul( Sine( DegToRad(vAngles[1])  ) , LeapStrength[skill_leap]);
                        vReturn[2] = FloatMul( Sine( DegToRad(vAngles[0])  ) , (0 - LeapStrength[skill_leap]));

                        // Enables user to escape fall damage
                        new Float:EmptyVector[3] = {0.0, 0.0, 0.0};
                        TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, EmptyVector);
                        
                        // Now make them leap
                        TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, vReturn);    
                        g_bHasDoubleJumped[client] = true;
                    }
            }
            else if (flags & FL_ONGROUND)
            {
                g_bIsJumping[client] = false;
                g_bHasDoubleJumped[client] = false;
            }
        }
    }

    return Plugin_Continue;    
}

stock AdjustWeaponSpeed(client, Float:Amount, slot)
{
    if (GetPlayerWeaponSlot(client, slot) > 0)
    {
        new Float:m_flNextPrimaryAttack = GetEntPropFloat(GetPlayerWeaponSlot(client, slot), Prop_Send, "m_flNextPrimaryAttack");
        new Float:m_flNextSecondaryAttack = GetEntPropFloat(GetPlayerWeaponSlot(client, slot), Prop_Send, "m_flNextSecondaryAttack");
        new Float:m_flCycle = GetEntPropFloat(GetPlayerWeaponSlot(client, slot), Prop_Send, "m_flCycle");
        new m_bInReload = GetEntProp(GetPlayerWeaponSlot(client, slot), Prop_Send, "m_bInReload");
        //Getting the animation cycle at zero seems to be key here, however the scar and pistols weren't seem to be getting affected
        if (m_flCycle == 0.000000 && m_bInReload < 1)
        {
            SetEntPropFloat(GetPlayerWeaponSlot(client, slot), Prop_Send, "m_flPlaybackRate", Amount);
            SetEntPropFloat(GetPlayerWeaponSlot(client, slot), Prop_Send, "m_flNextPrimaryAttack", m_flNextPrimaryAttack - ((Amount - 1.0) / 2));
            SetEntPropFloat(GetPlayerWeaponSlot(client, slot), Prop_Send, "m_flNextSecondaryAttack", m_flNextSecondaryAttack - ((Amount - 1.0) / 2));
        }
    }
}

//=======================================================================
//                                 TAUNT
//=======================================================================

public OnUltimateCommand(client, race, bool:pressed)
{
    if(ValidPlayer(client, true) && 
       race == thisRaceID && 
       pressed && 
       War3_SkillNotInCooldown(client, thisRaceID, ULT_TAUNT, true) && 
       !Silenced(client) &&
       GetClientTeam(client) == TEAM_SURVIVORS &&
       !War3_L4D_IsHelpless(client) &&
       !War3_IsPlayerIncapped(client))
    {    
        new skill = War3_GetSkillLevel(client, thisRaceID, ULT_TAUNT);
        if(skill > 0)
        {
            new iChaseEntity = CreateEntityByName("info_goal_infected_chase");
            if (IsValidEntity(iChaseEntity))
            {
                new Float:casterPos[3];    
                
                GetClientAbsOrigin(client, casterPos);
                TeleportEntity(iChaseEntity, casterPos, NULL_VECTOR, NULL_VECTOR);
                
                DispatchSpawn(iChaseEntity);
                
                ModifyEntityAttach(iChaseEntity, client, "eyes");
                
                ActivateEntity(iChaseEntity);
                AcceptEntityInput(iChaseEntity, "enable");
                
                ClientCommand(client, "vocalize PlayerTaunt");
                
                AttachThrowAwayParticle(client, "weapon_pipebomb_blinking_light", NULL_VECTOR, "eyes", 15.0);
                ModifyEntityAddDeathTimer(iChaseEntity, 15.0);
                
                War3_CooldownMGR(client, 90.0, thisRaceID, ULT_TAUNT);
            }
        }
    }
}

//=======================================================================
//                                 Damage Resistance
//=======================================================================


public OnW3TakeDmgAllPre(victim,attacker,Float:damage){
    if(ValidPlayer(victim,true))
    {
        if(War3_GetRace(victim) == thisRaceID)
        {
            new skill = War3_GetSkillLevel(victim, thisRaceID, SKILL_RESISTANCE);
            if(skill >= 0)
                War3_DamageModPercent(DamageResistance[skill]);
        }
    }
}
