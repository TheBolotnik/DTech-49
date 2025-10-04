"""
Utils package initialization.
Contains utility modules for the application.
"""
from .analytics import Analytics
from .cache import ChatCache
from .logger import AppLogger
from .monitor import PerformanceMonitor

__all__ = [
    'Analytics',
    'ChatCache',
    'AppLogger',
    'PerformanceMonitor'
]

try:
    import psutil
except ImportError:
    raise ImportError("Please install psutil: pip install psutil")