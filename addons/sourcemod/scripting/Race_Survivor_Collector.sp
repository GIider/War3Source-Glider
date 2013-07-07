#pragma semicolon 1

#include "W3SIncs/War3Source_Interface"
#include <sdkhooks>

public Plugin:myinfo = 
{
    name = "War3Source Race - L4D Survivor Collector",
    author = "Glider",
    description = "The Survivor Collector race for War3Source.",
    version = "1.0",
};

//=======================================================================
//                             VARIABLES
//=======================================================================

new thisRaceID;
new SKILL_HIGHLIGHT, SKILL_DROP, ULT_VORTEX;

new Float:fHighlightRange[5] = {0.0, 150.0, 300.0, 450.0, 600.0};
new Float:fDropModifier[5] = {0.0, 0.4, 0.6, 0.8, 1.0};

new bool:bHasVortex[MAXPLAYERS];
new Float:fVortexPositionEye[MAXPLAYERS][3];
new Float:fVortexPositionFeet[MAXPLAYERS][3];
new iVortexFlameParticle[MAXPLAYERS];

#define ULT_COOLDOWN 120.0
#define LIGHT_DISTANCE 150.0
#define MAX_CHANCE_FOR_DROP 2.0

#define VORTEX_RANGE 1200.0
#define VORTEX_MINIMUM_RANGE 150.0
#define VORTEX_DURATION 15.0

#define PARTICLE_VORTEX "electrical_arc_01_cp0"
#define PARTICLE_VORTEX_SPLASH "weapon_pipebomb_water_child_water7"
#define PARTICLE_VORTEX_FLAME_BLUE "flame_blue"
#define VORTEX_SOUND "ambient/wind/windgust_strong.wav"

#define DROP_SOUND "ui/littlereward.wav"
#define VORTEX_DROP_SOUND "ambient/energy/zap1.wav"
#define MODEL_BOX "models/props_junk/plasticcrate01a.mdl"

//=======================================================================
//                                 INIT
//=======================================================================

public OnWar3PluginReady(){
    thisRaceID = War3_CreateNewRace("Collector", "collector");
    SKILL_HIGHLIGHT = War3_AddRaceSkill(thisRaceID, "Highlight", "Highlights nearby throwables, aswell as pain pills, adrenaline and shows you what's closest.\nMax Range 5/10/15/20m", false, 4);
    SKILL_DROP = War3_AddRaceSkill(thisRaceID, "Droplets", "Makes enemys drop throwables, pain pills and adrenaline. Increasing the level will increase the chance of a dropped item", false, 4);
    ULT_VORTEX = War3_AddRaceSkill(thisRaceID, "Vortex", "Summon a vortex that brings items up to 40m away to itself. CD: 120s", true, 1);
    
    War3_CreateRaceEnd(thisRaceID);
}

public OnPluginStart()
{
    if(War3_GetGame() != Game_L4D && War3_GetGame() != Game_L4D2)
        SetFailState("Only works in the L4D engine! %i", War3_GetGame());
    
    //CreateTimer(0.1, TestTimer, _, TIMER_REPEAT);
    CreateTimer(1.0, CollectTimer, _, TIMER_REPEAT);
    CreateTimer(0.1, VortexEffectTimer, _, TIMER_REPEAT);
    CreateTimer(1.0, VortexTeleportTimer, _, TIMER_REPEAT);
}

public OnMapStart()
{
    War3_PrecacheParticle(PARTICLE_VORTEX);
    War3_PrecacheParticle(PARTICLE_VORTEX_SPLASH);
    War3_PrecacheParticle(PARTICLE_VORTEX_FLAME_BLUE);
    
    War3_AddCustomSound(VORTEX_DROP_SOUND);
    War3_AddCustomSound(VORTEX_SOUND);
    War3_AddCustomSound(DROP_SOUND);
    
    PrecacheModel(MODEL_BOX, true);
}

/*public Action:TestTimer(Handle:timer, any:userid)
{
    new Float:fPlayerPos[3];
    new Float:fEntityPos[3];
    new entity = INVALID_ENT_REFERENCE;
    
    for(new client=1; client <= MaxClients; client++)
    {
        if(ValidPlayer(client, true) && War3_GetRace(client) == thisRaceID)
        {
            GetClientEyePosition(client, fPlayerPos);
            
            while ((entity = FindEntityByClassname(entity, "weapon_pain_pills")) != INVALID_ENT_REFERENCE) 
            {
                GetEntPropVector(entity, Prop_Send, "m_vecOrigin", fEntityPos);
                new Float:fDirectionVector[3];

                SubtractVectors(fPlayerPos, fEntityPos, fDirectionVector);
                NormalizeVector(fDirectionVector, fDirectionVector);
                
                ScaleVector(fDirectionVector, 50.0);
                
                if (fDirectionVector[2] < 0)
                {
                    fDirectionVector[2] = fDirectionVector[2] - 5.0;
                }
                else
                {
                    fDirectionVector[2] = fDirectionVector[2] + 5.0;
                }
                
                TeleportEntity(entity, NULL_VECTOR, fDirectionVector, fDirectionVector);
                
                War3_ChatMessage(client, "%f %f %f", fDirectionVector[0], fDirectionVector[1], fDirectionVector[2]);
            }
        }
        
        

    }
}*/

//=======================================================================
//                                 STOCKS
//=======================================================================

Float:fGetDistance(entity, Float:fPlayerPos[3])
{
    new Float:fEntityPos[3];
    GetEntPropVector(entity, Prop_Send, "m_vecOrigin", fEntityPos);
        
    return GetVectorDistance(fPlayerPos, fEntityPos);    
}


MarkEntityIfClose(entity, Float:distance, Float:neededDistance, const String:color[])
{
    if (distance <= neededDistance)
    {
        new Float:fEntityPos[3];
        GetEntPropVector(entity, Prop_Send, "m_vecOrigin", fEntityPos);
        
        AttachThrowAwayLight(entity, fEntityPos, color, "4", LIGHT_DISTANCE, "", 1.0);
    }
}

//=======================================================================
//                                 HIGHLIGHT
//=======================================================================

public Action:CollectTimer(Handle:timer, any:userid)
{
    new Float:fPlayerPos[3];
    new entity = INVALID_ENT_REFERENCE;
    
    new Float:fNeededRange = 0.0;
    new Float:fDistance;
    new Float:fClosestDistance = 500.1;
    new closestEntity = INVALID_ENT_REFERENCE;
    
    for(new client=1; client <= MaxClients; client++)
    {
        if(ValidPlayer(client, true) && War3_GetRace(client) == thisRaceID)
        {
            new skill = War3_GetSkillLevel(client, thisRaceID, SKILL_HIGHLIGHT);
            if(skill > 0)
            { 
                GetClientAbsOrigin(client, fPlayerPos);
                fNeededRange = fHighlightRange[skill];
                fClosestDistance = fHighlightRange[skill] + 0.1;
                
                while ((entity = FindEntityByClassname(entity, "weapon_pain_pills")) != INVALID_ENT_REFERENCE) 
                {
                    fDistance = fGetDistance(entity, fPlayerPos);
                    MarkEntityIfClose(entity, fDistance, fNeededRange, "255 0 0");
                    
                    if (fDistance < fClosestDistance)
                    {
                        fClosestDistance = fDistance;
                        closestEntity = entity;
                    }
                }
                
                while ((entity = FindEntityByClassname(entity, "weapon_adrenaline")) != INVALID_ENT_REFERENCE) 
                {
                    fDistance = fGetDistance(entity, fPlayerPos);
                    MarkEntityIfClose(entity, fDistance, fNeededRange, "255 0 255");
                    
                    if (fDistance < fClosestDistance)
                    {
                        fClosestDistance = fDistance;
                        closestEntity = entity;
                    }
                }
                
                while ((entity = FindEntityByClassname(entity, "weapon_molotov")) != INVALID_ENT_REFERENCE) 
                {
                    fDistance = fGetDistance(entity, fPlayerPos);
                    MarkEntityIfClose(entity, fDistance, fNeededRange, "255 0 0");
                    
                    if (fDistance < fClosestDistance)
                    {
                        fClosestDistance = fDistance;
                        closestEntity = entity;
                    }
                }
                
                while ((entity = FindEntityByClassname(entity, "weapon_pipe_bomb")) != INVALID_ENT_REFERENCE) 
                {
                    fDistance = fGetDistance(entity, fPlayerPos);
                    MarkEntityIfClose(entity, fDistance, fNeededRange, "0 0 255");
                    
                    if (fDistance < fClosestDistance)
                    {
                        fClosestDistance = fDistance;
                        closestEntity = entity;
                    }
                }
                
                while ((entity = FindEntityByClassname(entity, "weapon_vomitjar")) != INVALID_ENT_REFERENCE) 
                {
                    fDistance = fGetDistance(entity, fPlayerPos);
                    MarkEntityIfClose(entity, fDistance, fNeededRange, "0 255 0");
                    
                    if (fDistance < fClosestDistance)
                    {
                        fClosestDistance = fDistance;
                        closestEntity = entity;
                    }
                }
                
                while ((entity = FindEntityByClassname(entity, "weapon_pain_pills_spawn")) != INVALID_ENT_REFERENCE) 
                {
                    fDistance = fGetDistance(entity, fPlayerPos);
                    MarkEntityIfClose(entity, fDistance, fNeededRange, "255 0 0");
                    
                    if (fDistance < fClosestDistance)
                    {
                        fClosestDistance = fDistance;
                        closestEntity = entity;
                    }
                }
                
                while ((entity = FindEntityByClassname(entity, "weapon_adrenaline_spawn")) != INVALID_ENT_REFERENCE) 
                {
                    fDistance = fGetDistance(entity, fPlayerPos);
                    MarkEntityIfClose(entity, fDistance, fNeededRange, "255 0 255");
                    
                    if (fDistance < fClosestDistance)
                    {
                        fClosestDistance = fDistance;
                        closestEntity = entity;
                    }
                }
                
                while ((entity = FindEntityByClassname(entity, "weapon_molotov_spawn")) != INVALID_ENT_REFERENCE) 
                {
                    if (GetEntProp(entity, Prop_Send, "m_fEffects") == 16)
                    {
                        fDistance = fGetDistance(entity, fPlayerPos);
                        MarkEntityIfClose(entity, fDistance, fNeededRange, "255 0 0");
                        
                        if (fDistance < fClosestDistance)
                        {
                            fClosestDistance = fDistance;
                            closestEntity = entity;
                        }
                    }
                }
                
                while ((entity = FindEntityByClassname(entity, "weapon_pipe_bomb_spawn")) != INVALID_ENT_REFERENCE) 
                {
                    if (GetEntProp(entity, Prop_Send, "m_fEffects") == 16)
                    {
                        fDistance = fGetDistance(entity, fPlayerPos);
                        MarkEntityIfClose(entity, fDistance, fNeededRange, "0 0 255");
                        
                        if (fDistance < fClosestDistance)
                        {
                            fClosestDistance = fDistance;
                            closestEntity = entity;
                        }
                    }
                }
                
                while ((entity = FindEntityByClassname(entity, "weapon_vomitjar_spawn")) != INVALID_ENT_REFERENCE) 
                {
                    if (GetEntProp(entity, Prop_Send, "m_fEffects") == 16)
                    {
                        fDistance = fGetDistance(entity, fPlayerPos);
                        MarkEntityIfClose(entity, fDistance, fNeededRange, "0 255 0");
                        
                        if (fDistance < fClosestDistance)
                        {
                            fClosestDistance = fDistance;
                            closestEntity = entity;
                        }
                    }
                }
                
                if (IsValidEntity(closestEntity))
                {
                    decl String:ClassName[128];
                    GetEdictClassname(closestEntity, ClassName, sizeof(ClassName));
                    
                    decl String:NiceName[20];
                    GetNiceName(ClassName, NiceName, sizeof(NiceName));
                    
                    new distance = RoundToCeil(fClosestDistance / 30.0);
                    
                    if (distance == 1) 
                    {
                        W3Hint(client, HINT_COOLDOWN_COUNTDOWN, 1.0, "[%s - 1 meter away]", NiceName);
                    }
                    else
                    {
                        W3Hint(client, HINT_COOLDOWN_COUNTDOWN, 1.0, "[%s - %i meters away]", NiceName, distance);
                    }
                }
                else
                {
                    W3Hint(client, HINT_COOLDOWN_COUNTDOWN, 1.0, "No goodys in range");
                }
            }
        }
    }
}

GetNiceName(const String:weaponName[], String:nicename[], maxlength)
{
    if (StrEqual(weaponName, "weapon_pain_pills", false) || StrEqual(weaponName, "weapon_pain_pills_spawn", false))
    {
        strcopy(nicename, maxlength, "PAIN PILLS");
        return;
    }
    if (StrEqual(weaponName, "weapon_adrenaline_spawn", false) || StrEqual(weaponName, "weapon_adrenaline", false))
    {
        strcopy(nicename, maxlength, "ADRENALINE");
        return;
    }
    if (StrEqual(weaponName, "weapon_molotov", false) || StrEqual(weaponName, "weapon_molotov_spawn", false))
    {
        strcopy(nicename, maxlength, "MOLOTOV");
        return;
    }
    if (StrEqual(weaponName, "weapon_pipe_bomb", false) || StrEqual(weaponName, "weapon_pipe_bomb_spawn", false))
    {
        strcopy(nicename, maxlength, "PIPEBOMB");
        return;
    }
    if (StrEqual(weaponName, "weapon_vomitjar", false) || StrEqual(weaponName, "weapon_vomitjar_spawn", false))
    {
        strcopy(nicename, maxlength, "BOOMER BILE");
        return;
    }
    
    strcopy(nicename, maxlength, "UNKNOWN ITEM");
    

}

//=======================================================================
//                                 DROPLETS
//=======================================================================

public OnW3TakeDmgAllPre(victim, attacker, Float:damage)
{
    if(ValidPlayer(attacker) && War3_GetRace(attacker) == thisRaceID && War3_SurvivorHittingZombie(victim, attacker))
    {
        new skill = War3_GetSkillLevel(attacker, thisRaceID, SKILL_DROP);
        if(skill > 0)
        {
            new hp = 0;
            if (ValidPlayer(victim)) {
                hp = GetClientHealth(victim);
            }
            else {
                hp = GetEntityHP(victim);
            }
            
            if (damage > 0.0 && hp > 0) {
                new Float:chance = damage / float(hp);
                
                //War3_ChatMessage(attacker, "HP: %i damage: %f", hp, damage);
                RollTheDropDice(attacker, victim, chance, skill);
            }
            
            // damage / hp
            // enemy hp: 50
            // damage: 25 -> 0.5
            // damage: 100 -> 2
            
        }
    }
}

RollTheDropDice(client, victim, Float:chance, level) {
    chance = Min(chance * fDropModifier[level], MAX_CHANCE_FOR_DROP);
    
    //War3_ChatMessage(client, "Rolling with a chance of {red}%f", chance);
    if (GetRandomFloat(0.0, 100.0) <= chance) {
        new Float:fVictimPosition[3];
        
        if (ValidPlayer(victim)) {
            GetClientAbsOrigin(victim, fVictimPosition);
        }
        else {
            GetEntPropVector(victim, Prop_Send, "m_vecOrigin", fVictimPosition);
        }
        
        fVictimPosition[2] += 10.0;
        
        switch (GetRandomInt(0, 4))
        {
            case 0:
                Drop(fVictimPosition, "weapon_pain_pills");
            case 1:
                Drop(fVictimPosition, "weapon_adrenaline");
            case 2:
                Drop(fVictimPosition, "weapon_pipe_bomb");
            case 3:
                Drop(fVictimPosition, "weapon_vomitjar");
            case 4:
                Drop(fVictimPosition, "weapon_molotov");
        }
        
        EmitSoundToClient(client, DROP_SOUND);
    }
}

Drop(Float:fPosition[3], const String:item[])
{
    new entity = CreateEntityByName(item);

    DispatchSpawn(entity);
    ActivateEntity(entity);
    TeleportEntity(entity, fPosition, NULL_VECTOR, NULL_VECTOR);
}

Float:Min(Float:x, Float:y)
{
    if (x < y)
        return x;

    return y;
}

//=======================================================================
//                                 VORTEX
//=======================================================================

public OnUltimateCommand(client,race,bool:pressed)
{
    if(ValidPlayer(client, true) && 
       race == thisRaceID && 
       pressed && 
       War3_SkillNotInCooldown(client, thisRaceID, ULT_VORTEX, true) && 
       !Silenced(client) &&
       GetClientTeam(client) == TEAM_SURVIVORS &&
       !War3_L4D_IsHelpless(client) &&
       !War3_IsPlayerIncapped(client) &&
       !bHasVortex[client]) 
    {
        new flags = GetEntityFlags(client);
        new skill = War3_GetSkillLevel(client, thisRaceID, ULT_VORTEX);
        if (skill > 0 && flags & FL_ONGROUND)
        {
            new Float:fCasterEyePosition[3];
            new Float:fCasterFeetPosition[3];
            
                        
            GetClientAbsOrigin(client, fCasterFeetPosition);
            GetClientEyePosition(client, fCasterEyePosition);
            
            iVortexFlameParticle[client] = ThrowAwayParticle(PARTICLE_VORTEX_FLAME_BLUE, fCasterEyePosition, VORTEX_DURATION);

            new Float:fAngleVector[3] = {-110.0, 0.0, 0.0};
            TeleportEntity(iVortexFlameParticle[client], NULL_VECTOR, fAngleVector, fAngleVector);
            
            fVortexPositionEye[client][0] = fCasterEyePosition[0];
            fVortexPositionEye[client][1] = fCasterEyePosition[1];
            fVortexPositionEye[client][2] = fCasterEyePosition[2];
            
            fVortexPositionFeet[client][0] = fCasterFeetPosition[0];
            fVortexPositionFeet[client][1] = fCasterFeetPosition[1];
            fVortexPositionFeet[client][2] = fCasterFeetPosition[2];
            
            bHasVortex[client] = true;
            EmitAmbientSound(VORTEX_SOUND, fCasterEyePosition);
            
            decl String: color[12];
            
            new r = GetRandomInt(50, 255);
            new g = GetRandomInt(50, 255);
            new b = GetRandomInt(50, 255);
            
            Format(color, sizeof(color), "%i %i %i", r, g, b);
            ThrowAwayLightEmitter(fCasterEyePosition, color, "4", 300.0, VORTEX_DURATION);
            
            CreateTimer(VORTEX_DURATION, ResetUltimate, client);
            War3_CooldownMGR(client, ULT_COOLDOWN, thisRaceID, ULT_VORTEX);
        }
    }
}

public Action:VortexEffectTimer(Handle:timer, any:userid)
{
    new Float:fCasterEyePosition[3];
    new Float:fCasterFeetPosition[3];
    
    for(new client=1; client <= MaxClients; client++)
    {
        if(ValidPlayer(client, true) && War3_GetRace(client) == thisRaceID)
        {
            new skill = War3_GetSkillLevel(client, thisRaceID, ULT_VORTEX);
            if(skill > 0 && bHasVortex[client])
            { 
                fCasterEyePosition[0] = fVortexPositionEye[client][0];
                fCasterEyePosition[1] = fVortexPositionEye[client][1];
                fCasterEyePosition[2] = fVortexPositionEye[client][2];
                
                fCasterFeetPosition[0] = fVortexPositionFeet[client][0];
                fCasterFeetPosition[1] = fVortexPositionFeet[client][1];
                fCasterFeetPosition[2] = fVortexPositionFeet[client][2];
                
                ThrowAwayParticle(PARTICLE_VORTEX, fCasterEyePosition, 1.0);
                ThrowAwayParticle(PARTICLE_VORTEX_SPLASH, fCasterFeetPosition, 1.0);
            }
        }
    }
}

public OnGameFrame()
{
    for(new client=1; client <= MaxClients; client++)
    {
        if (bHasVortex[client])
        {
            new particle = iVortexFlameParticle[client];
            if (IsValidEntity(particle))
            {
                new Float:fRotation[3];
                
                GetEntPropVector(particle, Prop_Send, "m_angRotation", fRotation);
                fRotation[2] -= 5;
                fRotation[1] += 5;
                
                TeleportEntity(particle, NULL_VECTOR, fRotation, fRotation);
            }
        }
    }
}

public Action:VortexTeleportTimer(Handle:timer, any:userid)
{
    new Float:fCasterEyePosition[3];
    
    for(new client=1; client <= MaxClients; client++)
    {
        if(ValidPlayer(client, true) && War3_GetRace(client) == thisRaceID)
        {
            new skill = War3_GetSkillLevel(client, thisRaceID, ULT_VORTEX);
            if(skill > 0 && bHasVortex[client])
            { 
                fCasterEyePosition[0] = fVortexPositionEye[client][0];
                fCasterEyePosition[1] = fVortexPositionEye[client][1];
                fCasterEyePosition[2] = fVortexPositionEye[client][2];
                
                SuckUpItems(fCasterEyePosition);
            }
        }
    }
}

bool:CheckVortexAndTeleport(entity, Float:fTargetPosition[3])
{
    new Float:fDistance;
    
    fDistance = fGetDistance(entity, fTargetPosition);
    if (fDistance <= VORTEX_RANGE && fDistance >= VORTEX_MINIMUM_RANGE) 
    {
        new Float:fDirectionVector[3] = {90.0, 0.0, 0.0};
        TeleportEntity(entity, fTargetPosition, NULL_VECTOR, fDirectionVector);
        
        EmitSoundToAll(VORTEX_DROP_SOUND, _, _, _, _, _, _, _, fTargetPosition); 
        return true;
    }
    
    return false;
}

SuckUpItems(Float:fTargetPosition[3])
{
    new entity = INVALID_ENT_REFERENCE;
    new Float:fDistance;
    
    while ((entity = FindEntityByClassname(entity, "weapon_pain_pills")) != INVALID_ENT_REFERENCE) 
    {
        if (CheckVortexAndTeleport(entity, fTargetPosition))
        {
            return;
        }
    }
    
    while ((entity = FindEntityByClassname(entity, "weapon_adrenaline")) != INVALID_ENT_REFERENCE) 
    {
        if (CheckVortexAndTeleport(entity, fTargetPosition))
        {
            return;
        }
    }
    
    while ((entity = FindEntityByClassname(entity, "weapon_molotov")) != INVALID_ENT_REFERENCE) 
    {
        if (CheckVortexAndTeleport(entity, fTargetPosition))
        {
            return;
        }
    }
    
    while ((entity = FindEntityByClassname(entity, "weapon_pipe_bomb")) != INVALID_ENT_REFERENCE) 
    {
        if (CheckVortexAndTeleport(entity, fTargetPosition))
        {
            return;
        }
    }
    
    while ((entity = FindEntityByClassname(entity, "weapon_vomitjar")) != INVALID_ENT_REFERENCE) 
    {
        if (CheckVortexAndTeleport(entity, fTargetPosition))
        {
            return;
        }
    }
    
    while ((entity = FindEntityByClassname(entity, "weapon_pain_pills_spawn")) != INVALID_ENT_REFERENCE) 
    {
        fDistance = fGetDistance(entity, fTargetPosition);
        if (fDistance <= VORTEX_RANGE && fDistance >= VORTEX_MINIMUM_RANGE) 
        {
            AcceptEntityInput(entity, "kill");
            Drop(fTargetPosition, "weapon_pain_pills");
            EmitSoundToAll(VORTEX_DROP_SOUND, _, _, _, _, _, _, _, fTargetPosition); 
            return;
        }
    }
    
    while ((entity = FindEntityByClassname(entity, "weapon_adrenaline_spawn")) != INVALID_ENT_REFERENCE) 
    {
        fDistance = fGetDistance(entity, fTargetPosition);
        if (fDistance <= VORTEX_RANGE && fDistance >= VORTEX_MINIMUM_RANGE) 
        {
            AcceptEntityInput(entity, "kill");
            Drop(fTargetPosition, "weapon_adrenaline");
            EmitSoundToAll(VORTEX_DROP_SOUND, _, _, _, _, _, _, _, fTargetPosition); 
            return;
        }
    }
    
    while ((entity = FindEntityByClassname(entity, "weapon_molotov_spawn")) != INVALID_ENT_REFERENCE) 
    {
        if (GetEntProp(entity, Prop_Send, "m_fEffects") == 16)
        {
            fDistance = fGetDistance(entity, fTargetPosition);
            if (fDistance <= VORTEX_RANGE && fDistance >= VORTEX_MINIMUM_RANGE) 
            {
                AcceptEntityInput(entity, "kill");
                Drop(fTargetPosition, "weapon_molotov");
                EmitSoundToAll(VORTEX_DROP_SOUND, _, _, _, _, _, _, _, fTargetPosition); 
                return;
            }
        }
    }
    
    while ((entity = FindEntityByClassname(entity, "weapon_pipe_bomb_spawn")) != INVALID_ENT_REFERENCE) 
    {
        if (GetEntProp(entity, Prop_Send, "m_fEffects") == 16)
        {
            fDistance = fGetDistance(entity, fTargetPosition);
            if (fDistance <= VORTEX_RANGE && fDistance >= VORTEX_MINIMUM_RANGE) 
            {
                AcceptEntityInput(entity, "kill");
                Drop(fTargetPosition, "weapon_pipe_bomb");
                EmitSoundToAll(VORTEX_DROP_SOUND, _, _, _, _, _, _, _, fTargetPosition); 
                return;
            }

        }
    }
    
    while ((entity = FindEntityByClassname(entity, "weapon_vomitjar_spawn")) != INVALID_ENT_REFERENCE) 
    {
        if (GetEntProp(entity, Prop_Send, "m_fEffects") == 16)
        {
            fDistance = fGetDistance(entity, fTargetPosition);
            if (fDistance <= VORTEX_RANGE && fDistance >= VORTEX_MINIMUM_RANGE) 
            {
                AcceptEntityInput(entity, "kill");
                Drop(fTargetPosition, "weapon_vomitjar");
                EmitSoundToAll(VORTEX_DROP_SOUND, _, _, _, _, _, _, _, fTargetPosition); 
                return;
            }

        }
    }
}

public Action:ResetUltimate(Handle:timer, any:client)
{
    DisableUltimate(client);
}

DisableUltimate(client)
{
    bHasVortex[client] = false;
}

public OnWar3EventSpawn(client)
{    
    DisableUltimate(client);
    
    if(War3_GetRace(client) == thisRaceID)
    {
        //SDKHook(client, SDKHook_WeaponCanUse, OnWeaponCanUse);
    }
}

public OnWar3EventDeath(victim, attacker)
{
    if(War3_GetRace(victim) == thisRaceID)
    {
        DisableUltimate(victim);
        //SDKUnhook(victim, SDKHook_WeaponCanUse, OnWeaponCanUse);
        
        // TODO: Make him drop all his items
    }
}

public OnRaceChanged(client, oldrace, newrace)
{
    if(newrace != thisRaceID)
    {
        DisableUltimate(client);
        //SDKUnhook(client, SDKHook_WeaponCanUse, OnWeaponCanUse);
    }
    else
    {
        //SDKHook(client, SDKHook_WeaponCanUse, OnWeaponCanUse);
    }
}

public OnSkillLevelChanged(client, race, skill, newskilllevel)
{
    if(skill == ULT_VORTEX && newskilllevel == 0)
    {    
        DisableUltimate(client);
    }
}

//=======================================================================
//                                 MULTI ITEMS
//=======================================================================

/*
stock bool:IsCollectible(const String:weaponName[])
{
    return (StrEqual(weaponName, "weapon_pain_pills", false) || 
            StrEqual(weaponName, "weapon_adrenaline", false) || 
            StrEqual(weaponName, "weapon_molotov", false) || 
            StrEqual(weaponName, "weapon_pipe_bomb", false) || 
            StrEqual(weaponName, "weapon_vomitjar", false));
}

stock GetCollectibleSlot(const String:weaponName[])
{
    if (StrEqual(weaponName, "weapon_pain_pills", false) || 
        StrEqual(weaponName, "weapon_adrenaline", false))
    {
        return 4;
    }
    else if (StrEqual(weaponName, "weapon_molotov", false) || 
             StrEqual(weaponName, "weapon_pipe_bomb", false) || 
             StrEqual(weaponName, "weapon_vomitjar", false))
    {
        return 2;
    }
    
    return -1;
}

public Action:OnWeaponCanUse(client, weapon)
{
    decl String:entityName[64];
    GetEdictClassname(weapon, entityName, sizeof(entityName));

    War3_ChatMessage(client, entityName);
    
    if (IsCollectible(entityName))
    {
        new slot = GetCollectibleSlot(entityName);
        new playerCollectible = GetPlayerWeaponSlot(client, slot);
        if (IsValidEntity(playerCollectible)) {
            RemovePlayerItem(client, playerCollectible);            
        }
    }

    return Plugin_Continue;
}*/