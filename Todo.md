# V1 = Radial = Planet in the centre and you circle it
✅ 1. Add a planet
✅ 2. Camera needs to move to follow the player as they circle the planet
✅ 3. Enemies cirlce the planet too!

# V1.5 (Multiplayer - p2p)
- ✅ Client and server each have names
- ✅ They log 
- ✅ Player sends: movement + position 
- ✅ Player sends shots WITH movement
- ✅ Server adds rockets sent by player
- ✅ Server sends whole game-state (players + enemy group + planet + score + lives)
    - Enemies have UUID etc like rockets
- ✅ Client reacts and renders WHOLE game-state
    - ✅ Game.gd should be able to respond to update current_game_based_on_state.
- ✅ Server sends LIVES and score
- enemies need to be fixed to shoot at players!!

Game.gd:
    - Owns and Serialises state
    - Game engine = game loop + logic
    - Managing networking => networking objects send signals
        - Server sends updatedState => game.gd updates based on that
        - Client 
    - Game loop 
        = Apply updates to game-state from external
        = One tick of game-loop
        = Broadcast any state changes



1. Multiplayer -- First person = Server (with an ip address)
2. 2nd player = client but NOT server
3. Next players join the server... -- by typing in the IP-address??
4. - NOT just localhost
5. Different colours!! (random colour on load)
6. NOT shared life pool

HTTP client, HTTP requests, WebSocket (client) and WebRTC

= SERVER = Pick one player as host - Runs the server
    - Relay server = initialising it and then set it up as P2P
    
= Game state:
    - 1a Send ENTIRE game-state (UDP - so you may lose some frames but it )
        - 1b = send patch of what has changed... 
    - 2b Send all updates as actions and server holds source of truth???
    - GDC talk = https://www.reddit.com/r/Overwatch/comments/apgxco/overwatch_gameplay_architecture_and_netcode_tim/


https://godotengine.org/asset-library/asset/2797

# V1.6 (Hosted in the cloud but still p2p with a cloud instance...)
https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_dedicated_servers.html#doc-exporting-for-dedicated-servers
1. Some sort of lobby / matchmaking??? 
2. or does everyone just join the same instance???
3. 


-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
# Gameplay ideas for improvement!
-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
# V2 = Once you complete it you move to the next planet (which is maybe a touch harder)
- Random environment generation
    - Different planets 
    - Once you clear a planet it loads a new one\
    - Planets have different colours
    - Varying level of difficulty
    - Minimap

# V3 = Mind Control
- Alternative win condition (TBC?)
    - Mind control the space invaders
    - To win them over and turn them into allies
    - Maybe they just stay and defend that planet
    - Allies join you on your quest to the next planet
    - or some gun that converts them to allies


# V4 Fuel Management
- Resource management
    - Fuel that runs out and you have to find as you go
    - Healing


* * *
- Permadeath 
    - TBC if anything carries over into your run
    - Different types of ships with levels of armour and


* * *
Future ideas:
- Tower defense = you build up defense on the planet

* * *
## Resource management
You have to manage your limited resources (e.g. food, healing potions)
and find uses for the resources you receive.

## Exploration and discovery
The game requires careful exploration of the dungeon levels and
discovery of the usage of unidentified items. This has to be done anew
every time the player starts a new game.

## ASCII display
The traditional display for roguelikes is to represent the tiled world
by ASCII characters.

## Dungeons
Roguelikes contain dungeons, such as levels composed of rooms and
corridors.

## Numbers
The numbers used to describe the character (hit points, attributes
etc.) are deliberately shown.


==Low value factors==

## Single player character

The player controls a single character. The game is player-centric,
the world is viewed through that one character and that character's
death is the end of the game.

## Monsters are similar to players## 
Rules that apply to the player apply to monsters as well. They have
inventories, equipment, use items, cast spells etc.

## Tactical challenge
You have to learn about the tactics before you can make any
significant progress. This process repeats itself, i.e. early game
knowledge is not enough to beat the late game. (Due to random
environments and permanent death, roguelikes are challenging to new
players.)

The game's focus is on providing tactical challenges (as opposed to
strategically working on the big picture, or solving puzzles).


* * * 
# Out of scope
## Turn-based

Each command corresponds to a single action/movement. The game is not
sensitive to time, you can take your time to choose your action.  

## Grid-based## 

The world is represented by a uniform grid of tiles. Monsters (and
the player) take up one tile, regardless of size.


## Non-modal

Movement, battle and other actions take place in the same mode. Every
action should be available at any point of the game. Violations to
this are ADOM's overworld or Angand's and Crawl's shops.

## Complexity
The game has enough complexity to allow several solutions to common
goals. This is obtained by providing enough item/monster and item/item
interactions and is strongly connected to having just one mode.
