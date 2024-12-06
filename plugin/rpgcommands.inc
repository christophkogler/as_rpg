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

// Command: sm_addskill <name> <description> <max_level>
stock Action Command_AddSkill(int args){
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

stock Action Command_ListSkills(int args){
    if (args != 0){
        PrintToServer("[AS:RPG] Usage: sm_listskills");
        return Plugin_Handled;
    }
    ListSkillsInDatabase();
    return Plugin_Handled;
}
// ----------------------------------------------------------------------------------------------------------------
