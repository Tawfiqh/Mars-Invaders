# V1 = Radial = Planet in the centre and you circle it
1. Add a planet
2. Camera needs to move to follow the player as they circle the planet


- Minimap
# V2 = Once you complete it you move to the next planet (which is maybe a touch harder)
- Random environment generation
    - Different planets 
    - Once you clear a planet it loads a new one\
    - Planets have different colours
    - Varying level of difficulty


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
