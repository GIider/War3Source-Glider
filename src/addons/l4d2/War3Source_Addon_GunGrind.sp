#pragma semicolon 1

#include "W3SIncs/War3Source_Interface"

public Plugin:myinfo = 
{
    name = "War3Source - Addon - GunGrind",
    author = "Glider",
    description = "Grind till you drop",
    version = "1.0",
};

//=======================================================================
//                             VARIABLES
//=======================================================================

#define MAX_DMG_BUFF 2.0

new Handle:h_DB = INVALID_HANDLE; // The handle to our database

/* A trie structure to store the experience each player has. This should
 * be much better since we have 21 unique columns we need to store for
 * each player.
*/
new Handle:h_PlayerExperience[MAXPLAYERS + 1] = INVALID_HANDLE;
/* List of entitys we leveled from
 */
new Handle:g_hASPDLimiterArray[MAXPLAYERS + 1] = INVALID_HANDLE;

//=======================================================================
//                             Handle Events
//=======================================================================

// Why the fuck do we do this? We have a fixed amount of tries, how much
// extra space could possibly go to waste if we don't do this?

// I might have considered something along the lines of players taking over
// the last clients xp or some shit like that, so I set it to invalid_handle
// so it forces the thing to retrieve the data of the new player.

// When a client disconnects delete his trie values so they don't
// stick around. 
public OnClientDisconnect(client) 
{
    if (h_PlayerExperience[client] != INVALID_HANDLE)
    {
        SaveStuff(client);
        ClearTrie(h_PlayerExperience[client]);
        
        //PrintToChatAll("Somebodys Trie has been reset");
        //h_PlayerExperience[client] = INVALID_HANDLE;
        //PrintToServer("[GUNGRIND DEBUG] Making somebodys trie invalid!");
    }
}

public Action:SayCommand(client, args)
{
    decl String:arg1[70];
    GetCmdArg(1,arg1,sizeof(arg1));
    
    if(StrEqual(arg1, "gungrind"))
    {
        new Handle:playerTrie = h_PlayerExperience[client];
        if ( playerTrie != INVALID_HANDLE )
        {
            new String:name[64];
            GetClientWeapon(client, name, sizeof(name));
            
            decl String:group[64] = "";
            if (TransformGunToGroup(name, group, sizeof(group)))
            {
                War3_ChatMessage(client, "%s:", group);
                
                decl String:column[64] = "";
                if (StrEqual(name, "weapon_melee"))
                {
                    new aspd;
                    
                    column = "";
                    StrCat(column, sizeof(column), group);
                    StrCat(column, sizeof(column), "_ASPD");
                    
                    GetTrieValue(playerTrie, column, aspd);
                    
                    new Float: dmgbuff = (getDamageBuff(client) - 1.0) * 100;
                    
                    War3_ChatMessage(client, "DMG: %f %%", dmgbuff);
                    //War3_ChatMessage(client, "ASPD: %i", aspd);
                }
                else
                {
                    new aspd;
                    new reload;
                    
                    column = "";
                    StrCat(column, sizeof(column), group);
                    StrCat(column, sizeof(column), "_ASPD");
                    
                    GetTrieValue(playerTrie, column, aspd);
                    
                    column = "";
                    StrCat(column, sizeof(column), group);
                    StrCat(column, sizeof(column), "_RELOAD");
                    
                    GetTrieValue(playerTrie, column, reload);
                    
                    new Float: dmgbuff = (getDamageBuff(client) - 1.0) * 100;
                                        
                    War3_ChatMessage(client, "DMG: %f %%", dmgbuff);
                    //War3_ChatMessage(client, "ASPD: %i", aspd);
                    //War3_ChatMessage(client, "RELOAD: %i", reload);
                }
            }
            else
            {
                War3_ChatMessage(client, "This weapon does not level. Sorry :(");
            }
        }
        else
        {
            War3_ChatMessage(client, "Invalid handle");
        }
    }
    return Plugin_Continue;
}

//=======================================================================
//                             INITIALIZE
//=======================================================================

public OnMapStart()
{
    for(new i = 1; i <= MAXPLAYERS; i++) {
        ClearArray(g_hASPDLimiterArray[i]);
    }
}

public Action:Event_RoundEnd(Handle:event, const String:name[], bool:dontBroadcast)
{
    for(new i = 1; i <= MAXPLAYERS; i++) {
        ClearArray(g_hASPDLimiterArray[i]);
    }
}

public OnPluginStart()
{    
    if(War3_GetGame() != Game_L4D && War3_GetGame() != Game_L4D2)
        SetFailState("Only works in the L4D engine! %i", War3_GetGame());
    
    RegConsoleCmd("say", SayCommand);
    RegConsoleCmd("say_team", SayCommand);

    HookEvent("weapon_reload", Event_Reload);
    
    CreateTimer(30.0, AutoSaveTimer, _, TIMER_REPEAT);
    
    for(new i=1; i <= MAXPLAYERS; i++) {
        g_hASPDLimiterArray[i] = CreateArray();
    }
    
    HookEvent("round_end", Event_RoundEnd);
}

// We wait for War3Source to hook the DB for us so we can use it :)
public OnWar3Event(W3EVENT:event, client)
{
    if(event == DatabaseConnected)
    {
        h_DB = W3GetVar(hDatabase);
        Initialize_SQLTable();
    }
}

// We initialize our table; If it doesn't exist we create it!
Initialize_SQLTable()
{
    new len = 0;
    decl String:query[2000];
    len += Format(query[len], sizeof(query)-len, "CREATE TABLE IF NOT EXISTS `war3_addon_gungrind` (");
    len += Format(query[len], sizeof(query)-len, "`steamid` VARCHAR(64) UNIQUE,");

    len += Format(query[len], sizeof(query)-len, "`SMG_RELOAD` INT DEFAULT '0',");
    len += Format(query[len], sizeof(query)-len, "`SMG_DMG` INT DEFAULT '0',");
    len += Format(query[len], sizeof(query)-len, "`SMG_ASPD` INT DEFAULT '0',");
    len += Format(query[len], sizeof(query)-len, "`SHOTGUN_RELOAD` INT DEFAULT '0',");
    len += Format(query[len], sizeof(query)-len, "`SHOTGUN_DMG` INT DEFAULT '0',");
    len += Format(query[len], sizeof(query)-len, "`SHOTGUN_ASPD` INT DEFAULT '0',");
    len += Format(query[len], sizeof(query)-len, "`PISTOLS_RELOAD` INT DEFAULT '0',");
    len += Format(query[len], sizeof(query)-len, "`PISTOLS_DMG` INT DEFAULT '0',");
    len += Format(query[len], sizeof(query)-len, "`PISTOLS_ASPD` INT DEFAULT '0',");
    len += Format(query[len], sizeof(query)-len, "`MELEE_DMG` INT DEFAULT '0',");
    len += Format(query[len], sizeof(query)-len, "`MELEE_ASPD` INT DEFAULT '0',");
    len += Format(query[len], sizeof(query)-len, "`ASSAULTRIFLE_RELOAD` INT DEFAULT '0',");
    len += Format(query[len], sizeof(query)-len, "`ASSAULTRIFLE_DMG` INT DEFAULT '0',");
    len += Format(query[len], sizeof(query)-len, "`ASSAULTRIFLE_ASPD` INT DEFAULT '0',");
    len += Format(query[len], sizeof(query)-len, "`AUTOSHOTGUN_RELOAD` INT DEFAULT '0',");
    len += Format(query[len], sizeof(query)-len, "`AUTOSHOTGUN_DMG` INT DEFAULT '0',");
    len += Format(query[len], sizeof(query)-len, "`AUTOSHOTGUN_ASPD` INT DEFAULT '0',");
    len += Format(query[len], sizeof(query)-len, "`SNIPER_RELOAD` INT DEFAULT '0',");
    len += Format(query[len], sizeof(query)-len, "`SNIPER_DMG` INT DEFAULT '0',");
    len += Format(query[len], sizeof(query)-len, "`SNIPER_ASPD` INT DEFAULT '0',");

    len += Format(query[len], sizeof(query)-len, "PRIMARY KEY  (`steamid`)");
    len += Format(query[len], sizeof(query)-len, ");");
    //len += Format(query[len], sizeof(query)-len, ") ENGINE=MyISAM DEFAULT CHARSET=utf8;");
    
    // Non threaded query, so lock the DB.
    SQL_LockDatabase(h_DB);
    if (!SQL_FastQuery(h_DB, query))
    {
        decl String:error[2000];
        SQL_GetError(h_DB, error, sizeof(error));
        PrintToServer(error);
    }
    SQL_UnlockDatabase(h_DB);
    
    LogMessage("[GunGrind] Table created!");
}


//=======================================================================
//                         CLIENT CONFIGURATION
//=======================================================================

// A client has connected. Check if he is in our database!
public OnClientPutInServer(client)
{
    if(!IsFakeClient(client))
    {
        loadPlayerData(client);
    }
}

loadPlayerData(client)
{
    decl String:steamid[64];
    if (GetClientAuthString(client, steamid, sizeof(steamid)))
    {
        War3_ChatMessage(client, "Loading your !gungrind data");
        
        new String:longquery[4000];
        Format(longquery, sizeof(longquery), "SELECT SMG_RELOAD, SMG_DMG, SMG_ASPD, SHOTGUN_RELOAD, SHOTGUN_DMG, SHOTGUN_ASPD, PISTOLS_RELOAD, PISTOLS_DMG, PISTOLS_ASPD, MELEE_DMG, MELEE_ASPD, ASSAULTRIFLE_RELOAD, ASSAULTRIFLE_DMG, ASSAULTRIFLE_ASPD, AUTOSHOTGUN_RELOAD, AUTOSHOTGUN_DMG,AUTOSHOTGUN_ASPD, SNIPER_RELOAD, SNIPER_DMG, SNIPER_ASPD FROM war3_addon_gungrind WHERE steamid='%s'", steamid);
                
        SQL_TQuery(h_DB, T_CallbackLoadPlayerData, longquery, client);
    }
}

//=======================================================================
//                             SAVING TO DB
//=======================================================================

public Action:AutoSaveTimer(Handle:timer, any:userid)
{
    for(new client=1; client <= MaxClients; client++)
    {
        SaveStuff(client);
    }
}

SaveStuff(client)
{
    decl String:steamid[64];
    if(ValidPlayer(client) && !IsFakeClient(client) && (h_DB != INVALID_HANDLE) && GetClientAuthString(client, steamid, sizeof(steamid)))
    {
        new Handle:playerTrie = h_PlayerExperience[client];
        if (playerTrie != INVALID_HANDLE)
        {
            //War3_ChatMessage(client, "[Gungrind] Autosaving...");
            new len = 0;
            decl String:query[4000];
            len += Format(query[len], sizeof(query)-len, "UPDATE war3_addon_gungrind SET ");
            
            len += Format(query[len], sizeof(query)-len, "SMG_RELOAD = %i, ", getKeyValue(playerTrie, "SMG_RELOAD"));
            len += Format(query[len], sizeof(query)-len, "SMG_DMG = %i, ", getKeyValue(playerTrie, "SMG_DMG"));
            len += Format(query[len], sizeof(query)-len, "SMG_ASPD = %i, ", getKeyValue(playerTrie, "SMG_ASPD"));
            len += Format(query[len], sizeof(query)-len, "SHOTGUN_RELOAD = %i, ", getKeyValue(playerTrie, "SHOTGUN_RELOAD"));
            len += Format(query[len], sizeof(query)-len, "SHOTGUN_DMG = %i, ", getKeyValue(playerTrie, "SHOTGUN_DMG"));
            len += Format(query[len], sizeof(query)-len, "SHOTGUN_ASPD = %i, ", getKeyValue(playerTrie, "SHOTGUN_ASPD"));
            len += Format(query[len], sizeof(query)-len, "PISTOLS_RELOAD = %i, ", getKeyValue(playerTrie, "PISTOLS_RELOAD"));
            len += Format(query[len], sizeof(query)-len, "PISTOLS_DMG = %i, ", getKeyValue(playerTrie, "PISTOLS_DMG"));
            len += Format(query[len], sizeof(query)-len, "PISTOLS_ASPD = %i, ", getKeyValue(playerTrie, "PISTOLS_ASPD"));
            len += Format(query[len], sizeof(query)-len, "MELEE_DMG = %i, ", getKeyValue(playerTrie, "MELEE_DMG"));
            len += Format(query[len], sizeof(query)-len, "MELEE_ASPD = %i, ", getKeyValue(playerTrie, "MELEE_ASPD"));
            len += Format(query[len], sizeof(query)-len, "ASSAULTRIFLE_RELOAD = %i, ", getKeyValue(playerTrie, "ASSAULTRIFLE_RELOAD"));
            len += Format(query[len], sizeof(query)-len, "ASSAULTRIFLE_DMG = %i, ", getKeyValue(playerTrie, "ASSAULTRIFLE_DMG"));
            len += Format(query[len], sizeof(query)-len, "ASSAULTRIFLE_ASPD = %i, ", getKeyValue(playerTrie, "ASSAULTRIFLE_ASPD"));
            len += Format(query[len], sizeof(query)-len, "AUTOSHOTGUN_RELOAD = %i, ", getKeyValue(playerTrie, "AUTOSHOTGUN_RELOAD"));
            len += Format(query[len], sizeof(query)-len, "AUTOSHOTGUN_DMG = %i, ", getKeyValue(playerTrie, "AUTOSHOTGUN_DMG"));
            len += Format(query[len], sizeof(query)-len, "AUTOSHOTGUN_ASPD = %i, ", getKeyValue(playerTrie, "AUTOSHOTGUN_ASPD"));
            len += Format(query[len], sizeof(query)-len, "SNIPER_RELOAD = %i, ", getKeyValue(playerTrie, "SNIPER_RELOAD"));
            len += Format(query[len], sizeof(query)-len, "SNIPER_DMG = %i, ", getKeyValue(playerTrie, "SNIPER_DMG"));
            len += Format(query[len], sizeof(query)-len, "SNIPER_ASPD = %i ", getKeyValue(playerTrie, "SNIPER_ASPD"));

            len += Format(query[len], sizeof(query)-len, "WHERE steamid = '%s'", steamid);
                    
            SQL_TQuery(h_DB, T_CallbackSavePlayer, query, client);
        }
        else
        {
            War3_ChatMessage(client, "[GunGrind] Your handle broke - Your XP is fucked!");
            loadPlayerData(client);
        }
    }
}

//=======================================================================
//                             INCREASE THE TRIE VALUES
//=======================================================================

public Event_Reload(Handle:event, const String:name[], bool:dontBroadcast)
{
    new client = GetClientOfUserId(GetEventInt(event,"userid"));
    
    new iWeapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
    new String:weaponname[64];
    GetEdictClassname(iWeapon, weaponname, sizeof(weaponname));

    AddExperience(client, weaponname, "RELOAD", 1);
}

public OnW3TakeDmgAllPre(victim, attacker, Float:damage)
{
    new inflictor = W3GetDamageInflictor();
            
    if (((War3_IsL4DZombieEntity(victim)) || (ValidPlayer(victim) && GetClientTeam(victim) == TEAM_INFECTED)) && 
        ValidPlayer(attacker, true) && GetClientTeam(attacker) == TEAM_SURVIVORS)
    {
        decl String:className[64];
        GetEdictClassname(inflictor, className, sizeof(className));
        
        if ( (attacker == inflictor) || StrEqual(className, "weapon_melee") )
        {
            new hp = GetEntProp(victim, Prop_Data, "m_iHealth");
            
            if (hp > 0)
            {
                new String:name[64];
                GetClientWeapon(attacker, name, sizeof(name));
                
                War3_DamageModPercent(getDamageBuff(attacker));

                // Only add the real damage dealt while it was alive...
                AddExperience(attacker, name, "DMG", Min(RoundToCeil(damage), hp));
                
                new foundindex = FindValueInArray(g_hASPDLimiterArray[attacker], victim);
                if(foundindex < 0) 
                {
                    AddExperience(attacker, name, "ASPD", 1);
                    PushArrayCell(g_hASPDLimiterArray[attacker], victim);
                    
                    new Handle:h_Pack;
    
                    CreateDataTimer(0.1, ResetFromASPD, h_Pack);
                    WritePackCell(h_Pack, attacker);
                    WritePackCell(h_Pack, victim);
                }
            }
        }
    }
}

Min(x, y)
{
    if (x > y)
        return y;
    
    return x;
}

public Action:ResetFromASPD(Handle:timer, Handle:h_Pack)
{
    new attacker, victim;

    ResetPack(h_Pack);
    attacker = ReadPackCell(h_Pack);
    victim = ReadPackCell(h_Pack);

    new foundindex = FindValueInArray(g_hASPDLimiterArray[attacker], victim);
    if(foundindex >= 0) {
        RemoveFromArray(g_hASPDLimiterArray[attacker], foundindex);
    }
}

//=======================================================================
//                             CALLBACKS
//=======================================================================

/* These are the callbacks for the db operations. If anything should fail,
 * then it will come up here
 */

public T_CallbackSavePlayer(Handle:owner,Handle:hndl,const String:error[],any:client)
{
    SQLCheckForErrors(hndl, error, "T_CallbackSavePlayer");
}

public T_CallbackInsertNewPlayer(Handle:owner, Handle:query, const String:error[], any:client)
{
    SQLCheckForErrors(query, error,"T_CallbackInsertNewPlayer");
    
    
    new Handle:playerTrie = h_PlayerExperience[client];
    if ( playerTrie != INVALID_HANDLE )
    {
        SetTrieValue(playerTrie, "SMG_RELOAD", 0);
        SetTrieValue(playerTrie, "SMG_DMG", 0);
        SetTrieValue(playerTrie, "SMG_ASPD", 0);
        SetTrieValue(playerTrie, "SHOTGUN_RELOAD", 0);
        SetTrieValue(playerTrie, "SHOTGUN_DMG", 0);
        SetTrieValue(playerTrie, "SHOTGUN_ASPD", 0);
        SetTrieValue(playerTrie, "PISTOLS_RELOAD", 0);
        SetTrieValue(playerTrie, "PISTOLS_DMG", 0);
        SetTrieValue(playerTrie, "PISTOLS_ASPD", 0);
        SetTrieValue(playerTrie, "MELEE_DMG", 0);
        SetTrieValue(playerTrie, "MELEE_ASPD", 0);
        SetTrieValue(playerTrie, "ASSAULTRIFLE_RELOAD", 0);
        SetTrieValue(playerTrie, "ASSAULTRIFLE_DMG", 0);
        SetTrieValue(playerTrie, "ASSAULTRIFLE_ASPD", 0);
        SetTrieValue(playerTrie, "AUTOSHOTGUN_RELOAD", 0);
        SetTrieValue(playerTrie, "AUTOSHOTGUN_DMG", 0);
        SetTrieValue(playerTrie, "AUTOSHOTGUN_ASPD", 0);
        SetTrieValue(playerTrie, "SNIPER_RELOAD", 0);
        SetTrieValue(playerTrie, "SNIPER_DMG", 0);
        SetTrieValue(playerTrie, "SNIPER_ASPD", 0);
        
        War3_ChatMessage(client, "[GunGrind] Profile created!");
    }
    else
    {
        War3_ChatMessage(client, "[GunGrind] Error when creating your profile");
    }
}

public T_CallbackUpdateKillAmount(Handle:owner, Handle:query, const String:error[], any:client)
{
    SQLCheckForErrors(query, error, "T_CallbackUpdateKillAmount");
}

public T_CallbackLoadPlayerData(Handle:owner,Handle:hndl,const String:error[],any:client)
{
    //PrintToChatAll("[GunGrind] LOADING PLAYER DATA");
    SQLCheckForErrors(hndl, error, "T_CallbackLoadPlayerData");
    
    // Not even valid? Bah, why bother then. Probably crashed/left or something
    if( !ValidPlayer(client) )
        return;
    
    if(hndl == INVALID_HANDLE)
    {
        LogError("[GunGrind] Invalid DB.");
    }
    else
    {
        // Player doesn't have a trie yet? Make one then!
        new Handle:playerTrie = h_PlayerExperience[client];
        if ( playerTrie == INVALID_HANDLE )
        {
            playerTrie = CreateTrie();
            h_PlayerExperience[client] = playerTrie;
        }
        
        // Old player returning
        if(SQL_GetRowCount(hndl) == 1)
        {
            SQL_Rewind(hndl);
            if (SQL_FetchRow(hndl))
            {    
                War3_ChatMessage(client, "[GunGrind] Loading old data...");
                SetTrieValue(playerTrie, "SMG_RELOAD", W3SQLPlayerInt(hndl, "SMG_RELOAD"));
                SetTrieValue(playerTrie, "SMG_DMG", W3SQLPlayerInt(hndl, "SMG_DMG"));
                SetTrieValue(playerTrie, "SMG_ASPD", W3SQLPlayerInt(hndl, "SMG_ASPD"));
                SetTrieValue(playerTrie, "SHOTGUN_RELOAD", W3SQLPlayerInt(hndl, "SHOTGUN_RELOAD"));
                SetTrieValue(playerTrie, "SHOTGUN_DMG", W3SQLPlayerInt(hndl, "SHOTGUN_DMG"));
                SetTrieValue(playerTrie, "SHOTGUN_ASPD", W3SQLPlayerInt(hndl, "SHOTGUN_ASPD"));
                SetTrieValue(playerTrie, "PISTOLS_RELOAD", W3SQLPlayerInt(hndl, "PISTOLS_RELOAD"));
                SetTrieValue(playerTrie, "PISTOLS_DMG", W3SQLPlayerInt(hndl, "PISTOLS_DMG"));
                SetTrieValue(playerTrie, "PISTOLS_ASPD", W3SQLPlayerInt(hndl, "PISTOLS_ASPD"));
                SetTrieValue(playerTrie, "MELEE_DMG", W3SQLPlayerInt(hndl, "MELEE_DMG"));
                SetTrieValue(playerTrie, "MELEE_ASPD", W3SQLPlayerInt(hndl, "MELEE_ASPD"));
                SetTrieValue(playerTrie, "ASSAULTRIFLE_RELOAD", W3SQLPlayerInt(hndl, "ASSAULTRIFLE_RELOAD"));
                SetTrieValue(playerTrie, "ASSAULTRIFLE_DMG", W3SQLPlayerInt(hndl, "ASSAULTRIFLE_DMG"));
                SetTrieValue(playerTrie, "ASSAULTRIFLE_ASPD", W3SQLPlayerInt(hndl, "ASSAULTRIFLE_ASPD"));
                SetTrieValue(playerTrie, "AUTOSHOTGUN_RELOAD", W3SQLPlayerInt(hndl, "AUTOSHOTGUN_RELOAD"));
                SetTrieValue(playerTrie, "AUTOSHOTGUN_DMG", W3SQLPlayerInt(hndl, "AUTOSHOTGUN_DMG"));
                SetTrieValue(playerTrie, "AUTOSHOTGUN_ASPD", W3SQLPlayerInt(hndl, "AUTOSHOTGUN_ASPD"));
                SetTrieValue(playerTrie, "SNIPER_RELOAD", W3SQLPlayerInt(hndl, "SNIPER_RELOAD"));
                SetTrieValue(playerTrie, "SNIPER_DMG", W3SQLPlayerInt(hndl, "SNIPER_DMG"));
                SetTrieValue(playerTrie, "SNIPER_ASPD", W3SQLPlayerInt(hndl, "SNIPER_ASPD"));
                War3_ChatMessage(client, "[GunGrind] Done!");
            }
        }
        // No rows returned?
        else if(SQL_GetRowCount(hndl) == 0)
        {
            //Not in database so add
            decl String:steamid[64];
            if(GetClientAuthString(client, steamid, sizeof(steamid)))
            {
                War3_ChatMessage(client, "[GunGrind] Creating a new gungrind profile for you..."); 
                                
                new String:longquery[500];
                Format(longquery, sizeof(longquery), "INSERT INTO war3_addon_gungrind (steamid) VALUES ('%s')", steamid);
                SQL_TQuery(h_DB, T_CallbackInsertNewPlayer, longquery, client);
            }
        }
        else if(SQL_GetRowCount(hndl) > 1)
        {
            // If you ever see this, something went horribly, horribly wrong.
            LogError("[GunGrind] Returned more than 1 record, primary or UNIQUE keys are screwed (main, rows: %d)", SQL_GetRowCount(hndl));
        }
    }
}

//=======================================================================
//                             VARIOUS STOCKS
//=======================================================================

/**
 * Gives you the group a passed gun belongs to
 * 
 * @param String:weapon[]: The weapon you need the group for
 * @param String:group[]: The string to store the group into
 * @param maxlength: The max length of the group string
 */
stock bool:TransformGunToGroup(const String:weapon[], String:group[], maxlength)
{
    if (StrEqual(weapon, "weapon_rifle", false) || StrEqual(weapon, "weapon_rifle_ak47", false) || StrEqual(weapon, "weapon_rifle_desert", false) || StrEqual(weapon, "weapon_rifle_sg552", false))
    {
        strcopy(group, maxlength, "ASSAULTRIFLE");
    }
    else if (StrEqual(weapon, "weapon_smg", false) || StrEqual(weapon, "weapon_smg_silenced", false) || StrEqual(weapon, "weapon_smg_mp5", false))
    {
        strcopy(group, maxlength, "SMG");
    }    
    else if (StrEqual(weapon, "weapon_pumpshotgun", false) || StrEqual(weapon, "weapon_shotgun_chrome", false))
    {
        strcopy(group, maxlength, "SHOTGUN");
    }
    else if (StrEqual(weapon, "weapon_autoshotgun", false) || StrEqual(weapon, "weapon_shotgun_spas", false))
    {
        strcopy(group, maxlength, "AUTOSHOTGUN");
    }
    else if (StrEqual(weapon, "weapon_hunting_rifle", false) || StrEqual(weapon, "weapon_sniper_military", false) || StrEqual(weapon, "weapon_sniper_awp", false) || StrEqual(weapon, "weapon_sniper_scout", false))
    {
        strcopy(group, maxlength, "SNIPER");
    }
    else if (StrEqual(weapon, "weapon_pistol") || StrEqual(weapon, "weapon_pistol_magnum"))
    {
        strcopy(group, maxlength, "PISTOLS");
    }
    else if (StrEqual(weapon, "weapon_melee"))
    {
        strcopy(group, maxlength, "MELEE");
    }
    else
    {
        //PrintToChatAll("UNKNOWN WEAPON: %s", weapon);
        return false;
    }
    
    return true;
}

getKeyValue(Handle:playerTrie, String:key[])
{
    new value = 0;
    GetTrieValue(playerTrie, key, value);
    
    return value;
}

AddExperience(client, const String:weapon[], const String:type[], amount=1)
{
    if (!IsFakeClient(client))
    {
        new Handle:playerTrie = h_PlayerExperience[client];
        if ( playerTrie != INVALID_HANDLE )
        {    
            decl String:column[64] = "";
            decl String:group[64] = "";
            
            if (TransformGunToGroup(weapon, group, sizeof(group)))
            {
                StrCat(column, sizeof(column), group);
                StrCat(column, sizeof(column), "_");
                StrCat(column, sizeof(column), type);
                
                //PrintToChatAll("Addding to column %s", column);
                
                new oldvalue;
                GetTrieValue(playerTrie, column, oldvalue);
                SetTrieValue(playerTrie, column, oldvalue + amount);
            }
        }
    }
}

//=======================================================================
//                             DAMAGE BUFF CALCULATION
//=======================================================================

Float:getDamageBuff(client)
{
    new Handle:playerTrie = h_PlayerExperience[client];
    if ( playerTrie != INVALID_HANDLE )
    {
        new dmg;
        new Float:dmgbuff;
        decl String:name[64];
        decl String:column[64] = "";
            
        GetClientWeapon(client, name, sizeof(name));
        
        decl String:group[64] = "";
        if (TransformGunToGroup(name, group, sizeof(group)))
        {
            StrCat(column, sizeof(column), group);
            StrCat(column, sizeof(column), "_DMG");
            
            GetTrieValue(playerTrie, column, dmg);
            
            dmgbuff = float(dmg) / 10000000.0;
            
            return FMin(1.0 + dmgbuff, MAX_DMG_BUFF);
        }
    }
    
    return 1.0;
}

Float:FMin(Float:x, Float:y)
{
    if(x < y)
        return x;
    else
        return y;
}