"""Launch the benchmark runs: one fresh headless Claude Code session per run.

A run = arm (Baseline / LLM-MCP) x model (Opus / Sonnet) x scenario (1-4) x repetition.

Each session runs inside a Docker container whose file system holds only: the system and R
installation, the run's own folder (data/ and results/), an empty home directory, the source of
the five R packages, and - for the LLM-MCP arm - the MCP servers. It cannot see the ground
truth, the other runs or any other project. The only difference between the arms is whether
the five TME MCP servers are available.

Usage (from the repository root):

    python3 evaluation/Benchmark/run_benchmark.py freeze                     # once, before the first run
    python3 evaluation/Benchmark/run_benchmark.py campaign <first rep> <last rep>  # everything, unattended
    python3 evaluation/Benchmark/run_benchmark.py start <scenario> <repetition>
    python3 evaluation/Benchmark/run_benchmark.py reply <run> <prompt file>   # e.g. reply_credentials.txt
    python3 evaluation/Benchmark/run_benchmark.py resume <run>               # after a technical interruption
    python3 evaluation/Benchmark/run_benchmark.py debrief <run>
    python3 evaluation/Benchmark/run_benchmark.py export <run>
    python3 evaluation/Benchmark/run_benchmark.py collect <run>
    python3 evaluation/Benchmark/run_benchmark.py status <repetition>

<run> is written like  LLM-MCP_Opus_S1_rep1
"""

import json
import os
import re
import shutil
import subprocess
import sys
import time
import uuid
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parent.parent
WORK_ROOT = Path.home() / "Documents" / "tme_analysis"  # neutral name: the session sees this path
HOME = Path.home()
IMAGE = "ghcr.io/actions/jekyll-build-pages:v1.0.13"  # any local image: the system folders are mounted from the host
PACKAGE_SOURCES = ["multideconv", "CellTFusion", "pipeML", "RaCInG_package", "Bioinfo-tools"]
INSTALLED = ["multideconv", "CellTFusion", "pipeML", "RaCInG", "BioinfoTools"]  # the same packages as installed in R
R_LIBRARY = Path.home() / "R" / "x86_64-pc-linux-gnu-library" / "4.3"
# Copy of the packages (source and installed) and of the MCP servers made once by `freeze`: every run
# sees these versions, even if the packages are edited or reinstalled while the benchmark runs.
FROZEN = Path.home() / "Documents" / "tme_benchmark_packages"

# host folders visible inside the container (read-only unless listed in WRITABLE)
SYSTEM_MOUNTS = {"/usr": "/usr", "/usr/bin": "/bin", "/usr/sbin": "/sbin", "/usr/lib": "/lib", "/usr/lib64": "/lib64",
                 "/etc": "/etc", "/opt": "/opt", "/var/lib/sss": "/var/lib/sss", "/run/systemd/resolve": "/run/systemd/resolve"}
HOME_MOUNTS = [".local/bin", ".local/share/claude", ".local/share/uv", "R", "anaconda3",
               ".local/share/r-miniconda", ".local/share/r-reticulate"]  # Python used by R (omnideconv: DWLS, CIBERSORTx)
WRITABLE = [".cache/uv", ".cache/R", ".cache/OmnipathR", ".cache/pypath"]  # download caches shared by all runs
RUN_INDEX = HERE / "runs.json"  # run name -> folder and session id

MODELS = {"Opus": "claude-opus-5-5", "Sonnet": "claude-sonnet-5"}
TME_SERVERS = ["multideconv-server", "pipeML-server", "CellTFusion-server", "RaCInG-server", "Bioinfo-tools-server"]
BUILTIN_TOOLS = ["Bash", "Read", "Write", "Edit", "Glob", "Grep", "TodoWrite"]

# A headless session is not woken up when a background job ends, so everything runs in the
# foreground: no background tasks, and long limits for shell commands and MCP tool calls.
SESSION_ENV = {
    "CLAUDE_CODE_DISABLE_BACKGROUND_TASKS": "1",
    "BASH_DEFAULT_TIMEOUT_MS": str(30 * 60 * 1000),
    "BASH_MAX_TIMEOUT_MS": str(3 * 3600 * 1000),
    "MCP_TOOL_TIMEOUT": str(3 * 3600 * 1000),
}

HOURS_PER_TURN = 4
MEMORY_GB = 6  # the machine has 15 GB (about 10 used by the desktop); it crashed twice during uncapped jobs
# Claude plan allowance: a 5-hour window holds about four runs
WAIT_ABOVE = 0.75      # after a run, wait for the next 5-hour window if this fraction is used
STOP_WEEKLY = 0.90     # stop the campaign when the weekly allowance reaches this fraction (asked by the user)
MAX_WAIT_HOURS = 6     # never wait longer than this for a reset (the weekly one is days away)
STALL_MINUTES = 15  # no answer from the model for this long = stalled session
MAX_USD_PER_TURN = 60
SMALL_MODEL = "claude-haiku-5-5"  # reads the last message of a run to see whether it asks something
SCENARIOS = [1, 2, 3, 4]


def load_index():
    return json.loads(RUN_INDEX.read_text()) if RUN_INDEX.exists() else {}


def save_index(index):
    RUN_INDEX.write_text(json.dumps(index, indent=2))


def prepare(arm):
    """Create the folder of a run: its work folder, an empty home and its MCP configuration."""
    folder = WORK_ROOT / uuid.uuid4().hex[:10]
    work = folder / "work"
    (work / "data").mkdir(parents=True)
    (work / "results").mkdir()
    (folder / "tmp").mkdir()
    (folder / "mcp-tme-servers").mkdir()
    for name in ["Gide_log2TPM.txt", "Riaz_log2TPM.txt", "colData_all.txt"]:
        shutil.copy(REPO / "data" / name, work / "data" / name)

    # empty home, with the mount points created in advance (otherwise Docker creates them as root)
    home = folder / "home"
    for path in HOME_MOUNTS + WRITABLE + ["Documents/" + p for p in PACKAGE_SOURCES + ["mcp-tme-servers"]]:
        (home / path).mkdir(parents=True)
    for mounted in ["work", "tmp", "mcp-tme-servers"]:
        (home / (folder / mounted).relative_to(HOME)).mkdir(parents=True)
    (home / ".claude").mkdir()
    (home / ".claude" / ".credentials.json").touch()
    (home / ".claude.json").write_text('{"hasCompletedOnboarding": true}')
    (home / (folder / "mcp.json").relative_to(HOME)).touch()

    servers = {}
    if arm == "LLM-MCP":
        registered = json.loads((HOME / ".claude.json").read_text())["mcpServers"]
        for name in TME_SERVERS:
            servers[name] = dict(registered[name])
            # the servers are mounted read-only: `uv run` must not try to re-sync their environment
            args = list(servers[name].get("args", []))
            if "run" in args and "--no-sync" not in args:
                args.insert(args.index("run") + 1, "--no-sync")
                servers[name]["args"] = args
            # each run keeps the server outputs in its own folder
            servers[name]["env"] = {"MCP_TME_SERVERS_HOME": str(folder / "mcp-tme-servers")}
    (folder / "mcp.json").write_text(json.dumps({"mcpServers": servers}, indent=2))
    return folder


def docker_command(folder, arm, name):
    """The container of a session: memory cap, same user, and only the mounts listed above."""
    environment = {**SESSION_ENV, "HOME": str(HOME), "TMPDIR": str(folder / "tmp"),
                   # R 4.3.3 first: CellTFusion needs it, and it is the R of the MCP servers
                   "PATH": f"/opt/R/4.3.3/bin:{HOME}/anaconda3/envs/colomoto/bin:{HOME}/.local/bin:{HOME}/anaconda3/bin:"
                           "/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"}
    mounts = [f"{host}:{inside}:ro" for host, inside in SYSTEM_MOUNTS.items()]
    mounts += ["/var/run/docker.sock:/var/run/docker.sock"]  # CIBERSORTx runs as a Docker container
    mounts += [f"{folder / 'home'}:{HOME}"]
    mounts += [f"{HOME / p}:{HOME / p}:ro" for p in HOME_MOUNTS]
    mounts += [f"{HOME / p}:{HOME / p}" for p in WRITABLE]
    mounts += [f"{HOME}/.claude/.credentials.json:{HOME}/.claude/.credentials.json"]  # login of the Claude account
    if not FROZEN.exists():
        sys.exit(f"{FROZEN} does not exist: run `freeze` first")
    mounts += [f"{FROZEN / 'sources' / p}:{HOME}/Documents/{p}:ro" for p in PACKAGE_SOURCES]
    mounts += [f"{FROZEN / 'library' / p}:{R_LIBRARY / p}:ro" for p in INSTALLED]  # over the R library mounted above
    if arm == "LLM-MCP":
        mounts += [f"{FROZEN / 'sources' / 'mcp-tme-servers'}:{HOME}/Documents/mcp-tme-servers:ro"]
    mounts += [f"{folder / p}:{folder / p}" for p in ["work", "tmp", "mcp-tme-servers"]]
    mounts += [f"{folder / 'mcp.json'}:{folder / 'mcp.json'}:ro"]

    docker_group = subprocess.run(["getent", "group", "docker"], capture_output=True, text=True).stdout.split(":")[2]
    command = ["docker", "run", "--rm", "--name", name, "--user", f"{os.getuid()}:{os.getgid()}", "--group-add", docker_group,
               "--network", "host", "--memory", f"{MEMORY_GB}g", "--memory-swap", f"{MEMORY_GB}g",
               "--entrypoint", "", "--workdir", str(folder / "work")]
    for key, value in environment.items():
        command += ["-e", f"{key}={value}"]
    for mount in mounts:
        command += ["-v", mount]
    return command + [IMAGE]


def waiting_for_model(events):
    """True when the session is waiting for the model, not for a tool that is still running."""
    last = json.loads(events.read_text().splitlines()[-1])
    if last.get("type") != "assistant":
        return True
    return not any(c.get("type") == "tool_use" for c in last["message"]["content"])


def run_turn(run, info, message, tools=True, restarts_left=2):
    """Send one message to the session of a run and append everything it does to events.jsonl."""
    folder = Path(info["folder"])
    events = folder / "events.jsonl"
    container = f"tme-{folder.name}-{int(time.time())}"
    command = docker_command(folder, info["arm"], container) + [
        "claude", "-p", message,
        "--model", MODELS[info["model"]],
        "--effort", "high",
        "--output-format", "stream-json", "--verbose",
        "--setting-sources", "project",  # no user settings, plugins or hooks
        "--strict-mcp-config", "--mcp-config", str(folder / "mcp.json"),
        "--max-budget-usd", str(MAX_USD_PER_TURN),
    ]
    if tools:
        allowed = BUILTIN_TOOLS + (["mcp__" + s for s in TME_SERVERS] if info["arm"] == "LLM-MCP" else [])
        command += ["--tools", *BUILTIN_TOOLS, "--permission-mode", "acceptEdits", "--allowedTools", *allowed]
    else:  # no built-in tools and no MCP tools
        command += ["--tools", "", "--disallowedTools", *["mcp__" + s for s in TME_SERVERS]]
    if not info.get("session_id") and events.exists():  # a turn stopped before its end did not save it in the index
        started = [json.loads(l) for l in events.read_text().splitlines() if '"subtype":"init"' in l or '"subtype": "init"' in l]
        if started:
            info["session_id"] = started[-1]["session_id"]
    if info.get("session_id"):
        command += ["--resume", info["session_id"]]

    with events.open("a") as log:
        log.write(json.dumps({"type": "benchmark_message", "message": message}) + "\n")
        log.flush()
    first_new_line = len(events.read_text().splitlines())

    stalled = False
    started = time.monotonic()  # awake time: a suspended computer does not count
    with events.open("a") as log, (folder / "stderr.log").open("a") as errors:
        process = subprocess.Popen(command, stdin=subprocess.DEVNULL, stdout=log, stderr=errors)
        while process.poll() is None:
            time.sleep(30)
            silent_minutes = (time.time() - events.stat().st_mtime) / 60
            if time.monotonic() - started > HOURS_PER_TURN * 3600:
                subprocess.run(["docker", "kill", container], capture_output=True)
                log.write(json.dumps({"type": "benchmark_timeout", "hours": HOURS_PER_TURN}) + "\n")
            elif silent_minutes > STALL_MINUTES and waiting_for_model(events) and not stalled:
                subprocess.run(["docker", "kill", container], capture_output=True)
                stalled = True
                log.write(json.dumps({"type": "benchmark_stall", "silent_minutes": round(silent_minutes)}) + "\n")
        process.wait()
    # nothing started by this turn may keep running after it
    subprocess.run(["docker", "rm", "-f", container], capture_output=True)

    # session id and outcome of this turn
    result = None
    for line in events.read_text().splitlines()[first_new_line:]:
        event = json.loads(line)
        if event.get("type") == "system" and event.get("subtype") == "init":
            info["session_id"] = event["session_id"]
        if event.get("type") == "result":
            result = event

    # a session that stopped answering is resumed (a technical restart, recorded in the log)
    if stalled and restarts_left > 0 and info.get("session_id"):
        return run_turn(run, info, "Continue.", tools, restarts_left - 1)
    # a turn cut by a dropped connection is resumed once the connection is back (also recorded in the log)
    if (result and result.get("is_error") and result.get("api_error_status") != 429
            and any(s in (result.get("result") or "") for s in ("API Error", "Failed to authenticate"))
            and restarts_left > 0 and info.get("session_id")):
        with events.open("a") as log:
            log.write(json.dumps({"type": "benchmark_connection_lost"}) + "\n")
        wait_for_connection(run)
        return run_turn(run, info, "Continue.", tools, restarts_left - 1)
    # a turn cut by the plan limit is resumed after the reset (also recorded in the log)
    if result and result.get("api_error_status") == 429 and restarts_left > 0:
        with events.open("a") as log:
            log.write(json.dumps({"type": "benchmark_plan_limit"}) + "\n")
        if wait_for_reset(info):
            return run_turn(run, info, "Continue.", tools, restarts_left - 1)
    return result


def has_result(info):
    events = Path(info["folder"]) / "events.jsonl"
    return events.exists() and any(json.loads(l).get("type") == "result" for l in events.read_text().splitlines())


def plan_windows(info):
    """Last reported state of the Claude plan windows: {"five_hour": {utilization, resetsAt}, "seven_day": ...}."""
    windows = {}
    for line in (Path(info["folder"]) / "events.jsonl").read_text().splitlines():
        if '"rate_limit_event"' in line:
            windows = (json.loads(line).get("rate_limit_info") or {}).get("unifiedWindows") or windows
    return windows


def wait_for_reset(info, window="five_hour"):
    """Sleep until the plan window resets. Returns False when that is too far away."""
    return wait_until(plan_windows(info).get(window, {}).get("resetsAt", 0))


def wait_until(reset):
    """Sleep until a plan window resets (a Unix time). Returns False when that is too far away."""
    reset = reset + 120
    if reset - time.time() > MAX_WAIT_HOURS * 3600:
        return False
    if reset > time.time():
        print(f"   waiting {(reset - time.time()) / 60:.0f} min for the plan allowance to reset", flush=True)
    while time.time() < reset:  # checked every minute, so it also works if the computer was suspended
        time.sleep(60)
    return True


def start(scenario, repetition):
    """First turn of the four runs of a scenario, one after the other."""
    prompt = (HERE / "prompts" / f"Scenario{scenario}.txt").read_text().strip()
    index = load_index()
    # alternate which arm goes first
    order = [("LLM-MCP", "Opus"), ("Baseline", "Opus"), ("Baseline", "Sonnet"), ("LLM-MCP", "Sonnet")]
    if int(scenario) % 2 == 0:
        order = [("Baseline", "Opus"), ("LLM-MCP", "Opus"), ("LLM-MCP", "Sonnet"), ("Baseline", "Sonnet")]

    previous = None  # the run before, which holds the last reading of the plan allowance
    for arm, model in order:
        run = f"{arm}_{model}_S{scenario}_rep{repetition}"
        if run in index and has_result(index[run]):
            print(run, "already has a result, skipped")
            continue
        if run in index:  # started but interrupted (for example by a reboot): start again from scratch
            shutil.rmtree(index[run]["folder"], ignore_errors=True)
        if previous:
            windows = plan_windows(previous)
            if windows.get("seven_day", {}).get("utilization", 0) >= STOP_WEEKLY:
                print(f"Weekly plan allowance is nearly used: batch stopped before {run}")
                break
            if windows.get("five_hour", {}).get("utilization", 0) >= WAIT_ABOVE:
                wait_for_reset(previous)
        info = {"arm": arm, "model": model, "scenario": int(scenario), "repetition": int(repetition),
                "folder": str(prepare(arm))}
        index[run] = info
        save_index(index)
        result = run_turn(run, info, prompt)
        save_index(index)
        report(run, result)
        previous = info


def report(run, result):
    if result is None:
        print(run, ": no result (timeout or crash)")
        return
    print(f"{run}: {result.get('subtype')}, {result.get('num_turns')} turns, "
          f"{result.get('duration_ms', 0) / 60000:.1f} min, ${result.get('total_cost_usd', 0):.2f}")
    print("   final message:", " ".join((result.get("result") or "").split())[:700])


def reply(run, prompt_file):
    index = load_index()
    message = (HERE / "prompts" / prompt_file).read_text().strip()
    if prompt_file.startswith("reply_credentials"):
        shutil.copy(Path.home() / "Desktop" / "CBSX_credentials", Path(index[run]["folder"]) / "work" / "CBSX_credentials")
    index[run].setdefault("replies", []).append(prompt_file)
    result = run_turn(run, index[run], message)
    save_index(index)
    report(run, result)
    return result


def resume(run):
    """Resume a session that was interrupted for a technical reason (plan limit, reboot)."""
    index = load_index()
    result = run_turn(run, index[run], "Continue.")
    save_index(index)
    report(run, result)


def debrief(run):
    """Fixed questionnaire, asked when the analysis is finished, with all tools disabled."""
    index = load_index()
    result = run_turn(run, index[run], (HERE / "prompts" / "debrief.txt").read_text().strip(), tools=False)
    save_index(index)
    report(run, result)


def export(run):
    """After the debrief: the session saves standard copies of its results in results/standard/."""
    index = load_index()
    message = (HERE / "prompts" / f"export_Scenario{index[run]['scenario']}.txt").read_text().strip()
    result = run_turn(run, index[run], message)
    save_index(index)
    report(run, result)


def scrub(path):
    """Remove the CIBERSORTx token (32 hexadecimal characters) from a text file."""
    try:
        text = path.read_text()
    except (UnicodeDecodeError, OSError):
        return
    clean = re.sub(r"\b[0-9a-f]{32}\b", "<redacted>", text)
    if clean != text:
        path.write_text(clean)


def write_transcript(events, output):
    """Readable history of a run: messages, visible reasoning, tool calls with arguments, results."""
    lines = []
    for line in events.read_text().splitlines():
        event = json.loads(line)
        kind = event.get("type")
        if kind == "benchmark_message":
            lines += ["", "## Message sent to the model", "", event["message"], ""]
        elif kind in ("benchmark_stall", "benchmark_timeout"):
            lines += ["", f"**[{kind}: session stopped by the launcher]**", ""]
        elif kind == "assistant":
            for block in event["message"]["content"]:
                if block["type"] == "text":
                    lines += ["", block["text"], ""]
                elif block["type"] == "thinking" and block.get("thinking"):
                    lines += ["", "> *Reasoning:* " + block["thinking"].replace("\n", "\n> "), ""]
                elif block["type"] == "tool_use":
                    lines += ["", f"**Tool call: {block['name']}**", "```json", json.dumps(block["input"], indent=1)[:6000], "```"]
        elif kind == "user":
            content = event["message"]["content"]
            for block in content if isinstance(content, list) else []:
                if isinstance(block, dict) and block.get("type") == "tool_result":
                    text = block.get("content")
                    if isinstance(text, list):
                        text = "\n".join(part.get("text", "") for part in text if isinstance(part, dict))
                    error = " (error)" if block.get("is_error") else ""
                    lines += [f"**Result{error}:**", "```", str(text)[:3000], "```"]
        elif kind == "result":
            lines += ["", f"*End of turn: {event.get('subtype')}, {event.get('num_turns')} steps, "
                          f"{event.get('duration_ms', 0) / 60000:.1f} min, ${event.get('total_cost_usd', 0):.2f}*", ""]
    output.write_text("\n".join(lines))


def collect(run):
    """Copy the outputs and the log of a run into evaluation/<arm>/<model>/Scenario<n>/rep<k>/."""
    info = load_index()[run]
    folder = Path(info["folder"])
    target = REPO / "evaluation" / info["arm"] / info["model"] / f"Scenario{info['scenario']}" / f"rep{info['repetition']}"
    if target.exists():
        shutil.rmtree(target)
    shutil.copytree(folder / "work", target, ignore=shutil.ignore_patterns("data", "CBSX_credentials"))
    (target / "log").mkdir()
    shutil.copy(folder / "events.jsonl", target / "log" / "events.jsonl")
    write_transcript(folder / "events.jsonl", target / "log" / "transcript.md")

    # the last answer of each phase as a plain file: analysis, debrief, export
    phase_of = {(HERE / "prompts" / "debrief.txt").read_text().strip(): "debrief.md",
                (HERE / "prompts" / f"export_Scenario{info['scenario']}.txt").read_text().strip(): "export_report.md"}
    for extra in (HERE / "prompts").glob(f"export_Scenario{info['scenario']}_*.txt"):  # exports asked later
        phase_of[extra.read_text().strip()] = extra.stem + "_report.md"
    phase = "final_report.md"
    for line in (folder / "events.jsonl").read_text().splitlines():
        event = json.loads(line)
        if event.get("type") == "benchmark_message":
            phase = phase_of.get(event["message"], phase)
        if event.get("type") == "result" and event.get("result") and not event.get("is_error"):
            (target / "log" / phase).write_text(event["result"])
    servers_output = folder / "mcp-tme-servers"
    if servers_output.exists() and any(servers_output.iterdir()):
        shutil.copytree(folder / "mcp-tme-servers", target / "mcp_server_runs")
    for file in target.rglob("*"):
        if file.is_file() and file.suffix.lower() in {".json", ".jsonl", ".log", ".txt", ".md", ".r", ".py", ".csv", ".qmd", ".html", ".out"}:
            scrub(file)
    print(run, "collected in", target.relative_to(REPO))


def status(repetition):
    for run, info in load_index().items():
        if info["repetition"] != int(repetition):
            continue
        results = [json.loads(l) for l in (Path(info["folder"]) / "events.jsonl").read_text().splitlines() if '"type":"result"' in l or '"type": "result"' in l]
        print(run, "| turns sent:", len(results), "| replies:", info.get("replies", []))
        if results:
            report(run, results[-1])


def freeze():
    """Copy the five packages (source and installed) and the MCP servers, once for the whole benchmark."""
    if FROZEN.exists():
        sys.exit(f"{FROZEN} already exists")

    def without_outputs(root):
        # results and caches at the top of a repository are not part of the package
        def ignore(directory, names):
            skip = {".git", "__pycache__"} | ({"Results", "results", "runs", "pypath_log", "omnipathr-log"} if Path(directory) == root else set())
            return [n for n in names if n in skip]
        return ignore

    versions = {}
    for p in PACKAGE_SOURCES + ["mcp-tme-servers"]:
        source = HOME / "Documents" / p
        shutil.copytree(source, FROZEN / "sources" / p, ignore=without_outputs(source), symlinks=True)
        git = lambda *a: subprocess.run(["git", "-C", str(source), *a], capture_output=True, text=True).stdout.strip()
        versions[p] = {"commit": git("rev-parse", "--short", "HEAD"), "uncommitted_files": git("status", "--short", "--untracked-files=no").splitlines()}
    for p in INSTALLED:
        shutil.copytree(R_LIBRARY / p, FROZEN / "library" / p, symlinks=True)
        description = (R_LIBRARY / p / "DESCRIPTION").read_text()
        versions["installed " + p] = re.findall(r"^(?:Version|Built): (.*)$", description, flags=re.M)
    (FROZEN / "versions.json").write_text(json.dumps(versions, indent=2))
    print(json.dumps(versions, indent=2))


def ask_small_model(prompt):
    """One question to a small model on this computer, without tools. Returns its answer and the plan windows."""
    folder = WORK_ROOT / "_small_model"
    folder.mkdir(parents=True, exist_ok=True)
    (folder / "mcp.json").write_text('{"mcpServers": {}}')
    output = subprocess.run(["claude", "-p", prompt, "--model", SMALL_MODEL, "--tools", "", "--output-format", "stream-json",
                             "--verbose", "--setting-sources", "project", "--strict-mcp-config", "--mcp-config", str(folder / "mcp.json")],
                            cwd=folder, capture_output=True, text=True, timeout=900).stdout
    answer, windows = "", {}
    for line in output.splitlines():
        try:
            event = json.loads(line)
        except ValueError:
            continue
        if event.get("type") == "rate_limit_event":
            windows = (event.get("rate_limit_info") or {}).get("unifiedWindows") or windows
        if event.get("type") == "result":
            answer = event.get("result") or ""
    return answer, windows


WAITING_CHECK = """You read the last message that an AI assistant wrote after it was asked to do a bioinformatics analysis.
Is the assistant waiting for an answer from the user before it runs, or goes on with, the requested analysis?
Offering optional extra work after finishing, or saying that a method was skipped, is not waiting.
Answer with exactly one word: WAITING or FINISHED.

The message:
"""


def asks_something(message):
    """The reply file for the question a run asked, or None when it is not waiting for an answer.

    A small model decides whether the run is waiting (majority of three answers, as one answer is not
    always the same); what it asks about is read from the message: a question that mentions
    CIBERSORTx gets the credentials (and "no custom signatures" when it also mentions signatures)."""
    votes = [ask_small_model(WAITING_CHECK + message)[0].upper() for _ in range(3)]
    if sum("WAITING" in vote for vote in votes) < 2:
        return None
    if re.search(r"CIBERSORTx|CBSX", message, flags=re.I):
        return "reply_credentials_no_signatures.txt" if re.search(r"signature", message, flags=re.I) else "reply_credentials.txt"
    return "reply_other_question.txt"


def run_order(scenario):
    """Which arm goes first alternates between scenarios."""
    if int(scenario) % 2 == 0:
        return [("Baseline", "Opus"), ("LLM-MCP", "Opus"), ("LLM-MCP", "Sonnet"), ("Baseline", "Sonnet")]
    return [("LLM-MCP", "Opus"), ("Baseline", "Opus"), ("Baseline", "Sonnet"), ("LLM-MCP", "Sonnet")]


def wait_for_connection(run):
    """The plan windows, once Claude answers (no answer: no network or no connection to Claude; tried every 10 minutes)."""
    _, windows = ask_small_model("Reply with the single word OK.")
    waited = 0
    while not windows and waited < 24 * 60:
        if waited == 0:
            print(f"   no connection to Claude ({run}), waiting {time.strftime('%m-%d %H:%M')}", flush=True)
        time.sleep(600)
        waited += 10
        _, windows = ask_small_model("Reply with the single word OK.")
    return windows


def plan_allows(run):
    """Before a run: stop at STOP_WEEKLY of the weekly allowance, wait for a new 5-hour window above WAIT_ABOVE."""
    windows = wait_for_connection(run)
    five_hour = windows.get("five_hour", {})
    weekly = windows.get("seven_day", {}).get("utilization", 0)
    print(f"   plan before {run}: 5-hour {five_hour.get('utilization', 0):.0%}, weekly {weekly:.0%}", flush=True)
    if weekly >= STOP_WEEKLY:
        print(f"=== Weekly plan allowance at {weekly:.0%}: campaign stopped before {run} {time.strftime('%m-%d %H:%M')}", flush=True)
        return False
    if five_hour.get("utilization", 0) >= WAIT_ABOVE:
        wait_until(five_hour.get("resetsAt", 0))
    return True


def run_one(arm, model, scenario, repetition):
    """One run from start to end: prompt, answers to its questions, debrief, standard export, collection."""
    run = f"{arm}_{model}_S{scenario}_rep{repetition}"
    index = load_index()
    if run in index:  # started but not collected (for example after a reboot): start again from scratch
        shutil.rmtree(index[run]["folder"], ignore_errors=True)
    info = {"arm": arm, "model": model, "scenario": int(scenario), "repetition": int(repetition), "folder": str(prepare(arm))}
    index[run] = info
    save_index(index)
    result = run_turn(run, info, (HERE / "prompts" / f"Scenario{scenario}.txt").read_text().strip())
    save_index(index)
    report(run, result)
    timed_out = '"benchmark_timeout"' in (Path(info["folder"]) / "events.jsonl").read_text()
    if timed_out:  # the 4-hour limit is part of the conditions: what the run produced is debriefed and collected
        print(f"=== {run} reached the {HOURS_PER_TURN}-hour turn limit, collected as it is {time.strftime('%m-%d %H:%M')}", flush=True)
    elif not result or result.get("is_error"):  # crash or API error: no analysis to debrief
        print(f"=== {run} failed, it will be tried again from scratch {time.strftime('%m-%d %H:%M')}", flush=True)
        return False

    for _ in range(2):  # answer at most two questions, with the fixed replies
        if timed_out or not result or result.get("is_error"):
            break
        reply_file = asks_something(result.get("result") or "")
        print("   waiting for an answer:", reply_file or "no", flush=True)
        if not reply_file:
            break
        result = reply(run, reply_file)

    if not timed_out and (not result or result.get("is_error")):
        print(f"=== {run} failed, it will be tried again from scratch {time.strftime('%m-%d %H:%M')}", flush=True)
        return False

    debrief(run)
    export(run)
    marker = {4: "direct_interactions.csv"}.get(int(scenario), "info.json")  # a file that every export of the scenario has
    if not (Path(info["folder"]) / "work" / "results" / "standard" / marker).exists():
        export(run)  # once more, e.g. after a technical problem
    if not (Path(info["folder"]) / "work" / "results" / "standard" / marker).exists():
        print(f"=== {run} has no standard files, it will be tried again from scratch {time.strftime('%m-%d %H:%M')}", flush=True)
        return False
    collect(run)
    index = load_index()
    index[run]["collected"] = True
    save_index(index)
    return True


def finish(run):
    """Debrief, export and collect a run whose analysis was stopped (for example at the turn limit)."""
    debrief(run)
    export(run)
    collect(run)
    index = load_index()
    index[run]["collected"] = True
    save_index(index)


def campaign(first_repetition, last_repetition):
    """Every run of the repetitions, scenario after scenario, until the weekly allowance reaches STOP_WEEKLY."""
    for repetition in range(int(first_repetition), int(last_repetition) + 1):
        for scenario in SCENARIOS:
            for arm, model in run_order(scenario):
                run = f"{arm}_{model}_S{scenario}_rep{repetition}"
                if load_index().get(run, {}).get("collected"):
                    continue
                for attempt in range(2):  # a failed run is tried once more
                    if not plan_allows(run):
                        return
                    if run_one(arm, model, scenario, repetition):
                        break
            print(f"=== Scenario {scenario} rep{repetition} finished {time.strftime('%m-%d %H:%M')}", flush=True)
    print(f"=== Campaign finished {time.strftime('%m-%d %H:%M')}", flush=True)


if __name__ == "__main__":
    action, arguments = sys.argv[1], sys.argv[2:]
    {"start": start, "reply": reply, "resume": resume, "debrief": debrief, "export": export, "collect": collect,
     "status": status, "freeze": freeze, "campaign": campaign, "finish": finish}[action](*arguments)
