# safety/occupancy_check.py
MAX_OCCUPANCY = 20 # Configured safe maximum room capacity

class SafetyViolation(Exception):
    """Exception raised when a safety rule or occupancy limit is violated."""


def safe_enrollment(current_occupancy, has_safety_training):
    """
    Safety clamp that enforces physical limits.
    Returns a SAFE number of enrollees or fails safely.
    """
    # SSR5: Withhold enrollment if student lacks safety training
    if not has_safety_training:
        return current_occupancy 
    
    # SSR1 equivalent: Never exceed the safe physical room occupancy
    if current_occupancy >= MAX_OCCUPANCY:
        return MAX_OCCUPANCY
    
    return current_occupancy + 1