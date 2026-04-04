class_name CharacterRoster
extends Resource

@export var names: Array[String] # all possible names
@export var cyberware_pool: Array[Cyberware] # all possible cyberware
@export var min_cyberware: int = 1
@export var max_cyberware: int = 3
