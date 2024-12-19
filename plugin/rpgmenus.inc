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
    // get a snapshot of the global skills stringmap
    StringMapSnapshot snapshot = view_as<StringMapSnapshot>(CreateTrieSnapshot(g_SkillList));
    int skillsCount = snapshot.Length;
    // iterate through the snapshot length
    for (new i = 0; i < skillsCount; i++) {
        // get the i-th key value
        char key[32];    snapshot.GetKey(i, key, sizeof(key));
        // build skill page
        SkillData skill;
        g_SkillList.GetArray(key, skill, sizeof(skill)); // enums have to be retrieved as arrays(?)
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
 * @brief Fetches and displays skill details for a specific skill.
 *
 * @param client The client index.
 * @param skillID The skill ID to display details for.
 */
stock void FetchPlayerSkillLevel(int client, int skillID) {
    // Transform the skillID to a string
    char skillIDStr[16];
    IntToString(skillID, skillIDStr, sizeof(skillIDStr));

    // Get current level of the skill, if they have it.
    int currentLevel = 0;
    StringMap playerSkillsTrie = g_PlayerData[client].skillsTrie;
    bool hasSkill = GetTrieValue(playerSkillsTrie, skillIDStr, currentLevel);

    // Fetch the skill's details from the global skill list
    SkillData skill;
    g_SkillList.GetArray(skillIDStr, skill, sizeof(skill));

    // If we couldn't retrieve the skill from their skill list, the player doesn't have the skill yet, so make sure current level is 0
    // is this even a necessary step? GetTrieValue shouldn't modify variable until after type checks, right?
    if (!hasSkill) {   currentLevel = 0;   }

    // Build and display skill detail menu
    BuildAndShowSkillDetailMenu(client, skill, currentLevel);
}

/**
 * @brief Builds and displays the skill detail submenu.
 *
 * @param client The client index.
 * @param skill The skill to display.
 * @param currentLevel The player's current level of the skill.
 */
stock void BuildAndShowSkillDetailMenu(int client, SkillData skill, int currentLevel) {
    Menu skillDetailMenu = CreateMenu(SkillDetailMenuHandler, MENU_ACTIONS_ALL);

    // Construct menu title with detailed information
    char menuTitle[512];
    Format(menuTitle, sizeof(menuTitle), 
           "Skill Details\nName: %s\nDescription: %s\nType: %s\nExperience Cost: %d\nLevel: %d/%d", 
           skill.skillName, skill.skillDescription, skill.type, skill.experience_cost, currentLevel, skill.maxLevel);
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
    PrintToServer("[AS:RPG] Client %d attempted to purchase skill %d.", client, g_ClientLookingAtSkillID[client]);
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
    // check if the player has the skill in their skill list
    // check if the skillid has a value in the client's playerdata skillstrie
    StringMap playerDataSkillsTrie = g_PlayerData[client].skillsTrie;

    int skillLevel = 0;
    char skillIDStr[16];

    IntToString(g_ClientLookingAtSkillID[client], skillIDStr,sizeof(skillIDStr));

    bool playerHasSkill = playerDataSkillsTrie.GetValue(skillIDStr,skillLevel); // if we can get the value, the player has at least A level of the skill.

    if(playerHasSkill){
        if(skillLevel == 1){
            // refund skill
            playerDataSkillsTrie.Remove(skillIDStr);
            // RemovePlayerSkill(client, g_ClientLookingAtSkillID[client]);
        }
        // UpdatePlayerSkillLevel
    }
    PrintToServer("[AS:RPG] Client %d attempted to refund skill %d.", client, g_ClientLookingAtSkillID[client]);
    PrintToChat(client, "Refund functionality is not yet implemented.");
}


// ------------------------------- Menu Handlers --------------------------------------------

/**
 * @brief Main menu handler.
 *
 * @param menu The current menu handle.
 * @param action The menu action being handled.
 * @param param1 Client index or menu action context.
 * @param param2 Menu item index or data context.
 * @return int Indicates whether the action was handled successfully.
 */
stock int MenuHandler1(Menu menu, MenuAction action, int param1, int param2) {
    switch (action) {
        case MenuAction_Start:{      
            PrintToServer("Displaying Main Menu");
        }

        case MenuAction_Display:{
            //char buffer[255];
            //Format(buffer, sizeof(buffer), "", "Character Overview", param1);
        
            //Panel panel = view_as<Panel>(param2);
            //panel.SetTitle(buffer);
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
 * @param menu The current menu handle.
 * @param action The menu action being handled.
 * @param param1 Client index or menu action context.
 * @param param2 Menu item index or data context.
 * @return int Indicates whether the action was handled successfully.
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
            int client = param1;
            int menuItemPosition = param2;
            char info[32];
            menu.GetItem(menuItemPosition, info, sizeof(info));
            if (StrEqual(info, BACKCHOICE)) {    ShowMainMenu(client);    } 
            else {
                int skillID = StringToInt(info);
                PrintToServer("[AS:RPG] Client %d selected skill ID: %d", client, skillID);
                g_ClientLookingAtSkillID[client] = skillID;
                FetchPlayerSkillLevel(client, skillID); // Fetch and show skill details
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
 * @param menu The current menu handle.
 * @param action The menu action being handled.
 * @param param1 Client index or menu action context.
 * @param param2 Menu item index or data context.
 * @return int Indicates whether the action was handled successfully.
 */
stock int SkillDetailMenuHandler(Menu menu, MenuAction action, int param1, int param2) {
    switch (action) {
        /*
        case MenuAction_DrawItem:{
            int style;
            char info[32];
            menu.GetItem(param2, info, sizeof(info), style);
            return style;    
        }
        */
        case MenuAction_Select: {
            char info[32];
            menu.GetItem(param2, info, sizeof(info));
            PrintToServer("[AS:RPG] MenuAction_Select: menu info for item at %d: %s", param2, info);
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
        case MenuAction_Cancel:{
            int client = param1;
            g_ClientLookingAtSkillID[client] = 0; // reset when they close the skilldetailmenu
            // menu cancelation reason code is param2
        }
        case MenuAction_End: {    CloseHandle(menu);    }
    }
    return 0;
}
