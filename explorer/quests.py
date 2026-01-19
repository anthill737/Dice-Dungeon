"""
Quest system for Dice Dungeon
"""

from enum import Enum
from dataclasses import dataclass
from typing import TYPE_CHECKING, Dict, Any, Optional

if TYPE_CHECKING:
    from dice_dungeon_explorer import DiceDungeonExplorer


class QuestStatus(Enum):
    """Status of a quest"""
    NOT_STARTED = "not_started"
    IN_PROGRESS = "in_progress"
    COMPLETED = "completed"
    FAILED = "failed"


@dataclass
class Quest:
    """Represents a quest in the game"""
    id: str
    name: str
    description: str
    status: QuestStatus
    objectives: Dict[str, Any]
    rewards: Dict[str, Any]
    floor_unlocked: int = 1
    
    
class QuestManager:
    """
    Manages quests in the game.
    Will be filled in with full implementation later.
    """
    
    def __init__(self, game: "DiceDungeonExplorer"):
        self.game = game
        self.quests: Dict[str, Quest] = {}
        
    def register_default_quests(self, quest_dict: Dict[str, Quest]):
        """Register the default quests"""
        self.quests.update(quest_dict)
        
    def get_quest(self, quest_id: str) -> Optional[Quest]:
        """Get a quest by ID"""
        return self.quests.get(quest_id)
        
    def update_quest_progress(self, quest_id: str, progress_data: Dict[str, Any]):
        """Update quest progress (stub for now)"""
        pass
        
    def complete_quest(self, quest_id: str):
        """Mark a quest as complete (stub for now)"""
        if quest_id in self.quests:
            self.quests[quest_id].status = QuestStatus.COMPLETED
