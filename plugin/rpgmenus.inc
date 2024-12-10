#if defined _rpgmenus_included
 #endinput
#endif
#define _rpgmenus_included

// -------------------------------------- Menus ----------------------------------------------------
/**
 * @brief Displays the main menu to the client.
 *
 * @param client The client index.
 */
stock void ShowMainMenu(int client) {
    // Create a menu with a callback and actions
    Menu menu = CreateMenu(MenuHandler1, MENU_ACTIONS_ALL);
    
    // Set the title of the menu
    //menu.SetTitle("%T", "Main Menu Title", LANG_SERVER);
    menu.SetTitle("", "Character Overview");
    
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
stock Action Menu_Test1(int client, int args) {
    ShowMainMenu(client);
    return Plugin_Handled;
}


/**
 * @brief Displays the skills menu using global arrays.
 *
 * @param client The client index.
 */
stock void FetchSkillsAndShowMenu(int client) {
    Menu skillMenu = CreateMenu(SkillMenuHandler, MENU_ACTIONS_ALL);
    skillMenu.SetTitle("Available Skills");

    bool skillsFound = false;

    // Iterate through global skill list
    for (int i = 0; i < g_SkillList.Length; i++) {
        SkillData skill;
        g_SkillList.GetArray(i, skill);
        char info[32];
        Format(info, sizeof(info), "%d", skill.skillID);
        skillMenu.AddItem(info, skill.skillName, ITEMDRAW_DEFAULT);
        skillsFound = true;
    }

    // If no skills are found, display a message
    if (!skillsFound) {
        skillMenu.AddItem(BACKCHOICE, "No skills available");
    }

    // Add a back option
    skillMenu.AddItem(BACKCHOICE, "Back to Main Menu");
    skillMenu.ExitButton = true;

    skillMenu.Display(client, MENU_TIME_FOREVER);
}

/**
 * @brief Fetches and displays skill details using global arrays.
 *
 * @param client The client index.
 * @param skillID The selected skill's ID.
 */
stock void FetchPlayerSkillLevel(int client, int skillID) {
    // Get player's skill level from global player data
    char skillIDStr[16];
    IntToString(skillID, skillIDStr, sizeof(skillIDStr));

    int currentLevel = 0;
    StringMap playerSkillsTrie = StringMap:g_PlayerData[client].skillsTrie;
    bool hasSkill = GetTrieValue(playerSkillsTrie, skillIDStr, currentLevel);

    // Fetch skill details from global skill list
    SkillData skill;
    for (int i = 0; i < g_SkillList.Length; i++) {
        g_SkillList.GetArray(i, skill);
        if (skill.skillID == skillID) break;
    }

    // If the player doesn't have the skill yet, current level is 0
    if (!hasSkill) {
        currentLevel = 0;
    }

    // Build and display skill detail menu
    BuildAndShowSkillDetailMenu(client, skillID, skill.skillName, skill.skillDescription, skill.maxLevel, currentLevel, skill.type, skill.experience_cost);
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
 * @param type The skill's type (e.g., Active, Passive).
 * @param experienceCost The experience cost for the skill.
 */
stock void BuildAndShowSkillDetailMenu(int client, int skillID, const char[] skillName, const char[] skillDescription, int maxLevel, int currentLevel, const char[] type, int experienceCost) {
    Menu skillDetailMenu = CreateMenu(SkillDetailMenuHandler, MENU_ACTIONS_ALL);

    // Construct menu title with detailed information
    char menuTitle[512];
    Format(menuTitle, sizeof(menuTitle), 
           "Skill Details\nName: %s\nDescription: %s\nType: %s\nExperience Cost: %d\nLevel: %d/%d", 
           skillName, skillDescription, type, experienceCost, currentLevel, maxLevel);
    skillDetailMenu.SetTitle(menuTitle);

    // Add purchase and refund options
    skillDetailMenu.AddItem("#purchase", "Purchase");
    skillDetailMenu.AddItem("#refund", "Refund");

    // Add back option
    skillDetailMenu.AddItem(BACKCHOICE, "Back to Skills");
    skillDetailMenu.ExitButton = true;

    skillDetailMenu.Display(client, MENU_TIME_FOREVER);
}

// ------------------------ Purchase and Refund Handlers -------------------------------

/**
 * @brief Handles the purchase of a skill.
 *
 * @param client The client index.
 * @param menu The current menu handle.
 */
stock void HandlePurchaseSkill(int client, Menu menu) {
    // TODO: Implement purchase logic
    // 1. Determine the skillID from the menu context or item info.
        // extract menu title > break string at first space/newline > find item in g_SkillData by name to get skillID
    // 2. Check if the player has enough experience to purchase.
    // 3. Deduct experience and increase skill level in the database.
    // 4. Notify the player of the successful purchase.
    char menuTitle[512];
    GetMenuTitle(menu, menuTitle, sizeof(menuTitle));

    PrintToServer("[AS:RPG] Client %d attempted to purchase a skill.", client);
    PrintToChat(client, "Purchase functionality is not yet implemented.");
}

/**
 * @brief Handles the refund of a skill.
 *
 * @param client The client index.
 * @param menu The current menu handle.
 */
stock void HandleRefundSkill(int client, Menu menu) {
    // TODO: Implement refund logic
    // Example steps:
    // 1. Determine the skillID from the menu context or item info.
    // 2. Check if the player can refund the skill.
    // 3. Add experience and decrease skill level in the database.
    // 4. Notify the player of the successful refund.
    char menuTitle[512];
    GetMenuTitle(menu, menuTitle, sizeof(menuTitle));
    // break string by spaces, first piece is title
    // retrieve skill information from global list by name
    PrintToServer("[AS:RPG] Client %d attempted to refund a skill.", client);
    PrintToChat(client, "Refund functionality is not yet implemented.");
}


// ------------------------------- Menu Handlers --------------------------------------------
/**
 * @brief Main menu handler.
 *
 * Handles selections in the main menu.
 */
stock int MenuHandler1(Menu menu, MenuAction action, int param1, int param2) {
    switch (action) {
        case MenuAction_Start:{      
            PrintToServer("Displaying Main Menu");
        }

        case MenuAction_Display:{
            char buffer[255];
            Format(buffer, sizeof(buffer), "", "Character Overview", param1);
        
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
stock int SkillMenuHandler(Menu menu, MenuAction action, int param1, int param2) {
    switch (action) {
        case MenuAction_Start:{
        }

        case MenuAction_Display:{
            PrintToServer("[AS:RPG] Displaying Skills Menu for Client %d!", param1);
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
stock int SkillDetailMenuHandler(Menu menu, MenuAction action, int param1, int param2) {
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
