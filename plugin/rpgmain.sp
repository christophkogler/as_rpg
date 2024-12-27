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
    version = "1.0.5",
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

    ConnectToDatabase(); // rpgdatabase

    HookRelevantEvents(); // rpgutility
    CreateCustomCommands(); // rpgutility

    GetSendPropOffsets(); //rpgutility

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
    UpdateDatabase(); // rpgdatabase

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
    PrintToServer("[AS:RPG] Event_PlayerConnect fired. Connecting client index: %d", client);

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
        char sSteamID[32];
        GetClientAuthId(client, AuthId_Steam2, sSteamID, sizeof(sSteamID));
        UpdatePlayerInDatabase(client, sSteamID); // rpgdatabase
        UpdateClientMarineMapping(); // rpgutility
        bool disconnect = true;
        UpdatePlayerDataArray(disconnect, client); // rpgutility
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
    int marineEntityID = event.GetInt("marine");

    if (!IsValidEntity(marineEntityID)) return;    // Early return if invalid killer entity (hopefully handles 'entity 0/worldspawn')

    char killerClassName[64];
    GetEntityClassname(marineEntityID, killerClassName, sizeof(killerClassName));

    if(!StrEqual(killerClassName, "asw_marine")){
        return; // early return if the killing entity was not a marine.
    }

    if(!Swarm_IsGameActive()) return;
    // if we get here, the killer MUST actually be a marine and swarm tools is good to use!

    int attackerWeaponEntityID = -1;
    attackerWeaponEntityID = GetEntityActiveWeaponIndex(marine); // rpgutility

    // get primary ammo type...
    int WeaponAmmoType = -1;
    WeaponAmmoType = GetEntData(attackerWeaponEntityID, g_OFFSET_Weapon_m_iPrimaryAmmoType, 1);
    //WeaponAmmoType = SafeGetEntPropEnt(attackerWeaponEntityID, Prop_Data, "m_iPrimaryAmmoType"); //rpgutility
    PrintToServer("[AS:RPG] OnAlienKilled: Marine %d used weapon %d (ammo type %d) to kill an alien.", marineEntityID, attackerWeaponEntityID, WeaponAmmoType);

    int client = Swarm_GetClientOfMarine(marineEntityID); // swarmtools
    if( Swarm_GetMarine(client) == marineEntityID ){    
        OnPlayerKillAlien(client);
        g_PlayerData[client].kills++;    
        PrintToServer("[AS:RPG] OnAlienKilled: Client %d got a kill.", client);
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
    if (!Swarm_IsGameActive()) return;// swarmtools

    int entindex_killed = event.GetInt("entindex_killed");
    int entindex_attacker = event.GetInt("entindex_attacker");

    if (!IsValidEntity(entindex_killed) || !IsValidEntity(entindex_attacker)) return;    // Early return if invalid entities

    char modelName[256];
    char victimClassname[256];
    char attackerClassname[256];

    GetEntityClassname(entindex_killed, victimClassname, sizeof(victimClassname));
    GetEntPropString(entindex_killed, Prop_Data, "m_ModelName", modelName, sizeof(modelName));
    GetEntityClassname(entindex_attacker, attackerClassname, sizeof(attackerClassname));

    if (StrEqual(attackerClassname, "asw_marine")){    
        if (IsClassnameAnAlien(victimClassname)){ // rpgutility
            int AlienExperienceValue = GetExperienceForAlienClass(victimClassname); // rpgutility
            int SharedExperience = RoundToNearest( float(AlienExperienceValue) * ExperienceSharingRate);
            int client = Swarm_GetClientOfMarine(entindex_attacker); // swarmtools
            
            // give other actively playing clients some of the experience. You don't miss out (much!) when killing things with a team!

            if( Swarm_GetMarine(client) == entindex_attacker ){    // if attacking marine is controlled by a player, give the player experience.
                g_PlayerData[client].experience += AlienExperienceValue;
                PrintToServer("[AS:RPG] OnEntityKilled: Client %d (entity %d) killed %s and earned %d XP.", client, entindex_attacker, victimClassname, AlienExperienceValue);
                for(int otherClients = 0; otherClients < MaxClients; otherClients++){
                    if(otherClients != client && g_ClientToMarine[otherClients] != -1 && IsClientConnected(otherClients)){
                        g_PlayerData[otherClients].experience += SharedExperience; // experiencesharingrate in rpgglobals.
                    }
                }
                PrintToServer("[AS:RPG] OnEntityKilled: All clients besides %d earned %d XP for a squad player kill.", client, SharedExperience);
            }
            else{ // if killing marine is NOT being actively controlled by a player,
                for(int allClients = 0; allClients < MaxClients; allClients++){
                    if(g_ClientToMarine[allClients] != -1 && IsClientConnected(allClients)){
                        g_PlayerData[allClients].experience += SharedExperience; // experiencesharingrate in rpgglobals.
                    }
                }
                PrintToServer("[AS:RPG] OnEntityKilled: All clients earned %d XP for a squad bot kill.", client, SharedExperience);
            }
        }
    }

    // Debug output; what just died?
    //PrintToServer("[AS:RPG] OnEntityKilled: Entity killed: index %d, classname '%s', model name '%s'", entindex_killed, victimClassname, modelName);
}
// -------------------------------------------------------------------------------------------------------






// -------------------------------------- Forwards. -------------------------------------------------------
/**
 * @brief OnClientAuthorized, retrieve the client index from the event and initializes their data in the server.
 * 
 * The DB uses getsteamauth to get SteamID. Client needs to be connected enough to authorize before updating player data array.
 *
 * @param event The event data.
 * @param name The name of the event.
 * @param dontBroadcast Whether to broadcast the event.
 */
public void OnClientAuthorized(int client, const char[] auth){
    if (client > 0){
        UpdateClientMarineMapping(); // rpgutility
        bool disconnecting = false;
        UpdatePlayerDataArray(disconnecting, client); // rpgutility
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
    // hook every entities OnTakeDamage at creation, because this makes the process simple.
    // almost zero delay on entity creation, slower entity OnTakeDamage's.
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

    // If a new asw_marine is created, update client-marine mapping.
    if (StrEqual(classname, "asw_marine")){UpdateClientMarineMapping();} // rpgutility
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
    if(!IsValidEntity(victim)){        PrintToServer("[AS:RPG] [ERROR] Invalid entity took damage?");        return Plugin_Continue;    } 
    if(!IsValidEntity(attacker)){        PrintToServer("[AS:RPG] [ERROR] Invalid entity dealt damage?");        return Plugin_Continue;    }
    
    // Get victim, attacker, and inflictor class names
    GetEntityClassname(victim, VictimClass, sizeof(VictimClass));
    GetEntityClassname(attacker, AttackerClass, sizeof(AttackerClass));
    //GetEntityClassname(inflictor, InflictorClass, sizeof(InflictorClass));

    // separated the classname and client checks into two layers for tiny efficiency. 
    // those nanoseconds MIGHT start to matter if server gets to doing 100+ of these per second, which WILL be ON TOP of everything the engine is already doing. 
    // probably only have a few microseconds/call max before server tickrate dies under heavy load! need to try to be efficient here! (consider: worst case is a full squad with smgs/miniguns + multiple turrets vs max swarm / high hp boss)
    // of course i'm not ACTUALLY profiling anything so I can only find out if it's efficient enough by putting a server through the wringer.... annoying! 

    // if victim is a marine, controlled by a player, apply the player's damage reduction...
    if (StrEqual(VictimClass, "asw_marine")){
        int client = Swarm_GetClientOfMarine(victim);
        if (Swarm_GetMarine(client) == victim){
            float damageAdjustment = CalculateMarineDamageReduction(victim, damage, damagetype);  // rpgutility
            if(damageAdjustment != 0.00){
                damage *= damageAdjustment;
                changedDamageValue = true;
            }
        }
    }
    // if attacker is a marine, controlled by a player, apply the player's damage boosts...
    else if(StrEqual(AttackerClass, "asw_marine")){
        int client = Swarm_GetClientOfMarine(attacker);
        if (Swarm_GetMarine(client) == attacker){
            float damageAdjustment = CalculateMarineDamageBoost(attacker, damagetype); // rpgutility
            if(damageAdjustment != 0.00){
                damage *= damageAdjustment;
                changedDamageValue = true;
            }
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
    UpdateDatabase(); //rpgdatabase
    return Plugin_Continue;
}
// --------------------------------------------------------------------------------------------------------------



// -------------------------------------- Experimental Junkyard -------------------------------------------------------

/*
// display all ammo reserves for a given marineEntityID
    if (g_OFFSET_Marine_m_iAmmo > 0){
        // int offset = g_OFFSET_Marine_m_iAmmo + (g_OFFSET_Weapon_m_iPrimaryAmmoType * 4);
        // int ammoCount = GetEntData(marineEntityID, offset, 4);

        for (int i = 0; i < g_MaxAmmoSlots; i++){
            // Each integer ammo type in the m_iAmmo array is spaced by 4 bytes
            // int offset = g_OFFSET_Marine_m_iAmmo + (i * 4);
            // int ammoCount = GetEntData(marineEntityID, offset, 4);
            // PrintToServer("[AS:RPG] Marine %d Ammo Index %d: %d", marineEntityID, i, ammoCount);
        }
    }
*/