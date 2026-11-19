#!/usr/bin/env python3
"""usage.py: the tokens that Claude Code sessions used, read from Claude Code's own transcripts.

Nothing here calls a model, so it costs no tokens. bin/shipinetics-usage and the SessionEnd hook
(scripts/usage-record.sh) run it; `shipinetics-usage --help` lists the commands.

A transcript is <claude dir>/projects/<folder>/<session id>.jsonl. Its subagents are in
<session id>/subagents/agent-*.jsonl, with their type in agent-*.meta.json. How the lines count:
- Claude Code writes one API response several times (once for each content block) with the same
  message id. The usage can grow between the copies, so each field takes the largest value, and
  each id counts once in the whole session.
- A forked or resumed session starts with a copy of its parent's lines, which keep the parent's
  session id. Those lines in a main transcript are skipped, so the parent's calls count only once.
- A call with no tokens at all, or with the model "<synthetic>", is not an API call.

The log has one row for each session, agent and model. Recording a session again replaces the rows
that it has again and keeps the others (Claude Code can delete subagent files before the session).
Default path: ${XDG_DATA_HOME:-~/.local/share}/shipinetics/usage.tsv (SHIPINETICS_USAGE_LOG
overrides it). Python 3.7 or later, standard library only.
"""
import argparse
import collections
import datetime
import fcntl
import glob
import html
import json
import os
import re
import subprocess
import sys

FIELDS = ["session_id", "start", "end", "project", "branch", "title", "entrypoint", "agent", "model",
          "effort", "api_calls", "input", "cache_write", "cache_read", "output"]
NUM = ["api_calls", "input", "cache_write", "cache_read", "output"]
TOKENS = (("input", "input_tokens"), ("cache_write", "cache_creation_input_tokens"),
          ("cache_read", "cache_read_input_tokens"), ("output", "output_tokens"))
HERE = os.path.dirname(os.path.abspath(__file__))
CHANGED_AFTER = datetime.timedelta(minutes=2)


def log_path():
    p = os.environ.get("SHIPINETICS_USAGE_LOG")
    if p:
        return p
    base = os.environ.get("XDG_DATA_HOME") or os.path.join(os.path.expanduser("~"), ".local", "share")
    return os.path.join(base, "shipinetics", "usage.tsv")


def claude_dir():
    return os.environ.get("CLAUDE_CONFIG_DIR") or os.path.join(os.path.expanduser("~"), ".claude")


def gemini_home():
    return os.environ.get("GEMINI_HOME") or os.path.join(os.path.expanduser("~"), ".gemini")


def is_antigravity_transcript(path):
    """True when path is an Antigravity transcript.jsonl (by layout or by its first JSONL entry)."""
    if os.path.basename(path) == "transcript.jsonl" and os.path.basename(os.path.dirname(path)) == "logs":
        return True
    for o in read_jsonl(path):
        return "step_index" in o or ("created_at" in o and "timestamp" not in o)
    return False


def transcript_sid(path):
    """Session id for a Claude Code (<id>.jsonl) or Antigravity (brain/<id>/.system_generated/logs/transcript.jsonl) transcript."""
    if os.path.basename(path) == "transcript.jsonl" and os.path.basename(os.path.dirname(path)) == "logs":
        parent = os.path.dirname(os.path.dirname(path))
        if os.path.basename(parent) == ".system_generated":
            return os.path.basename(os.path.dirname(parent))
    name = os.path.basename(path)
    return name[:-len(".jsonl")] if name.endswith(".jsonl") else name


def unwrap_arg(val):
    """Unwrap JSON-encoded string values inside Antigravity transcript tool_calls args."""
    if not isinstance(val, str):
        return ""
    s = val.strip()
    if len(s) >= 2 and s[0] == '"' and s[-1] == '"':
        try:
            u = json.loads(s)
            if isinstance(u, str):
                return u
        except ValueError:
            pass
        return s[1:-1]
    return s


def _skip_inferred_path(p):
    """Ignore agent-internal and OS directories when inferring a session's workspace path."""
    home = os.path.expanduser("~")
    prefixes = (
        gemini_home().rstrip("/") + "/",
        claude_dir().rstrip("/") + "/",
        os.path.join(home, ".gemini") + "/",
        os.path.join(home, ".claude") + "/",
        "/usr/", "/etc/", "/System/", "/bin/", "/sbin/",
    )
    return any(p.startswith(pre) for pre in prefixes)


def _resolve_project_from_path(p, git_cache):
    if not p or not p.startswith("/") or _skip_inferred_path(p):
        return ""
    d = p if os.path.isdir(p) else os.path.dirname(p)
    if not d or not os.path.isdir(d):
        return ""
    if d not in git_cache:
        git_cache[d] = git(d, "rev-parse", "--show-toplevel")
    return git_cache[d] or d


def _antigravity_user_title(content):
    if not isinstance(content, str) or not content:
        return ""
    m = re.search(r"<USER_REQUEST>\s*(.*?)\s*</USER_REQUEST>", content, re.S)
    text = m.group(1) if m else content
    for line in text.splitlines():
        line = line.strip()
        if line:
            return line[:120]
    return ""


def _antigravity_entrypoint(path):
    parts = os.path.abspath(path).split(os.sep)
    for name in ("antigravity-cli", "antigravity-ide", "antigravity"):
        if name in parts:
            return name
    return "antigravity"


def scan_antigravity(path, calls, meta, cwd_override=""):
    """Collect API calls and metadata from an Antigravity transcript.jsonl."""
    meta["entrypoint"] = meta["entrypoint"] or _antigravity_entrypoint(path)
    if cwd_override:
        meta["cwd"] = cwd_override
    git_cache = {}
    fallback_dir = ""
    for idx, o in enumerate(read_jsonl(path)):
        ts = o.get("created_at")
        if isinstance(ts, str) and ts:
            if not meta["start"] or ts < meta["start"]:
                meta["start"] = ts
            if not meta["end"] or ts > meta["end"]:
                meta["end"] = ts
        if not meta["cwd"]:
            ws = o.get("workspacePaths")
            if o.get("cwd"):
                meta["cwd"] = str(o["cwd"])
            elif isinstance(ws, list) and ws:
                meta["cwd"] = str(ws[0])
        if o.get("type") == "USER_INPUT" and not meta["title"]:
            meta["title"] = _antigravity_user_title(o.get("content", ""))
        if o.get("type") != "PLANNER_RESPONSE":
            continue
        if not meta["cwd"]:
            for tc in o.get("tool_calls") or []:
                args = tc.get("args") if isinstance(tc, dict) else None
                if not isinstance(args, dict):
                    continue
                for k in ("Cwd", "Path", "TargetFile", "AbsolutePath", "SearchPath", "DirectoryPath"):
                    p = unwrap_arg(args.get(k))
                    if not p:
                        continue
                    resolved = _resolve_project_from_path(p, git_cache)
                    if resolved:
                        # Prefer a git repo root over a plain directory.
                        d = p if os.path.isdir(p) else os.path.dirname(p)
                        if git_cache.get(d):
                            meta["cwd"] = resolved
                            break
                        if not fallback_dir:
                            fallback_dir = resolved
                if meta["cwd"]:
                    break
        key = "step_%s" % o.get("step_index", idx)
        model = o.get("model") or "unknown"
        if model == "<synthetic>":
            continue
        c = calls.get(key)
        if c is None:
            c = calls[key] = {"agent": "main", "model": model, "effort": "",
                              "input": 0, "cache_write": 0, "cache_read": 0, "output": 0}
        c["input"] = max(c["input"], num(o.get("input_tokens")))
        c["cache_write"] = max(c["cache_write"],
                               num(o.get("cache_write_tokens")) or num(o.get("cache_creation_input_tokens")))
        c["cache_read"] = max(c["cache_read"],
                              num(o.get("cache_read_tokens")) or num(o.get("cache_read_input_tokens")))
        c["output"] = max(c["output"], num(o.get("output_tokens")))
        if o.get("effort") and not c["effort"]:
            c["effort"] = str(o["effort"])
    if not meta["cwd"] and fallback_dir:
        meta["cwd"] = fallback_dir


def clean(s):
    """A TSV field or a line of output: no tabs or new lines, never empty."""
    return re.sub(r"[\t\r\n]+", " ", str(s or "")).strip() or "-"


def read_jsonl(path):
    with open(path, encoding="utf-8", errors="replace") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                o = json.loads(line)
            except ValueError:
                continue
            if isinstance(o, dict):
                yield o


def num(v):
    return v if isinstance(v, int) and v > 0 else 0


def parse_ts(ts):
    try:
        t = datetime.datetime.fromisoformat(str(ts).replace("Z", "+00:00"))
    except ValueError:
        return None
    return t if t.tzinfo else t.replace(tzinfo=datetime.timezone.utc)


# ---- reading transcripts

def scan(path, agent, calls, meta, own_sid):
    """Collect the API calls in one transcript file into calls[message id], and update meta.
    own_sid is set for a main transcript: lines copied from another session are skipped."""
    main = own_sid is not None
    for o in read_jsonl(path):
        osid = o.get("sessionId")
        if main and osid and osid != own_sid:
            continue
        ts = o.get("timestamp")
        if isinstance(ts, str) and ts:
            if not meta["start"] or ts < meta["start"]:
                meta["start"] = ts
            if not meta["end"] or ts > meta["end"]:
                meta["end"] = ts
        if main and o.get("type") == "custom-title" and o.get("customTitle"):
            meta["title"] = o["customTitle"]
        if o.get("type") != "assistant":
            continue
        m = o.get("message")
        if not isinstance(m, dict) or not isinstance(m.get("usage"), dict):
            continue
        key = m.get("id") or o.get("requestId") or o.get("uuid")
        model = m.get("model") or "unknown"
        if not key or model == "<synthetic>":
            continue
        if main:
            meta["cwd"] = meta["cwd"] or o.get("cwd") or ""
            meta["branch"] = o.get("gitBranch") or meta["branch"]
            meta["entrypoint"] = meta["entrypoint"] or o.get("entrypoint") or ""
        c = calls.get(key)
        if c is None:
            c = calls[key] = {"agent": agent or ("subagent" if o.get("isSidechain") else "main"),
                              "model": model, "effort": "", "input": 0, "cache_write": 0, "cache_read": 0, "output": 0}
        u = m["usage"]
        for field, name in TOKENS:
            c[field] = max(c[field], num(u.get(name)))
        if o.get("effort") and not c["effort"]:
            c["effort"] = str(o["effort"])


def session_rows(transcript, cwd_override=""):
    """(session id, rows) for one main transcript, its subagents included."""
    sid = transcript_sid(transcript)
    meta = {"start": "", "end": "", "cwd": "", "branch": "", "title": "", "entrypoint": ""}
    calls = {}
    if is_antigravity_transcript(transcript):
        scan_antigravity(transcript, calls, meta, cwd_override=cwd_override)
    else:
        scan(transcript, None, calls, meta, own_sid=sid)
        if not meta["cwd"] and cwd_override:
            meta["cwd"] = cwd_override
        folder = transcript[:-len(".jsonl")]
        for p in sorted(glob.glob(os.path.join(folder, "subagents", "*.jsonl"))):
            agent = "subagent"
            try:
                with open(p[:-len(".jsonl")] + ".meta.json", encoding="utf-8") as f:
                    agent = json.load(f).get("agentType") or agent
            except (OSError, ValueError, AttributeError):
                pass
            scan(p, agent, calls, meta, own_sid=None)
        if not meta["title"]:
            try:
                with open(os.path.join(folder, "custom-title.json"), encoding="utf-8") as f:
                    meta["title"] = json.load(f).get("customTitle") or ""
            except (OSError, ValueError, AttributeError):
                pass
    acc = {}
    for c in calls.values():
        if not any(c[f] for f, _ in TOKENS):
            continue
        a = acc.setdefault((c["agent"], c["model"]), {"api_calls": 0, "input": 0, "cache_write": 0, "cache_read": 0,
                                                       "output": 0, "efforts": collections.Counter()})
        a["api_calls"] += 1
        for f, _ in TOKENS:
            a[f] += c[f]
        if c["effort"]:
            a["efforts"][c["effort"]] += 1
    rows = []
    for (agent, model), a in sorted(acc.items()):
        effort = a["efforts"].most_common(1)[0][0] if a["efforts"] else "-"
        rows.append({"session_id": sid, "start": meta["start"], "end": meta["end"], "project": meta["cwd"],
                     "branch": meta["branch"], "title": meta["title"], "entrypoint": meta["entrypoint"],
                     "agent": agent, "model": model, "effort": effort, **{k: a[k] for k in NUM}})
    return sid, rows


def peek_cwd(transcript, limit=200):
    """The working folder of a session, from the first lines of its transcript."""
    sid = transcript_sid(transcript)
    ag = is_antigravity_transcript(transcript)
    git_cache = {}
    fallback_dir = ""
    try:
        with open(transcript, encoding="utf-8", errors="replace") as f:
            for i, line in enumerate(f):
                if i >= limit:
                    break
                try:
                    o = json.loads(line)
                except ValueError:
                    continue
                if not isinstance(o, dict):
                    continue
                if ag:
                    ws = o.get("workspacePaths")
                    if o.get("cwd"):
                        return str(o["cwd"])
                    if isinstance(ws, list) and ws:
                        return str(ws[0])
                    if o.get("type") == "PLANNER_RESPONSE":
                        for tc in o.get("tool_calls") or []:
                            args = tc.get("args") if isinstance(tc, dict) else None
                            if not isinstance(args, dict):
                                continue
                            for k in ("Cwd", "Path", "TargetFile", "AbsolutePath", "SearchPath", "DirectoryPath"):
                                p = unwrap_arg(args.get(k))
                                if not p:
                                    continue
                                resolved = _resolve_project_from_path(p, git_cache)
                                if resolved:
                                    d = p if os.path.isdir(p) else os.path.dirname(p)
                                    if git_cache.get(d):
                                        return resolved
                                    if not fallback_dir:
                                        fallback_dir = resolved
                elif o.get("cwd") and o.get("sessionId", sid) == sid:
                    return o["cwd"]
    except OSError:
        pass
    return fallback_dir


# ---- the log

def read_log(path):
    """(rows, bad lines). Lines that don't parse are kept, so a rewrite never drops them."""
    rows, bad = [], []
    if not os.path.exists(path):
        return rows, bad
    header = None
    with open(path, encoding="utf-8", errors="replace") as f:
        for line in f:
            line = line.rstrip("\n")
            if header is None:
                header = line.split("\t")
                continue
            if not line:
                continue
            parts = line.split("\t")
            if len(parts) != len(header):
                bad.append(line)
                continue
            r = dict(zip(header, parts))
            try:
                for k in NUM:
                    r[k] = int(r.get(k, ""))
            except ValueError:
                bad.append(line)
                continue
            rows.append(r)
    return rows, bad


def load_log(path):
    return read_log(path)[0]


def write_sessions(path, sessions, only_if_newer=False):
    """Record sessions ({id: rows}) in the log under a lock. A session with no rows changes nothing.
    New rows replace the rows with the same agent and model; the session's other old rows stay.
    only_if_newer (backfill): skip a session that the log already has with the same or a later end."""
    os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
    with open(path + ".lock", "w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        rows, bad = read_log(path)
        current = collections.OrderedDict()
        for r in rows:
            current.setdefault(r["session_id"], []).append(r)
        changed = False
        for sid, new in sessions.items():
            if not new:
                continue
            old = current.get(sid, [])
            if only_if_newer and old and max(r["end"] for r in old) >= max(r["end"] for r in new):
                continue
            keys = {(r["agent"], r["model"]) for r in new}
            current[sid] = list(new) + [r for r in old if (r["agent"], r["model"]) not in keys]
            changed = True
        if not changed:
            return
        out = sorted((r for rs in current.values() for r in rs),
                     key=lambda r: (r["start"], r["session_id"], r["agent"], r["model"]))
        tmp = "%s.%d.tmp" % (path, os.getpid())
        with open(tmp, "w", encoding="utf-8") as f:
            f.write("\t".join(FIELDS) + "\n")
            for r in out:
                f.write("\t".join(str(int(r[k])) if k in NUM else clean(r.get(k)) for k in FIELDS) + "\n")
            for line in bad:
                f.write(line + "\n")
        os.replace(tmp, path)


# ---- which project

def git(start, *args):
    try:
        out = subprocess.run(["git", "-C", start] + list(args), capture_output=True, text=True, timeout=10)
    except (OSError, subprocess.SubprocessError):
        return ""
    return out.stdout.strip() if out.returncode == 0 else ""


def project_roots():
    """The folders that make up this project: the git main checkout and every worktree of the
    repo, or the folder itself outside git. The project starts at CLAUDE_PROJECT_DIR, else PWD."""
    start = os.path.abspath(os.environ.get("CLAUDE_PROJECT_DIR") or os.getcwd())
    top = git(start, "rev-parse", "--show-toplevel")
    if not top:
        return [start]
    roots = []
    common = git(start, "rev-parse", "--git-common-dir")
    if common:
        common = os.path.normpath(os.path.join(start, common))
        if os.path.basename(common) == ".git":
            roots.append(os.path.dirname(common))
    for line in git(start, "worktree", "list", "--porcelain").splitlines():
        if line.startswith("worktree "):
            roots.append(line[len("worktree "):])
    roots.append(top)
    seen, out = set(), []
    for r in roots:
        r = r.rstrip("/") or "/"
        if r not in seen:
            seen.add(r)
            out.append(r)
    return out


def in_project(project, roots):
    if roots is None:
        return True
    for root in roots:
        root = root.rstrip("/")
        if project == root or project.startswith(root + "/"):
            return True
    return False


def transcripts():
    """Every main transcript under Claude Code's projects folder and Antigravity's brain folders."""
    out = []
    for d in sorted(glob.glob(os.path.join(claude_dir(), "projects", "*"))):
        out.extend(sorted(glob.glob(os.path.join(d, "*.jsonl"))))
    gh = gemini_home()
    for app in ("antigravity", "antigravity-cli", "antigravity-ide"):
        out.extend(sorted(glob.glob(os.path.join(gh, app, "brain", "*", ".system_generated", "logs", "transcript.jsonl"))))
    return out


def backfill(roots, path):
    """Record the project's transcripts that the log doesn't have, or that changed after the log's
    end time for them. roots None means every project. Returns how many sessions were parsed."""
    ends = {}
    for r in load_log(path):
        if r["end"] > ends.get(r["session_id"], ""):
            ends[r["session_id"]] = r["end"]
    new = {}
    for t in transcripts():
        sid = transcript_sid(t)
        if sid in ends:
            end = parse_ts(ends[sid])
            mtime = datetime.datetime.fromtimestamp(os.path.getmtime(t), datetime.timezone.utc)
            if end and mtime <= end + CHANGED_AFTER:
                continue
        if roots is not None and not in_project(peek_cwd(t), roots):
            continue
        sid, rows = session_rows(t)
        if rows and in_project(rows[0]["project"], roots):
            new[sid] = rows
    if new:
        write_sessions(path, new, only_if_newer=True)
    return len(new)


# ---- output

def compact(n):
    n = int(n)
    for limit, div, suffix in ((999_950_000, 1_000_000_000, "B"), (999_950, 1_000_000, "M"), (1_000, 1_000, "K")):
        if n >= limit:
            return ("%.1f" % (n / div)).rstrip("0").rstrip(".") + suffix
    return str(n)


def total(r):
    return r["input"] + r["cache_write"] + r["cache_read"] + r["output"]


def local(ts, n=16):
    """A transcript time (UTC) as local time, YYYY-MM-DD HH:MM (or the first n characters)."""
    t = parse_ts(ts)
    return t.astimezone().strftime("%Y-%m-%d %H:%M")[:n] if t else "-"


def since(days):
    if days is None or days <= 0:
        return ""
    t = datetime.datetime.now(datetime.timezone.utc) - datetime.timedelta(days=days)
    return t.strftime("%Y-%m-%dT%H:%M:%S")


def by_session(rows):
    out = collections.OrderedDict()
    for r in sorted(rows, key=lambda r: (r["start"], r["session_id"])):
        s = out.setdefault(r["session_id"], {"session_id": r["session_id"], "start": r["start"], "end": r["end"],
                                             "title": r["title"], "project": r["project"], **{k: 0 for k in NUM}})
        for k in NUM:
            s[k] += r[k]
    return list(out.values())


def table(header, rows, right):
    widths = [max(len(str(x)) for x in col) for col in zip(header, *rows)]
    for row in [header] + rows:
        print("  ".join(str(c).rjust(w) if i in right else str(c).ljust(w)
                        for i, (c, w) in enumerate(zip(row, widths))).rstrip())


def scope_label(roots):
    if roots is None:
        return "all projects"
    return roots[0] + (" and %d worktree%s" % (len(roots) - 1, "" if len(roots) == 2 else "s") if len(roots) > 1 else "")


def cmd_report(args):
    path = log_path()
    roots = None if args.all else project_roots()
    backfill(roots, path)
    rows = [r for r in load_log(path) if in_project(r["project"], roots) and r["start"] >= since(args.days)]
    span = "all time" if not args.days or args.days <= 0 else "last %d days" % args.days
    print("Token usage: %s, %s. From session transcripts; no model ran." % (scope_label(roots), span))
    sessions = by_session(rows)
    if not sessions:
        print("No sessions found. Sessions are recorded when they end, and backfill reads Claude Code and Antigravity transcripts.")
        return 0
    out = []
    for s in sessions:
        title = s["title"] if s["title"] != "-" else ""
        out.append([local(s["start"], 10), s["session_id"][:8], (title[:34] + "...") if len(title) > 37 else title,
                    s["api_calls"], compact(s["input"]), compact(s["cache_write"]), compact(s["cache_read"]),
                    compact(s["output"]), compact(total(s))])
    t = {k: sum(s[k] for s in sessions) for k in NUM}
    out.append(["Total", "%d sessions" % len(sessions), "", t["api_calls"], compact(t["input"]),
                compact(t["cache_write"]), compact(t["cache_read"]), compact(t["output"]), compact(total(t))])
    table(["Date", "Session", "Title", "Calls", "Input", "Cache write", "Cache read", "Output", "Total"], out,
          right={3, 4, 5, 6, 7, 8})
    print("Input: new input tokens. Cache write: input written to the prompt cache. Cache read: input read from it. "
          "Output: tokens the model wrote. Details of one session: shipinetics-usage session <id>")
    return 0


def duration(start, end):
    a, b = parse_ts(start), parse_ts(end)
    if not a or not b:
        return "-"
    mins = int((b - a).total_seconds() // 60)
    return "%dh %02dm" % (mins // 60, mins % 60) if mins >= 60 else "%dm" % mins


def print_session(sid, rows, source):
    r0 = min(rows, key=lambda r: r["start"])
    end = max(r["end"] for r in rows)
    print("Session %s  %s" % (sid, clean(r0["title"])))
    print("%s to %s, local time (%s from the first to the last message). Project: %s. From %s." % (
        local(r0["start"]), local(end), duration(r0["start"], end), clean(r0["project"]), source))
    out = [[r["agent"], r["model"], r["effort"], r["api_calls"], compact(r["input"]), compact(r["cache_write"]),
            compact(r["cache_read"]), compact(r["output"]), compact(total(r))] for r in rows]
    t = {k: sum(r[k] for r in rows) for k in NUM}
    out.append(["Total", "", "", t["api_calls"], compact(t["input"]), compact(t["cache_write"]),
                compact(t["cache_read"]), compact(t["output"]), compact(total(t))])
    table(["Agent", "Model", "Effort", "Calls", "Input", "Cache write", "Cache read", "Output", "Total"], out,
          right={3, 4, 5, 6, 7, 8})
    print()
    print("For the worksheet Metrics (add up the sessions of the task):")
    print("| Tokens: input / cache write / cache read / output | %s / %s / %s / %s |" % tuple(
        format(t[k], ",") for k in ("input", "cache_write", "cache_read", "output")))
    print("| API calls | %d |" % t["api_calls"])
    print("| Session span (first to last message) | %s |" % duration(r0["start"], end))


def cmd_session(args):
    if args.id:
        found = [t for t in transcripts() if transcript_sid(t).startswith(args.id)]
        logged = collections.OrderedDict()
        for r in load_log(log_path()):
            if r["session_id"].startswith(args.id):
                logged.setdefault(r["session_id"], []).append(r)
        ids = sorted({transcript_sid(t) for t in found} | set(logged))
        if len(ids) > 1:
            print("shipinetics-usage: %s matches %d sessions: %s. Give more of the id." % (args.id, len(ids), ", ".join(ids)),
                  file=sys.stderr)
            return 2
        if found:
            sid, rows = session_rows(max(found, key=os.path.getmtime))
            if rows:
                print_session(sid, rows, "its transcript")
                return 0
        if logged:
            sid = next(iter(logged))
            print_session(sid, logged[sid], "the usage log (the transcript is no longer on disk)")
            return 0
        print("shipinetics-usage: no session %s in the transcripts or the usage log." % args.id, file=sys.stderr)
        return 1
    roots = None if args.all else project_roots()
    for t in sorted(transcripts(), key=os.path.getmtime, reverse=True):
        if roots is not None and not in_project(peek_cwd(t), roots):
            continue
        sid, rows = session_rows(t)
        if rows and in_project(rows[0]["project"], roots):
            print_session(sid, rows, "its transcript")
            return 0
    print("shipinetics-usage: no session transcript found for this project.", file=sys.stderr)
    return 1


def shipinetics_root(start):
    d = os.path.abspath(start)
    while True:
        if os.path.isdir(os.path.join(d, ".shipinetics")):
            return d
        parent = os.path.dirname(d)
        if parent == d:
            return None
        d = parent


def cmd_html(args):
    path = log_path()
    roots = None if args.all else project_roots()
    backfill(roots, path)
    rows = [r for r in load_log(path) if in_project(r["project"], roots)]
    data = [{k: r[k] for k in FIELDS} for r in rows]
    name = "all projects" if roots is None else os.path.basename(roots[0]) or roots[0]
    with open(os.path.join(HERE, "usage-page.html"), encoding="utf-8") as f:
        page = f.read()
    # The data goes in a JSON script block. Escape < so no value (a session title) can close it.
    # The title goes in first, so no value in the data can be mistaken for its placeholder.
    blob = json.dumps({"scope": name, "generated": datetime.datetime.now().strftime("%Y-%m-%d %H:%M"),
                       "days": args.days if args.days and args.days > 0 else 0, "rows": data})
    page = page.replace("__USAGE_TITLE__", html.escape(name)).replace("__USAGE_DATA__", blob.replace("<", "\\u003c"))
    out = args.out
    if not out:
        today = datetime.date.today().isoformat()
        sroot = None if roots is None else shipinetics_root(roots[0])
        if sroot:
            out = os.path.join(sroot, ".shipinetics", "explainers", "%s-token-usage.html" % today)
        else:
            out = os.path.join(os.environ.get("TMPDIR") or "/tmp", "shipinetics-token-usage-%s.html" % today)
    os.makedirs(os.path.dirname(os.path.abspath(out)), exist_ok=True)
    with open(out, "w", encoding="utf-8") as f:
        f.write(page)
    print(out)
    print("%d sessions. Open it with: open %s" % (len({r["session_id"] for r in rows}), out))
    return 0


def detach():
    """Go on in the background, so the SessionEnd hook returns at once."""
    if os.fork() > 0:
        os._exit(0)
    os.setsid()
    if os.fork() > 0:
        os._exit(0)
    fd = os.open(os.devnull, os.O_RDWR)
    for i in (0, 1, 2):
        os.dup2(fd, i)


def cmd_record(args):
    if not os.path.isfile(args.transcript):
        return 0
    if args.detach:
        detach()
    sid, rows = session_rows(args.transcript, cwd_override=getattr(args, "cwd", "") or "")
    if rows:
        write_sessions(log_path(), {sid: rows})
    return 0


def cmd_backfill(args):
    n = backfill(None if args.all else project_roots(), log_path())
    print("Recorded %d session%s in %s" % (n, "" if n == 1 else "s", log_path()))
    return 0


def main(argv):
    p = argparse.ArgumentParser(prog="shipinetics-usage", add_help=False)
    p.add_argument("--all", action="store_true")
    p.add_argument("--days", type=int, default=30)
    sub = p.add_subparsers(dest="cmd")
    s = sub.add_parser("session", add_help=False)
    s.add_argument("id", nargs="?")
    h = sub.add_parser("html", add_help=False)
    h.add_argument("--out")
    r = sub.add_parser("record", add_help=False)
    r.add_argument("transcript")
    r.add_argument("--cwd", default="")
    r.add_argument("--detach", action="store_true")
    b = sub.add_parser("backfill", add_help=False)
    for sp in (s, h, r, b):
        sp.add_argument("--all", action="store_true", default=argparse.SUPPRESS)
        sp.add_argument("--days", type=int, default=argparse.SUPPRESS)
    try:
        args = p.parse_args(argv)
    except SystemExit:
        return 2
    cmd = {"session": cmd_session, "html": cmd_html, "record": cmd_record, "backfill": cmd_backfill}.get(args.cmd, cmd_report)
    return cmd(args)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
