"""Resolves security incidents — a genuine database WRITE, not a read-only lookup.
Still OPA-authorized and AGT-screened before it runs, same as every other
tool; the point is that "allowed to write" and "governed on every write"
are not mutually exclusive."""
from agent.db import execute, fetch_one


def resolve_incident(incident_id: int) -> dict:
    incident = fetch_one("SELECT incident_id, status FROM security_incidents WHERE incident_id = :iid", {"iid": incident_id})
    if not incident:
        return {"status": "error", "reason": f"incident {incident_id} not found"}
    execute("UPDATE security_incidents SET status = 'Resolved' WHERE incident_id = :iid", {"iid": incident_id})
    return {"status": "Resolved", "incident_id": incident_id}


NAME = "remediation_agent"
DESCRIPTION = "Resolves security incidents (writes to the database)."
TOOLS = {"resolve_incident": resolve_incident}
TOOL_SCHEMAS = [
    {
        "type": "function",
        "function": {
            "name": "resolve_incident",
            "description": "Mark a security incident as Resolved, by its numeric incident id.",
            "parameters": {"type": "object", "properties": {"incident_id": {"type": "integer"}}, "required": ["incident_id"]},
        },
    }
]