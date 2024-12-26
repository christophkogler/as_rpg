#if defined _rpgcommands_included
 #endinput
#endif
#define _rpgcommands_included

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
stock Action Command_KillCount(int client, int args){
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
stock Action Command_SpawnEntity(int client, int args) {
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
stock Action Command_DifficultyScale(int args){
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
 * @brief Console command handler to add a skill.
 *
 * Adds a new skill to the RPG system database.
 *
 * @param args The number of arguments passed with the command.
 * @return Action Indicates whether the plugin has handled the command.
 */
stock Action Command_AddSkill(int args){
    if (args != 5){
        PrintToServer("[AS:RPG] Usage: sm_addskill \"<name>\" \"<description>\" <type> <experience_cost> <max_level>");
        return Plugin_Handled;
    }

    char name[64], description[256], type[32];
    GetCmdArg(1, name, sizeof(name));
    GetCmdArg(2, description, sizeof(description));
    GetCmdArg(3, type, sizeof(type));
    int experience_cost = GetCmdArgInt(4);
    int max_level = GetCmdArgInt(5);

    AddSkillToDatabase(name, description, type, experience_cost, max_level);

    return Plugin_Handled;
}

/**
 * @brief Console command handler to delete a skill.
 *
 * Removes an existing skill from the RPG system database.
 *
 * @param args The number of arguments passed with the command.
 * @return Action Indicates whether the plugin has handled the command.
 */
stock Action Command_DeleteSkill(int args){
    if (args != 1){
        PrintToServer("[AS:RPG] Usage: sm_deleteskill \"<name>\"");
        return Plugin_Handled;
    }

    char name[64];
    GetCmdArg(1, name, sizeof(name));

    DeleteSkillFromDatabase(name);

    return Plugin_Handled;
}

/**
 * @brief Console command handler to list all skills.
 *
 * Displays a list of all skills in the RPG system database.
 *
 * @param client The client index who issued the command.
 * @param args The number of arguments passed with the command.
 * @return Action Indicates whether the plugin has handled the command.
 */
stock Action Command_ListSkills(int client, int args){
    if (args != 0){
        PrintToServer("[AS:RPG] Usage: sm_listskills");
        return Plugin_Handled;
    }


    
    ListSkillsInDatabase(); 

    
    return Plugin_Handled;
}

/**
 * @brief Console command handler to set the skill level for a player.
 *
 * Sets the skill level of a specified player for a specified skill.
 *
 * @param args The number of arguments passed with the command.
 * @return Action Indicates whether the plugin has handled the command.
 */
stock Action Command_SetSkillLevel(int args){
    if (args != 3){
        PrintToServer("[AS:RPG] Usage: sm_addskill \"<player name>\" \"<skill name>\" <level>");
        return Plugin_Handled;
    }

    //char name[64], skillName[256];
    //GetCmdArg(1, name, sizeof(name));
    //GetCmdArg(2, skillName, sizeof(skillName));
    //int level = GetCmdArgInt(3);

    // SetClientSkillToLevel()

    return Plugin_Handled;
}

/**
 * @brief Command to open the main menu.
 *
 * @param client The client index.
 * @param args The number of arguments.
 * @return Action Indicates the command was handled.
 */
stock Action Command_MainMenu(int client, int args) {
    ShowMainMenu(client);
    return Plugin_Handled;
}

// ----------------------------------------------------------------------------------------------------------------
