"""
Quest definitions for Dice Dungeon
"""

from typing import Dict
from .quests import Quest, QuestStatus


def create_default_quests() -> Dict[str, Quest]:
    """
    Create the default quest set.
    Placeholder for now - will be filled in later with actual quests.
    """
    quests = {}
    
    # Example placeholder quest
    # quests["first_blood"] = Quest(
    #     id="first_blood",
    #     name="First Blood",
    #     description="Defeat your first enemy",
    #     status=QuestStatus.NOT_STARTED,
    #     objectives={"enemies_defeated": 1},
    #     rewards={"gold": 10, "exp": 5},
    #     floor_unlocked=1
    # )
    
    return quests
