#if defined _rpgutility_included
 #endinput
#endif
#define _rpgutility_included

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
stock void SpawnEntityByName(const char[] classname, float position[3], const float angles[3], const char[] model, float range, bool bNotify) {
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
stock void AdjustDifficultyConVars(float difficulty){
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
 * @brief Safely modifies a float ConVar without requiring sv_cheats.
 *
 * @param command The ConVar name to modify.
 * @param value The new float value.
 */
stock void StripAndChangeServerConVarFloat(String:command[], float value) {
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
 * @brief Safely modifies a bool ConVar without requiring sv_cheats.
 *
 * @param command The ConVar name to modify.
 * @param value The new boolean value.
 */
stock void StripAndChangeServerConVarBool(String:command[], bool value) {
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
 * @brief Safely modifies an integer ConVar without requiring sv_cheats.
 *
 * @param command The ConVar name to modify.
 * @param value The new integer value.
 */
stock void StripAndChangeServerConVarInt(String:command[], int value) {
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
stock int GetExperienceForAlienClass(const char[] classname){
    if (StrEqual(classname, "asw_drone"))              return 10;    
    else if (StrEqual(classname, "asw_drone_jumper"))   return 13;
    else if (StrEqual(classname, "asw_boomer"))        return 15;    
    else if (StrEqual(classname, "asw_zombine"))       return 20;    
    // Add more conditions as needed for different alien classes
    else{
        LogStackTrace("[AS:RPG] rpgutility: GetExperienceForAlienClass encountered Alien class %s without defined experience! Defaulting to 10.", classname);
    }

    return 10; // Default experience for unknown classes
}

/*
 * @brief Determines if a classname indicates alien swarm-ness.
 *
 * @param classname The classname string.
 * @return bool If the classname belongs to the swarm.
 */
stock bool IsClassnameAnAlien(const char[] classname){
    if (StrEqual(classname, "asw_drone"))               return true;
    else if (StrEqual(classname, "asw_drone_jumper"))   return true;
    else if (StrEqual(classname, "asw_boomer"))         return true;
    else if (StrEqual(classname, "asw_zombine"))        return true;
    else {
        LogStackTrace("[AS:RPG] IsClassnameAnAlien processed non-defined classname '%s'.", classname);
    }

    return false; // default for undefined
}

/**
 * @brief Updates the client-to-marine mapping for all connected clients.
 */
stock void UpdateClientMarineMapping(){
    PrintToServer("[AS:RPG] Updating client-marine mapping!");

    for (int client = 1; client <= MaxClients; client++){
        if (IsClientInGame(client) && Swarm_IsGameActive()){
            g_ClientToMarine[client] = Swarm_GetMarine(client)
            PrintToServer("[AS:RPG] Client %d got marine %d!", client, g_ClientToMarine[client])
        }
        else{
            //PrintToServer("[AS:RPG] Client %d not in game!", client)
            g_ClientToMarine[client] = -1;
        }
    }
}

/**
 * @brief Safely retrieves an entity's property of type entity index.
 *
 * @param entity The entity ID.
 * @param type The property type (PropType).
 * @param property The name of the property.
 * @return The entity index or -1 if invalid.
 */
stock int SafeGetEntPropEnt(int entity, PropType type, char[] property){
    if (IsValidEntity(entity) && HasEntProp(entity, type, property)){
        return GetEntPropEnt(entity, type, property);
    }
    else return -1;
}

/**
 * @brief Safely retrieves an entity's property of a generic type.
 *
 * @param entity The entity ID.
 * @param type The property type (PropType).
 * @param property The name of the property.
 * @return The property value or -1 if invalid.
 */
stock int SafeGetEntProp(int entity, PropType type, char[] property){
    if(!IsValidEntity(entity)) {
        LogStackTrace("[AS:RPG] rpgutility.SafeGetEntProp received invalid entity.");
        return -1;
    }
    if(!HasEntProp(entity, type, property)) {
        LogStackTrace("[AS:RPG] rpgutility.SafeGetEntProp attempted to access invalid property.")
        return -1;
    }
    return GetEntProp(entity, type, property);
}

/**
 * @brief Safely retrieves an entity's property of integer type.
 *
 * @param entity The entity ID.
 * @param type The property type (PropType).
 * @param property The name of the property.
 * @return The property value or -1 if invalid.
 */
stock int SafeGetEntData(int entity, int offset, int size=4){
    if (IsValidEntity(entity)){
        return GetEntData(entity, offset, size);
    }
    else return -1;
}


/**
 * @brief Updates the PlayerData array based on client connection or disconnection.
 *
 * @param disconnecting Whether the client is disconnecting.
 * @param client The client index.
 */
stock void UpdatePlayerDataArray(bool disconnecting, int client) {
    //PrintToServer("[AS:RPG] Updating playerdata array.")
    // Assume PlayerData is a global array with MAX_PLAYERS as the size
    // Define MAX_PLAYERS based on your game, typically 64 for Source games
    if(disconnecting){
        PrintToServer("[AS:RPG] Updating playerdata array: cleaning up disconnecting player's data.")
        PlayerData emptyPlayer;    g_PlayerData[client] = emptyPlayer;                                          // Clear the disconnecting player's data
        for (int i = client; i < MAXPLAYERS - 1; i++) {    g_PlayerData[i] = g_PlayerData[i + 1];    }          // Shift players above this index down by one
        g_PlayerData[MAXPLAYERS - 1] = emptyPlayer;                                                 // Clear the second-to-last slot after the shift; old data.
    }
    else{
        // if connecting, then...
        // get client number, fetch?
        PrintToServer("[AS:RPG] Updating playerdata array: getting connecting client's data.")
        UpdatePlayerData(client);
    }
}

stock int GetEntityActiveWeaponIndex(int entity){
    return SafeGetEntPropEnt(entity, Prop_Send, "m_hActiveWeapon");
}

/**
 * @brief Retrieves the classname of the active weapon for a given entity.
 *
 * @param entity The entity index.
 * @param name The buffer to store the weapon classname.
 * @param maxlength The maximum length of the buffer.
 */
stock void GetEntityActiveWeaponClassname(int entity, String:name[]){
    char WeaponName[64];
    int attackerWeaponEntityID = GetEntityActiveWeaponIndex(entity);
    if(!IsValidEntity(attackerWeaponEntityID)){ attackerWeaponEntityID = SafeGetEntPropEnt(entity, Prop_Send, "m_hASWActiveWeapon"); }

    // If weapon is valid, get its classname
    if (IsValidEntity(attackerWeaponEntityID)){    GetEntityClassname(attackerWeaponEntityID, WeaponName, sizeof(WeaponName));    }
    else{    strcopy(WeaponName, sizeof(WeaponName), "UnknownWeapon");    }

    strcopy(name, sizeof(name), WeaponName);
}

/**
 * @brief Determines if a weapon is classified as 'auto-aim' by its classname.
 *
 * @param name The classname of the weapon.
 * @return Whether the weapon is auto-aim capable.
 */
stock bool IsAutoAimWeapon(char[] name){
    bool isAutoAim = false;
    if(StrEqual(name, "asw_weapon_prifle") || StrEqual(name, "asw_weapon_autogun")) isAutoAim = true;
    return isAutoAim;
}

/**
 * @brief Find the send property of a server class and set output to it, or else enter a fail state.
 * @param output Will be set to the offset of the networkable send property.
 * @param serverclass The serverclass to search within for the property.
 * @param property The property of serverclass to find the offset of.
 * @return This function alters output by reference.
 */
stock void FindSendPropInfoOrEnterFailstate(int &output, char[] serverclass, char[] property){
    output = FindSendPropInfo(serverclass, property);
    if (output <= 0){    SetFailState("Could not find offset of %s->%s", serverclass, property);    }
    else{               PrintToServer("[AS:RPG] Found %s's property %s offset at: %d.", serverclass, property, output);    }
}

stock void AlterWeaponMagazineCount(int entity, int amount){
    if (g_OFFSET_Weapon_m_iClip1 > 0){
        int ammoCount = GetEntData(entity, g_OFFSET_Weapon_m_iClip1,2);
        SetEntData(entity, g_OFFSET_Weapon_m_iClip1, ammoCount + amount, 2, true);
    }
}
// -----------------------------------------------------------------------------------------------------






// -------------------------------------------- Plugin setup ----------------------------------------
/**
 * @brief Hooks alien_died, entity_killed, player_connect, and player_disconnect.
 */
stock void HookRelevantEvents(){
    HookEvent("alien_died", Event_AlienDied);
    HookEvent("entity_killed", Event_EntityKilled);

    HookEvent("player_connect", Event_PlayerConnect);
    HookEvent("player_disconnect", Event_PlayerDisconnect, EventHookMode_Pre);
}

/**
 * @brief Creates a series of custom commands.
 */
stock void CreateCustomCommands(){
    RegConsoleCmd("sm_killcount", Command_KillCount);
    RegConsoleCmd("sm_listskills", Command_ListSkills, "List the skills in the database.");
    RegConsoleCmd("sm_menu", Command_MainMenu);

    RegAdminCmd("sm_spawnentity", Command_SpawnEntity, ADMFLAG_GENERIC);

    RegServerCmd("sm_difficultyscale", Command_DifficultyScale);
    RegServerCmd("sm_addskill", Command_AddSkill, "Adds a new skill to the database.");
    RegServerCmd("sm_deleteskill", Command_DeleteSkill, "Deletes a skill by name from the database.");
}

stock void GetSendPropOffsets(){
    FindSendPropInfoOrEnterFailstate(g_OFFSET_Marine_m_iAmmo, "CASW_Marine", "m_iAmmo");

    FindSendPropInfoOrEnterFailstate(g_OFFSET_Weapon_m_iPrimaryAmmoType, "CASW_Weapon", "m_iPrimaryAmmoType");
    FindSendPropInfoOrEnterFailstate(g_OFFSET_Weapon_m_iClip1, "CASW_Weapon", "m_iClip1");
}
// --------------------------------------------------------------------------------------------------------







// ----------------------------- Skill Implementation ---------------------------------
// where skills touch the game.

/**
 * @brief Calculates a marine's damage boost based on its skills and conditions.
 *
 * @param marineIndex The marine entity index.
 * @param damagetype The type of damage being dealt.
 * @return The damage boost multiplier.
 */
stock float CalculateMarineDamageBoost(int marineIndex, damagetype){
    int client = Swarm_GetClientOfMarine(marineIndex);
    int test = damagetype;    test++; // stfu compiler warning
    if (client != -1){
        //StringMap playerSkillsTrie = StringMap:g_PlayerData[client].skillsTrie;
        // get the active weapon.
        //char WeaponName[64];
        //GetEntityActiveWeaponClassname(attacker, WeaponName, sizeof(WeaponName));
        
        // get all skillids from g_SkillData into an array
        // for each skilldata where type == 'general_offensive', get ID.
            // see if the player skills trie has a value for the (stringified) id. if so, multiply 

    }
    return 1.0;
}

stock float CalculateMarineDamageReduction(int victim, float damage, int damagetype){
    if(damagetype != 4){
        PrintToServer("[AS:RPG] [DEBUGGING] A marine took a new type of damage: %d", damagetype);
    }

    int client = -1;
    client = Swarm_GetClientOfMarine(victim);
    if (client == -1){
        //PrintToServer("[AS:RPG] A non-player marine took damage.")
        return damage;
    }
    // StringMap clientSkills = g_PlayerData[client].skillsTrie;
    // multiply damage by some factor based on each skill...?

    // hard nitty gritty details of skill implementation end up here. eugh! 

    // how to control WHICH of the player's skills are applied to damage reduction? 
        // skill type enough? doesn't feel specific enough. surely not ALL damage marines take will be from slash damage? but every defense skill defending from all damage seems too broad.
        // skill type and additional specification? IE 'defense' (w/e) and 'slash'? 
        // better db design would break type and specification into new table, link to skills. 'optimally normalized' would probably have type & specification in separate tables - likely to be highly repeated.
        // for attack...? that gives the possibility of different weapon types, different damage types, etc...

    // how to transform some factor per level per skill stored in the database into applying that to damage reduction HERE?
        // in an extremely flexible way that makes it 'easy' for people to add their own skills into?

    if(damagetype == 4){
        // for each skill with slash specification...?
    }

    return damage;
}

/**
 * @brief when the player gets a kill, do.. things! heeheehaha
 */
stock void OnPlayerKillAlien(int client){
    // when the player gets a kill, do.. things! heeheehaha
    
    // give them ammo back! (make this a chance) (make this based on skills!)
    int MarineEntityID = Swarm_GetMarine(client);
    int attackerWeaponEntityID = GetEntityActiveWeaponIndex(MarineEntityID);
    AlterWeaponMagazineCount(attackerWeaponEntityID, 1);

    // heal! (BLAH BLAH MAKE IT BETTER)

}


// -------------------------------------------------------------------------------------




// ------------------------ Purchase and Refund Handlers -------------------------------

/**
 * @brief Handles the purchase of a skill.
 *
 * @param client The client index.
 * @param menu The current menu handle.
 */
stock void HandlePurchaseSkill(int client, int skillID) {
    // TODO: Implement purchase logic
    PrintToServer("[AS:RPG] Client %d attempted to purchase skill %d.", client, skillID);
    PrintToChat(client, "Purchase functionality is not yet fully implemented.");
    // int skillExperienceCost = 0;
    // skillExperienceCost = calculateSkillLevelCostForClient(client);
    // int canBuy = experienceTransaction(client, -skillExperienceCost); // can the player afford the skill?
    // if canbuy,     UpdatePlayerSkillLevel(client, 1);
    // else some kind of error in chat IE     PrintToChat(client, "You don't have enough experience for that skill!");
    UpdatePlayerSkillLevel(client, 1, skillID);
}

/**
 * @brief Handles the refund of a skill.
 *
 * @param client The client index.
 * @param menu The current menu handle.
 */
stock void HandleRefundSkill(int client, int skillID) {
    PrintToServer("[AS:RPG] Client %d attempted to refund skill %d.", client, skillID);
    PrintToChat(client, "Refund functionality is not yet fully implemented.");
    // LOGIC GOES HERE :)
    // skillExperienceCost = calculateSkillLevelCostForClient(client);
    // processExperienceTransaction(client, skillExperienceCost * RefundExperience)
    UpdatePlayerSkillLevel(client, -1, skillID);
}
// ----------------------------------------------------------------------------------------------------------------
