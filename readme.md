# AS:RPG
A RPG-style SourceMod plugin for Alien Swarm: Reactive Drop.

Currently, it persistently tracks each player's kills in a database, and allows them to see their total kills. It has a few dummy skills that do nothing. It also doubles the autogun and prototype rifle's damage.

### Setup:

1. Install the Alien Swarm: Reactive Drop Dedicated Server through the Steam Library. In the case of AS:RD, the dedicated server installed via the Steam Library is in the same folder as the game: `steamapps\common\Alien Swarm Reactive Drop\reactivedrop`.
2. This can be found by right clicking on the server in the library, hovering your mouse over *Manage >* and selecting *Browse Local Files*.
3. Install [SourceMod](https://www.sourcemod.net/downloads.php?branch=stable) and [MetaMod:Source](https://www.sourcemm.net/downloads.php?branch=stable).
4. This plugin uses [swarmtools](https://forums.alliedmods.net/showthread.php?p=1361373).
5. Place swarmtools.inc into `...\sourcemod\scripting\include\`
6. SourceMod comes with the necessary functionality to compile .sp files.  
   Simply drag and drop the .sp onto the executable at `...\sourcemod\scripting\spcomp.exe`, or execute spcomp.exe targeting the file, ie `path\to\spcomp.exe example\file\path.sp`.
7. Compile both swarmtools.sp and kill_counter.sp using spcomp.
   This will produce .smx files, which go into your sourcemod\plugins folder.
8. Start your dedicated server and count your kills!
