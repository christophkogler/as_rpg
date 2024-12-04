/*
Alien Swarm: Reactive drop PluGin, A.K.A., AS:RPG
    -   Persistent!

    -   New varieties of enemies? Various HL2 mobs should be available - IE antlion, combine and zombie varieties.
        -   Few combines, enemies that shoot back SUCK in Alien Swarm, UNLESS I can make them and the swarm hostile to each other.
    -   Minibosses - enemies with effects, auras, increased health/speed/damage.
    -   Earn experience by killing enemies. Harder / rarer enemies give more experience.
        -   Hold your experience to level up (increase stats like max hp, move speed, minor damage and resistance boosts).
        -   Spend it to get skills (boost damage / gain resistances / regenerate ammo )
    -   Spend experience on leveling up (increase max hp, boost damage and resistances a small amount) or getting skills (boost damage / gain resistances / regenerate ammo / bigger magazines / more reloads)



    -   Damage boost goes forever, resistances cap at 99%, minimum damage to marines is 1. Even at 99%, getting hit 100 times by drones = die.
*/

#include <sourcemod>
#include <sdkhooks>
#include <dbi>

public Plugin myinfo = {
    name = "Kill Counter",
    author = "Your Name",
    description = "Counts your kills.",
    version = "1.0",
    url = "http://yourwebsite.com"
};

// Define weapon damage increases?

// Database configuration name (as defined in databases.cfg)
#define DATABASE_CONFIG "default"

// Global database handle
Database g_hDatabase = null;

// Mapping from client index to marine entity index
int g_ClientToMarine[MAXPLAYERS + 1];

// Accumulated kills per client
int g_ClientKillAccum[MAXPLAYERS + 1];

// Plugin entry point
public void OnPluginStart()
{
    PrintToServer("[Kill Counter] Initializing Kill Counter!");

    // Initialize arrays
    for (int i = 0; i <= MaxClients; i++)
    {
        g_ClientToMarine[i] = -1;
        g_ClientKillAccum[i] = 0;
    }

    ConnectToDatabase();

    // Hook events
    HookEvent("alien_died", OnAlienKilled);
    HookEvent("entity_killed", OnEntityKilled);
    HookEvent("player_shoot", OnPlayerShoot);

    HookEvent("game_start", Event_GameStart);
    HookEvent("player_connect", Event_PlayerConnect);
    HookEvent("player_disconnect", Event_PlayerDisconnect);

    // Register client console command
    RegConsoleCmd("sm_killcount", Command_KillCount);
    
    // Make timers for updating client-marine mapping and database
    CreateTimer(30.0, Timer_UpdateMapping, _, TIMER_REPEAT);
    CreateTimer(30.0, Timer_UpdateDatabase, _, TIMER_REPEAT);
}

// Plugin unload point
public void OnPluginEnd()
{
    // Update the database one last time
    UpdateDatabase();

    if (g_hDatabase != null)
    {
        delete g_hDatabase;
        g_hDatabase = null;
    }
}

// SDKHooks provides the 'OnEntityCreated' forward.
// We hook every entities OnTakeDamage at creation because it is simple and efficient. We want to alter weapon damage values; weapons should hit everything by an equally altered amount.
public OnEntityCreated(int entity, const char[] classname){    SDKHook(entity, SDKHook_OnTakeDamage, OnTakeDamage);    }

// Connect to the database
public void ConnectToDatabase()
{
    char error[255];

    g_hDatabase = SQL_Connect(DATABASE_CONFIG, true, error, sizeof(error));

    if (g_hDatabase == null)
    {
        PrintToServer("[Kill Counter] Could not connect: %s", error);
    }
    else
    {
        PrintToServer("[Kill Counter] Connected to database!");
        CreateKillCountTable();
    }
}

// Create necessary database tables
public void CreateKillCountTable()
{
    char sQuery[512];

    // Create player_kills table
    Format(sQuery, sizeof(sQuery), "CREATE TABLE IF NOT EXISTS `player_kills` ( `steam_id` VARCHAR(32) NOT NULL, `kills` INT NOT NULL DEFAULT 0, PRIMARY KEY (`steam_id`) )");

    Handle hQuery = SQL_Query(g_hDatabase, sQuery);

    if (hQuery == null)
    {
        PrintToServer("[Kill Counter] Failed to create or verify player_kills table!");
    }
    else
    {
        PrintToServer("[Kill Counter] player_kills table is ready.");
        delete hQuery;
    }
}

// Event when a player connects
public void Event_PlayerConnect(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (client > 0)
    {
        OnClientPutInServer(client);
        UpdateClientMarineMapping();
    }
}

// Event when a player disconnects
public void Event_PlayerDisconnect(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (client > 0)
    {
        // update DB BEFORE updating mapping, or else we may get kill counts confused / lose kills
        // updating DB also flushes the accumulators which means we don't have to worry about the client-accumulator relations possibly changing after disconnect
        UpdateDatabase(); 
        UpdateClientMarineMapping();
    }
}


// Event when a game starts
public void Event_GameStart(Event event, const char[] name, bool dontBroadcast)
{
    PrintToServer("[Kill Counter] Game started! Updating client-marine mapping!");
    UpdateClientMarineMapping();
}

// When a client is put in the server
public void OnClientPutInServer(int client)
{
    // Get player's Steam ID
    char sSteamID[32];
    GetClientAuthId(client, AuthId_Steam2, sSteamID, sizeof(sSteamID));

    // Retrieve player's kill count
    GetPlayerKillCount(sSteamID, client, true);
}


public Action OnPlayerShoot(Event event, const char[] name, bool dontBroadcast)
{
    int userID = event.GetInt("userid");
    int weaponID = event.GetInt("weapon");

    PrintToServer("User %d shot weapon %d.", userID, weaponID)

    // Alter weapon damage by a multiplier; switch based on name? Might just be a bunch of if's, gross.
    // Also, if altering weapon damage, set a flag.

    // If weapon damage altered flag is true, return Plugin_Changed.

    return Plugin_Continue;
}


public Action OnTakeDamage(victim, &attacker, &inflictor, &Float:damage, &damagetype){
    decl String:sWeapon[64];
    decl String:sAttackerClass[64];
    decl String:sInflictorClass[64];

    // Get class names for debugging
    GetEntityClassname(attacker, sAttackerClass, sizeof(sAttackerClass));
    GetEntityClassname(inflictor, sInflictorClass, sizeof(sInflictorClass));

    int weapon = -1;

    // Check if the attacker is valid
    if (IsValidEntity(attacker)){
        // safely try to retrieve the weapon
        if(HasEntProp(attacker, Prop_Send, "m_hActiveASWWeapon")){
            // Try to get the active weapon using m_hActiveASWWeapon
            PrintToServer("Found an m_hActiveASWWeapon!");
            weapon = GetEntPropEnt(attacker, Prop_Send, "m_hActiveASWWeapon");
        }

        // If not found, try m_hActiveWeapon
        if (!IsValidEntity(weapon) && HasEntProp(attacker, Prop_Send, "m_hActiveWeapon")){
            PrintToServer("Found an m_hActiveWeapon!");
            weapon = GetEntPropEnt(attacker, Prop_Send, "m_hActiveWeapon");
        }

        // If weapon is valid, get its classname
        if (IsValidEntity(weapon)){
            GetEntityClassname(weapon, sWeapon, sizeof(sWeapon));
        }
        else{
            // Weapon not found
            strcopy(sWeapon, sizeof(sWeapon), "UnknownWeapon");
        }
    }
    else{
        // Attacker is not valid
        strcopy(sWeapon, sizeof(sWeapon), "NoAttacker");
    }

    // Debug output
    PrintToServer("OnTakeDamage: victim %d, attacker %d (%s), inflictor %d (%s), weapon %s, damage %f, damagetype %d",
        victim, attacker, sAttackerClass, inflictor, sInflictorClass, sWeapon, damage, damagetype);

    /*
    // Example of modifying damage based on weapon
    if damagetype is 128
        // THEN WE ARE MELEEING
    else

        if (StrEqual(sWeapon, "asw_weapon_rifle"))
        {
            damage *= 1.5; // Increase damage by 50% for rifles
            return Plugin_Changed;
        }
        else if (StrEqual(sWeapon, "asw_weapon_pistol"))
        {
            damage *= 0.8; // Decrease damage by 20% for pistols
            return Plugin_Changed;
        }
    */

    return Plugin_Continue;
}

// Hook for when an alien is killed
public void OnAlienKilled(Event event, const char[] name, bool dontBroadcast)
{
    //int killedAlienClassify = event.GetInt("alien");
    int marineEntityIndex = event.GetInt("marine");
    //int killingWeaponClassify = event.GetInt("marine");

    int client = -1;
    for (int i = 1; i <= MaxClients; i++)
    {
        if (g_ClientToMarine[i] == marineEntityIndex)
        {
            client = i;
            break;
        }
    }

    // if the marine that killed the alien has a matching client, increment that client's kill accumulator
    if (client != -1){    g_ClientKillAccum[client]++;    }
}

// Hook for when any entity is killed
public void OnEntityKilled(Event event, const char[] name, bool dontBroadcast)
{
    int entindex_killed = event.GetInt("entindex_killed");

    if (IsValidEntity(entindex_killed))
    {
        char className[256];
        GetEntityClassname(entindex_killed, className, sizeof(className));

        char modelName[256];
        GetEntPropString(entindex_killed, Prop_Data, "m_ModelName", modelName, sizeof(modelName));

        PrintToServer("Entity killed: index %d, classname '%s', model name '%s'", entindex_killed, className, modelName);
    }
}

// Timer to refresh the map of client IDs to marine entities periodically
public Action Timer_UpdateMapping(Handle timer)
{
    UpdateClientMarineMapping();
    return Plugin_Continue;
}

// Update the mapping of clients to marines
public void UpdateClientMarineMapping()
{
    PrintToServer("[Kill Counter] Updating client-marine mapping!");
    int marineEntityIDs[MAXPLAYERS + 1];
    int marineCount = 0;

    // Get all marine entities
    int maxEntities = GetMaxEntities();
    for (int i = 0; i < maxEntities; i++)
    {
        if (IsValidEntity(i))
        {
            char className[256];
            GetEntityClassname(i, className, sizeof(className));

            //PrintToServer("Entity %d was a %s", i, className);

            if (StrEqual(className, "asw_marine"))
            {
                marineEntityIDs[marineCount++] = i;
                PrintToServer("[Kill Counter] Found marine %d, entity ID %d.", marineCount, i);
            }
        }
    }

    // Sort marineEntityIDs by entity ID
    SortIntegers(marineEntityIDs, marineCount);

    // Map clients to marines
    int clientIndex = 0;
    for (int client = 1; client <= MaxClients; client++)
    {
        if (IsClientInGame(client))
        {
            if (clientIndex < marineCount)
            {
                PrintToServer("[Kill Counter] Client %d was assigned marine entity [%d] %d", client, clientIndex, marineEntityIDs[clientIndex])
                g_ClientToMarine[client] = marineEntityIDs[clientIndex];
                clientIndex++;
            }
            else
            {
                PrintToServer("[Kill Counter] Too many clients for marines. Client %d not assigned to a marine!", client)
                g_ClientToMarine[client] = -1; // No marine assigned
            }
        }
        else
        {
            PrintToServer("[Kill Counter] Client %d not in game!", client)
            g_ClientToMarine[client] = -1;
        }
    }
}


// DATABASE CALLERS BELOW THIS LINE :)

// Timer to update the database with accumulated kills
public Action Timer_UpdateDatabase(Handle timer)
{
    UpdateDatabase();
    return Plugin_Continue;
}

// Update the database with accumulated kills
public void UpdateDatabase()
{
    PrintToServer("[Kill Counter] Updating database!");
    char sSteamID[32];
    char sQuery[512];

    for (int client = 1; client <= MaxClients; client++)
    {
        if (g_ClientKillAccum[client] > 0 && IsClientInGame(client))
        {
            GetClientAuthId(client, AuthId_Steam2, sSteamID, sizeof(sSteamID));

            PrintToServer("[Kill Counter] Adding %d to client %d's total.", g_ClientKillAccum[client], client);

            // Use accumulated kills to update the database
            Format(sQuery, sizeof(sQuery),
                "INSERT INTO player_kills (steam_id, kills) VALUES ('%s', %d) ON DUPLICATE KEY UPDATE kills = kills + %d",
                sSteamID, g_ClientKillAccum[client], g_ClientKillAccum[client]);

            Handle hQuery = SQL_Query(g_hDatabase, sQuery);

            if (hQuery != null){    delete hQuery;  }
            else{   PrintToServer("[Kill Counter] Failed to update kill count for player %s", sSteamID);   }

            // Reset the accumulated kills for the client
            g_ClientKillAccum[client] = 0;
        }
    }
}

// Retrieve and optionally display player's kill count
public void GetPlayerKillCount(const char[] sSteamID, int client, bool bNotify)
{
    char sQuery[256];

    Format(sQuery, sizeof(sQuery), "SELECT kills FROM player_kills WHERE steam_id = '%s'", sSteamID);

    Handle hQuery = SQL_Query(g_hDatabase, sQuery);

    int playerKills = 0;
    bool hasKills = false;

    if (hQuery == null)
    {
        PrintToServer("[Kill Counter] Failed to retrieve kill count for player %s", sSteamID);
    }
    else
    {
        if (SQL_FetchRow(hQuery))
        {
            playerKills = SQL_FetchInt(hQuery, 0);
            hasKills = true;
        }
        delete hQuery;
    }

    if (bNotify)
    {
        if (hasKills)
        {
            PrintToChat(client, "Welcome back! Your total kills: %d", playerKills);
        }
        else
        {
            PrintToChat(client, "Welcome! Let's start counting your kills!");
        }
    }
}

// Client console command to display kill count
public Action Command_KillCount(int client, int args){
    if (client <= 0 || !IsClientInGame(client)){    return Plugin_Handled;    }

    // Get player's Steam ID
    char sSteamID[32];
    GetClientAuthId(client, AuthId_Steam2, sSteamID, sizeof(sSteamID));

    // Retrieve and display player's kill count
    GetPlayerKillCount(sSteamID, client, false);

    // Fetch player's kill count
    char sQuery[256];
    Format(sQuery, sizeof(sQuery), "SELECT kills FROM player_kills WHERE steam_id = '%s'", sSteamID);

    Handle hQuery = SQL_Query(g_hDatabase, sQuery);

    int playerKills = 0;
    bool hasKills = false;

    if (hQuery != null){
        if (SQL_FetchRow(hQuery)){
            playerKills = SQL_FetchInt(hQuery, 0);
            hasKills = true;
        }
        delete hQuery;
    }

    // Add any accumulated kills not yet saved to the database
    playerKills += g_ClientKillAccum[client];

    if (hasKills || g_ClientKillAccum[client] > 0){
        PrintToChat(client, "Your total kills: %d", playerKills);
    }
    else{
        PrintToChat(client, "You have no recorded kills yet.");
    }

    return Plugin_Handled;
}
