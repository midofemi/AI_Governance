package governance.tool_access

test_demo_agent_can_read_orders {
    allow with input as {"subject": {"role": "demo-agent"}, "tool": "get_incident"}
}

test_demo_agent_can_resolve_incident {
    allow with input as {"subject": {"role": "demo-agent"}, "tool": "resolve_incident"}
}

test_demo_agent_cannot_purge {
    not allow with input as {"subject": {"role": "demo-agent"}, "tool": "purge_employee_data"}
}

test_demo_agent_cannot_route_to_admin_agent {
    not allow with input as {"subject": {"role": "demo-agent"}, "tool": "route:admin_agent"}
}

test_admin_can_purge {
    allow with input as {"subject": {"role": "admin"}, "tool": "purge_employee_data"}
}

test_unknown_role_denied_with_reason {
    not allow with input as {"subject": {"role": "nobody"}, "tool": "get_incident"}
    reason != "" with input as {"subject": {"role": "nobody"}, "tool": "get_incident"}
}
