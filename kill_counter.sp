/*
Alien Swarm: Reactive drop PluGin, A.K.A., AS:RPG
    -   Persistent!

TO-DO:
    -   New varieties of enemies? Various HL2 mobs should be available - IE antlion, combine and zombie varieties.
        -   Few combines, enemies that shoot back SUCK in Alien Swarm, UNLESS I can make them and the swarm hostile to each other.
    -   Minibosses - enemies with effects, auras, increased health/speed/damage.
    -   Earn experience by killing enemies. Harder / rarer enemies give more experience.
        -   Hold your experience to level up (increase stats like max hp, move speed, minor damage and resistance boosts).
        -   Spend it to get skills (boost damage / gain resistances / regenerate ammo )
    -   Spend experience on leveling up (increase max hp, boost damage and resistances a small amount) or getting skills (boost damage / gain resistances / regenerate ammo / bigger magazines / more reloads)



    -   Damage boost goes forever, resistances cap at 99%, minimum damage to marines is 1(?). Even at 99%, getting hit 100 times by drones = die.
*/

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <dbi>
#include <swarmtools>

public Plugin myinfo = {
    name = "Alien Swarm: Reactive drop PluGin, A.K.A, AS:RPG",
    author = "Christoph Kogler",
    description = "Counts your kills. :(",
    version = "1.0.3",
    url = "https://github.com/christophkogler/as_rpg"
};


// ---------------------------- Definitions, global variables, and enums. ---------------------------------
// Database configuration name (as defined in databases.cfg)
#define DATABASE_CONFIG "default"

const float ExperienceSharingRate = 0.25; // 0 - inf. greather than 1 would be kind of dumb.

Database g_hDatabase = null; // Global database handle

// load all skills from database into a global data structure on plugin load
// more efficient to take up an extra 10mb of ram than hit a SQL server anytime somebody looks at the skill menu.
// same reason for the PlayerData array.

/**
 * @brief Struct to hold skill data.
 *
 * Contains experience points, level, skill points, and kill count for each player.
 */
enum struct SkillData {
    char skillName[64];
    char skillDescription[256];
    int skillLevel;
}
// how to make an array of appropriate size???
// how to define the size of a GLOBAL array from OnPluginStart???


int g_ClientToMarine[MAXPLAYERS + 1];
int g_ClientKillAccumulator[MAXPLAYERS + 1];
int g_ClientExperienceAccumulator[MAXPLAYERS + 1];

/**
 * @brief Struct to hold player-specific data.
 *
 * Contains experience points, level, skill points, and kill count for each player.
 */
enum struct PlayerData {
    int experience;
    int level;
    int skill_points;
    int kills;
    // how to hold skills of player, and their levels? basically a set of keyvals?
}
PlayerData g_PlayerData[MAXPLAYERS + 1];

/**
 * @brief Enumeration for identifying different table types during creation.
 *
 * Used to determine which table has been processed in the OnCreateTableFinished callback.
 */
enum TableType {
    TableType_Players = 1,
    TableType_Skills = 2,
    TableType_PlayerSkills = 3
};

/**
 * @brief Enumeration for identifying different skill types during initialization.
 *
 * Used to determine which skill has been processed in the OnInitializeSkillFinished callback.
 */
enum SkillType {
    SkillType_DamageBoost = 1,
    SkillType_HealthRegen = 2
};
// ----------------------------------------------------------------------------------------------------------





// ------------------------- Plugin utility functions. ----------------------------------------------------
/**
 * @brief Called when the plugin is started.
 *
 * Initializes kill counters, connects to the database, hooks events, registers console commands, and creates a timer for database updates.
 */
public void OnPluginStart()
{
    PrintToServer("[AS:RPG] Initializing Kill Counter!");

    LoadTranslations("menu_test.phrases");
    RegConsoleCmd("menu_test1", Menu_Test1);

    // Initialize arrays
    for (int i = 0; i <= MaxClients; i++)
    {
        g_ClientToMarine[i] = -1;
        g_ClientKillAccumulator[i] = 0;
        g_PlayerData[i].experience = 0;
        g_PlayerData[i].level = 1;
        g_PlayerData[i].skill_points = 0;
        g_PlayerData[i].kills = 0;
        //g_PlayerData[i].skills = new Dictionary;
    }

    ConnectToDatabase();

    HookEvent("alien_died", OnAlienKilled);
    HookEvent("entity_killed", OnEntityKilled);

    HookEvent("player_connect", Event_PlayerConnect);
    HookEvent("player_disconnect", Event_PlayerDisconnect);

    RegConsoleCmd("sm_killcount", Command_KillCount);
    RegAdminCmd("sm_spawnentity", Command_SpawnEntity, ADMFLAG_GENERIC);
    RegServerCmd("sm_difficultyscale", Command_DifficultyScale);

    RegServerCmd("sm_addskill", Command_AddSkill, "Adds a new skill to the database.");
    RegServerCmd("sm_listskills", Command_ListSkills, "Lists all skills in the database.");
    RegServerCmd("sm_deleteskill", Command_DeleteSkill, "Deletes a skill by name from the database.");

    CreateTimer(30.0, Timer_UpdateDatabase, _, TIMER_REPEAT);
}

/**
 * @brief Called when the plugin is unloaded.
 *
 * Updates the database one last time and cleans up the database handle.
 */
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
//--------------------------------------------------------------------------------------------





// ------------------------- Database interactions. ------------------------------
/**
 * @brief Initiates an asynchronous connection to the database.
 */
public void ConnectToDatabase(){
    SQL_TConnect(OnDatabaseConnected, DATABASE_CONFIG, 0);
}

/**
 * @brief Creates necessary database tables if they do not exist.
 *
 * Executes asynchronous SQL queries to ensure the required tables are present in the database.
 */
public void CreateTables(){
    SQL_TQuery(g_hDatabase, OnCreateTableFinished,
        "CREATE TABLE IF NOT EXISTS `players` (`steam_id` VARCHAR(32) NOT NULL PRIMARY KEY, `experience` INT NOT NULL DEFAULT 0, `level` INT NOT NULL DEFAULT 1, `skill_points` INT NOT NULL DEFAULT 0, `kills` INT NOT NULL DEFAULT 0);", 
        TableType_Players);

    SQL_TQuery(g_hDatabase, OnCreateTableFinished, 
        "CREATE TABLE IF NOT EXISTS `skills` ( `skill_id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY, `name` VARCHAR(64) NOT NULL, `description` TEXT, `max_level` INT NOT NULL DEFAULT 1);", 
        TableType_Skills);

    SQL_TQuery(g_hDatabase, OnCreateTableFinished, 
        "CREATE TABLE IF NOT EXISTS `player_skills` ( `steam_id` VARCHAR(32) NOT NULL, `skill_id` INT NOT NULL, `skill_level` INT NOT NULL DEFAULT 1, PRIMARY KEY (`steam_id`, `skill_id`), FOREIGN KEY (`steam_id`) REFERENCES `players`(`steam_id`) ON DELETE CASCADE, FOREIGN KEY (`skill_id`) REFERENCES `skills`(`skill_id`) ON DELETE CASCADE);", 
        TableType_PlayerSkills);
}

/**
 * @brief Initializes predefined skills in the database.
 *
 * Inserts skills like "Damage Boost" and "Health Regeneration" into the `skills` table.
 */
public void InitializeSkills(){
    SQL_TQuery(g_hDatabase, 
        OnInitializeSkillFinished, 
        "INSERT IGNORE INTO `skills` (`name`, `description`, `max_level`) VALUES ('Damage Boost', 'Increases your damage output.', 5);", 
        SkillType_DamageBoost);

    SQL_TQuery(g_hDatabase, 
        OnInitializeSkillFinished, 
        "INSERT IGNORE INTO `skills` (`name`, `description`, `max_level`) VALUES ('Health Regeneration', 'Regenerates your health over time.', 3);", 
        SkillType_HealthRegen);
}

/**
 * @brief Initiates an asynchronous query to retrieve a player's kill count.
 *
 * @param sSteamID The Steam ID of the player.
 * @param client The client index requesting the kill count.
 * @param bNotify Whether to send a notification to the player upon retrieval.
 * @return int Returns 0 as the result is handled asynchronously.
 */
public int GetPlayerKillCount(const char[] sSteamID, int client, bool bNotify) { 
    // Create a handle to store the context data
    Handle hContext = CreateArray(1); 
    PushArrayCell(hContext, view_as<int>(client)); // Pack client
    PushArrayCell(hContext, bNotify ? 1 : 0);     // Pack bNotify
    PushArrayString(hContext, sSteamID);          // Pack sSteamID

    char sQuery[256];
    Format(sQuery, sizeof(sQuery), "SELECT kills FROM player_kills WHERE steam_id = '%s'", sSteamID);
    PrintToServer("Client %d initialized database query for their kill count!", client);

    SQL_TQuery(g_hDatabase, OnGetPlayerKillCountFinished, sQuery, hContext);

    return 0;
}

/**
 * @brief Updates the database with accumulated kills and experience for each client.
 *
 * Iterates through all clients, updates their kill counts and experience in the database, and resets their accumulated counters.
 */
public void UpdateDatabase(){
    PrintToServer("[AS:RPG] Updating database with accumulated kills and experience.");
    char sSteamID[32];
    char sQuery[512];

    for (int client = 1; client <= MaxClients; client++){
        if (IsClientInGame(client)){
            GetClientAuthId(client, AuthId_Steam2, sSteamID, sizeof(sSteamID));

            // Update kills
            if (g_ClientKillAccumulator[client] > 0){
                Format(sQuery, sizeof(sQuery),
                    "INSERT INTO player_kills (steam_id, kills) VALUES ('%s', %d) ON DUPLICATE KEY UPDATE kills = kills + %d",
                    sSteamID, g_ClientKillAccumulator[client], g_ClientKillAccumulator[client]
                );

                // Pass client as 'data' to identify later
                SQL_TQuery(g_hDatabase, OnUpdateKillCountFinished, sQuery, client);
                g_ClientKillAccumulator[client] = 0; 
            }

            // Update experience
            if (g_ClientExperienceAccumulator[client] > 0){
                Format(sQuery, sizeof(sQuery),
                    "INSERT INTO players (steam_id, experience) VALUES ('%s', %d) ON DUPLICATE KEY UPDATE experience = experience + %d",
                    sSteamID, g_ClientExperienceAccumulator[client], g_ClientExperienceAccumulator[client]
                );
                SQL_TQuery(g_hDatabase, OnUpdateExperienceFinished, sQuery, client);
                g_ClientExperienceAccumulator[client] = 0;
            }
        }
    }
}


public void AddSkillToDatabase(char[] name, char[] description, int max_level){
    PrintToServer("[AS:RPG] Adding a skill to the database.");
    PrintToServer("[AS:RPG] %s, maximum level %d.\n%s", name, max_level, description);
    char sQuery[512];
    Format(sQuery, sizeof(sQuery), "INSERT INTO skills (name, description, max_level) VALUES ('%s', '%s', %d);",
           name, description, max_level);
    SQL_TQuery(g_hDatabase, OnCreateSkillFinished, sQuery);
}

public void DeleteSkillFromDatabase(char[] name){
    PrintToServer("[AS:RPG] Deleting the skill %s from the database.", name);
    char sQuery[512];
    Format(sQuery, sizeof(sQuery), "DELETE FROM skills WHERE name = '%s';", name);
    SQL_TQuery(g_hDatabase, OnDeleteSkillFinished, sQuery);
}

public void ListSkillsInDatabase(){
    PrintToServer("[AS:RPG] List all skills.");
    char sQuery[512];
    Format(sQuery, sizeof(sQuery), "SELECT * FROM skills;");
    SQL_TQuery(g_hDatabase, OnListSkillsFinished, sQuery);
}

//----------------------------------------------------------------------------------------------------------------



// --------------------------------------- Database callback functions. -----------------------------------------
/**
 * @brief Callback function invoked after attempting to connect to the database.
 *
 * Handles the result of the asynchronous database connection attempt.
 *
 * @param owner The parent handle (unused in this context).
 * @param hndl The handle to the database connection.
 * @param error An error message if the connection failed.
 * @param data Extra data passed during the connection attempt (unused here).
 */
public void OnDatabaseConnected(Handle owner, Handle hndl, const char[] error, any data){
    // check the state of the database's handle before it is passed off
    if (hndl == null || hndl == INVALID_HANDLE){
        PrintToServer("[AS:RPG] Could not connect to database: %s", error);
        return;
    }

    // handle is valid, so connect. cast the handle to a database.
    g_hDatabase = Database:hndl;
    PrintToServer("[AS:RPG] Connected to database!");

    CreateTables();
    InitializeSkills();
}

/**
 * @brief Callback function invoked after attempting to create a database table.
 *
 * Handles the result of the asynchronous table creation queries.
 *
 * @param owner The parent handle (unused in this context).
 * @param hndl The handle to the SQL query result.
 * @param error An error message if the table creation failed.
 * @param data An identifier indicating which table was processed.
 */
public void OnCreateTableFinished(Handle owner, Handle hndl, const char[] error, any data){
    int switcher = data;

    if (error[0] != '\0' || hndl == INVALID_HANDLE || hndl == null){
        PrintToServer("[AS:RPG] Failed to create/verify table type %d: %s", data, error);
        return;
    }

    switch (switcher)
    {
        case TableType_Players:
            PrintToServer("[AS:RPG] 'players' table is ready.");
        case TableType_Skills:
            PrintToServer("[AS:RPG] 'skills' table is ready.");
        case TableType_PlayerSkills:
            PrintToServer("[AS:RPG] 'player_skills' table is ready.");
    }
}

/**
 * @brief Callback function invoked after attempting to initialize a skill in the database.
 *
 * Handles the result of the asynchronous skill initialization queries.
 *
 * @param owner The parent handle (unused in this context).
 * @param hndl The handle to the SQL query result.
 * @param error An error message if the skill initialization failed.
 * @param data An identifier indicating which skill was processed.
 */
public void OnInitializeSkillFinished(Handle owner, Handle hndl, const char[] error, any data){
    int switcher = data;
    if (error[0] != '\0' || hndl == INVALID_HANDLE || hndl == null){
        switch (switcher){
            case SkillType_DamageBoost:
                PrintToServer("[AS:RPG] Failed to insert/verify 'Damage Boost' skill: %s", error);
            case SkillType_HealthRegen:
                PrintToServer("[AS:RPG] Failed to insert/verify 'Health Regeneration' skill: %s", error);
        }
        return;
    }

    switch (switcher){
        case SkillType_DamageBoost:
            PrintToServer("[AS:RPG] 'Damage Boost' skill is ready.");
        case SkillType_HealthRegen:
            PrintToServer("[AS:RPG] 'Health Regeneration' skill is ready.");
    }
}

/**
 * @brief Callback function invoked after attempting to retrieve a player's kill count.
 *
 * Handles the result of the asynchronous kill count retrieval query and optionally notifies the player.
 *
 * @param owner The parent handle (unused in this context).
 * @param hndl The handle to the SQL query result.
 * @param error An error message if the retrieval failed.
 * @param data A handle containing context information.
 */
public void OnGetPlayerKillCountFinished(Handle owner, Handle hndl, const char[] error, any data){
    // Unpack the context data
    Handle hContext = view_as<Handle>(data);

    int client = GetArrayCell(hContext, 0);
    bool bNotify = GetArrayCell(hContext, 1) == 1;
    char sSteamID[32];
    GetArrayString(hContext, 2, sSteamID, sizeof(sSteamID));

    CloseHandle(hContext); // Clean up handle after unpacking

    int playerKills = 0;
    bool hasKills = false;

    if (error[0] != '\0' || hndl == INVALID_HANDLE || hndl == null) {
        PrintToServer("[AS:RPG] Failed to retrieve kill count for player %s: %s", sSteamID, error);
    } else {
        if (SQL_FetchRow(hndl)) {
            playerKills = SQL_FetchInt(hndl, 0);
            hasKills = true;
        }
    }

    playerKills += g_ClientKillAccumulator[client];

    if (bNotify) {
        if (hasKills)
            PrintToChat(client, "Welcome back! Your total kills: %d", playerKills);
        else
            PrintToChat(client, "Welcome! Let's start counting your kills!");
    }
}

/**
 * @brief Callback function invoked after attempting to update a client's kill count.
 *
 * Handles the result of the asynchronous kill count update query.
 *
 * @param owner The parent handle (unused in this context).
 * @param hndl The handle to the SQL query result.
 * @param error An error message if the kill count update failed.
 * @param data The client index associated with this update.
 */
public void OnUpdateKillCountFinished(Handle owner, Handle hndl, const char[] error, any data){
    int client = data;
    char sSteamID[32];
    GetClientAuthId(client, AuthId_Steam2, sSteamID, sizeof(sSteamID));
    if (error[0] != '\0' || hndl == INVALID_HANDLE || hndl == null){
        PrintToServer("[AS:RPG] Failed to update kill count for player %s: %s", sSteamID, error);
    }
}

/**
 * @brief Callback function invoked after attempting to update a client's experience.
 *
 * Handles the result of the asynchronous experience update query.
 *
 * @param owner The parent handle (unused in this context).
 * @param hndl The handle to the SQL query result.
 * @param error An error message if the experience update failed.
 * @param data The client index associated with this update.
 */
public void OnUpdateExperienceFinished(Handle owner, Handle hndl, const char[] error, any data){
    int client = data;
    char sSteamID[32];
    GetClientAuthId(client, AuthId_Steam2, sSteamID, sizeof(sSteamID));
    if (error[0] != '\0' || hndl == INVALID_HANDLE || hndl == null){
        PrintToServer("[AS:RPG] Failed to update experience for player %s: %s", sSteamID, error);
    }
}

public void OnCreateSkillFinished(Handle owner, Handle hndl, const char[] error, any data){
    if (error[0] != '\0' || hndl == INVALID_HANDLE || hndl == null){
        PrintToServer("[AS:RPG] Failed to create skill! Error: %s", error);
    }
}

public void OnDeleteSkillFinished(Handle owner, Handle hndl, const char[] error, any data){
    if (error[0] != '\0' || hndl == INVALID_HANDLE || hndl == null){
        PrintToServer("[AS:RPG] Failed to delete skill! Error: %s", error);
    }
}

public void OnListSkillsFinished(Handle owner, Handle hndl, const char[] error, any data) {
    // Check if there was an error or if the handle is invalid
    if (error[0] != '\0' || hndl == INVALID_HANDLE || hndl == null) {    PrintToServer("[AS:RPG] Failed to get skills! Error: %s", error);    return;    }

    // Begin processing the result set
    PrintToServer("[AS:RPG] Skills list retrieved successfully:");
    int rowCount = 0;

    // Iterate through each row in the result set
    while (SQL_FetchRow(hndl)) {
        char skillName[64];
        char skillDescription[256];
        int skillLevel;

        // Retrieve the skill name and level from the current row
        SQL_FetchString(hndl, 0, skillName, sizeof(skillName));
        skillLevel = SQL_FetchInt(hndl, 1);

        // Print the skill information to the server console
        PrintToServer("[AS:RPG] Skill #%d: %s - max level %d - %s", ++rowCount, skillName, skillLevel, skillDescription);

        // refresh global stored skills
    }

    // Check if no rows were retrieved
    if (rowCount == 0) {    PrintToServer("[AS:RPG] No skills found in the database.");    }
}
// -----------------------------------------------------------------------------------------------------------





// -------------------------------------- In-game events. -------------------------------------------------------
/**
 * @brief Handles the player connect event.
 *
 * Retrieves the client index from the event and initializes their data in the server.
 *
 * @param event The event data.
 * @param name The name of the event.
 * @param dontBroadcast Whether to broadcast the event.
 */
public void Event_PlayerConnect(Event event, const char[] name, bool dontBroadcast){
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (client > 0){UpdateClientMarineMapping();}
}

/**
 * @brief Handles the player disconnect event.
 *
 * Updates the database and client-marine mapping when a player disconnects.
 *
 * @param event The event data.
 * @param name The name of the event.
 * @param dontBroadcast Whether to broadcast the event.
 */
public void Event_PlayerDisconnect(Event event, const char[] name, bool dontBroadcast){
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (client > 0){    UpdateDatabase();    UpdateClientMarineMapping();    }
}

/**
 * @brief Called when an entity is created in the game.
 *
 * Hooks the OnTakeDamage event for the entity and updates client-marine mapping if an ASW marine is created.
 *
 * @param entity The entity index of the created entity.
 * @param classname The classname of the created entity.
 */
public void OnEntityCreated(int entity, const char[] classname){    
    // I hook every entities OnTakeDamage at creation, because this makes the process simple.
    SDKHook(entity, SDKHook_OnTakeDamage, OnTakeDamage);

    /*
    float random = GetRandomFloat(0.0, 1.0);
    if (StrEqual(classname, "asw_drone") && Swarm_IsGameActive() && random < increasedSwarmSizeChance && currentSwarmSizeCounter <= maxSwarmSizeIncrease){
        currentSwarmSizeCounter++;
        PrintToServer("Spawn group size increased by %d", currentSwarmSizeCounter);
        float position[3];
        GetEntPropVector(entity, Prop_Send, "m_vecOrigin", position);    // get the location of the client's marine
        float angles[3] = {0.0, 0.0, 0.0}; // Default angles
        SpawnEntityByName("asw_drone", position, angles, "", 0.0, false);
    }
    currentSwarmSizeCounter = 0;
    */

    // If an asw_marine is created, update the mapping.
    if (StrEqual(classname, "asw_marine")){UpdateClientMarineMapping();}
}

/**
 * @brief Handles the event when an entity takes damage.
 *
 * Adjusts damage based on the victim and attacker classes and their attributes.
 *
 * @param victim The entity index of the victim.
 * @param attacker A reference to the entity index of the attacker.
 * @param inflictor A reference to the entity index of the inflictor.
 * @param damage A reference to the damage value.
 * @param damagetype A reference to the type of damage.
 * @return Action Whether the plugin has changed the damage value.
 */
public Action OnTakeDamage(victim, &attacker, &inflictor, &Float:damage, &damagetype){
    decl String:VictimClass[64];
    decl String:AttackerClass[64];
    decl String:InflictorClass[64];

    int attackerWeaponEntityID = -1;
    decl String:WeaponName[64];

    bool changedDamageValue = false;

    // make sure the victim and attacker are valid entities.
    if(!IsValidEntity(victim)){
        PrintToServer("[AS:RPG] [ERROR] Invalid entity took damage?");
        return Plugin_Continue;
    } 
    if(!IsValidEntity(attacker)){
        PrintToServer("[AS:RPG] [ERROR] Invalid entity dealt damage?");
        return Plugin_Continue;
    }
    
    // Get victim, attacker, and inflictor class names
    GetEntityClassname(victim, VictimClass, sizeof(VictimClass));
    GetEntityClassname(attacker, AttackerClass, sizeof(AttackerClass));
    GetEntityClassname(inflictor, InflictorClass, sizeof(InflictorClass));

    // if victim is a marine, we (will) need to apply player damage reduction stuff...
    if (StrEqual(VictimClass, "asw_marine")){
        // damage = CalculateMarineDamageReduction(victim, damage, damagetype)
        // changedDamageValue = true;
        if(damagetype != 4){
            PrintToServer("[AS:RPG] [DEBUGGING] A marine took a new type of damage: %d", damagetype);
        }
    } 
    // if the attacker is a marine, we (will) need to apply damage boosting stuff...
    else if(StrEqual(AttackerClass, "asw_marine")){    
        // safely try to retrieve the weapon the attacker is using; m_hActiveWeapon is normally right. try ASW active weapon if it isnt for some reason
        attackerWeaponEntityID = SafeGetEntPropEnt(attacker, Prop_Send, "m_hActiveWeapon");
        if(!IsValidEntity(attackerWeaponEntityID)){ attackerWeaponEntityID = SafeGetEntPropEnt(attacker, Prop_Send, "m_hASWActiveWeapon"); }

        // If weapon is valid, get its classname
        if (IsValidEntity(attackerWeaponEntityID)){    GetEntityClassname(attackerWeaponEntityID, WeaponName, sizeof(WeaponName));    }
        else{    strcopy(WeaponName, sizeof(WeaponName), "UnknownWeapon");    }
        
        // damage = CalculateMarineDamageBoost(attacker, damage, damagetype);
        // chandedDamageValue = true;

        if (StrEqual(WeaponName, "asw_weapon_prifle") || StrEqual(WeaponName, "asw_weapon_autogun")){
            if(damagetype == 128){
            // MELEE!
            // SPECIFICALLY clubbing with the weapon? make it scale differently based on weapon? MAYBE!
            // damage = CalculateMarineMeleeDamageBoost(attacker, damage, damagetype)
            }
            damage *= 2; // Increase damage by 15x for the prototype rifle and autogun.
            changedDamageValue = true;
        }
    }

    // Debug output
    //PrintToServer("[AS:RPG] [DEBUGGING] OnTakeDamage: victim %d (%s), attacker %d (%s), inflictor %d (%s), weapon %s, damage %f, damagetype %d", victim, VictimClass, attacker, AttackerClass, inflictor, InflictorClass, WeaponName, damage, damagetype);

    if(changedDamageValue){
        return Plugin_Changed;
    }else{
        return Plugin_Continue;
    }
}

/**
 * @brief Called when an alien is killed.
 *
 * Increments the kill counter for the corresponding client who killed the alien. Also, give them one extra bullet.
 *
 * @param event The event data.
 * @param name The name of the event.
 * @param dontBroadcast Whether to broadcast the event.
 */
public void OnAlienKilled(Event event, const char[] name, bool dontBroadcast){
    int client = -1;
    int marineEntityID = event.GetInt("marine");
    if (Swarm_IsGameActive()) client = Swarm_GetClientOfMarine(marineEntityID);
    if (client != -1){
        int attackerWeaponEntityID = -1;
        int weaponMaxAmmo = 0;
        int currentAmmo = 0;

        attackerWeaponEntityID = SafeGetEntPropEnt(marineEntityID, Prop_Send, "m_hActiveWeapon");
        if (attackerWeaponEntityID == -1){
            PrintToServer("[AS:RPG] Client %d's marine %d killed an alien without an active weapon?", client, marineEntityID);
        } 

        currentAmmo = SafeGetEntProp(marineEntityID, Prop_Send, "m_iAmmo");
        if (currentAmmo == -1){
            PrintToServer("[AS:RPG] Client %d's marine %d's weapon had no ammo, or -1.", client, marineEntityID);
        } 

        weaponMaxAmmo = SafeGetEntProp(attackerWeaponEntityID, Prop_Send, "m_iPrimaryAmmoCount");
        if (weaponMaxAmmo == -1){
            PrintToServer("[AS:RPG] Failed to get ammo count or -1 max ammo for client %d's marine %d's weapon entity %d.", client, marineEntityID, attackerWeaponEntityID);
        } 

        SetEntProp(marineEntityID, Prop_Send, "m_iAmmo", currentAmmo+1)

        g_ClientKillAccumulator[client]++;    
    }
}

/**
 * @brief Called when any entity is killed.
 *
 * Logs details about the killed entity and awards experience if applicable.
 *
 * @param event The event data.
 * @param name The name of the event.
 * @param dontBroadcast Whether to broadcast the event.
 */
public void OnEntityKilled(Event event, const char[] name, bool dontBroadcast){
    if (!Swarm_IsGameActive()) return;

    int entindex_killed = event.GetInt("entindex_killed");
    int entindex_attacker = event.GetInt("entindex_attacker");

    if (!IsValidEntity(entindex_killed) || !IsValidEntity(entindex_attacker)) return;    // Early return if invalid entities

    char victimClassname[256];
    GetEntityClassname(entindex_killed, victimClassname, sizeof(victimClassname));

    char modelName[256];
    GetEntPropString(entindex_killed, Prop_Data, "m_ModelName", modelName, sizeof(modelName));

    char attackerClassname[256];
    GetEntityClassname(entindex_attacker, attackerClassname, sizeof(attackerClassname));

    if (StrEqual(attackerClassname, "asw_marine")){    
        // Example: Determine experience based on victim class
        int experienceGained = GetExperienceForAlienClass(victimClassname);
        int client = Swarm_GetClientOfMarine(entindex_attacker);
        if (client != -1){
            g_ClientExperienceAccumulator[client] += experienceGained;
            g_ClientKillAccumulator[client]++;
            PrintToServer("[AS:RPG] Client %d killed %s and earned %d XP.", client, victimClassname, experienceGained);
        }
        // give other actively playing clients 25% the experience. You don't miss out (much!) when killing things as a group! 
        for(int otherClients = 0; otherClients < MaxClients; otherClients++){
            if(otherClients == client || g_ClientToMarine[otherClients] == -1 || !IsClientConnected(otherClients)) continue;
            g_ClientExperienceAccumulator[otherClients] += RoundToNearest( float(experienceGained) * ExperienceSharingRate);
        }
    }

    // Debug output
    PrintToServer("[AS:RPG] Entity killed: index %d, classname '%s', model name '%s'", entindex_killed, victimClassname, modelName);
}
//----------------------------------------------------------------------------------------------------------------



// ---------------------------------------------- Timers --------------------------------------------------------
// (only database update loop rn, but maybe active skill cooldowns one day?)
/**
 * @brief Timer callback to periodically update the database with accumulated kills.
 *
 * Invoked by a repeating timer to ensure kill data is regularly saved to the database.
 *
 * @param timer The handle to the timer.
 * @return Action Indicates whether the plugin should continue running the timer.
 */
public Action Timer_UpdateDatabase(Handle timer){
    UpdateDatabase();
    return Plugin_Continue;
}
// --------------------------------------------------------------------------------------------------------------



// ------------------------------------ Console commands. ------------------------------------------------------
/**
 * @brief Console command handler to display a player's kill count.
 *
 * Allows players to view their total kills via the `sm_killcount` command.
 *
 * @param client The client index who issued the command.
 * @param args The number of arguments passed with the command.
 * @return Action Indicates whether the plugin has handled the command.
 */
public Action Command_KillCount(int client, int args){
    if (client <= 0 || !IsClientInGame(client)) { return Plugin_Handled; }
    PrintToServer("Client %d attempting to get kill count!", client);
    char sSteamID[32];
    GetClientAuthId(client, AuthId_Steam2, sSteamID, sizeof(sSteamID));
    GetPlayerKillCount(sSteamID, client, true);
    return Plugin_Handled;
}

/**
 * @brief Console command handler to spawn entities.
 *
 * Allows admins to spawn entities on their marine using the `sm_spawnentity` command with specified parameters.
 *
 * @param client The client index who issued the command.
 * @param args The number of arguments passed with the command.
 * @return Action Indicates whether the plugin has handled the command.
 */
public Action Command_SpawnEntity(int client, int args) {
    if (args < 1) {
        ReplyToCommand(client, "Usage: sm_spawnentity <classname> <model> <random spawn range float>\n  ex: sm_spawnentity prop_physics models/props_c17/oildrum001.mdl 10.0    sm_spawnentity npc_headcrab 20.0    sm_spawnentity aws_drone 123.4");
        return Plugin_Handled;
    }

    char classname[64];
    GetCmdArg(1, classname, sizeof(classname));

    char model[64];
    GetCmdArg(1, classname, sizeof(classname));

    float position[3];
    GetEntPropVector(Swarm_GetMarine(client), Prop_Send, "m_vecOrigin", position);    // get the location of the client's marine

    float angles[3] = {0.0, 0.0, 0.0}; // Default angles

    SpawnEntityByName(classname, position, angles, model, 100.0, true);
    return Plugin_Handled;
}

/**
 * @brief Console command handler to adjust the game's difficulty.
 *
 * Allows the server to modify many game settings related to difficulty using the `sm_difficultyscale` command.
 *
 * @param client The client index who issued the command.
 * @param args The number of arguments passed with the command.
 * @return Action Indicates whether the plugin has handled the command.
 */
public Action Command_DifficultyScale(int args){
	if (args < 1) { 
		PrintToServer("Usage: sm_difficultyscale <0-n> (low values will be boring and high values will cause server instability - have fun!)"); 
		return Plugin_Handled;
	}

	float difficulty = 1.0;
	GetCmdArgFloatEx(1, difficulty);
    AdjustDifficultyConVars(difficulty)
    return Plugin_Handled;
}

// Command: sm_addskill <name> <description> <max_level>
public Action Command_AddSkill(int args){
    if (args != 3){
        PrintToServer("[AS:RPG] Usage: sm_addskill \"<name>\" \"<description>\" <max_level>");
        return Plugin_Handled;
    }

    char name[64], description[256];
    GetCmdArg(1, name, sizeof(name));
    GetCmdArg(2, description, sizeof(description));
    int max_level = GetCmdArgInt(3);

    AddSkillToDatabase(name, description, max_level);

    return Plugin_Handled;
}

public Action Command_DeleteSkill(int args){
    if (args != 1){
        PrintToServer("[AS:RPG] Usage: sm_deleteskill \"<name>\"");
        return Plugin_Handled;
    }

    char name[64];
    GetCmdArg(1, name, sizeof(name));

    DeleteSkillFromDatabase(name);

    return Plugin_Handled;
}

public Action Command_ListSkills(int args){
    if (args != 0){
        PrintToServer("[AS:RPG] Usage: sm_listskills");
        return Plugin_Handled;
    }
    ListSkillsInDatabase();
    return Plugin_Handled;
}
// ----------------------------------------------------------------------------------------------------------------



// -------------------------------------------------- Utility / helper functions. ------------------------------------
/**
 * @brief Spawns an entity by its classname at a specified position with optional model and range.
 *
 * Creates and positions an entity in the game world, optionally notifying the server.
 *
 * @param classname The classname of the entity to spawn.
 * @param position The base position vector where the entity should be created.
 * @param angles The orientation angles for the entity.
 * @param model The model path for the entity (optional).
 * @param range The random spawn range to offset the position.
 * @param bNotify Whether to notify the server about the spawned entity.
 */
public void SpawnEntityByName(const char[] classname, float position[3], const float angles[3], const char[] model, float range, bool bNotify) {
    // Create the entity by classname
    int entity = CreateEntityByName(classname);
    if (entity == -1) {
        PrintToServer("[AS:RPG] Failed to create entity of type %s", classname);
        return;
    }

    // Set a model for the entity, if provided
    if (model[0] != '\0') {
        DispatchKeyValue(entity, "model", model);
    }

    position[0] += GetRandomFloat(-range, range);
    position[1] += GetRandomFloat(-range, range);
    position[2] += GetRandomFloat(0.0, range); // Slightly smaller vertical variation

    // Set the entity's position and rotation
    TeleportEntity(entity, position, angles, NULL_VECTOR);

    // Finalize the entity creation
    DispatchSpawn(entity);

    // Optional: Print a message to confirm the entity was spawned
    if (bNotify) PrintToServer("[AS:RPG] Spawned entity of type %s at position %.2f, %.2f, %.2f", classname, position[0], position[1], position[2]);
}

/**
 * @brief Function to adjust the game's difficulty scale.
 *
 * Modifies many ConVars in an attempt to scale the difficulty.
 *
 * @param client The client index who issued the command.
 * @param args The number of arguments passed with the command.
 * @return Action Indicates whether the plugin has handled the command.
 */
void AdjustDifficultyConVars(float difficulty){
    // ???
    if(difficulty < 0.25) StripAndChangeServerConVarInt("ai_inhibit_spawners", 0);
    else StripAndChangeServerConVarInt("ai_inhibit_spawners", 1);

    // Scales the number of aliens each spawner will put out
    //if(difficulty >= 1) StripAndChangeServerConVarBool("asw_carnage", true);
    //else StripAndChangeServerConVarBool("asw_carnage", false);

    // the factor used to scale the amount of aliens in each drone spawner
    if(difficulty >= 1) StripAndChangeServerConVarFloat("rd_carnage_scale", difficulty);
    else StripAndChangeServerConVarFloat("rd_carnage_scale", 1.0);

    // Max time that director keeps spawning aliens when marine intensity has peaked
    StripAndChangeServerConVarFloat("asw_director_peak_max_time", 3.0 * difficulty);
    // Min time that director keeps spawning aliens when marine intensity has peaked
    StripAndChangeServerConVarFloat("asw_director_peak_min_time", 1.0 * difficulty);

    // Max time that director stops spawning aliens
    StripAndChangeServerConVarInt("asw_director_relaxed_max_time", RoundToNearest(40 / difficulty));
    // Min time that director stops spawning aliens
    StripAndChangeServerConVarInt("asw_director_relaxed_min_time", RoundToNearest(25 / difficulty));

    // If set, eggs will respawn the parasite inside
    if(difficulty >= 1.5) StripAndChangeServerConVarBool("asw_egg_respawn", true);
    else StripAndChangeServerConVarBool("asw_egg_respawn", false);

    // wtf is a harvester?
    // "asw_harverter_suppress_children" = "0" game cheat                               - If set to 1, harvesters won't spawn xenomites
    // "asw_harvester_max_critters" = "5" game cheat                                    - maximum critters the harvester can spawn
    // "asw_harvester_spawn_height" = "16" game cheat                                   - Height above harvester origin to spawn xenomites at
    // asw_harvester_spawn_interval" = "1.0" game cheat                                - Time between spawning a harvesite and starting to spawn another

    // Maximum distance away from the marines the horde can spawn
    StripAndChangeServerConVarInt("asw_horde_max_distance", RoundToNearest(1500 / difficulty));
    // Minimum distance away from the marines the horde can spawn
    StripAndChangeServerConVarInt("asw_horde_min_distance", RoundToNearest(800 / difficulty));

    // asw_horde_override" = "0" game replicated                                       - Forces hordes to spawn

    // Director: Max scale applied to alien spawn interval each spawn
    StripAndChangeServerConVarFloat("asw_interval_change_max", 0.95 / difficulty);
    // Director: Min scale applied to alien spawn interval each spawn
    StripAndChangeServerConVarFloat("asw_horde_min_distance", 0.9 / difficulty);

    // Director: Max time between alien spawns when first entering spawning state
    StripAndChangeServerConVarInt("asw_interval_initial_max", RoundToNearest(7 / difficulty));
    // Director: Min time between alien spawns when first entering spawning state
    StripAndChangeServerConVarInt("asw_interval_initial_min", RoundToNearest(5 / difficulty));

    // Director: Min time between alien spawns.
    StripAndChangeServerConVarFloat("asw_interval_min", 1 / difficulty);

    // Max number of aliens spawned in a horde batch
    StripAndChangeServerConVarInt("asw_max_alien_batch", RoundToNearest(10 * difficulty));

    // "asw_respawn_marine_enable" = "0" min. 0.000000 max. 1.000000 game cheat         - Enables respawning marines.
    
    // If there are more awake aliens than this number director will not spawn new hord
    StripAndChangeServerConVarInt("rd_director_max_awake_aliens_for_horde", RoundToNearest(25 * difficulty));
    // If there are more awake aliens than this number director will not spawn new wanderers
    StripAndChangeServerConVarInt("rd_director_max_awake_aliens_for_wanderers", RoundToNearest(20 * difficulty));

    // "rd_director_spawner_bias" = "0.9" min. 0.000000 max. 1.000000 game cheat        - 0 (search from the node) to 1 (search from the nearest marine)
    // "rd_director_spawner_range" = "600" game cheat                                   - Radius around expected spawn point that the director can look for spawners

    // If 0 hordes and wanderers cannot spawn in map exit zone. 1 by default
    if(difficulty < 0.75) StripAndChangeServerConVarBool("rd_horde_from_exit", false);
    else StripAndChangeServerConVarBool("rd_horde_from_exit", true);

    // "rd_horde_ignore_north_door" = "0" game cheat                                    - If 1 hordes can spawn behind sealed and locked doors to the north from marines.
    // "rd_horde_retry_on_fail" = "1" game cheat                                        - When set to 1 will retry to spawn horde from opposite direction if previous dire

    // If 1 all spawners will be set to infinitely spawn aliens
    if(difficulty > 2) StripAndChangeServerConVarBool("rd_infinite_spawners", true);
    else StripAndChangeServerConVarBool("rd_infinite_spawners", false);

    // Chance to spawn a zombine when a marine dies from an alien
    if(difficulty > 0.5) StripAndChangeServerConVarFloat("rd_marine_spawn_zombine_on_death_chance", 1.0);
    else StripAndChangeServerConVarFloat("rd_marine_spawn_zombine_on_death_chance", 0.0);
    
    // If 1 and Onslaught is enabled an npc_antlionguard will be prespawned somewhere on the map
    if(difficulty > 1.5) StripAndChangeServerConVarBool("rd_prespawn_antlionguard", true);
    else StripAndChangeServerConVarBool("rd_prespawn_antlionguard", false);
    
    // If 1 and Onslaught is enabled an npc_antlionguard will be prespawned somewhere on the map
    if(difficulty > 1.5) StripAndChangeServerConVarBool("rd_prespawn_scale", true);
    else StripAndChangeServerConVarBool("rd_prespawn_scale", false);

    // Num biomass to randomly spawn if rd_prespawn_scale 1
    StripAndChangeServerConVarInt("rm_prespawn_num_biomass", RoundToNearest(3.0 * difficulty));
    // Num aliens to randomly spawn if rd_prespawn_scale 1
    StripAndChangeServerConVarInt("rm_prespawn_num_boomers", RoundToNearest(3.0 * difficulty));
    StripAndChangeServerConVarInt("rm_prespawn_num_buzzers", RoundToNearest(1.0 * difficulty));
    StripAndChangeServerConVarInt("rm_prespawn_num_drones", RoundToNearest(15.0 * difficulty));
    StripAndChangeServerConVarInt("rm_prespawn_num_harvesters", RoundToNearest(4.0 * difficulty));
    StripAndChangeServerConVarInt("rm_prespawn_num_mortars", RoundToNearest(2.0 * difficulty));
    StripAndChangeServerConVarInt("rm_prespawn_num_parasites", RoundToNearest(7.0 * difficulty));
    StripAndChangeServerConVarInt("rm_prespawn_num_rangers", RoundToNearest(5.0 * difficulty));
    StripAndChangeServerConVarInt("rm_prespawn_num_shamans", RoundToNearest(5.0 * difficulty));
    StripAndChangeServerConVarInt("rm_prespawn_num_shieldbugs", RoundToNearest(1.0 * difficulty));
    StripAndChangeServerConVarInt("rm_prespawn_num_uber_drones", RoundToNearest(2.0 * difficulty));

    /*
    "rd_spawn_ammo" = "0" game cheat replicated                                      - Will spawn an ammo box from 51st killed alien if set to 51
    "rd_spawn_medkits" = "0" game cheat replicated                                   - Will spawn a med kit from 31st killed alien is set to 31
    */
}

/**
 * @brief Helper function to modify a server ConVar of type float without using sv_cheats.
 *
 * Strips the FCVAR_CHEAT flag, sets the new value, and restores the original flags.
 *
 * @param client The client index who initiated the change.
 * @param command The name of the ConVar to modify.
 * @param value The new float value to set.
 */
void StripAndChangeServerConVarFloat(String:command[], float value) {
    new ConVar:conVar = FindConVar(command);
    if (conVar == INVALID_HANDLE) {
        PrintToServer("ConVar '%s' not found or invalid.", command);
        return;
    }
    new flags = GetCommandFlags(command);
    SetCommandFlags(command, flags & ~FCVAR_CHEAT);
    SetConVarFloat(conVar, value, false, false);
    SetCommandFlags(command, flags);
	LogAction(0, -1, "[NOTICE]: (%L) set %s to %d", 0, command, value);		
}

/**
 * @brief Helper function to modify a server ConVar of type bool without using sv_cheats.
 *
 * Strips the FCVAR_CHEAT flag, sets the new value, and restores the original flags.
 *
 * @param client The client index who initiated the change.
 * @param command The name of the ConVar to modify.
 * @param value The new bool value to set.
 */
void StripAndChangeServerConVarBool(String:command[], bool value) {
    new ConVar:conVar = FindConVar(command);
    if (conVar == INVALID_HANDLE) {
        PrintToServer("ConVar '%s' not found or invalid.", command);
        return;
    }
    new flags = GetCommandFlags(command);
    SetCommandFlags(command, flags & ~FCVAR_CHEAT);
    SetConVarBool(conVar, value, false, false);
    SetCommandFlags(command, flags);
	LogAction(0, -1, "[NOTICE]: (%L) set %s to %d", 0, command, value);	
}

/**
 * @brief Helper function to modify a server ConVar of type int without using sv_cheats.
 *
 * Strips the FCVAR_CHEAT flag, sets the new value, and restores the original flags.
 *
 * @param client The client index who initiated the change.
 * @param command The name of the ConVar to modify.
 * @param value The new integer value to set.
 */
void StripAndChangeServerConVarInt(String:command[], int value) {
    new ConVar:conVar = FindConVar(command);
    if (conVar == INVALID_HANDLE) {
        PrintToServer("ConVar '%s' not found or invalid.", command);
        return;
    }
    new flags = GetCommandFlags(command);
    SetCommandFlags(command, flags & ~FCVAR_CHEAT);
    SetConVarInt(conVar, value, false, false);
    SetCommandFlags(command, flags);
	LogAction(0, -1, "[NOTICE]: (%L) set %s to %d", 0, command, value);	
}

/**
 * @brief Determines the experience points awarded based on the classname of the alien killed.
 *
 * @param victimClassname The classname string of the alien.
 * @return int The experience points awarded for the kill.
 */
int GetExperienceForAlienClass(const char[] victimClassname){
    if (StrEqual(victimClassname, "asw_drone")){            return 10;    }
    else if (StrEqual(victimClassname, "asw_boomer")){      return 15;    }
    else if (StrEqual(victimClassname, "asw_zombine")){     return 20;    }
    // Add more conditions as needed for different alien classes
    else{
        PrintToServer("[AS:RPG] GetExperienceForAlienClass() encountered Alien class %s without defined experience! Defaulting to 10.", victimClassname);
        return 10; // Default experience for unknown classes
    }
}

/**
 * @brief Updates the mapping of clients to their corresponding marine entities.
 *
 * Iterates through all clients and updates the global mapping to associate each client with their marine entity.
 */
public void UpdateClientMarineMapping(){
    PrintToServer("[AS:RPG] Updating client-marine mapping!");

    for (int client = 1; client <= MaxClients; client++){
        if (IsClientInGame(client) && Swarm_IsGameActive()){
            g_ClientToMarine[client] = Swarm_GetMarine(client)
            PrintToServer("[AS:RPG] Client %d got marine %d!", client, g_ClientToMarine[client])
        }
        else{
            PrintToServer("[AS:RPG] Client %d not in game!", client)
            g_ClientToMarine[client] = -1;
        }
    }
}

/**
 * @brief Safely retrieves an entity's property of entity type.
 *
 * Checks that the entity is valid and has the property before trying to get it.
 * 
 * @param entity The entity ID to retrieve the property from.
 * @param type The PropType to attempt to access.
 * @param property The string represting the property name.
 * @return Entity index, or -1 if invalid entity / nonexistent property.
 */
public int SafeGetEntPropEnt(int entity, PropType type, char[] property){
    if (IsValidEntity(entity) && HasEntProp(entity, type, property)){
        return GetEntPropEnt(entity, type, property);
    }
    else return -1;
}

/**
 * @brief Safely retrieves an entitie's property of generic type.
 *
 * Checks that the entity is valid and has the property before trying to get it.
 *
 * @param entity The entity ID to retrieve the property from.
 * @param type The PropType to attempt to access.
 * @param property The string represting the property name.
 * @return Property value, or -1 if invalid entity / nonexistent property.
 */
public int SafeGetEntProp(int entity, PropType type, char[] property){
    if (IsValidEntity(entity) && HasEntProp(entity, type, property)){
        return GetEntProp(entity, type, property);
    }
    else return -1;
}
// ----------------------------------------------------------------------------------------------------------------










// -------------------------------------- Menus ----------------------------------------------------

#define MAIN_MENU_VIEW_SKILLS "#view_skills"
#define BACKCHOICE "#back"
#define PURCHASECHOICE "#purchase"
#define REFUNDCHOICE "#refund"

/**
 * @brief Displays the main menu to the client.
 *
 * @param client The client index.
 */
public void ShowMainMenu(int client) {
    // Create a menu with a callback and actions
    Menu menu = CreateMenuEx(GetMenuStyleHandle(MenuStyle_Radio), MenuHandler1, MENU_ACTIONS_ALL);
    
    // Set the title of the menu
    menu.SetTitle("%T", "Main Menu Title", LANG_SERVER);
    
    // Add menu items
    menu.AddItem(MAIN_MENU_VIEW_SKILLS, "View Skills");
    menu.AddItem(BACKCHOICE, "Exit");
    
    // Enable the exit button
    menu.ExitButton = true;
    
    // Display the menu to the client indefinitely
    menu.Display(client, MENU_TIME_FOREVER);
}

/**
 * @brief Command to open the main menu.
 *
 * @param client The client index.
 * @param args The number of arguments.
 * @return Action Indicates the command was handled.
 */
public Action Menu_Test1(int client, int args) {
    ShowMainMenu(client);
    return Plugin_Handled;
}

/**
 * @brief Initiates fetching skills and displaying the skills menu.
 *
 * @param client The client index.
 */
public void FetchSkillsAndShowMenu(int client) {
    // Ensure client is valid
    if (client <= 0 || !IsClientInGame(client)) return;

    // Prepare SQL query to fetch all skills
    char query[256];
    Format(query, sizeof(query), "SELECT skill_id, name, description, max_level FROM skills");

    // Use client index as data for callback
    SQL_TQuery(g_hDatabase, OnFetchSkillsFinished, query, client);
}


/**
 * @brief Callback after fetching skills.
 *
 * Builds and displays the skills menu.
 *
 * @param owner The parent handle (unused).
 * @param hndl The handle to the SQL query result.
 * @param error An error message if the query failed.
 * @param data The client index.
 */
public void OnFetchSkillsFinished(Handle owner, Handle hndl, const char[] error, any data) {

    int client = data;

    // Handle errors
    if (hndl == INVALID_HANDLE || error[0] != '\0') {
        PrintToServer("[AS:RPG] Failed to fetch skills: %s", error);
        return;
    }

    // Create skills menu
    Menu skillMenu = CreateMenuEx(GetMenuStyleHandle(MenuStyle_Radio), SkillMenuHandler, MENU_ACTIONS_ALL);
    
    // Set the menu style to Radio
    skillMenu.Style
    
    skillMenu.SetTitle("Available Skills");

    // Add skills to the menu
    bool skillsFound = false; // Track if any skills are added
    while (SQL_FetchRow(hndl)) {
        skillsFound = true;

        int skillID = SQL_FetchInt(hndl, 0);
        char skillName[64], skillDescription[128];
        SQL_FetchString(hndl, 1, skillName, sizeof(skillName));
        SQL_FetchString(hndl, 2, skillDescription, sizeof(skillDescription));
        //int maxLevel = SQL_FetchInt(hndl, 3);

        // Store skill ID as menu item info
        char info[32];
        Format(info, sizeof(info), "%d", skillID);
        skillMenu.AddItem(info, skillName, ITEMDRAW_DEFAULT);
    }

    // If no skills found, inform the player
    if (!skillsFound) {
        skillMenu.AddItem(BACKCHOICE, "No skills available");
    }

    // Add back option
    skillMenu.AddItem(BACKCHOICE, "Back to Main Menu");
    skillMenu.ExitButton = true;

    // Display menu
    skillMenu.Display(client, MENU_TIME_FOREVER);
}

/**
 * @brief Initiates fetching the player's current skill level and displaying the skill detail submenu.
 *
 * @param client The client index.
 * @param skillID The selected skill's ID.
 */
public void FetchPlayerSkillLevel(int client, int skillID) {
    // Get player's Steam ID
    char sSteamID[32];
    GetClientAuthId(client, AuthId_Steam2, sSteamID, sizeof(sSteamID));

    // Prepare SQL query to fetch the player's current skill level
    char query[256];
    Format(query, sizeof(query), 
        "SELECT ps.skill_level, s.name, s.description, s.max_level FROM player_skills ps JOIN skills s ON ps.skill_id = s.skill_id WHERE ps.steam_id = '%s' AND ps.skill_id = %d", 
        sSteamID, skillID
    );

    // Create a context handle to pass client and skillID
    Handle hContext = CreateArray(2);
    PushArrayCell(hContext, client); // Client index
    PushArrayCell(hContext, skillID); // Skill ID

    // Execute the query with a callback
    SQL_TQuery(g_hDatabase, OnFetchPlayerSkillLevel, query, hContext);
}

/**
 * @brief Callback after fetching the player's current skill level.
 *
 * Builds and displays the skill detail submenu.
 *
 * @param owner The parent handle (unused).
 * @param hndl The handle to the SQL query result.
 * @param error An error message if the query failed.
 * @param data The context handle containing client index and skillID.
 */
public void OnFetchPlayerSkillLevel(Handle owner, Handle hndl, const char[] error, any data) {
    // Unpack context data
    Handle hContext = view_as<Handle>(data);
    int client = GetArrayCell(hContext, 0);
    int skillID = GetArrayCell(hContext, 1);
    CloseHandle(hContext); // Clean up

    // Handle errors
    if (hndl == INVALID_HANDLE || error[0] != '\0') {
        PrintToServer("[AS:RPG] Failed to fetch player skill level: %s", error);
        return;
    }

    // Initialize variables
    int currentLevel = 0;
    char skillName[64], skillDescription[128];
    int maxLevel = 1;

    // Check if the player has the skill
    if (SQL_FetchRow(hndl)) {
        currentLevel = SQL_FetchInt(hndl, 0);
        SQL_FetchString(hndl, 1, skillName, sizeof(skillName));
        SQL_FetchString(hndl, 2, skillDescription, sizeof(skillDescription));
        maxLevel = SQL_FetchInt(hndl, 3);
    } else {
        // Player does not have the skill yet
        // Fetch skill info from skills table
        char skillInfoQuery[256];
        Format(skillInfoQuery, sizeof(skillInfoQuery), 
            "SELECT name, description, max_level FROM skills WHERE skill_id = %d", 
            skillID
        );

        // Create a new context with client and skillID
        Handle hNewContext = CreateArray(2);
        PushArrayCell(hNewContext, client);
        PushArrayCell(hNewContext, skillID);

        // Execute the query to get skill info
        SQL_TQuery(g_hDatabase, OnFetchSkillInfoForNewSkill, skillInfoQuery, hNewContext);
        return;
    }

    // Create and display the skill detail submenu
    BuildAndShowSkillDetailMenu(client, skillID, skillName, skillDescription, maxLevel, currentLevel);
}

/**
 * @brief Callback to fetch skill info for a new skill (player does not have it yet).
 *
 * @param owner The parent handle (unused).
 * @param hndl The handle to the SQL query result.
 * @param error An error message if the query failed.
 * @param data The context handle containing client index and skillID.
 */
public void OnFetchSkillInfoForNewSkill(Handle owner, Handle hndl, const char[] error, any data) {
    // Unpack context data
    Handle hContext = view_as<Handle>(data);
    int client = GetArrayCell(hContext, 0);
    int skillID = GetArrayCell(hContext, 1);
    CloseHandle(hContext); // Clean up

    // Handle errors
    if (hndl == INVALID_HANDLE || error[0] != '\0') {
        PrintToServer("[AS:RPG] Failed to fetch skill info: %s", error);
        return;
    }

    // Initialize variables
    char skillName[64], skillDescription[128];
    int maxLevel = 1;

    // Fetch skill info
    if (SQL_FetchRow(hndl)) {
        SQL_FetchString(hndl, 0, skillName, sizeof(skillName));
        SQL_FetchString(hndl, 1, skillDescription, sizeof(skillDescription));
        maxLevel = SQL_FetchInt(hndl, 2);
    } else {
        PrintToServer("[AS:RPG] Skill ID %d not found.", skillID);
        return;
    }

    // Player does not have the skill yet, set current level to 0
    int currentLevel = 0;

    // Create and display the skill detail submenu
    BuildAndShowSkillDetailMenu(client, skillID, skillName, skillDescription, maxLevel, currentLevel);
}

/**
 * @brief Builds and displays the skill detail submenu.
 *
 * @param client The client index.
 * @param skillID The skill's ID.
 * @param skillName The skill's name.
 * @param skillDescription The skill's description.
 * @param maxLevel The skill's maximum level.
 * @param currentLevel The player's current level of the skill.
 */
public void BuildAndShowSkillDetailMenu(int client, int skillID, const char[] skillName, const char[] skillDescription, int maxLevel, int currentLevel) {
    // Create skill detail menu
    Menu skillDetailMenu = CreateMenuEx(GetMenuStyleHandle(MenuStyle_Radio), SkillDetailMenuHandler, MENU_ACTIONS_ALL);
    
    // Construct the menu title with skill name, description, and level on separate lines
    char menuTitle[512];
    Format(menuTitle, sizeof(menuTitle), "Skill Details\nName: %s\nDescription: %s\nLevel: %d/%d", 
           skillName, skillDescription, currentLevel, maxLevel);
    SetMenuTitle(skillDetailMenu, menuTitle);

    // Purchase and Refund buttons
    AddMenuItem(skillDetailMenu, "#purchase", "Purchase");
    AddMenuItem(skillDetailMenu, "#refund", "Refund");

    // Back button
    AddMenuItem(skillDetailMenu, BACKCHOICE, "Back to Skills");

    // Enable Exit Button if necessary
    skillDetailMenu.ExitButton = true;

    // Display menu
    skillDetailMenu.Display(client, MENU_TIME_FOREVER);
}

// ------------------------ Purchase and Refund Handlers -------------------------------

/**
 * @brief Handles the purchase of a skill.
 *
 * @param client The client index.
 * @param menu The current menu handle.
 */
public void HandlePurchaseSkill(int client, Menu menu) {
    // TODO: Implement purchase logic
    // Example steps:
    // 1. Determine the skillID from the menu context or item info.
    // 2. Check if the player has enough experience to purchase.
    // 3. Deduct experience and increase skill level in the database.
    // 4. Notify the player of the successful purchase.

    PrintToServer("[AS:RPG] Client %d attempted to purchase a skill.", client);
    PrintToChat(client, "Purchase functionality is not yet implemented.");
}

/**
 * @brief Handles the refund of a skill.
 *
 * @param client The client index.
 * @param menu The current menu handle.
 */
public void HandleRefundSkill(int client, Menu menu) {
    // TODO: Implement refund logic
    // Example steps:
    // 1. Determine the skillID from the menu context or item info.
    // 2. Check if the player can refund the skill.
    // 3. Add experience and decrease skill level in the database.
    // 4. Notify the player of the successful refund.

    PrintToServer("[AS:RPG] Client %d attempted to refund a skill.", client);
    PrintToChat(client, "Refund functionality is not yet implemented.");
}


// ------------------------------- Menu Handlers --------------------------------------------
/**
 * @brief Main menu handler.
 *
 * Handles selections in the main menu.
 */
public int MenuHandler1(Menu menu, MenuAction action, int param1, int param2) {
    switch (action) {
        case MenuAction_Start:{      
            PrintToServer("Displaying Main Menu");
        }

        case MenuAction_Display:{
            char buffer[255];
            Format(buffer, sizeof(buffer), "%T", "Main Menu Title", param1);
        
            Panel panel = view_as<Panel>(param2);
            panel.SetTitle(buffer);
        }

        case MenuAction_Select:{
            char info[32];
            menu.GetItem(param2, info, sizeof(info));
            if (StrEqual(info, MAIN_MENU_VIEW_SKILLS)) {
                PrintToServer("Client %d selected View Skills", param1);
                FetchSkillsAndShowMenu(param1); // Open the skills menu
            } else if (StrEqual(info, BACKCHOICE)) {
                PrintToServer("Client %d selected Exit", param1);
                // Optionally handle exit
            } else {
                PrintToServer("Client %d selected unknown option: %s", param1, info);
            }
        }

        case MenuAction_End:{
            CloseHandle(menu);
        }
    }
    
    return 0;
}

/**
 * @brief Skills menu handler.
 *
 * Handles selections in the skills menu.
 */
public int SkillMenuHandler(Menu menu, MenuAction action, int param1, int param2) {
    switch (action) {
        case MenuAction_Start:{
            PrintToServer("Displaying Skills Menu for Client %d", param1);
        }

        case MenuAction_Display:{
            // Optionally customize display
        }

        case MenuAction_Select: {
            char info[32];
            menu.GetItem(param2, info, sizeof(info));
            if (StrEqual(info, BACKCHOICE)) {
                // Go back to the main menu
                ShowMainMenu(param1);
            } else {
                // Handle skill selection
                int skillID = StringToInt(info);
                PrintToServer("Client %d selected skill ID: %d", param1, skillID);
                FetchPlayerSkillLevel(param1, skillID); // Fetch and show skill details
            }
        }

        case MenuAction_End: {
            CloseHandle(menu);
        }
    }
    return 0;
}

/**
 * @brief Skill detail menu handler.
 *
 * Handles selections in the skill detail submenu.
 */
public int SkillDetailMenuHandler(Menu menu, MenuAction action, int param1, int param2) {
    switch (action) {
        case MenuAction_DrawItem:{
            int style;
            char info[32];
            menu.GetItem(param2, info, sizeof(info), style);
            return style;    
        }
        case MenuAction_Select: {
            char info[32];
            menu.GetItem(param2, info, sizeof(info));

            if (StrEqual(info, PURCHASECHOICE)) {
                // Handle purchase action
                HandlePurchaseSkill(param1, menu);
            } else if (StrEqual(info, REFUNDCHOICE)) {
                // Handle refund action
                HandleRefundSkill(param1, menu);
            } else if (StrEqual(info, BACKCHOICE)) {
                // Go back to the skills menu
                FetchSkillsAndShowMenu(param1);
            } else {
                PrintToServer("[AS:RPG] Client %d selected unknown option: %s", param1, info);
            }
        }
        case MenuAction_End: {
            CloseHandle(menu);
        }
    }
    return 0;
}
