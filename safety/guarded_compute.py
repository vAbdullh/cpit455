# safety/guarded_compute.py
from occupancy_check import safe_enrollment, SafetyViolation

def compute_and_guard(current_occupancy, has_safety_training):
    """
    Wraps the logic so any arithmetic exception fails safely rather 
    than propagating a corrupt value[cite: 1].
    """
    try:
        # Normal functional logic (which might contain a hidden fault)
        proposed_occupancy = current_occupancy + 1
    except (OverflowError, ArithmeticError, ValueError):
        # Arithmetic fail-safe[cite: 1]
        return current_occupancy 
    
    # Pass the result through the independent safety clamp[cite: 1]
    return safe_enrollment(current_occupancy, has_safety_training)