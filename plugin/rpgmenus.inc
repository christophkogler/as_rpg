#if defined _rpgmenus_included
 #endinput
#endif
#define _rpgmenus_included

// -------------------------------------- Menu Constructors ----------------------------------------------------
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
 * @brief Displays the skills menu using global arrays.
 *
 * @param client The client index.
 */
stock void MakeSkillsMenu(int client) {
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
stock void MakeSkillDetailMenuForPlayer(int client, int skillID) {
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

    // Build and display skill detail menu...
    Menu skillDetailMenu = CreateMenu(SkillDetailMenuHandler, MENU_ACTIONS_ALL);

    // Construct menu title with detailed information
    char menuTitle[512];
    Format(menuTitle, sizeof(menuTitle), 
           "Skill Details\nName: %s\nDescription: %s\nType: %s\nExperience Cost: %d\nLevel: %d/%d", 
           skill.skillName, skill.skillDescription, skill.type, skill.experience_cost, currentLevel, skill.maxLevel);
    skillDetailMenu.SetTitle(menuTitle);

    // Add purchase and refund options
    // only display the buttons the player SHOULD have access to. if they are at max level, they can't purchase more; if they don't have it, they can't refund it.
    if(currentLevel < skill.maxLevel) skillDetailMenu.AddItem("#purchase", "Purchase");
    if(hasSkill)    skillDetailMenu.AddItem("#refund", "Refund");

    // Add back option
    skillDetailMenu.AddItem(BACKCHOICE, "Back to Skills");
    skillDetailMenu.ExitButton = true;

    skillDetailMenu.Display(client, MENU_TIME_FOREVER);
}
// --------------------------------------------------------------------------------------------



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
            int client = param1;
            int menuItemPosition = param2;

            char info[32];
            menu.GetItem(menuItemPosition, info, sizeof(info));
            if (StrEqual(info, MAIN_MENU_VIEW_SKILLS)) {
                PrintToServer("[AS:RPG] Client %d selected View Skills.", client);
                MakeSkillsMenu(client); // Open the skills menu
            } else if (StrEqual(info, BACKCHOICE)) {
                PrintToServer("[AS:RPG] Client %d selected Exit", client);
                // Optionally handle exit
            } else {
                PrintToServer("[AS:RPG] Client %d selected unknown option: %s", client, info);
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
                MakeSkillDetailMenuForPlayer(client, skillID); // Fetch and show skill details
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
            int client = param1;
            int menuItemIndex = param2;

            char info[32];
            menu.GetItem(menuItemIndex, info, sizeof(info));
            PrintToServer("[AS:RPG] MenuAction_Select: menu info for item at %d: %s", menuItemIndex, info);
            if (StrEqual(info, PURCHASECHOICE)) {
                HandlePurchaseSkill(client, g_ClientLookingAtSkillID[client]); // rpgutility
                MakeSkillDetailMenuForPlayer(client, g_ClientLookingAtSkillID[client]);
            } else if (StrEqual(info, REFUNDCHOICE)) {
                HandleRefundSkill(client, g_ClientLookingAtSkillID[client]); // rpgutility
                MakeSkillDetailMenuForPlayer(client, g_ClientLookingAtSkillID[client]);
            } else if (StrEqual(info, BACKCHOICE)) {
                MakeSkillsMenu(client);
            } else {
                PrintToServer("[AS:RPG] Client %d selected unknown option: %s", client, info);
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
