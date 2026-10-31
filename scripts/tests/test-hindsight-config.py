import copy
import json
from pathlib import Path
import sys
from urllib.parse import parse_qs, urlsplit, urlunsplit


def validate(f):
    assert "--encoding=UTF8" in f["initdbArgs"]
    assert not f["enableTCPIP"]
    assert f["api"]["User"] == "hindsight"
    assert f["api"]["UMask"] == "0077"
    database_url = f["environment"]["HINDSIGHT_API_DATABASE_URL"]
    parsed = urlsplit(database_url)
    assert parsed.username == f["api"]["User"]
    assert parsed.hostname is None and parsed.path == "/hindsight"
    assert parse_qs(parsed.query)["host"] == ["/run/postgresql"]
    assert urlunsplit(parsed) == database_url
    assert f["databaseSetup"]["User"] == "postgres"
    assert "CREATE EXTENSION IF NOT EXISTS vector" in f["databaseSetup"]["ExecStart"]
    assert "postgresql.target" in f["databaseAfter"]
    assert "postgresql.target" in f["databaseRequires"]
    assert f["dump"]["ConditionPathIsMountPoint"] == f["mountPoint"]
    assert f["dumpDir"] in f["dump"]["RequiresMountsFor"]
    assert f["location"] == f["dumpDir"]
    assert "--format=custom" in f["pgdumpOptions"]
    assert f["dumpDir"] in f["backupPaths"]
    assert "postgresqlBackup-hindsight.service" in f["backupRequires"]
    tools = set(f["environment"]["HINDSIGHT_API_MCP_ENABLED_TOOLS"].split(","))
    assert {"invalidate_memory", "retain", "recall", "list_memories", "reflect"} <= tools
    assert not {"delete_bank", "clear_memories"} & tools
    assert "HINDSIGHT_API_LLM_API_KEY" not in f["environment"]
    assert f["environment"]["HINDSIGHT_API_RERANKER_PROVIDER"] == "rrf"
    assert "hindsight-client-token" in f["piMemory"]
    assert f["hermesMemoryProvider"] == "hindsight"
    assert "memory" not in f["hermesMcpServers"]
    assert any(name.startswith("python3.14-hindsight-client-") for name in f["hermesPythonPackages"])
    assert any(name.startswith("python3.14-hermes-plugin-hindsight-") for name in f["hermesPythonPackages"])
    assert "HINDSIGHT_MODE=local_external" in f["hermesEnv"]
    assert f"HINDSIGHT_API_URL=http://127.0.0.1:{f['port']}" in f["hermesEnv"]
    assert f"HINDSIGHT_BANK_ID={f['bank']}" in f["hermesEnv"]
    assert "HINDSIGHT_RECALL_SYNC=true" in f["hermesEnv"]
    assert "claude-shared" not in f["folders"]
    assert "pi-shared" in f["folders"]
    for host, other, key in [("nixos-pc", "nixos-laptop", "pcFolders"),
                             ("nixos-laptop", "nixos-pc", "laptopFolders")]:
        folder = f["folders"]["pi-" + host]
        assert set(folder["devices"]) == {host, "nixos-station"}
        assert "pi-" + other not in f[key]
        assert f[key]["claude-shared"]["paused"]


fixture = json.loads(Path(sys.argv[1]).read_text())
validate(fixture)
for name, mutate in [
    ("SQL_ASCII", lambda f: f.update(initdbArgs=[])),
    ("empty database authority", lambda f: f["environment"].update(HINDSIGHT_API_DATABASE_URL="postgresql:///hindsight?host=/run/postgresql")),
    ("missing dump dependency", lambda f: f.update(backupRequires=[])),
    ("cross-host state sharing", lambda f: f["folders"]["pi-nixos-pc"]["devices"].append("nixos-laptop")),
]:
    broken = copy.deepcopy(fixture)
    mutate(broken)
    try:
        validate(broken)
    except AssertionError:
        continue
    raise AssertionError("Undetected defect: " + name)
print("PASS: memory auth boundaries, socket URL, UTF-8, completed dumps and per-host pi backup isolation; 4 planted defects rejected")
