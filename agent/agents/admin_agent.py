"""Destructive, irreversible operations (data erasure). Neither the
`demo-agent` role nor routing to this agent at all is in tool_access.rego's
allow-list for demo-agent — two layered checks (route + tool) have to both
say yes before purge_employee_data ever runs."""
from agent.db import execute


def purge_employee_data(employee_id: int) -> dict:
    rowcount = execute("DELETE FROM employees WHERE employee_id = :eid", {"eid": employee_id})
    return {"status": "purged" if rowcount else "not_found", "employee_id": employee_id}


NAME = "admin_agent"
DESCRIPTION = "Destructive admin operations (data purges). Admin-only."
TOOLS = {"purge_employee_data": purge_employee_data}
TOOL_SCHEMAS = [
    {
        "type": "function",
        "function": {
            "name": "purge_employee_data",
            "description": "Permanently delete an employee and all their security incidents. Destructive and irreversible.",
            "parameters": {"type": "object", "properties": {"employee_id": {"type": "integer"}}, "required": ["employee_id"]},
        },
    }
]
