#if defined _rpgglobals_included
 #endinput
#endif
#define _rpgglobals_included

// ----------------------------------------- Definitions, global variables, and enums. -----------------------------------------------

// -------------------- Definitions ------------------------------
// Database config is in databases.cfg.
#define DATABASE_CONFIG "default"

// Menu connections.
#define MAIN_MENU_VIEW_SKILLS "#view_skills"
#define BACKCHOICE "#back"
#define PURCHASECHOICE "#purchase"
#define REFUNDCHOICE "#refund"
// -----------------------------------------------------------------

// -------------------------- Enums ---------------------------------------------
// load all skills from database into a global data structure on plugin load?
// more efficient to take up an extra 10mb of ram than hit a SQL server anytime somebody looks at the skill menu.
// same reason for the PlayerData array.

/**
 * @brief Struct to hold skill data.
 *
 * Contains experience points, level, skill points, and kill count for each player.
 */
enum struct SkillData {
    int skillID;
    char skillName[64];
    char skillDescription[256];
    int maxLevel;
    char type[32];
    int experience_cost;
}
// how to make an array of appropriate size???
// how to define the size of a GLOBAL array from OnPluginStart???

/**
 * @brief Struct to hold player-specific data.
 *
 * Contains experience points, level, skill points, and kill count for each player.
 */
enum struct PlayerData {
    int experience;
    int level;
    int skill_points;
    int kills;
    StringMap skillsTrie; // Trie to store skill ids (keys) and levels (values)
}

/**
 * @brief Enumeration for identifying different table types during creation.
 *
 * Used to determine which table has been processed in the OnCreateTableFinished callback.
 */
enum TableType {
    TableType_Players = 1,
    TableType_Skills = 2,
    TableType_PlayerSkills = 3
};

/**
 * @brief Enumeration for identifying different skill types during initialization.
 *
 * Used to determine which skill has been processed in the OnInitializeSkillFinished callback.
 */
enum SkillType {
    SkillType_DamageBoost = 1,
    SkillType_HealthRegen = 2
};
// ----------------------------------------------------------------------------------------------------------


// --------------------------- Variables, arrays ----------------------------------------

Database g_hDatabase = null;                // Global database handle
ArrayList g_SkillList = null;               // Global skill ArrayList handle

int g_ClientToMarine[MAXPLAYERS + 1];                       // array that tracks which client goes to which marine: clienttomarine[client] = marine
int g_ClientKillAccumulator[MAXPLAYERS + 1];                // array that tracks each alien a person kills              between db updates
int g_ClientExperienceAccumulator[MAXPLAYERS + 1];          // array that tracks how much client each person has        between db updates

PlayerData g_PlayerData[MAXPLAYERS + 1];                    // array of playerdata to hold player data? IDK, its NOT complete or ready.

// --------------- These settings are tune-able without immediately breaking things. Use with caution. --------------------
const float ExperienceSharingRate = 0.25; // 0 - inf. greather than 1 would be kind of dumb.

// ---------------------------------------------------------------------------------------------------------------------