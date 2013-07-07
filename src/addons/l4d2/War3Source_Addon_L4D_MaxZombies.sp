#pragma semicolon 1

#include "W3SIncs/War3Source_Interface"
#include <sdkhooks>

public Plugin:myinfo = 
{
    name = "War3Source - Addon - L4D - Max Zombies",
    author = "Glider",
    description = "Force a max amount",
    version = "1.0",
};

new Handle:g_hMaxZombies = INVALID_HANDLE;
new g_iMaxZombiesAllowed = 50;
new g_iCurrentZombies;


public OnPluginStart()
{
    g_hMaxZombies = CreateConVar("war3_addon_max_zombies","50","Max amount of zombies allowed around");
    if (g_hMaxZombies != INVALID_HANDLE)
    {
        HookConVarChange(g_hMaxZombies, OnMaxZombiesChange);
    }
}

public OnMaxZombiesChange(Handle:cvar, const String:oldVal[], const String:newVal[])
{
    g_iMaxZombiesAllowed = StringToInt(newVal);
}

public OnMapStart()
{    
    if(GameL4DAny()){    
        HookEvent("round_end", RoundEndEvent);
        HookEvent("mission_lost", RoundEndEvent);
        
        g_iCurrentZombies = 0;
    }
}

public Action:RoundEndEvent(Handle:h_Event, const String:s_Name[], bool:b_DontBroadcast)
{
    g_iCurrentZombies = 0;
}

public OnEntityCreated(entity, const String:classname[])
{
    if (StrEqual(classname, "infected"))
    {
        g_iCurrentZombies++;
    
        if (g_iCurrentZombies > g_iMaxZombiesAllowed)
        {
            PrintToServer("Too many zombies around! Preventing spawn.");
            
            new ref = EntIndexToEntRef(entity);
            CreateTimer(0.1, DelayedKillTimer, ref);
        }
    }
}

public Action:DelayedKillTimer(Handle:timer, any:ref)
{
    new iEntity = EntRefToEntIndex(ref);
    if(iEntity > 0 && IsValidEntity(iEntity) && IsValidEdict(iEntity))
        AcceptEntityInput(iEntity, "kill");
    
}

public OnEntityDestroyed(entity)
{
    if (War3_IsCommonInfected(entity) && g_iCurrentZombies > 0)
    {
        g_iCurrentZombies--;
    }
}