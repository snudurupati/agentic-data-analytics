"""Print the message board and the task list of a Claude Code agent team as they change.

An agent team keeps its state in plain files under ~/.claude:

    ~/.claude/teams/<team>/config.json            who is on the team
    ~/.claude/teams/<team>/inboxes/<agent>.json   messages waiting for each agent
    ~/.claude/tasks/<team>/                       the shared task list

Claude Code removes the teams folder when the session ends. This script polls those files once a
second, prints every new message and every task status change, and appends each event to a log
file, so the record outlives the session.

Usage, in a second terminal, before starting the team:

    python3 tools/board.py                  # watch every team
    python3 tools/board.py --log board.log  # choose where the log goes

Standard library only. Stop it with Ctrl+C.
"""

import argparse
import json
import time
from datetime import datetime
from pathlib import Path

CLAUDE_HOME = Path.home() / ".claude"
TEAMS = CLAUDE_HOME / "teams"
TASKS = CLAUDE_HOME / "tasks"


def read_json(path):
    """Return the parsed file, or None while it is missing or half written."""
    try:
        return json.loads(path.read_text())
    except (OSError, ValueError):
        return None


def first(entry, *names):
    """Return the first field present in a dictionary, so small format changes do not break the watcher."""
    for name in names:
        if isinstance(entry, dict) and entry.get(name) not in (None, ""):
            return entry[name]
    return None


def message_text(entry):
    """Return the readable part of a message.

    A plain message carries its words in "text". A status update from Claude Code, such as a
    teammate going idle or failing, carries a JSON object inside "text" instead.
    """
    text = first(entry, "text", "content", "message", "body", "summary")
    if isinstance(text, str) and text.startswith("{"):
        try:
            text = json.loads(text)
        except ValueError:
            pass
    if isinstance(text, dict):
        kind = text.get("type", "status")
        detail = first(text, "failureReason", "summary", "result", "content") or ""
        reason = text.get("idleReason")
        text = f"[{kind}{': ' + reason if reason else ''}] {detail}"
    return " ".join(str(text or entry).split())


def inbox_entries(data):
    """An inbox file holds a list of messages, or an object with a list inside it."""
    if isinstance(data, list):
        return data
    if isinstance(data, dict):
        for key in ("messages", "inbox", "items"):
            if isinstance(data.get(key), list):
                return data[key]
    return []


def task_entries(folder):
    """Each task is a JSON file in the team's task folder."""
    for path in sorted(folder.glob("*.json")):
        data = read_json(path)
        if isinstance(data, dict):
            yield path.stem, data


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--log", default="board.log", help="file that keeps every event")
    parser.add_argument("--interval", type=float, default=0.25, help="seconds between polls")
    parser.add_argument("--width", type=int, default=160, help="characters of each message to print")
    args = parser.parse_args()

    seen_messages = set()
    task_state = {}
    log = open(args.log, "a", encoding="utf-8")

    def emit(kind, team, line, raw, recipient=None):
        stamp = datetime.now().strftime("%H:%M:%S")
        print(f"{stamp}  {line[: args.width]}", flush=True)
        event = {"seen_at": stamp, "kind": kind, "team": team, "to": recipient, "line": line, "raw": raw}
        log.write(json.dumps(event) + "\n")
        log.flush()

    print(f"Watching {TEAMS} and {TASKS}. Log: {args.log}", flush=True)
    while True:
        for inbox in sorted(TEAMS.glob("*/inboxes/*.json")):
            team, recipient = inbox.parent.parent.name, inbox.stem
            for entry in inbox_entries(read_json(inbox)):
                key = (team, recipient, json.dumps(entry, sort_keys=True))
                if key in seen_messages:
                    continue
                seen_messages.add(key)
                sender = first(entry, "from", "sender", "from_agent") or "?"
                emit("message", team, f"MSG   {sender} -> {recipient}: {message_text(entry)}", entry, recipient)

        for folder in sorted(p for p in TASKS.glob("*") if p.is_dir()):
            team = folder.name
            for task_id, task in task_entries(folder):
                status = first(task, "status") or "?"
                owner = first(task, "owner", "assignee") or "unassigned"
                subject = first(task, "subject", "title", "description") or ""
                state = (status, owner)
                if task_state.get((team, task_id)) == state:
                    continue
                task_state[(team, task_id)] = state
                emit("task", team, f"TASK  #{task_id} [{status}] {owner}: {subject}", task)

        time.sleep(args.interval)


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        pass
