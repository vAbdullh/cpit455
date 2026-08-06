import logging
logging.basicConfig(filename="safety_hazard.log", level=logging.INFO)

class SafetyMonitor:
    """Independent damage-limitation layer. Vetoes and alarms on any breach."""
    
    def __init__(self, db_query, max_occupancy=20):
        self.q = db_query  # Pass your database query function here[cite: 1]
        self.max_occupancy = max_occupancy
        self.suspended = False

    def check_and_enroll(self, student_id, has_training):
        # SSR6: Block if the system is suspended[cite: 1]
        if self.suspended:
            raise Exception("System suspended awaiting reset")

        # 1. Independently re-read from the database[cite: 1]
        current_occupancy = self.q("SELECT COUNT(*) FROM student")

        # 2. Check limits independently[cite: 1]
        if not has_training:
            self._alarm(student_id, "No safety training")
            return
            
        if current_occupancy >= self.max_occupancy:
            self._alarm(student_id, "Room capacity exceeded")
            return

        # 3. Safe to proceed[cite: 1]
        self.q(f"INSERT INTO student (student_id) VALUES ({student_id})")
        logging.info(f"SAFE enroll for {student_id}")

    def _alarm(self, student_id, reason):
        # Log the alarm and suspend the system[cite: 1]
        logging.info(f"ALARM student={student_id} reason={reason} -> SUSPEND")
        self.suspended = True

    def reset(self):
        self.suspended = False