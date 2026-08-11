# resilience/txlog.py
import json, time

class TransactionLog:
    def __init__(self, path="transactions.log"):
        self.path = path
    def append(self, op, table, key, before, after, user):
        entry = {"ts": time.time(), "op": op, "table": table, "key": key,
                 "before": before, "after": after, "user": user}
        with open(self.path, "a") as f:                 # append-only
            f.write(json.dumps(entry) + "\n")
    def entries_since(self, ts):
        for line in open(self.path):
            e = json.loads(line)
            if e["ts"] >= ts:
                yield e
    def replay(self, db, since_ts):
        for e in self.entries_since(since_ts):
            if e["op"] == "UPDATE":
                db.execute(f"UPDATE {e['table']} SET data=? WHERE id=?",
                           (e["after"], e["key"]))
            elif e["op"] == "INSERT":
                db.execute(f"INSERT INTO {e['table']}(id,data) VALUES(?,?)",
                           (e["key"], e["after"]))
    def undo(self, db, key, table):
        prior = None
        for line in open(self.path):
            e = json.loads(line)
            if e["table"] == table and e["key"] == key:
                prior = e["before"] if prior is None else prior
        if prior is not None:
            db.execute(f"UPDATE {table} SET data=? WHERE id=?", (prior, key))
