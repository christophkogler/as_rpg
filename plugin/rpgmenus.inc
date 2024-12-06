#if defined _rpgmenus_included
 #endinput
#endif
#define _rpgmenus_included

#include <rpgglobals>

// -------------------------------------- Menus ----------------------------------------------------

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
