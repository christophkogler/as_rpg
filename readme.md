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
 - Implements a menu system that doesn't do anything (besides display the list of available skills).
 - Adds multiple commands!
    - Adds console commands to let players see their current kill count and list skills.
    - Adds an admin command to spawn an entity by name on their own marine.
    - Adds a Server command to scale difficulty ConVars.
    - Adds Server commands for creating and removing skills.

### Setup:

1. Install the Alien Swarm: Reactive Drop Dedicated Server through the Steam Library. In the case of AS:RD, the dedicated server installed via the Steam Library is in the same folder as the game: `...\steamapps\common\Alien Swarm Reactive Drop`.
   -  The server files are `srcds.exe` and `srcds_console.exe`.
2. This can be found by right clicking on the server in the library, hovering your mouse over *Manage >* and selecting *Browse Local Files*.
3. Install [SourceMod](https://www.sourcemod.net/downloads.php?branch=stable) and [MetaMod:Source](https://www.sourcemm.net/downloads.php?branch=stable).
4. This plugin uses [swarmtools](https://forums.alliedmods.net/showthread.php?p=1361373).
5. Place swarmtools.inc into `...\sourcemod\scripting\include\`
6. SourceMod comes with the necessary functionality to compile .sp files.  
   - Simply drag and drop the .sp onto the executable at `...\sourcemod\scripting\spcomp.exe`, or execute spcomp.exe targeting the file, ie `path\to\spcomp.exe example\file\path.sp`.
7. Compile both swarmtools.sp and kill_counter.sp using spcomp.
   - This will produce .smx files, which go into your sourcemod\plugins folder.
8. [Set up your MySQL server.](https://dev.mysql.com/doc/mysql-getting-started/en/) This plugin has only been tested with MySQL 8.4 @ localhost.
   - Create a new database, and a user for the server. I reccommend naming the user something like `reactivedropserver`.
10. Alter your database config, `...\Alien Swarm Reactive Drop\reactivedrop\addons\sourcemod\configs\databases.cfg` 'default' options, to match.
   - `host` is the IP of the server. If you are running the dedicated server and the MySQL server on the same computer, this should remain as `localhost`.
   - `database` is the name of the database the server will work in. I recommend `reactivedrop`.
   - `user` is the name of the new MySQL user you made to give the server access.
   - `pass` is the password of the server's MySQL user.
11. Start your dedicated server and count your kills!
