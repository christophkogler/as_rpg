/*
Alien Swarm: Reactive drop PluGin, A.K.A., AS:RPG
    -   Persistent!

    TO-DO:
    -   New varieties of enemies? Various HL2 mobs should be available - IE antlion, combine and zombie varieties.
        -   Few combines, enemies that shoot back SUCK in Alien Swarm, UNLESS I can make them and the swarm hostile to each other.
    -   Minibosses - enemies with effects, auras, increased health/speed/damage.
    -   Earn experience by killing enemies. Harder / rarer enemies give more experience.
        -   Hold your experience to level up (increase stats like max hp, move speed, minor damage and resistance boosts).
        -   Spend it to get skills (boost damage / gain resistances / regenerate ammo )
    -   Spend experience on leveling up (increase max hp, boost damage and resistances a small amount) or getting skills (boost damage / gain resistances / regenerate ammo / bigger magazines / more reloads)



    -   Damage boost goes forever, resistances cap at 99%, minimum damage to marines is 1(?). Even at 99%, getting hit 100 times by drones = die.
*/

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <dbi>
#include <swarmtools>

#include "rpgglobals"
#include "rpgcommands"
#include "rpgdatabase"
#include "rpgmenus"
#include "rpgutility"

public Plugin myinfo = {
    name = "AS:RPG",
    author = "Christoph Kogler",
    description = "Gain experience, level up, acquire skills, and conquer increasingly difficult challenges.",
    version = "1.0.4",
    url = "https://github.com/christophkogler/as_rpg"
};


// ------------------------- Plugin utility functions. ----------------------------------------------------
/**
 * @brief Called when the plugin is started.
 *
 * Initializes kill counters, connects to the database, hooks events, registers console commands, and creates a timer for database updates.
 */

public void OnPluginStart()
{
    PrintToServer("[AS:RPG] Initializing Alien Swarm: RPG!");

    // Initialize some variables... 
    // (this has to be done at runtime because... sourcepawn, I think? IDK. Seems to break if declared before plugin startup.)
    g_SkillList = new StringMap();
    for (int i = 0; i <= MaxClients; i++){    g_PlayerData[i].Init();    }

    ConnectToDatabase(); // rpgdatabase.inc

    HookRelevantEvents(); // rpgutility.inc
    CreateCustomCommands();

    CreateTimer(30.0, Timer_UpdateDatabase, _, TIMER_REPEAT);
}

/**
 * @brief Called when the plugin is unloaded.
 *
 * Updates the database one last time and cleans up the database handle.
 */
public void OnPluginEnd()
{
    // Update the database one last time
    UpdateDatabase();

    if (g_hDatabase != null)
    {
        delete g_hDatabase;
        g_hDatabase = null;
    }
}
//--------------------------------------------------------------------------------------------



// -------------------------------------- Hooked events. ----------------------------------------------------------
/**
 * @brief Handles the player connect event.
 *
 * Retrieves the client index from the event and initializes their data in the server.
 *
 * @param event The event data.
 * @param name The name of the event.
 * @param dontBroadcast Whether to broadcast the event.
 */
public void Event_PlayerConnect(Event event, const char[] name, bool dontBroadcast){
    /*
    int client = event.GetInt("index") + 1;
    //PrintToServer("[AS:RPG] Event_PlayerConnect fired. Connecting client index: %d", client);

    if (client > 0){
        UpdateClientMarineMapping();
        bool disconnect = false;
        UpdatePlayerDataArray(disconnect, client);
    }
    else{
        PrintToServer("[AS:RPG] ERROR! Connecting client ID was less than zero?")
    }
    */
}


/**
 * @brief Handles the player disconnect event.
 *
 * Updates the database and client-marine mapping when a player disconnects.
 *
 * @param event The event data.
 * @param name The name of the event.
 * @param dontBroadcast Whether to broadcast the event.
 */
public void Event_PlayerDisconnect(Event event, const char[] name, bool dontBroadcast){
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (client > 0){    
        UpdateDatabase();    
        UpdateClientMarineMapping();
        bool disconnect = true;
        UpdatePlayerDataArray(disconnect, client);
    }
}


/**
 * @brief Called when an alien is killed.
 *
 * Increments the kill counter for the corresponding client who killed the alien. Also, give them one extra bullet.
 *
 * @param event The event data.
 * @param name The name of the event.
 * @param dontBroadcast Whether to broadcast the event.
 */
public void Event_AlienDied(Event event, const char[] name, bool dontBroadcast){
    int client = -1;
    int marineEntityID = event.GetInt("marine");
    if (Swarm_IsGameActive()) client = Swarm_GetClientOfMarine(marineEntityID);
    PrintToServer("[AS:RPG] OnAlienKilled: Client killing alien was %d, using marine %d.", client, marineEntityID)
    if (client != -1){
        int attackerWeaponEntityID = -1;
        int weaponMaxAmmo = 0;
        int currentAmmo = 0;

        attackerWeaponEntityID = SafeGetEntPropEnt(marineEntityID, Prop_Send, "m_hActiveWeapon");
        if (attackerWeaponEntityID == -1){
            PrintToServer("[AS:RPG] Client %d's marine %d killed an alien without an active weapon?", client, marineEntityID);
        } 

        currentAmmo = SafeGetEntProp(marineEntityID, Prop_Send, "m_iAmmo");
        if (currentAmmo == -1){
            PrintToServer("[AS:RPG] Failed to get m_iAmmo or -1 max ammo for client %d's marine %d's weapon entity %d.", client, marineEntityID, attackerWeaponEntityID);
        } 
        else{
            PrintToServer("[AS:RPG] m_iAmmo = %d", currentAmmo);
        }

        weaponMaxAmmo = SafeGetEntProp(attackerWeaponEntityID, Prop_Send, "m_iPrimaryAmmoCount");
        if (weaponMaxAmmo == -1){
            PrintToServer("[AS:RPG] Failed to get m_iPrimaryAmmoCount or -1 max ammo for client %d's marine %d's weapon entity %d.", client, marineEntityID, attackerWeaponEntityID);
        } 

        //SetEntProp(marineEntityID, Prop_Send, "m_iAmmo", currentAmmo+1)

        g_ClientKillAccumulator[client]++;    
    }
}

/**
 * @brief Called when any entity is killed.
 *
 * Logs details about the killed entity and awards experience if applicable.
 *
 * @param event The event data.
 * @param name The name of the event.
 * @param dontBroadcast Whether to broadcast the event.
 */
public void Event_EntityKilled(Event event, const char[] name, bool dontBroadcast){
    if (!Swarm_IsGameActive()) return;

    int entindex_killed = event.GetInt("entindex_killed");
    int entindex_attacker = event.GetInt("entindex_attacker");

    if (!IsValidEntity(entindex_killed) || !IsValidEntity(entindex_attacker)) return;    // Early return if invalid entities

    char victimClassname[256];
    GetEntityClassname(entindex_killed, victimClassname, sizeof(victimClassname));

    char modelName[256];
    GetEntPropString(entindex_killed, Prop_Data, "m_ModelName", modelName, sizeof(modelName));

    char attackerClassname[256];
    GetEntityClassname(entindex_attacker, attackerClassname, sizeof(attackerClassname));

    if (StrEqual(attackerClassname, "asw_marine")){    
        // Example: Determine experience based on victim class
        int experienceGained = GetExperienceForAlienClass(victimClassname);
        int client = Swarm_GetClientOfMarine(entindex_attacker);
        if (client != -1){
            g_ClientExperienceAccumulator[client] += experienceGained;
            g_ClientKillAccumulator[client]++;
            PrintToServer("[AS:RPG] Client %d killed %s and earned %d XP.", client, victimClassname, experienceGained);
        }
        // give other actively playing clients 25% the experience. You don't miss out (much!) when killing things as a group! 
        for(int otherClients = 0; otherClients < MaxClients; otherClients++){
            if(otherClients == client || g_ClientToMarine[otherClients] == -1 || !IsClientConnected(otherClients)) continue;
            g_ClientExperienceAccumulator[otherClients] += RoundToNearest( float(experienceGained) * ExperienceSharingRate);
        }
    }

    // Debug output
    PrintToServer("[AS:RPG] Entity killed: index %d, classname '%s', model name '%s'", entindex_killed, victimClassname, modelName);
}
// -------------------------------------------------------------------------------------------------------



// -------------------------------------- Forwards. -------------------------------------------------------
/**
 * @brief OnClientAuthorized, retrieve the client index from the event and initializes their data in the server.
 * 
 * The DB uses getsteamauth to get SteamID. Client needs to be connected enough to authorize to update player data array.
 *
 * @param event The event data.
 * @param name The name of the event.
 * @param dontBroadcast Whether to broadcast the event.
 */
public void OnClientAuthorized(int client, const char[] auth){
    if (client > 0){
        UpdateClientMarineMapping();
        bool disconnect = false;
        UpdatePlayerDataArray(disconnect, client);
    }
}

/**
 * @brief Called when an entity is created in the game.
 *
 * Hooks the OnTakeDamage event for the entity and updates client-marine mapping if an ASW marine is created.
 *
 * @param entity The entity index of the created entity.
 * @param classname The classname of the created entity.
 */
public void OnEntityCreated(int entity, const char[] classname){    
    // I hook every entities OnTakeDamage at creation, because this makes the process simple.
    SDKHook(entity, SDKHook_OnTakeDamage, OnTakeDamage);

    /*
    float random = GetRandomFloat(0.0, 1.0);
    if (StrEqual(classname, "asw_drone") && Swarm_IsGameActive() && random < increasedSwarmSizeChance && currentSwarmSizeCounter <= maxSwarmSizeIncrease){
        currentSwarmSizeCounter++;
        PrintToServer("Spawn group size increased by %d", currentSwarmSizeCounter);
        float position[3];
        GetEntPropVector(entity, Prop_Send, "m_vecOrigin", position);    // get the location of the client's marine
        float angles[3] = {0.0, 0.0, 0.0}; // Default angles
        SpawnEntityByName("asw_drone", position, angles, "", 0.0, false);
    }
    currentSwarmSizeCounter = 0;
    */

    // If an asw_marine is created, update the mapping.
    if (StrEqual(classname, "asw_marine")){UpdateClientMarineMapping();}
}

/**
 * @brief Handles the event when an entity takes damage.
 *
 * Adjusts damage based on the victim and attacker classes and their attributes.
 *
 * @param victim The entity index of the victim.
 * @param attacker A reference to the entity index of the attacker.
 * @param inflictor A reference to the entity index of the inflictor.
 * @param damage A reference to the damage value.
 * @param damagetype A reference to the type of damage.
 * @return Action Whether the plugin has changed the damage value.
 */
public Action OnTakeDamage(victim, &attacker, &inflictor, &Float:damage, &damagetype){
    decl String:VictimClass[64];
    decl String:AttackerClass[64];
    decl String:InflictorClass[64];

    bool changedDamageValue = false;

    // make sure the victim and attacker are valid entities.
    if(!IsValidEntity(victim)){
        PrintToServer("[AS:RPG] [ERROR] Invalid entity took damage?");
        return Plugin_Continue;
    } 
    if(!IsValidEntity(attacker)){
        PrintToServer("[AS:RPG] [ERROR] Invalid entity dealt damage?");
        return Plugin_Continue;
    }
    
    // Get victim, attacker, and inflictor class names
    GetEntityClassname(victim, VictimClass, sizeof(VictimClass));
    GetEntityClassname(attacker, AttackerClass, sizeof(AttackerClass));
    GetEntityClassname(inflictor, InflictorClass, sizeof(InflictorClass));

    // if victim is a marine, we (will) need to apply player damage reduction stuff...
    if (StrEqual(VictimClass, "asw_marine")){
        // damage = CalculateMarineDamageReduction(victim, damage, damagetype)
        // changedDamageValue = true;
        if(damagetype != 4){
            PrintToServer("[AS:RPG] [DEBUGGING] A marine took a new type of damage: %d", damagetype);
        }
    } 
    // if the attacker is a marine, calculate damage boost(s)...
    else if(StrEqual(AttackerClass, "asw_marine")){
        float damageAdjustment = CalculateMarineDamageBoost(attacker, damagetype);
        if(damageAdjustment != 0.00){
            damage *= damageAdjustment;
            changedDamageValue = true;
        }
    }

    // Debug output
    //PrintToServer("[AS:RPG] [DEBUGGING] OnTakeDamage: victim %d (%s), attacker %d (%s), inflictor %d (%s), weapon %s, damage %f, damagetype %d", victim, VictimClass, attacker, AttackerClass, inflictor, InflictorClass, WeaponName, damage, damagetype);

    if(changedDamageValue){    return Plugin_Changed;    }
    else{    return Plugin_Continue;    }
}
//----------------------------------------------------------------------------------------------------------------



// ---------------------------------------------- Timers --------------------------------------------------------
// (only database update loop rn, but maybe active skill cooldowns one day?)
/**
 * @brief Timer callback to periodically update the database with accumulated kills.
 *
 * Invoked by a repeating timer to ensure kill data is regularly saved to the database.
 *
 * @param timer The handle to the timer.
 * @return Action Indicates whether the plugin should continue running the timer.
 */
public Action Timer_UpdateDatabase(Handle timer){
    UpdateDatabase();
    return Plugin_Continue;
}
// --------------------------------------------------------------------------------------------------------------



// -------------------------------------- Experimental Junkyard -------------------------------------------------------
