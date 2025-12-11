"""
Debug Logger for Dice Dungeon Explorer
Automatically activates when running from VS Code or when DEBUG env var is set
"""

import logging
import os
import sys
from datetime import datetime

class DebugLogger:
    """Centralized debug logging system with automatic VS Code detection"""
    
    def __init__(self):
        self.enabled = self._should_enable_debug()
        self.logger = None
        
        if self.enabled:
            self._setup_logger()
    
    def _should_enable_debug(self):
        """Detect if we're running from VS Code or debug mode is requested"""
        # Check for VS Code environment
        if os.environ.get('TERM_PROGRAM') == 'vscode':
            return True
        
        # Check for explicit debug flag
        if os.environ.get('DEBUG') == '1':
            return True
        
        # Check if running from VS Code Python extension
        if 'VSCODE_PID' in os.environ:
            return True
        
        # Check command line args
        if '--debug' in sys.argv:
            return True
        
        return False
    
    def _setup_logger(self):
        """Configure the logger with file and console output"""
        # Create logs directory if needed
        log_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'logs')
        os.makedirs(log_dir, exist_ok=True)
        
        # Create log file with timestamp
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        log_file = os.path.join(log_dir, f'debug_{timestamp}.log')
        
        # Configure logger
        self.logger = logging.getLogger('DiceDungeon')
        self.logger.setLevel(logging.DEBUG)
        
        # File handler - detailed logs
        file_handler = logging.FileHandler(log_file, encoding='utf-8')
        file_handler.setLevel(logging.DEBUG)
        file_formatter = logging.Formatter(
            '%(asctime)s | %(levelname)-8s | %(name)s | %(message)s',
            datefmt='%H:%M:%S'
        )
        file_handler.setFormatter(file_formatter)
        
        # Console handler - important logs only
        console_handler = logging.StreamHandler(sys.stdout)
        console_handler.setLevel(logging.INFO)
        console_formatter = logging.Formatter(
            '[%(levelname)s] %(message)s'
        )
        console_handler.setFormatter(console_formatter)
        
        # Add handlers
        self.logger.addHandler(file_handler)
        self.logger.addHandler(console_handler)
        
        self.logger.info("=" * 80)
        self.logger.info("DEBUG LOGGING ENABLED")
        self.logger.info(f"Log file: {log_file}")
        self.logger.info("=" * 80)
    
    def debug(self, category, message, **kwargs):
        """Log debug message with category"""
        if not self.enabled or not self.logger:
            return
        
        extra_info = ' | '.join(f'{k}={v}' for k, v in kwargs.items())
        full_message = f"[{category}] {message}"
        if extra_info:
            full_message += f" | {extra_info}"
        
        self.logger.debug(full_message)
    
    def info(self, category, message, **kwargs):
        """Log info message with category"""
        if not self.enabled or not self.logger:
            return
        
        extra_info = ' | '.join(f'{k}={v}' for k, v in kwargs.items())
        full_message = f"[{category}] {message}"
        if extra_info:
            full_message += f" | {extra_info}"
        
        self.logger.info(full_message)
    
    def warning(self, category, message, **kwargs):
        """Log warning message with category"""
        if not self.enabled or not self.logger:
            return
        
        extra_info = ' | '.join(f'{k}={v}' for k, v in kwargs.items())
        full_message = f"[{category}] {message}"
        if extra_info:
            full_message += f" | {extra_info}"
        
        self.logger.warning(full_message)
    
    def error(self, category, message, **kwargs):
        """Log error message with category"""
        if not self.enabled or not self.logger:
            return
        
        extra_info = ' | '.join(f'{k}={v}' for k, v in kwargs.items())
        full_message = f"[{category}] {message}"
        if extra_info:
            full_message += f" | {extra_info}"
        
        self.logger.error(full_message)
    
    def combat(self, message, **kwargs):
        """Log combat-specific message"""
        self.info("COMBAT", message, **kwargs)
    
    def ui(self, message, **kwargs):
        """Log UI-specific message"""
        self.debug("UI", message, **kwargs)
    
    def dice(self, message, **kwargs):
        """Log dice-specific message"""
        self.debug("DICE", message, **kwargs)
    
    def state(self, message, **kwargs):
        """Log state change message"""
        self.info("STATE", message, **kwargs)
    
    def button(self, message, **kwargs):
        """Log button interaction message"""
        self.debug("BUTTON", message, **kwargs)
    
    def navigation(self, message, **kwargs):
        """Log navigation message"""
        self.info("NAVIGATION", message, **kwargs)

# Global logger instance
_debug_logger = DebugLogger()

def get_logger():
    """Get the global debug logger instance"""
    return _debug_logger

def is_debug_enabled():
    """Check if debug logging is enabled"""
    return _debug_logger.enabled
