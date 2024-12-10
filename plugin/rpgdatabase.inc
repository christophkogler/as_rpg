#if defined _rpgdatabase_included
 #endinput
#endif
#define _rpgdatabase_included

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
        "CREATE TABLE IF NOT EXISTS `skills` ( `skill_id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY, `name` VARCHAR(64) NOT NULL, `description` TEXT, `type` VARCHAR(32) NOT NULL, `experience_cost` INT NOT NULL DEFAULT 0, `max_level` INT NOT NULL DEFAULT 1);", 
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
        "INSERT IGNORE INTO `skills` (`name`, `description`, `type`, `experience_cost`, `max_level`) VALUES ('Damage Boost', 'Increases your damage output.', 'Active', 100, 5);", 
        SkillType_DamageBoost);

    SQL_TQuery(g_hDatabase, 
        OnInitializeSkillFinished, 
        "INSERT IGNORE INTO `skills` (`name`, `description`, `type`, `experience_cost`, `max_level`) VALUES ('Health Regeneration', 'Regenerates your health over time.', 'Passive', 150, 3);", 
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
stock void GetPlayerKillCount(const char[] sSteamID, int client, bool bNotify) { 
    // Create a handle to store the context data
    Handle hContext = CreateArray(1); 
    PushArrayCell(hContext, view_as<int>(client)); // Pack client
    PushArrayCell(hContext, bNotify ? 1 : 0);     // Pack bNotify
    PushArrayString(hContext, sSteamID);          // Pack sSteamID

    char sQuery[256];
    Format(sQuery, sizeof(sQuery), "SELECT kills FROM players WHERE steam_id = '%s'", sSteamID);
    PrintToServer("Client %d initialized database query for their kill count!", client);

    SQL_TQuery(g_hDatabase, OnGetPlayerKillCountFinished, sQuery, hContext);
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
                    "INSERT INTO players (steam_id, kills) VALUES ('%s', %d) ON DUPLICATE KEY UPDATE kills = kills + %d",
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


stock void AddSkillToDatabase(char[] name, char[] description, char[] type, int experience_cost, int max_level){
    PrintToServer("[AS:RPG] Adding a skill to the database.");
    PrintToServer("[AS:RPG] %s, Type: %s, Experience Cost: %d, Maximum level %d.\n%s", name, type, experience_cost, max_level, description);
    char sQuery[512];
    Format(sQuery, sizeof(sQuery), "INSERT INTO skills (name, description, type, experience_cost, max_level) VALUES ('%s', '%s', '%s', %d, %d);",
           name, description, type, experience_cost, max_level);
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
    bool bUpdateSkillArray = false;
    SQL_TQuery(g_hDatabase, OnListSkillsFinished, sQuery, bUpdateSkillArray);
}

// when called, clean out the skill array, fetch anew, rebuild it. 
stock void UpdateSkillArray(){
    PrintToServer("[AS:RPG] Updating skill array.");
    char sQuery[512];
    Format(sQuery, sizeof(sQuery), "SELECT * FROM skills;");
    bool bUpdateSkillArray = true;
    SQL_TQuery(g_hDatabase, OnListSkillsFinished, sQuery, bUpdateSkillArray);
}


/**
 * @brief Initiates fetching for player data.
 *
 * @param client The client index.
 */
stock void UpdatePlayerData(int client) {
    PrintToServer("[AS:RPG] Beginning update player data function.");
    // Ensure client is valid
    if (client <= 0) return;

    char sSteamID[32];
    GetClientAuthId(client, AuthId_Steam2, sSteamID, sizeof(sSteamID));

    PrintToServer("[AS:RPG] Client %d's steamID is %s", client, sSteamID);

    // query to get player data from player and player_skills table
    char query[512];
    Format(query, sizeof(query),
        "SELECT p.steam_id, p.experience, p.level, p.skill_points, p.kills, ps.skill_id, ps.skill_level FROM players AS p LEFT JOIN player_skills AS ps ON p.steam_id = ps.steam_id WHERE p.steam_id = '%s';",
        sSteamID);
    PrintToServer("[AS:RPG] Beginning player data fetch...");
    // Use client index as data for callback
    SQL_TQuery(g_hDatabase, OnFetchPlayerDataFinished, query, client);
}



//----------------------------------------------------------------------------------------------------------------


// --------------------------------------- Database callback functions. -----------------------------------------
/**
 * @brief Callback function invoked after attempting to connect to the database.
 *
 * Handles the result of the asynchronous database connection attempt.
 *
 * @param owner The parent handle (unused in this context).
 * @param databaseHandle The handle to the database connection.
 * @param error An error message if the connection failed.
 * @param data Extra data passed during the connection attempt (unused here).
 */
stock void OnDatabaseConnected(Handle owner, Handle databaseHandle, const char[] error, any data){
    // check the state of the database's handle before it is passed off
    if (databaseHandle == null || databaseHandle == INVALID_HANDLE){
        PrintToServer("[AS:RPG] Could not connect to database: %s", error);
        return;
    }

    // handle is valid, so connect. cast the handle to a database.
    g_hDatabase = Database:databaseHandle;
    PrintToServer("[AS:RPG] Connected to database!");

    CreateTables();
    InitializeSkills();
    UpdateSkillArray();
}

/**
 * @brief Callback function invoked after attempting to create a database table.
 *
 * Handles the result of the asynchronous table creation queries.
 *
 * @param owner The parent handle (unused in this context).
 * @param queryHandle The handle to the SQL query result.
 * @param error An error message if the table creation failed.
 * @param data An identifier indicating which table was processed.
 */
stock void OnCreateTableFinished(Handle owner, Handle queryHandle, const char[] error, any data){
    int switcher = data;

    if (error[0] != '\0' || queryHandle == INVALID_HANDLE || queryHandle == null){
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
 * @param queryHandle The handle to the SQL query result.
 * @param error An error message if the skill initialization failed.
 * @param data An identifier indicating which skill was processed.
 */
stock void OnInitializeSkillFinished(Handle owner, Handle queryHandle, const char[] error, any data){
    int switcher = data;
    if (error[0] != '\0' || queryHandle == INVALID_HANDLE || queryHandle == null){
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
 * @param queryHandle The handle to the SQL query result.
 * @param error An error message if the retrieval failed.
 * @param data A handle containing context information.
 */
stock void OnGetPlayerKillCountFinished(Handle owner, Handle queryHandle, const char[] error, any data){
    // Unpack the context data
    Handle hContext = view_as<Handle>(data);

    int client = GetArrayCell(hContext, 0);
    bool bNotify = GetArrayCell(hContext, 1) == 1;
    char sSteamID[32];
    GetArrayString(hContext, 2, sSteamID, sizeof(sSteamID));

    CloseHandle(hContext); // Clean up handle after unpacking

    int playerKills = 0;
    bool hasKills = false;

    if (error[0] != '\0' || queryHandle == INVALID_HANDLE || queryHandle == null) {
        PrintToServer("[AS:RPG] Failed to retrieve kill count for player %s: %s", sSteamID, error);
    } else {
        if (SQL_FetchRow(queryHandle)) {
            playerKills = SQL_FetchInt(queryHandle, 0);
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
 * @param queryHandle The handle to the SQL query result.
 * @param error An error message if the kill count update failed.
 * @param data The client index associated with this update.
 */
stock void OnUpdateKillCountFinished(Handle owner, Handle queryHandle, const char[] error, any data){
    int client = data;
    char sSteamID[32];
    GetClientAuthId(client, AuthId_Steam2, sSteamID, sizeof(sSteamID));
    if (error[0] != '\0' || queryHandle == INVALID_HANDLE || queryHandle == null){
        PrintToServer("[AS:RPG] Failed to update kill count for player %s: %s", sSteamID, error);
    }
}

/**
 * @brief Callback function invoked after attempting to update a client's experience.
 *
 * Handles the result of the asynchronous experience update query.
 *
 * @param owner The parent handle (unused in this context).
 * @param queryHandle The handle to the SQL query result.
 * @param error An error message if the experience update failed.
 * @param data The client index associated with this update.
 */
stock void OnUpdateExperienceFinished(Handle owner, Handle queryHandle, const char[] error, any data){
    int client = data;
    char sSteamID[32];
    GetClientAuthId(client, AuthId_Steam2, sSteamID, sizeof(sSteamID));
    if (error[0] != '\0' || queryHandle == INVALID_HANDLE || queryHandle == null){
        PrintToServer("[AS:RPG] Failed to update experience for player %s: %s", sSteamID, error);
    }
}

stock void OnCreateSkillFinished(Handle owner, Handle queryHandle, const char[] error, any data){
    if (error[0] != '\0' || queryHandle == INVALID_HANDLE || queryHandle == null){
        PrintToServer("[AS:RPG] Failed to create skill! Error: %s", error);
    }
}

stock void OnDeleteSkillFinished(Handle owner, Handle queryHandle, const char[] error, any data){
    if (error[0] != '\0' || queryHandle == INVALID_HANDLE || queryHandle == null){
        PrintToServer("[AS:RPG] Failed to delete skill! Error: %s", error);
    }
}

stock void OnListSkillsFinished(Handle owner, Handle queryHandle, const char[] error, any data) {
    bool bUpdateSkillArray = bool:data;
    // Check if there was an error or if the handle is invalid
    if (error[0] != '\0' || queryHandle == INVALID_HANDLE || queryHandle == null) {    
        PrintToServer("[AS:RPG] Failed to get skills! Error: %s", error);    
        return;    
    }

    // Begin processing the result set
    if (bUpdateSkillArray)    
        PrintToServer("[AS:RPG] Beginning skill list rebuild:");
    else                    
        PrintToServer("[AS:RPG] Skills list retrieved successfully:");

    int rowCount = 0;

    if (bUpdateSkillArray)    
        g_SkillList.Clear();    // reset skill array

    // Iterate through each row in the result set
    while (SQL_FetchRow(queryHandle)) {
        int skillID;
        char skillName[64];
        char skillDescription[256];
        char skillType[32];
        int experienceCost;
        int maxLevel;

        // Retrieve the skill details from the current row
        skillID = SQL_FetchInt(queryHandle, 0);
        SQL_FetchString(queryHandle, 1, skillName, sizeof(skillName));
        SQL_FetchString(queryHandle, 2, skillDescription, sizeof(skillDescription));
        maxLevel = SQL_FetchInt(queryHandle, 3);
        SQL_FetchString(queryHandle, 4, skillType, sizeof(skillType));
        experienceCost = SQL_FetchInt(queryHandle, 5);

        // Print the skill information to the server console
        PrintToServer("[AS:RPG] Skill #%d: %s - Type: %s - Experience Cost: %d - Max Level: %d - %s", 
            ++rowCount, skillName, skillType, experienceCost, maxLevel, skillDescription);

        if (bUpdateSkillArray){
            SkillData newSkill;
            newSkill.skillDescription = skillDescription;
            newSkill.skillID = skillID;
            newSkill.type = skillType;
            newSkill.experience_cost = experienceCost;
            newSkill.maxLevel = maxLevel;
            newSkill.skillName = skillName;
            g_SkillList.PushArray(newSkill);
        }
    }

    // Check if no rows were retrieved
    if (rowCount == 0) {    
        PrintToServer("[AS:RPG] No skills found in the database.");    
    }
}

/**
 * @brief Handles the completion of the player data fetch query.
 *
 * @param hQuery The SQL query handle.
 * @param iData The client index passed as data.
 */
public void OnFetchPlayerDataFinished(Handle owner, Handle queryHandle, const char[] error, any data) {
    PrintToServer("[AS:RPG] Fetch callback started.");

    int client = view_as<int>(data);

    // Ensure client is valid and still connected
    if (client <= 0) return; // they dont need to be in the game for the server to load their data from db
                                    //this is called only on connecting(?)

    if (queryHandle == null || queryHandle == INVALID_HANDLE){
        LogError("[AS:RPG] Failed to execute player data query for client %d. Error: %s", client, error);  
        return;
    }

    PrintToServer("[AS:RPG] Loading playerdata for client %d", client);

    StringMap playerSkillDataTrie = g_PlayerData[client].skillsTrie;


    bool firstLoop = true;
    while (SQL_FetchRow(queryHandle)) {
        char sSteamID[32];      
        SQL_FetchString(queryHandle, 0, sSteamID, sizeof(sSteamID));
        int experience = SQL_FetchInt(queryHandle, 1);
        int level = SQL_FetchInt(queryHandle, 2);
        int skill_points = SQL_FetchInt(queryHandle, 3);
        int kills = SQL_FetchInt(queryHandle, 4);
        int skillID = SQL_FetchInt(queryHandle, 5);
        int currentLevel = SQL_FetchInt(queryHandle, 6);

        // Update core player data - only need to do once.
        if (firstLoop) {
            g_PlayerData[client].experience = experience;
            g_PlayerData[client].kills = kills;
            g_PlayerData[client].level = level;
            g_PlayerData[client].skill_points = skill_points;
            firstLoop = false;
        }

        // set the trie value for the STRING equivalent of skillId to currentlevel.
        // EX: skill Damage Boost with skillID 88 would be key "88"
        char skillIDString[16];
        IntToString(skillID, skillIDString, sizeof(skillIDString));
        SetTrieValue(g_PlayerData[client].skillsTrie, skillIDString, currentLevel);
    }
    
    PrintToServer("[AS:RPG] Player data update completed!");
}
// -----------------------------------------------------------------------------------------------------------
