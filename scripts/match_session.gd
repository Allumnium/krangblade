extends Node
# Roster survives scene transitions; every peer receives it in the start RPC.
var roster: Dictionary = {}

func clear_roster() -> void:
    roster.clear()
