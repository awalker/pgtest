# pgtest
## Procedural Generation Test

Creates a cave system from cellular automata and/or blasting rooms into the walls. Currently using multi-threaded GDscript, really work is done a separate worker thread. Could possibly split some sections into more workers/threads.

# Milestone TODOs:

* fix the edge generator to get all the edges
* Place entrance and exit (possible support for screen side entrance and exit)
* Place decorative items
* Place treasures
* Place enemies
* Add mode to play test to get a sense of scale for the maps
* Possibly convert the generator to C# for speed boost.

# Possible targets for more threads

* The cellular automata section: The map could be divided into sections and run parallel, however this is not the slowest section
* Finding closest rooms: Each tuple of rooms could be split into another worker. Distances compared at the end