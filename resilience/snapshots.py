# resilience/snapshots.py
import shutil, os, time, glob

class SnapshotManager:
    def __init__(self, db_path, snap_dir="snapshots", keep=10):
        self.db_path, self.snap_dir, self.keep = db_path, snap_dir, keep
        os.makedirs(snap_dir, exist_ok=True)
    def take(self):
        name = f"{self.snap_dir}/snap_{int(time.time())}.db"
        shutil.copyfile(self.db_path, name)
        self._prune()
        return name
    def _prune(self):
        snaps = sorted(glob.glob(f"{self.snap_dir}/snap_*.db"))
        for old in snaps[:-self.keep]:
            os.remove(old)
    def latest_good(self, verify_fn):
        for snap in sorted(glob.glob(f"{self.snap_dir}/snap_*.db"), reverse=True):
            if verify_fn(snap):
                return snap
        return None
