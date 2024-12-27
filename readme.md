# AS:RPG
A RPG-style SourceMod plugin for Alien Swarm: Reactive Drop.
<br>
<br>
## INCOMPLETE! WIP!
I try to only commit functional code, but I can't catch any (or probably even most!) bugs. Sorry!
<br>
<br>
<br>
Currently, it:
 - Uses an SQL database to hold players, player_skills, and skills tables.
 - Persistently tracks each player's stats (kills, experience).
 - Automatically implements a few dummy skills that do nothing.
 - Implements a menu system that allows acquiring and removing skills.
 - Returns a bullet to your gun for every kill :)
 - Adds multiple commands!
    - Adds console commands to let players see their current kill count, open the main menu, and list all skills - sm_killcount, sm_menu, and sm_listskills.
    - Adds an admin command to spawn an entity by name on their own marine, sm_spawnentity.
    - Adds a Server command to scale difficulty ConVars, sm_difficultyscale.
    - Adds Server commands for creating and removing skills, sm_addskill and sm_deleteskill.

### Setup:

1. Install the Alien Swarm: Reactive Drop Dedicated Server through the Steam Library. In the case of AS:RD, the dedicated server installed via the Steam Library is in the same folder as the game: `...\steamapps\common\Alien Swarm Reactive Drop`.
   -  The server files are `srcds.exe` and `srcds_console.exe`.
   -  This directory can be found by right clicking on the server in the library, hovering your mouse over *Manage >* and selecting *Browse Local Files*.
2. Install [SourceMod](https://www.sourcemod.net/downloads.php?branch=stable) and [MetaMod:Source](https://www.sourcemm.net/downloads.php?branch=stable).
3. This repository provides a minorly modified version of [swarmtools](https://forums.alliedmods.net/showthread.php?p=1361373).
   - Swarmtools only requires a tiny modification to work in Reactive Drop - I just disabled the check for if it was in Alien Swarm.
4. Place swarmtools.inc and all AS:RPG include files into `...\steamapps\common\Alien Swarm Reactive Drop\reactivedrop\addons\sourcemod\scripting\include\`.
5. SourceMod comes with the necessary functionality to compile .sp files.  
   - Simply drag and drop the .sp file onto the executable at `...\steamapps\common\Alien Swarm Reactive Drop\reactivedrop\addons\sourcemod\scripting\spcomp.exe`
   - **OR** use command prompt to execute spcomp.exe targeting the file, ie `path\to\spcomp.exe "example\file\path.sp"`.
6. Compile both swarmtools.sp and rpgmain.sp using spcomp.exe.
   - This will produce .smx files, which go into your sourcemod\plugins folder.
7. [Set up your MySQL server.](https://dev.mysql.com/doc/mysql-getting-started/en/) This plugin has only been tested with MySQL 8.4 @ localhost.
   - Create a new database and a user for the server. I reccommend naming the database `reactivedrop` and the user something like `reactivedropserver`.  
8. Alter your database config, `...\steamapps\common\Alien Swarm Reactive Drop\reactivedrop\addons\sourcemod\configs\databases.cfg` 'default', to match your MySQL server.
   - `host` is the IP of the server. If you are running the dedicated server and the MySQL server on the same computer, this should remain as `localhost`.
   - `database` is the name of the database the server will work in.
   - `user` is the name of the new MySQL user you made for the server.
   - `pass` is the password for the server's user.
9. You should be ready to go!
