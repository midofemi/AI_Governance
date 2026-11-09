#!/bin/bash
# Runs automatically on first Postgres startup (official image convention:
# anything in /docker-entrypoint-initdb.d/ runs once, against an empty data
# volume). Creates a small but real relational schema plus two
# least-privilege application roles, distinct from the postgres superuser —
# the DB-level "blast radius ceiling" underneath the app-level OPA/AGT
# checks, not a replacement for them.
set -e

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    CREATE TABLE employees (
        employee_id SERIAL PRIMARY KEY,
        name TEXT NOT NULL,
        email TEXT NOT NULL,
        ssn TEXT NOT NULL,
        department TEXT NOT NULL
    );

    CREATE TABLE devices (
        device_id SERIAL PRIMARY KEY,
        name TEXT NOT NULL,
        device_type TEXT NOT NULL,
        ip_address TEXT NOT NULL
    );

    CREATE TABLE security_incidents (
        incident_id SERIAL PRIMARY KEY,
        employee_id INTEGER NOT NULL REFERENCES employees(employee_id) ON DELETE CASCADE,
        device_id INTEGER NOT NULL REFERENCES devices(device_id),
        incident_type TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'Open',
        created_at TIMESTAMP NOT NULL DEFAULT now()
    );

    INSERT INTO employees (name, email, ssn, department) VALUES
        ('Amidu Kamara', 'amidu.kamara@hq.dhs.gov', '912-45-6781', 'LAC'),
        ('John Merrill', 'john.merrill@hq.dhs.gov', '923-56-7812', 'Cyber Security'),
        ('Donald Coulter', 'donald.coulter@hq.dhs.gov', '934-67-8923', 'HSARPA'),
        ('Cameron Whitelam', 'cameron.whitelam@hq.dhs.gov', '945-78-9034', 'BIAC'),
        ('Anthony Ayodele', 'anthony.ayodele@hq.dhs.gov', '956-89-0145', 'Cyber Security');

    INSERT INTO devices (name, device_type, ip_address) VALUES
        ('Laptop-001', 'Laptop', '192.168.1.10'),
        ('Server-001', 'Server', '192.168.1.20'),
        ('Desktop-001', 'Desktop', '192.168.1.30'),
        ('Firewall-001', 'Firewall', '192.168.1.1'),
        ('Laptop-002', 'Laptop', '192.168.1.40');

    INSERT INTO security_incidents (employee_id, device_id, incident_type, status) VALUES
        (1, 1, 'Phishing Attempt', 'Investigating'),
        (2, 2, 'Unauthorized Access', 'Open'),
        (3, 3, 'Malware Detection', 'Resolved'),
        (4, 4, 'Suspicious Login', 'Investigating'),
        (5, 5, 'Data Exfiltration Alert', 'Closed');

    -- Tamper-evident audit trail (agent/audit_log.py) — OPA's decision_logs
    -- plugin POSTs every policy decision to POST /internal/audit-log, which
    -- hash-chains each row here. decided_at is TEXT, not TIMESTAMPTZ, on
    -- purpose: Postgres reformats timestamps on round-trip (different
    -- precision/offset display), which silently broke hash verification
    -- during testing — TEXT preserves the exact original string the hash
    -- was computed over.
    CREATE TABLE audit_log (
        id BIGSERIAL PRIMARY KEY,
        decision_id TEXT NOT NULL UNIQUE,
        opa_path TEXT NOT NULL,
        input JSONB NOT NULL,
        result JSONB NOT NULL,
        decided_at TEXT NOT NULL,
        ingested_at TIMESTAMPTZ NOT NULL DEFAULT now(),
        prev_hash TEXT NOT NULL,
        entry_hash TEXT NOT NULL
    );

    -- Used by the agent service. Can read all 3 tables, can UPDATE order
    -- status (billing_agent.issue_refund), can DELETE customers
    -- (admin_agent.purge_customer_data). Whether a given request is ever
    -- allowed to reach these grants at all is OPA's/AGT's job, checked
    -- BEFORE any SQL runs — this role is the ceiling, not the gate.
    CREATE ROLE agent_app LOGIN PASSWORD '${AGENT_APP_DB_PASSWORD}';
    GRANT SELECT ON employees, devices, security_incidents TO agent_app;
    GRANT UPDATE (status) ON security_incidents TO agent_app;
    GRANT DELETE ON employees TO agent_app;
    GRANT SELECT, INSERT ON audit_log TO agent_app;
    GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO agent_app;

    -- Used by the dashboard's "Live Database" tab. Read-only, on purpose —
    -- a viewer has no business being able to write.
    CREATE ROLE dashboard_viewer LOGIN PASSWORD '${DASHBOARD_DB_PASSWORD}';
    GRANT SELECT ON employees, devices, security_incidents, audit_log TO dashboard_viewer;
EOSQL
