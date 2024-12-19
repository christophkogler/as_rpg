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

    void Init(){
        this.experience = 0;            this.level = 1;
        this.skill_points = 0;          this.kills = 0;
        this.skillsTrie = new StringMap(); // skillIDAsString, skill level -> key, val
    }
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

// --------------- These settings are tune-able without immediately breaking things. Use with caution. --------------------
const float ExperienceSharingRate = 0.25; // 0 - inf. greather than 1 would be kind of dumb.
// ------------------------------------------------------------------------------------------------------------------------

// simple varaibles that can be fully initialized now
int g_ClientToMarine[MAXPLAYERS + 1] = {-1};                        // which client goes to which marine. clienttomarine[client id] = marine entity id
int g_ClientKillAccumulator[MAXPLAYERS + 1] = {0};                  // how many aliens a person has killed between db updates
int g_ClientExperienceAccumulator[MAXPLAYERS + 1] = {0};            // how much experience each client has earned between db updates
int g_ClientLookingAtSkillID[MAXPLAYERS+1] = {0};                   // the skill ID that the client is currently looking at in the skill detail menu.

// these variables have their initialization completed on plugin startup.
Database g_hDatabase = null;                    // Global database handle.
StringMap g_SkillList = null;                   // Global StringMap of SkillData. skill id in database, SkillData for the skill -> key, value
PlayerData g_PlayerData[MAXPLAYERS + 1];        // Global array of playerdata's to hold player data. g_PlayerData[clientID] = ClientPlayerData

// ---------------------------------------------------------------------------------------------------------------------