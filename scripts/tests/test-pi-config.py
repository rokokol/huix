import json
from pathlib import Path
import re
import subprocess
import sys


fixture = json.loads(Path(sys.argv[1]).read_text())
settings = json.loads(Path(fixture["settings"]).read_text())
models = json.loads(Path(fixture["models"]).read_text())
keybindings = json.loads(Path(fixture["keybindings"]).read_text())
assert set(keybindings["tui.editor.deleteWordBackward"]) >= {"ctrl+backspace", "ctrl+h", "ctrl+w", "alt+backspace"}
assert any(isinstance(package, str) and package.endswith("/pi-editor-selection") for package in settings["packages"])
assert not settings["enableInstallTelemetry"]
assert not settings["enableAnalytics"]
assert settings["showCacheMissNotices"]
assert settings["hideThinkingBlock"]
assert "theme" not in settings
assert models["providers"]["openrouter"]["apiKey"].startswith("!")
assert "/run/secrets/pi-fixture-key" in models["providers"]["openrouter"]["apiKey"]
assert settings["terminal"]["hyperlinks"]
assert f'{fixture["directory"]}/extensions/hoster.ts' in settings["extensions"]
assert Path(fixture["hoster"]).is_file()
assert f'{fixture["directory"]}/extensions/modules.ts' in settings["extensions"]
assert not any("resume" in extension for extension in settings["extensions"])
assert any(isinstance(package, str) and package.endswith("/@nicknisi/pi-heads-up") for package in settings["packages"])
assert json.loads(Path(fixture["headsUp"]).read_text())["model"] == "openai-codex/gpt-6.1-sol"
assert not any("questionnaire" in extension for extension in settings["extensions"])
assert any(isinstance(package, str) and package.endswith("/@mrclrchtr/supi-ask-user") for package in settings["packages"])
assert f'{fixture["directory"]}/extensions/resume.ts' not in settings["extensions"]
assert not any(isinstance(package, str) and package.endswith("/@fahrizkyputra/pi-auto-resume") for package in settings["packages"])
module_catalog = json.loads(Path(fixture["modules"]).read_text())
assert {name: module["source"] for name, module in module_catalog.items()} == fixture["groups"]
assert models["providers"]["openrouter"]["compat"]["openRouterRouting"] == {
    "data_collection": "deny", "zdr": True, "require_parameters": True,
}
assert "openai/*" not in settings["enabledModels"]
assert "openrouter/*" not in settings["enabledModels"]
assert settings["defaultProvider"] == "openai-codex"
assert settings["defaultModel"] == "gpt-6.1-sol"
assert any(isinstance(package, str) and package.endswith("/@narumitw/pi-usage") for package in settings["packages"])
overrides = models["providers"]["openrouter"]["modelOverrides"]
assert set(overrides) == {"deepseek/deepseek-v4.1-flash-1017", "z-ai/glm-5.3", "z-ai/glm-5.3-flash"}
for override in overrides.values():
    routing = override["compat"]["openRouterRouting"]
    assert routing["zdr"] and routing["data_collection"] == "deny"
    assert routing["require_parameters"]
    assert routing["order"] == routing["only"] and len(routing["only"]) == 2
automode = fixture["automode"]
assert automode["autoMode"]["allowInsideWorkingDirectory"]
assert automode["autoMode"]["classifierModel"] == "openrouter/z-ai/glm-5.3-flash"
assert automode["autoMode"]["log"] == {"enabled": True, "classifierIo": False}
assert "$defaults" in automode["autoMode"]["hard_deny"]
assert "$defaults" in automode["autoMode"]["soft_deny"]
assert any("trash-put" in rule and "rm" in rule for rule in automode["autoMode"]["hard_deny"])
assert any("git reset" in rule for rule in automode["autoMode"]["soft_deny"])
assert any("credential" in rule for rule in automode["autoMode"]["hard_deny"])
assert not any(".claude" in rule or "claude-shared" in rule for rule in automode["autoMode"]["hard_deny"])
for command in ("skvpn down*", "skvpn up*", "skvpn restart*", "tailscale down*", "nixos-rebuild switch*"):
    assert f"bash({command})" in automode["permissions"]["deny"]
    assert f"bash(sudo {command})" in automode["permissions"]["deny"]
allows = automode["permissions"]["allow"]
for directory in ("/nix/store", "/build/pi-test/huix", "/build/pi-test/myWiki", "/build/pi-test/Projects"):
    assert f"read({directory})" in allows
    assert f"read({directory}/*)" in allows
    if directory != "/nix/store":
        assert f"write({directory}/*)" in allows
        assert f"edit({directory}/*)" in allows
assert "write(/nix/store/*)" not in allows
assert not any(".ssh" in rule or "opencode" in rule for rule in allows)
assert set(fixture["groups"]) == {"huix", "research"}, fixture["groups"]
registered = {}
for group, directory in fixture["groups"].items():
    root = Path(directory)
    manifest = json.loads((root / "package.json").read_text())
    assert manifest["name"] == f"@huix/{group}"
    assert manifest["pi"]["extensions"] == ["./mcp.ts"]
    assert manifest["pi"]["skills"] == ["./skills"]
    assert str(root) in settings["packages"]
    extension = (root / "mcp.ts").read_text()
    match = re.search(r"const servers = (.*);", extension)
    assert match, extension
    registered[group] = json.loads(match.group(1))
assert set(registered["huix"]) == {"local"}, registered
assert set(registered["research"]) == {"remote"}, registered
assert registered["research"]["remote"]["url"] == "http://127.0.0.1:9/mcp"
local = registered["huix"]["local"]
assert "{file:" not in json.dumps(local), local
assert "apiKey" not in settings
skill = Path(fixture["groups"]["research"]) / "skills/example/SKILL.md"
assert skill.is_file()
assert "name: example\n" in skill.read_text()
print("PASS: grouped packages preserve MCP transport, file credentials and skills")

target = Path(fixture["directory"]) / "settings.json"
marker = target.with_name(".huix-settings-source")
backup = target.with_name("settings.json.pre-huix")


def activate(changed=False):
    subprocess.run(["bash", fixture["changedActivation" if changed else "activation"]], check=True)


target.parent.mkdir(parents=True)
target.write_text('{"personal":true}')
activate()
assert json.loads(backup.read_text()) == {"personal": True}
assert target.read_bytes() == Path(fixture["settings"]).read_bytes()
assert target.stat().st_mode & 0o777 == 0o600
assert not target.is_symlink()
assert marker.resolve() == Path(fixture["settings"]).resolve()
target.write_text('{"runtime":true}')
activate()
assert json.loads(target.read_text()) == {"runtime": True}, "Activation discarded runtime edits"
activate(changed=True)
assert json.loads(target.read_text())["theme"] == "dark", "New Nix settings were not applied"
target.unlink()
activate(changed=True)
assert json.loads(target.read_text())["theme"] == "dark", "Missing settings were not recreated"
assert json.loads(backup.read_text()) == {"personal": True}, "Original backup was overwritten"
print("PASS: mutable settings keep UI edits until Nix changes, with a private first-copy backup")
