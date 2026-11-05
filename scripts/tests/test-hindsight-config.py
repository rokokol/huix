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
    assert {"invalidate_memory", "retain", "recall", "get_mental_model", "list_memories", "reflect"} <= tools
    assert not {"delete_bank", "clear_memories"} & tools
    assert "HINDSIGHT_API_LLM_API_KEY" not in f["environment"]
    env = f["environment"]
    assert env.get("HINDSIGHT_API_RERANKER_PROVIDER") == "openrouter"
    assert env.get("HINDSIGHT_API_RERANKER_OPENROUTER_MODEL") == "qwen/qwen3-reranker-8b"
    assert env.get("HINDSIGHT_API_RERANKER_1_PROVIDER") == "rrf"
    # Every model of Hindsight spends on one key of its own, and the dashboard reads that key's
    # counter; a model left on the agents' key would spend outside the number the panels show
    template = f["envTemplate"]
    for name in (
        "HINDSIGHT_API_LLM_API_KEY",
        "HINDSIGHT_API_EMBEDDINGS_OPENAI_API_KEY",
        "HINDSIGHT_API_RERANKER_OPENROUTER_API_KEY",
    ):
        assert f"{name}={f['placeholders']['hindsight']}" in template, name
    assert f["placeholders"]["hindsight"] != f["placeholders"]["agents"]
    assert "openrouter-hindsight-api-key" in f["spendMonitor"]["LoadCredential"]
    assert any("hindsight-spend.prom" in rule for rule in f["textfileRules"])
    assert "hindsight-client-token" in f["piMemory"]
    assert 'get_mental_model: "direct"' in f["piMemory"]
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
        assert "claude-shared" not in f[key]


fixture = json.loads(Path(sys.argv[1]).read_text())
validate(fixture)
for name, mutate in [
    ("SQL_ASCII", lambda f: f.update(initdbArgs=[])),
    ("empty database authority", lambda f: f["environment"].update(HINDSIGHT_API_DATABASE_URL="postgresql:///hindsight?host=/run/postgresql")),
    ("missing dump dependency", lambda f: f.update(backupRequires=[])),
    ("cross-host state sharing", lambda f: f["folders"]["pi-nixos-pc"]["devices"].append("nixos-laptop")),
    ("a model spending on the agents' key", lambda f: f.update(
        envTemplate=f["envTemplate"].replace(f["placeholders"]["hindsight"], f["placeholders"]["agents"], 1))),
    ("no fallback when the rerank host overloads", lambda f: f["environment"].pop("HINDSIGHT_API_RERANKER_1_PROVIDER")),
    ("the cross-encoder switched off", lambda f: f["environment"].update(HINDSIGHT_API_RERANKER_PROVIDER="rrf")),
    ("a spend counter nothing exports", lambda f: f.update(textfileRules=[])),
]:
    broken = copy.deepcopy(fixture)
    mutate(broken)
    try:
        validate(broken)
    except AssertionError:
        continue
    raise AssertionError("Undetected defect: " + name)
print("PASS: memory auth boundaries, socket URL, UTF-8, completed dumps, per-host pi backup isolation, one Hindsight key for every model and a reranked chain with its fallback; 8 planted defects rejected")
