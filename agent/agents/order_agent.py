"""Read-only security incident lookups. The specialist agent OPA authorizes for the
`demo-agent` role by default (see policy/policies/tool_access.rego)."""
from agent.db import fetch_all, fetch_one

_SELECT = """
    SELECT i.incident_id, e.name AS employee_name, e.email AS email, e.ssn AS ssn, e.department,
           d.name AS device, d.ip_address, i.incident_type, i.status
    FROM security_incidents i
    JOIN employees e ON e.employee_id = i.employee_id
    JOIN devices d ON d.device_id = i.device_id
"""


def search_incidents(query: str) -> list[dict]:
    sql = _SELECT + (
        " WHERE CAST(i.incident_id AS TEXT) ILIKE :q OR i.incident_type ILIKE :q"
        " OR i.status ILIKE :q OR d.name ILIKE :q OR e.department ILIKE :q"
    )
    return fetch_all(sql, {"q": f"%{query}%"})


def get_incident(incident_id: int) -> dict:
    return fetch_one(_SELECT + " WHERE i.incident_id = :iid", {"iid": incident_id}) or {}


NAME = "incident_agent"
DESCRIPTION = "Looks up security incidents (read-only)."
TOOLS = {"search_incidents": search_incidents, "get_incident": get_incident}
TOOL_SCHEMAS = [
    {
        "type": "function",
        "function": {
            "name": "search_incidents",
            "description": "Search security incidents by incident id, incident type, status, device name, or department.",
            "parameters": {"type": "object", "properties": {"query": {"type": "string"}}, "required": ["query"]},
        },
    },
    {
        "type": "function",
        "function": {
            "name": "get_incident",
            "description": "Look up a single security incident (includes employee name, email, SSN and device) by numeric incident id.",
            "parameters": {"type": "object", "properties": {"incident_id": {"type": "integer"}}, "required": ["incident_id"]},
        },
    },
]