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



    -   Damage boost goes forever, resistances cap at 99%, minimum damage to marines is 1. Even at 99%, getting hit 100 times by drones = die.
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
    version = "1.0",
    url = "https://github.com/christophkogler/as_rpg"
};

// Define weapon damage increases?

// Database configuration name (as defined in databases.cfg)
#define DATABASE_CONFIG "default"

// Global database handle
Database g_hDatabase = null;

// Mapping from client index to marine entity index
int g_ClientToMarine[MAXPLAYERS + 1];

// Accumulated kills per client
int g_ClientKillAccumulator[MAXPLAYERS + 1];

// Define a struct to hold player data
enum struct PlayerData {
    int experience;
    int level;
    int skill_points;
    int kills;
    //Dictionary skills; // To hold skill_id and skill_level
}

PlayerData g_PlayerData[MAXPLAYERS + 1];

/**
 * @brief Called when the plugin is started.
 *
 * Initializes kill counters, connects to the database, hooks events, registers console commands, and creates a timer for database updates.
 */
public void OnPluginStart()
{
    PrintToServer("[AS:RPG] Initializing Kill Counter!");

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

    // Hook events
    HookEvent("alien_died", OnAlienKilled);
    HookEvent("entity_killed", OnEntityKilled);

    HookEvent("player_connect", Event_PlayerConnect);
    HookEvent("player_disconnect", Event_PlayerDisconnect);

    // Register client console command
    RegConsoleCmd("sm_killcount", Command_KillCount);
    RegConsoleCmd("sm_spawnentity", Command_SpawnEntity);
    RegServerCmd("sm_difficultyscale", Command_DifficultyScale);

    // Timer for updating the database. So crashes in the middle of a run don't mean losing up to 10 minutes of experience.
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
 * @brief Connects to the database using the predefined configuration.
 *
 * Attempts to establish a connection to the database and initializes necessary tables and skills upon success.
 */
public void ConnectToDatabase()
{
    char error[255];

    g_hDatabase = SQL_Connect(DATABASE_CONFIG, true, error, sizeof(error));

    if (g_hDatabase == null){PrintToServer("[AS:RPG] Could not connect: %s", error);}
    else{
        PrintToServer("[AS:RPG] Connected to database!");
        CreateTables();
        InitializeSkills(); // Initialize predefined skills
    }
}

/**
 * @brief Creates necessary database tables if they do not exist.
 *
 * Creates the `players`, `skills`, and `player_skills` tables in the database.
 */
public void CreateTables(){
    char sQuery[1024];
    Handle hQuery;

    // 1. Create players table
    Format(sQuery, sizeof(sQuery),
        "CREATE TABLE IF NOT EXISTS `players` (`steam_id` VARCHAR(32) NOT NULL PRIMARY KEY, `experience` INT NOT NULL DEFAULT 0, `level` INT NOT NULL DEFAULT 1, `skill_points` INT NOT NULL DEFAULT 0, `kills` INT NOT NULL DEFAULT 0);"
    );
    hQuery = SQL_Query(g_hDatabase, sQuery);
    if (hQuery == null){PrintToServer("[AS:RPG] Failed to insert or verify 'players' table!");}
    else{        PrintToServer("[AS:RPG] 'players' table is ready.");}

    // 2. Create skills table
    Format(sQuery, sizeof(sQuery),
        "CREATE TABLE IF NOT EXISTS `skills` ( `skill_id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY, `name` VARCHAR(64) NOT NULL, `description` TEXT, `max_level` INT NOT NULL DEFAULT 1);"
    );
    hQuery = SQL_Query(g_hDatabase, sQuery);
    if (hQuery == null){PrintToServer("[AS:RPG] Failed to insert or verify 'skills' table!");}
    else{        PrintToServer("[AS:RPG] 'skills' table is ready.");}

    // 3. Create player_skills table
    Format(sQuery, sizeof(sQuery),
        "CREATE TABLE IF NOT EXISTS `player_skills` ( `steam_id` VARCHAR(32) NOT NULL, `skill_id` INT NOT NULL, `skill_level` INT NOT NULL DEFAULT 1, PRIMARY KEY (`steam_id`, `skill_id`), FOREIGN KEY (`steam_id`) REFERENCES `players`(`steam_id`) ON DELETE CASCADE, FOREIGN KEY (`skill_id`) REFERENCES `skills`(`skill_id`) ON DELETE CASCADE);"
    );
    hQuery = SQL_Query(g_hDatabase, sQuery);
    if (hQuery == null){PrintToServer("[AS:RPG] Failed to insert or verify 'player_skills' table!");}
    else{        PrintToServer("[AS:RPG] 'player_skills' table is ready.");}

    delete hQuery;    
}

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
        // safely try to retrieve the weapon the attacker is using; m_hActiveWeapon is normally right.
        if (HasEntProp(attacker, Prop_Send, "m_hActiveWeapon")){
            attackerWeaponEntityID = GetEntPropEnt(attacker, Prop_Send, "m_hActiveWeapon");
        }
        if(!IsValidEntity(attackerWeaponEntityID) && HasEntProp(attacker, Prop_Send, "m_hActiveASWWeapon")){
            PrintToServer("[AS:RPG] [DEBUGGING] Found an m_hActiveASWWeapon!");
            attackerWeaponEntityID = GetEntPropEnt(attacker, Prop_Send, "m_hActiveASWWeapon");
        }

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
 * Increments the kill counter for the corresponding client who killed the alien.
 *
 * @param event The event data.
 * @param name The name of the event.
 * @param dontBroadcast Whether to broadcast the event.
 */
public void OnAlienKilled(Event event, const char[] name, bool dontBroadcast){
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
    if (client != -1){    g_ClientKillAccumulator[client]++;    }
}

/**
 * @brief Called when any entity is killed.
 *
 * Logs details about the killed entity for debugging purposes.
 *
 * @param event The event data.
 * @param name The name of the event.
 * @param dontBroadcast Whether to broadcast the event.
 */
public void OnEntityKilled(Event event, const char[] name, bool dontBroadcast){
    int entindex_killed = event.GetInt("entindex_killed");

    if (IsValidEntity(entindex_killed))
    {
        char className[256];
        GetEntityClassname(entindex_killed, className, sizeof(className));

        char modelName[256];
        GetEntPropString(entindex_killed, Prop_Data, "m_ModelName", modelName, sizeof(modelName));

        //PrintToServer("[AS:RPG] Entity killed: index %d, classname '%s', model name '%s'", entindex_killed, className, modelName);
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

//  database callers below this line :) 
//  VERY SLOW, AFAICT sourcemod only supports SYNCHRONOUS so QUERIES ARE LOCKING, CANNOT CALL THESE FRIVOLOUSLY!



/**
 * @brief Initializes predefined skills in the database.
 *
 * Inserts skills like "Damage Boost" and "Health Regeneration" into the `skills` table.
 */
public void InitializeSkills()
{
    char sQuery[512];
    Handle hQuery;

    // Example Skill 1: Damage Boost
    Format(sQuery, sizeof(sQuery),"INSERT INTO `skills` (`name`, `description`, `max_level`) VALUES ('Damage Boost', 'Increases your damage output.', 5) ON DUPLICATE KEY UPDATE `name` = `name`;");
    hQuery = SQL_Query(g_hDatabase, sQuery);
    if (hQuery == null){PrintToServer("[AS:RPG] Failed to insert or verify 'Damage Boost' skill!");}
    else{
        PrintToServer("[AS:RPG] 'Damage Boost' skill is ready.");
        delete hQuery;
    }

    // Example Skill 2: Health Regeneration
    Format(sQuery, sizeof(sQuery),"INSERT INTO `skills` (`name`, `description`, `max_level`) VALUES ('Health Regeneration', 'Regenerates your health over time.', 3) ON DUPLICATE KEY UPDATE `name` = `name`;");
    hQuery = SQL_Query(g_hDatabase, sQuery);
    if (hQuery == null){PrintToServer("[AS:RPG] Failed to insert or verify 'Health Regeneration' skill!");}
    else{
        PrintToServer("[AS:RPG] 'Health Regeneration' skill is ready.");
        delete hQuery;
    }

    // Add more skills as needed following the same pattern
}


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

/**
 * @brief Updates the database with accumulated kills for each client.
 *
 * Iterates through all clients, updates their kill counts and experience in the database, and resets their accumulated kills.
 */
public void UpdateDatabase(){
    PrintToServer("[AS:RPG] Updating database!");
    char sSteamID[32];
    char sQuery[512];

    for (int client = 1; client <= MaxClients; client++)
    {
        if (g_ClientKillAccumulator[client] > 0 && IsClientInGame(client))
        {
            GetClientAuthId(client, AuthId_Steam2, sSteamID, sizeof(sSteamID));

            PrintToServer("[AS:RPG] Adding %d to client %d's total.", g_ClientKillAccumulator[client], client);

            // Use accumulated kills to update the database
            Format(sQuery, sizeof(sQuery),
                "INSERT INTO player_kills (steam_id, kills) VALUES ('%s', %d) ON DUPLICATE KEY UPDATE kills = kills + %d",
                sSteamID, g_ClientKillAccumulator[client], g_ClientKillAccumulator[client]);

            Handle hQuery = SQL_Query(g_hDatabase, sQuery);

            if (hQuery != null){    delete hQuery;  }
            else{   PrintToServer("[AS:RPG] Failed to update kill count for player %s", sSteamID);   }

            Format(sQuery, sizeof(sQuery),
                "INSERT INTO players (steam_id, experience) VALUES ('%s', %d) ON DUPLICATE KEY UPDATE experience = experience + %d",
                sSteamID, g_ClientKillAccumulator[client], g_ClientKillAccumulator[client]);

            hQuery = SQL_Query(g_hDatabase, sQuery);

            if (hQuery != null){    delete hQuery;  }
            else{   PrintToServer("[AS:RPG] Failed to update experience for player %s", sSteamID);   }

            // Reset the accumulated kills for the client
            g_ClientKillAccumulator[client] = 0;
        }
    }
}


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
    if (client <= 0 || !IsClientInGame(client)){return Plugin_Handled;}

    // Get player's Steam ID
    char sSteamID[32];
    GetClientAuthId(client, AuthId_Steam2, sSteamID, sizeof(sSteamID));
    // check if they have any kills
    int playerKills = GetPlayerKillCount(sSteamID, client, false) + g_ClientKillAccumulator[client];
    bool hasKills = (playerKills > 0);

    if (hasKills){PrintToChat(client, "Your total kills: %d", playerKills);}
    else{PrintToChat(client, "You have no recorded kills yet.");}
    return Plugin_Handled;
}

/**
 * @brief Retrieves and optionally displays a player's kill count.
 *
 * Fetches the kill count from the database and sends a welcome message to the player if required.
 *
 * @param sSteamID The Steam ID of the player.
 * @param client The client index.
 * @param bNotify Whether to send a notification to the player.
 */
public int GetPlayerKillCount(const char[] sSteamID, int client, bool bNotify){
    char sQuery[256];

    Format(sQuery, sizeof(sQuery), "SELECT kills FROM player_kills WHERE steam_id = '%s'", sSteamID);
    Handle hQuery = SQL_Query(g_hDatabase, sQuery);

    int playerKills = 0;
    bool hasKills = false;

    if (hQuery == null){
        PrintToServer("[AS:RPG] Failed to retrieve kill count for player %s", sSteamID);
    }
    else{
        if (SQL_FetchRow(hQuery)){
            playerKills = SQL_FetchInt(hQuery, 0);
            hasKills = true;
        }
        delete hQuery;
    }

    if (bNotify){
        if (hasKills){PrintToChat(client, "Welcome back! Your total kills: %d", playerKills);}
        else{PrintToChat(client, "Welcome! Let's start counting your kills!");}
    }
    return playerKills;
}



// ------------------------------------------- Generic 'extra' commands here. Relatively fast ones. -------------------------------------------------------

/**
 * @brief Console command handler to spawn entities.
 *
 * Allows players to spawn entities using the `sm_spawnentity` command with specified parameters.
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