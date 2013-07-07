#pragma semicolon 1

#include <sourcemod>
#include "W3SIncs/War3Source_Interface"
#include <sdktools>


enum{
    BEACON=0,
    LASER,
    GORE,
    DEVELOPER,
    MIRROR,
}

new shopItem[MAXITEMS];

public Plugin:myinfo = 
{
    name = "W3S - L4D - Shopitems",
    author = "Glider",
    description = "Yay shopitems",
};

public OnPluginStart()
{
    if(!GAMEL4DANY)
    {
        SetFailState("L4D only");
    }
    
    HookEvent("bullet_impact", BulletImpactEvent, EventHookMode_Pre);
}

public OnMapStart()
{
    War3_PrecacheParticle("mini_fireworks");
}

public OnWar3LoadRaceOrItemOrdered(num)
{
    if(num==10) 
    {
        for(new x=0; x < MAXITEMS; x++)
            shopItem[x]=0;
        
        shopItem[BEACON]=War3_CreateShopItem("Tracer-Rounds", "short_beacon", "Makes your bullets pretty", 5, 0);
        shopItem[LASER]=War3_CreateShopItem("Laser sight", "short_lzs", "Gives you the laser sight attachment", 25, 0);
        shopItem[GORE]=War3_CreateShopItem("Bloody Death", "short_gore", "Enhances zombie deaths", 5, 0);
        shopItem[DEVELOPER]=War3_CreateShopItem("Developers Glasses", "short_develop", "Lets you see the health of enemys you're shooting at. Doesn't work with fire damage.", 25, 0);
        shopItem[MIRROR]=War3_CreateShopItem("Mirror", "short_mirror", "Mirrors friendly fire damage.", 10, 0);
    }    
}

public OnItemPurchase(client,item)
{
    if(item == shopItem[BEACON])
    {
        War3_ChatMessage(client, "You load yourself with tracer rounds...");
    }
    else if(item == shopItem[LASER])
    {
        new slot0 = GetPlayerWeaponSlot(client, 0);
        L4D2_SetWeaponUpgrades(slot0, L4D2_GetWeaponUpgrades(slot0) | L4D2_WEPUPGFLAG_LASER);

        War3_ChatMessage(client, "You feel much more accurate...");
        War3_SetOwnsItem(client, shopItem[LASER], false);
    }
    else if(item == shopItem[GORE])
    {
        War3_ChatMessage(client, "Delicious gore activated...");
    }
}

public OnW3TakeDmgBulletPre(victim,attacker,Float:damage)
{
    if (ValidPlayer(victim, true) && ValidPlayer(attacker, true) &&
        GetClientTeam(victim) == GetClientTeam(attacker) && 
        (victim != attacker) && War3_GetOwnsItem(victim, shopItem[MIRROR]) &&
        W3GetDamageType() ^ DMG_BURN)
    {
        War3_DamageModPercent(0.0);
        War3_DealDamage(attacker, RoundToCeil(damage), attacker, DMG_GENERIC, "mirror", _, _, _, true);
        
        W3Hint(attacker, HINT_COOLDOWN_COUNTDOWN, 0.1, "Your friendly fire hurts yourself!");
    }
}

public OnW3TakeDmgAllPre(victim, attacker, Float:damage)
{
    if(ValidPlayer(attacker, true) && War3_GetOwnsItem(attacker, shopItem[DEVELOPER]) && !(W3GetDamageType() & DMG_BURN))
    {
        new hp = GetEntityHP(victim) - RoundToFloor(damage);
        if (hp > 0)
        {
            if (ValidPlayer(victim))
            {
                if (War3_IsPlayerIncapped(victim))
                {
                    W3Hint(attacker, HINT_COOLDOWN_COUNTDOWN, 0.1, "This enemy is dead!", hp);
                    return;
                }
                if (GetClientTeam(victim) == GetClientTeam(attacker))
                {
                    return;
                }
            }
            W3Hint(attacker, HINT_COOLDOWN_COUNTDOWN, 0.1, "This enemy has %i HP", hp);
        }
        else
        {
            W3Hint(attacker, HINT_COOLDOWN_COUNTDOWN, 0.1, "This enemy is dead!", hp);
        }
    }
    
    if(War3_IsCommonInfected(victim) && ValidPlayer(attacker, true) && War3_GetOwnsItem(attacker, shopItem[GORE]) && (RoundToFloor(damage) > GetEntityHP(victim)) && (W3GetDamageType() & DMG_BULLET))
    {
        new Float:ClientVector[3];
        new Float:ZombieVector[3];
        
        new Float:DirectionVector[3];
        
        GetClientEyePosition(attacker, ClientVector);
        GetEntPropVector(victim, Prop_Send, "m_vecOrigin", ZombieVector);
        
        ZombieVector[2] += 65.0;
        
        SubtractVectors(ZombieVector, ClientVector, DirectionVector);
        NormalizeVector(DirectionVector, DirectionVector);
        
        ScaleVector(DirectionVector, 12000.0);
        
        SetEntPropVector(victim, Prop_Send, "m_gibbedLimbForce", DirectionVector);
        SetEntProp(victim, Prop_Send, "m_iRequestedWound1", 24);
    }
}

public OnWar3Event(W3EVENT:event, client)
{
    if(event == CanBuyItem)
    {
        new itemID = W3GetVar(EventArg1);
        if (itemID == shopItem[LASER])
        {
            new slot0 = GetPlayerWeaponSlot(client, 0);
                    
            if (IsValidEdict(slot0) && IsValidEntity(slot0))
            {
                new upgrades = L4D2_GetWeaponUpgrades(slot0);
                if (upgrades & L4D2_WEPUPGFLAG_LASER)
                {
                    W3SetVar(EventArg2, 0);
                    War3_ChatMessage(client, "You already have laser sights!");
                }
            }
            else
            {
                W3SetVar(EventArg2, 0);
                War3_ChatMessage(client, "You need a primary weapon for this upgrade!");
            }
        }
    }
}

public OnWar3EventDeath(victim, attacker)
{
    if (ValidPlayer(victim))
    {
        for(new x=0; x < MAXITEMS; x++)
        {
            if(War3_GetOwnsItem(victim, shopItem[x]))
            {
                War3_SetOwnsItem(victim, shopItem[x], false);
            }
        }
    }
    
    /*new Handle:event = W3GetVar(SmEvent);
    //if (War3_IsCommonInfected(victim) && War3_GetOwnsItem(attacker, shopItem[BIRTHDAY]) && GetEventBool(event, "headshot"))
    //{
        new Float:EffectPosition[3];
        new particle = AttachThrowAwayParticle(victim, "mini_fireworks", NULL_VECTOR, "head", 3.0);
        
        GetEntPropVector(particle, Prop_Send, "m_vecOrigin", EffectPosition);
        EffectPosition[2] -= 20;
        TeleportEntity(particle, EffectPosition, NULL_VECTOR, NULL_VECTOR);
        
        AcceptEntityInput(particle, "ClearParent");
        
        SetVariantString("head");
        AcceptEntityInput(particle, "SetParentAttachmentMaintainOffset", particle, particle, 0);
    //}
    */
}

public BulletImpactEvent(Handle:event, const String:name[], bool:dontBroadcast)
{
    new client = GetClientOfUserId(GetEventInt(event, "userid"));
    
    if (ValidPlayer(client, true) && War3_GetOwnsItem(client, shopItem[BEACON]))
    {
        new Float:x = GetEventFloat(event, "x");
        new Float:y = GetEventFloat(event, "y");
        new Float:z = GetEventFloat(event, "z");
        
        new Float:position[3] = {0.0, 0.0, 0.0};
        position[0] = x;
        position[1] = y;
        position[2] = z;
        
        ThrowAwayLightEmitter(position, "128 0 0 255", "0", 95.0, 0.10);
    }
}
