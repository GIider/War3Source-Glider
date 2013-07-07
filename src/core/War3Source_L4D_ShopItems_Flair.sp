#pragma semicolon 1

#include <sourcemod>
#include "W3SIncs/War3Source_Interface"
#include <sdktools>


enum{
    TRAIL=0,
}

#define PARTICLE_TRAIL                "spitter_slime_trail"

new shopItem[MAXITEMS];

public Plugin:myinfo = 
{
    name = "W3S - L4D - Shopitems",
    author = "Glider",
    description = "Yay shopitems",
};

public OnMapStart()
{
    War3_PrecacheParticle(PARTICLE_TRAIL);
}

public OnPluginStart()
{
    if(!GAMEL4DANY)
    {
        SetFailState("Only compatible with L4D");
    }

    CreateTimer(3.0, FlairTimer, _, TIMER_REPEAT);
}

public OnWar3LoadRaceOrItemOrdered(num)
{
    if(num==10) 
    {
        for(new x=0; x < MAXITEMS; x++)
            shopItem[x]=0;
        
        shopItem[TRAIL]=War3_CreateShopItem("Trail", "short_trail", "Gives you a trail", 10, 0);
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
}

public Action:FlairTimer(Handle:timer, any:userid)
{
    new Float:fParticlePos[3];
    
    for(new client=1; client <= MaxClients; client++)
    {
        if(ValidPlayer(client, true))
        {
            if (War3_GetOwnsItem(client, shopItem[TRAIL]))
            {
                GetClientAbsOrigin(client, fParticlePos);
                fParticlePos[2] += 35.0;
                
                AttachThrowAwayParticle(client, PARTICLE_TRAIL, fParticlePos, "", 2.5);
            }
        }
    }
}
