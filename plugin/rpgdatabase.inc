#if defined _rpgdatabase_included
 #endinput
#endif
#define _rpgdatabase_included

#include <rpgglobals>

// ------------------------- Database interactions. ------------------------------
/**
 * @brief Initiates an asynchronous connection to the database.
 */
stock void ConnectToDatabase(){
    SQL_TConnect(OnDatabaseConnected, DATABASE_CONFIG, 0);
}

/**
 * @brief Creates necessary database tables if they do not exist.
 *
 * Executes asynchronous SQL queries to ensure the required tables are present in the database.
 */
stock void CreateTables(){
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
stock void InitializeSkills(){
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
stock int GetPlayerKillCount(const char[] sSteamID, int client, bool bNotify) { 
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
stock void UpdateDatabase(){
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


stock void AddSkillToDatabase(char[] name, char[] description, int max_level){
    PrintToServer("[AS:RPG] Adding a skill to the database.");
    PrintToServer("[AS:RPG] %s, maximum level %d.\n%s", name, max_level, description);
    char sQuery[512];
    Format(sQuery, sizeof(sQuery), "INSERT INTO skills (name, description, max_level) VALUES ('%s', '%s', %d);",
           name, description, max_level);
    SQL_TQuery(g_hDatabase, OnCreateSkillFinished, sQuery);
}

stock void DeleteSkillFromDatabase(char[] name){
    PrintToServer("[AS:RPG] Deleting the skill %s from the database.", name);
    char sQuery[512];
    Format(sQuery, sizeof(sQuery), "DELETE FROM skills WHERE name = '%s';", name);
    SQL_TQuery(g_hDatabase, OnDeleteSkillFinished, sQuery);
}

stock void ListSkillsInDatabase(){
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
stock void OnDatabaseConnected(Handle owner, Handle hndl, const char[] error, any data){
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
stock void OnCreateTableFinished(Handle owner, Handle hndl, const char[] error, any data){
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
stock void OnInitializeSkillFinished(Handle owner, Handle hndl, const char[] error, any data){
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
stock void OnGetPlayerKillCountFinished(Handle owner, Handle hndl, const char[] error, any data){
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
stock void OnUpdateKillCountFinished(Handle owner, Handle hndl, const char[] error, any data){
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
stock void OnUpdateExperienceFinished(Handle owner, Handle hndl, const char[] error, any data){
    int client = data;
    char sSteamID[32];
    GetClientAuthId(client, AuthId_Steam2, sSteamID, sizeof(sSteamID));
    if (error[0] != '\0' || hndl == INVALID_HANDLE || hndl == null){
        PrintToServer("[AS:RPG] Failed to update experience for player %s: %s", sSteamID, error);
    }
}

stock void OnCreateSkillFinished(Handle owner, Handle hndl, const char[] error, any data){
    if (error[0] != '\0' || hndl == INVALID_HANDLE || hndl == null){
        PrintToServer("[AS:RPG] Failed to create skill! Error: %s", error);
    }
}

stock void OnDeleteSkillFinished(Handle owner, Handle hndl, const char[] error, any data){
    if (error[0] != '\0' || hndl == INVALID_HANDLE || hndl == null){
        PrintToServer("[AS:RPG] Failed to delete skill! Error: %s", error);
    }
}

stock void OnListSkillsFinished(Handle owner, Handle hndl, const char[] error, any data) {
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
