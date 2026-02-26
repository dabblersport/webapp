import json

LOG_FILE = "/Users/moatazmustapha/Library/Application Support/Code/User/workspaceStorage/852760e6bd4bda813181c6a59edab75b/GitHub.copilot-chat/chat-session-resources/bcbaceab-312f-4897-a68f-ac2bdcd59cae/toolu_01QjX5sdiAJXk9A2HpA5s3eb__vscode-1771788356347/content.json"

with open(LOG_FILE) as f:
    data = json.load(f)

results = data.get("result", [])
print(f"Total entries: {len(results)}")

for entry in results:
    s = json.dumps(entry)
    status = entry.get("status_code", "")
    has_error = str(status).startswith(("4", "5")) if status else False
    has_vibe = "vibe" in s.lower()
    has_pgrst = "PGRST" in s

    if has_vibe or has_pgrst or has_error:
        print(f"\n{'='*60}")
        print(f"Method: {entry.get('method','')} Path: {entry.get('path','')}")
        print(f"Status: {status}")
        print(f"Message: {entry.get('event_message','')[:500]}")
        meta = entry.get("metadata", [])
        if meta:
            for m in (meta if isinstance(meta, list) else [meta]):
                ms = json.dumps(m) if not isinstance(m, str) else m
                if "vibe" in ms.lower() or "PGRST" in ms or "select" in ms.lower() or "error" in ms.lower():
                    print(f"Meta: {ms[:500]}")
