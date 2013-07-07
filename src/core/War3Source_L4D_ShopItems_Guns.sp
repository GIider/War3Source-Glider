#pragma semicolon 1

#include "W3SIncs/War3Source_Interface"


enum{
    PISTOL=0,
    MAGNUM,
    PUMPSHOTTY,
    CHROMESHOTGUN,
    AUTOSHOTTY,
    AUTOSHOTTY_SPAS,
    SMG,
    SMG_SILENCED,
    MP5,
    M4,
    AK,
    SCAR,
    SG552,
    HUNTING,
    SNIPER_MILITARY,
    SNIPER_AWP,
    SNIPER_SCOUT,
    GRENADELAUNCHER,
    M60
}

new shopItem[MAXITEMS];

public Plugin:myinfo = 
{
    name = "W3S - L4D - Shopitems - Guns",
    author = "Glider",
    description = "Yay shopitems",
};


public OnPluginStart()
{
    if(!GAMEL4DANY)
    {
        SetFailState("Only compatible with the left4dead games");
    }
}

public OnWar3LoadRaceOrItemOrdered(num)
{
    if(num == 11) 
    {
        shopItem[PISTOL]=War3_CreateShopItem("Pistol", "short_pistol", "The regular Pistol", 10, 0);
        shopItem[MAGNUM]=War3_CreateShopItem("Magnum", "short_magnum", "The Magnum", 25, 0);
        shopItem[PUMPSHOTTY]=War3_CreateShopItem("Shotgun", "short_shotgun", "The regular Shotgun", 25, 0);
        shopItem[SMG]=War3_CreateShopItem("SMG", "short_smg", "The regular SMG", 25, 0);
        shopItem[SMG_SILENCED]=War3_CreateShopItem("Silenced SMG", "short_ss", "The regular Silenced SMG", 25, 0);
        shopItem[MP5]=War3_CreateShopItem("MP5", "short_mp5", "The regular MP5", 25, 0);
        shopItem[CHROMESHOTGUN]=War3_CreateShopItem("Chrome Shotgun", "short_shotc", "The regular Shotgun", 25, 0);
        shopItem[AUTOSHOTTY]=War3_CreateShopItem("Autoshotgun", "short_as", "The regular Autoshotgun", 50, 0);
        shopItem[AUTOSHOTTY_SPAS]=War3_CreateShopItem("SPAS Shotgun", "short_spas", "The regular SPAS Shotgun", 50, 0);
        shopItem[M4]=War3_CreateShopItem("M4", "short_m4", "The regular M4", 50, 0);
        shopItem[AK]=War3_CreateShopItem("AK47", "short_ak47", "The regular AK47", 50, 0);
        shopItem[SCAR]=War3_CreateShopItem("SCAR", "short_scar", "The regular SCAR", 50, 0);
        shopItem[SCAR]=War3_CreateShopItem("SG552", "short_sg552", "The regular SG552", 50, 0);
        shopItem[HUNTING]=War3_CreateShopItem("Hunting Rifle", "short_hr", "The regular Hunting Rifle", 50, 0);
        shopItem[SNIPER_MILITARY]=War3_CreateShopItem("Military Sniper", "short_ms", "The regular Military Sniper", 50, 0);
        shopItem[SNIPER_SCOUT]=War3_CreateShopItem("Scout Sniper", "short_scout", "The regular Scout Sniper", 50, 0);
        shopItem[SNIPER_AWP]=War3_CreateShopItem("AWP Sniper", "short_awp", "The regular AWP Sniper", 50, 0);
        shopItem[GRENADELAUNCHER]=War3_CreateShopItem("Grenade Launcher", "short_gl", "The regular Grenade Launcher", 50, 0);
        shopItem[M60]=War3_CreateShopItem("M60", "short_m60", "The regular M60", 100, 0);
    }    
}

public OnItemPurchase(client, item)
{
    if(item == shopItem[PISTOL])
    {
        Do_SpawnItem(client, "pistol");
        War3_SetOwnsItem(client, item, false);
    }
    else if(item == shopItem[MAGNUM])
    {
        Do_SpawnItem(client, "pistol_magnum");
        War3_SetOwnsItem(client, item, false);
    }
    else if(item == shopItem[PUMPSHOTTY])
    {
        Do_SpawnItem(client, "pumpshotgun");
        War3_SetOwnsItem(client, item, false);
    }
    else if(item == shopItem[CHROMESHOTGUN])
    {
        Do_SpawnItem(client, "shotgun_chrome");
        War3_SetOwnsItem(client, item, false);
    }
    else if(item == shopItem[AUTOSHOTTY])
    {
        Do_SpawnItem(client, "autoshotgun");
        War3_SetOwnsItem(client, item, false);
    }
    else if(item == shopItem[AUTOSHOTTY_SPAS])
    {
        Do_SpawnItem(client, "shotgun_spas");
        War3_SetOwnsItem(client, item, false);
    }
    else if(item == shopItem[SMG])
    {
        Do_SpawnItem(client, "smg");
        War3_SetOwnsItem(client, item, false);
    }
    else if(item == shopItem[SMG_SILENCED])
    {
        Do_SpawnItem(client, "smg_sileneced");
        War3_SetOwnsItem(client, item, false);
    }
    else if(item == shopItem[M4])
    {
        Do_SpawnItem(client, "rifle");
        War3_SetOwnsItem(client, item, false);
    }
    else if(item == shopItem[AK])
    {
        Do_SpawnItem(client, "rifle_ak47");
        War3_SetOwnsItem(client, item, false);
    }
    else if(item == shopItem[SCAR])
    {
        Do_SpawnItem(client, "rifle_desert");
        War3_SetOwnsItem(client, item, false);
    }
    else if(item == shopItem[HUNTING])
    {
        Do_SpawnItem(client, "hunting_rifle");
        War3_SetOwnsItem(client, item, false);
    }
    else if(item == shopItem[SNIPER_MILITARY])
    {
        Do_SpawnItem(client, "sniper_military");
        War3_SetOwnsItem(client, item, false);
    }
    else if(item == shopItem[GRENADELAUNCHER])
    {
        Do_SpawnItem(client, "grenade_launcher");
        War3_SetOwnsItem(client, item, false);
    }
    else if(item == shopItem[M60])
    {
        Do_SpawnItem(client, "rifle_m60");
        War3_SetOwnsItem(client, item, false);
    }
    else if(item == shopItem[SG552])
    {
        Do_SpawnItem(client, "rifle_sg552");
        War3_SetOwnsItem(client, item, false);
    }
    else if(item == shopItem[MP5])
    {
        Do_SpawnItem(client, "smg_mp5");
        War3_SetOwnsItem(client, item, false);
    }
    else if(item == shopItem[SNIPER_SCOUT])
    {
        Do_SpawnItem(client, "sniper_scout");
        War3_SetOwnsItem(client, item, false);
    }
    else if(item == shopItem[SNIPER_AWP])
    {
        Do_SpawnItem(client, "sniper_awp");
        War3_SetOwnsItem(client, item, false);
    }
}

Do_SpawnItem(client, const String:type[])
{
    if(ValidPlayer(client, true))
    {
        StripAndExecuteClientCommand(client, "give", type);
    }
}

StripAndExecuteClientCommand(client, const String:command[], const String:arguments[]) 
{
    new flags = GetCommandFlags(command);
    SetCommandFlags(command, flags & ~FCVAR_CHEAT);
    FakeClientCommand(client, "%s %s", command, arguments);
    SetCommandFlags(command, flags);
}