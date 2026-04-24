"""
GME Agent Session Logger
Writes agent activity, token usage, workflow status, and events
to memory/session-log.json for the live dashboard.

Usage:
    from scripts.session_logger import log_event, set_agent_state, set_workflow_status
"""

import json
import os
from pathlib import Path
from datetime import datetime

LOG_PATH = Path(__file__).parent.parent / "memory" / "session-log.json"

def _load():
    if LOG_PATH.exists():
        with open(LOG_PATH, "r") as f:
            return json.load(f)
    return {}

def _save(data):
    with open(LOG_PATH, "w") as f:
        json.dump(data, f, indent=2)

def init_session(model="claude-sonnet-4-6", context_window=200000):
    data = _load()
    data["session"]["id"] = f"gme-{datetime.now().strftime('%Y%m%d-%H%M%S')}"
    data["session"]["started"] = datetime.now().isoformat()
    data["session"]["model"] = model
    data["session"]["context_window"] = context_window
    data["token_usage"] = {
        "system_tokens": 0,
        "context_file_tokens": 0,
        "history_tokens": 0,
        "current_query_tokens": 0,
        "input_tokens_total": 0,
        "output_tokens_total": 0,
        "tasks_run": 0
    }
    for agent in data["agents"]:
        agent["state"] = "idle"
        agent["task"] = ""
        agent["last_active"] = ""
    for wf in data["critical_workflows"].values():
        wf["status"] = "clear"
        wf["last_checked"] = ""
    data["log"] = []
    _save(data)
    log_event("system", "Session initialized", sys=True)

def set_agent_state(agent_name, state, task=""):
    """state: 'idle' | 'active' | 'running'"""
    data = _load()
    now = datetime.now().strftime("%H:%M:%S")
    for agent in data["agents"]:
        if agent["name"] == agent_name:
            agent["state"] = state
            agent["task"] = task
            agent["last_active"] = now
        elif state in ("active", "running") and agent["state"] == "active" and agent["name"] != agent_name:
            pass
    _save(data)

def log_event(agent_name, message, sys=False, level="info"):
    data = _load()
    now = datetime.now().strftime("%H:%M:%S")
    entry = {
        "ts": now,
        "agent": agent_name,
        "msg": message,
        "sys": sys,
        "level": level
    }
    data["log"].append(entry)
    if len(data["log"]) > 300:
        data["log"] = data["log"][-300:]
    _save(data)

def set_workflow_status(workflow_key, status, note=""):
    """
    workflow_key: duty_hours | resident_grievance | accreditation_risk | medicare_funding | affiliation_agreement
    status: clear | active | escalated
    """
    data = _load()
    now = datetime.now().isoformat()
    if workflow_key in data["critical_workflows"]:
        data["critical_workflows"][workflow_key]["status"] = status
        data["critical_workflows"][workflow_key]["last_checked"] = now
        if note:
            data["critical_workflows"][workflow_key]["note"] = note
    _save(data)
    if status != "clear":
        log_event("Orchestrator", f"Critical workflow triggered: {workflow_key} — {status}", level="warn")

def update_tokens(input_tokens=0, output_tokens=0, task_ran=False):
    data = _load()
    tu = data["token_usage"]
    tu["input_tokens_total"] += input_tokens
    tu["output_tokens_total"] += output_tokens
    if task_ran:
        tu["tasks_run"] += 1
    _save(data)

def set_context_breakdown(system=0, context_files=0, history=0, current_query=0):
    data = _load()
    tu = data["token_usage"]
    tu["system_tokens"] = system
    tu["context_file_tokens"] = context_files
    tu["history_tokens"] = history
    tu["current_query_tokens"] = current_query
    _save(data)

def complete_agent(agent_name, result_summary=""):
    set_agent_state(agent_name, "idle", "")
    log_event(agent_name, f"Complete — {result_summary}" if result_summary else "Complete")
