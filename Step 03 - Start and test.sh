/bin/bash <<'DAN_STEP_03'
# STEP 03 - Starts the AI engine, tests every model, and opens Buzz. About 15 minutes.
# Keep Parallels/Windows closed while this runs.
set -Eeuo pipefail
fail() { printf '\nSTOP: %s\n' "$*" >&2; exit 1; }
ROOT="$HOME/Library/Application Support/DanLocalAI"
[[ -f "$ROOT/environment.sh" ]] || fail "Run Step 01 first."
[[ -d /Applications/oMLX.app ]] || fail "oMLX is missing. Run Step 01 again."
source "$ROOT/environment.sh"
if pgrep -f 'prl_vm_app|prl_client_app' >/dev/null 2>&1; then
  fail "Parallels is open. Shut down Windows, quit Parallels, then paste again."
fi
STAMP="$(date +%Y%m%d-%H%M%S)"
mkdir -p "$ROOT/logs" "$ROOT/tests"
exec > >(tee "$ROOT/logs/step03-$STAMP.log") 2>&1
/usr/bin/caffeinate -is -w "$$" >/dev/null 2>&1 &
API="http://127.0.0.1:8000/v1"

echo "Starting the AI engine (oMLX)..."
open -gj /Applications/oMLX.app
READY=0
for attempt in {1..90}; do
  if curl --noproxy '*' -fsS --max-time 2 "$API/models" >/dev/null 2>&1; then READY=1; break; fi
  sleep 2
done
[[ "$READY" -eq 1 ]] || fail "oMLX did not start. Click the oMLX icon at the top of the screen, choose Start Server, then paste again."

# Read-only tool-call test. Never executes anything a model produces.
cat > "$ROOT/probe.py" <<'PY'
import json, re, sys, uuid, urllib.request

api, model = sys.argv[1:]
opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
token = str(uuid.uuid4())
body = {"model": model, "stream": False, "max_tokens": 1024, "temperature": 0,
        "messages": [{"role": "user", "content":
          "Call read_probe_file with filename probe.txt. After the tool returns, "
          "reply with only its token, without quotes or explanation."}],
        "tools": [{"type": "function", "function": {
          "name": "read_probe_file", "description": "Read the local test file.",
          "parameters": {"type": "object", "properties": {
            "filename": {"type": "string", "enum": ["probe.txt"]}},
            "required": ["filename"]}}}]}
if re.search(r"Qwen3\.[568]", model):
    body["chat_template_kwargs"] = {"enable_thinking": False}

def ask(payload):
    request = urllib.request.Request(api + "/chat/completions",
        data=json.dumps(payload).encode(), headers={"Content-Type": "application/json"})
    with opener.open(request, timeout=1800) as response:
        return json.loads(response.read().decode())["choices"][0]["message"]

try:
    message = ask(body)
    calls = message.get("tool_calls") or []
    if len(calls) != 1:
        raise ValueError("expected one structured tool call")
    function = calls[0]["function"]
    args = function["arguments"]
    args = json.loads(args) if isinstance(args, str) else args
    if function["name"] != "read_probe_file" or args != {"filename": "probe.txt"}:
        raise ValueError("wrong tool name or arguments")
    body["messages"] += [
        {"role": "assistant", "content": message.get("content") or "", "tool_calls": calls},
        {"role": "tool", "tool_call_id": calls[0]["id"], "content": json.dumps({"token": token})}]
    if token not in (ask(body).get("content") or ""):
        raise ValueError("tool result was not reported back")
    print("PASS")
except Exception as exc:
    print(f"NOT VERIFIED: {exc}")
    sys.exit(1)
PY

REPORT="$ROOT/results-$STAMP.txt"
: > "$REPORT"
FAILED=0
while IFS='|' read -r name role; do
  [[ -n "$name" ]] || continue
  printf '\n=== Testing %s ===\n' "$name"
  if [[ ! -d "$HOME/.omlx/models/$name" ]]; then
    RESULT="NOT DOWNLOADED (paste Step 02 again)"
  elif RESULT="$(python3 "$ROOT/probe.py" "$API" "$name" </dev/null 2>&1 | tail -1)"; then
    :
  fi
  [[ "$RESULT" == PASS ]] || FAILED=$((FAILED + 1))
  echo "$RESULT"
  printf '%-44s %s\n    %s\n' "$name" "$RESULT" "$role" >> "$REPORT"
done <<'MODEL_LIST'
Qwen3.6-35B-A3B-oQ4e-mtp|EVERYDAY AGENT - fast and capable. Use this one first.
Qwen3.5-4B-MLX-8bit|QUICK HELPER - tiny and instant, for simple repeated jobs.
Qwen3.5-9B-MLX-4bit|GENERAL WORKER - light everyday tasks.
gemma-4-12B-it-qat-4bit|SECOND WORKER - a different "voice", good at writing.
Qwen3.8-27B-oQ4e-mtp|DEEP THINKER - smartest reasoning and planning, slower.
Devstral-Small-2-24B-Instruct-2512-4bit|CODE REVIEWER - second opinion on code.
Qwen3-Coder-Next-MLX-4bit|BIG CODER - largest coding model (45 GB). Let it run alone.
MODEL_LIST

# Disposable project for a first real test from inside Buzz.
PROJECT="$HOME/BuzzProjects/SetupCheck-$STAMP"
mkdir -p "$PROJECT"
printf 'module.exports.add = (a, b) => a - b;\n' > "$PROJECT/add.cjs"
printf "const {add}=require('./add.cjs'); require('node:assert/strict').equal(add(2,3),5); console.log('PASS');\n" > "$PROJECT/test.cjs"
/usr/bin/uuidgen > "$PROJECT/CHECK_TOKEN.txt"

NOTES="$HOME/Desktop/Dan AI Notes.txt"
cat > "$NOTES" <<NOTES
DAN LOCAL AI - NOTES

EVERY DAY
Start: double-click "Start Dan AI" on the Desktop.
Before opening Parallels/Windows: double-click "Stop Dan AI".
Keep the Mac plugged in. Only use models marked PASS below.

CONNECT BUZZ TO THE LOCAL MODELS (one time)
1. In Buzz, create/import your identity and join your community or invitation.
   Keep private identity keys private.
2. Add a LOCAL agent using the OpenAI-compatible / custom provider:
   Base URL: http://127.0.0.1:8000/v1
   API key:  dan-local
   Model:    Qwen3.6-35B-A3B-oQ4e-mtp   (type the name exactly as shown below)
3. Give the agent access only to this test project, then ask it:
   "Read CHECK_TOKEN.txt and report its exact content. Fix add.cjs so add(2,3)
   equals 5. Run node test.cjs and report the actual output."
   Project: $PROJECT

MODELS AND TEST RESULTS
$(cat "$REPORT")

GOOD TO KNOW
The engine keeps the models you use in memory and swaps others in as needed.
The first answer after switching models takes up to a minute while it loads.
Dashboard (see what is loaded, chat with a model): http://127.0.0.1:8000/admin
The models run on this Mac. Buzz messages still travel through your Buzz relay.
A PASS here is a basic check, not proof a model can handle a big project.
Logs: $ROOT/logs
NOTES

cat "$REPORT"
printf '\n============================================================\n'
printf ' STEP 03 COMPLETE. Models needing attention: %s\n' "$FAILED"
printf ' Read "Dan AI Notes" on the Desktop to connect Buzz.\n'
printf '============================================================\n'
/bin/bash "$HOME/Desktop/Start Dan AI.command" || echo "Open Buzz manually if macOS requests approval."
open -a TextEdit "$NOTES" || true
DAN_STEP_03
