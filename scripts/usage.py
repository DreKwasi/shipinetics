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

# Built-in API list rates in USD per 1M tokens: input, cache_write (5m), cache_read, output.
# Matched by exact key first, then longest case-insensitive prefix. Preview/unlisted models stay
# unpriced until you add them in ~/.config/shipinetics/pricing.json (or the dashboard Pricing panel).
DEFAULT_PRICING = {
    "claude-opus-5":        {"input": 4.00, "cache_write": 5.00, "cache_read": 0.20,  "output": 20.00},
    "claude-opus-4":        {"input": 5.00, "cache_write": 6.25, "cache_read": 0.50,  "output": 25.00},
    "claude-opus":          {"input": 5.00, "cache_write": 6.25, "cache_read": 0.50,  "output": 25.00},
    "claude-sonnet-5":      {"input": 2.00, "cache_write": 2.50, "cache_read": 0.10,  "output": 10.00},
    "claude-sonnet-4":      {"input": 3.00, "cache_write": 3.75, "cache_read": 0.30,  "output": 15.00},
    "claude-sonnet":        {"input": 3.00, "cache_write": 3.75, "cache_read": 0.30,  "output": 15.00},
    "claude-haiku-4":        {"input": 1.00, "cache_write": 1.25, "cache_read": 0.10,  "output": 5.00},
    "claude-haiku":          {"input": 1.00, "cache_write": 1.25, "cache_read": 0.10,  "output": 5.00},
    # Gemini 4 standard API list rates (Carbon & Argon are 50% off through 2026-11-30; override in pricing.json if desired).
    "gemini-4-argon":        {"input": 4.00, "cache_write": 4.00, "cache_read": 0.20,  "output": 20.00},
    "gemini-4-carbon":       {"input": 4.00, "cache_write": 4.00, "cache_read": 0.20,  "output": 20.00},
    "gemini-4-neon":         {"input": 3.00, "cache_write": 3.00, "cache_read": 0.15,  "output": 15.00},
    "gemini-4-hydrogen":     {"input": 1.50, "cache_write": 1.50, "cache_read": 0.075, "output": 7.50},
    "gemini-3.8-flash":      {"input": 0.75, "cache_write": 0.75, "cache_read": 0.075, "output": 3.75},
    "gemini-3-pro":          {"input": 2.00, "cache_write": 2.00, "cache_read": 0.20,  "output": 12.00},
    "gemini-3-flash":       {"input": 0.50, "cache_write": 0.50, "cache_read": 0.05,  "output": 3.00},
    "gemini-2.5-pro":       {"input": 1.25, "cache_write": 1.25, "cache_read": 0.125, "output": 10.00},
    "gemini-2.5-flash-lite": {"input": 0.10, "cache_write": 0.10, "cache_read": 0.01, "output": 0.40},
    "gemini-2.5-flash":     {"input": 0.30, "cache_write": 0.30, "cache_read": 0.03,  "output": 2.50},
    "gemini-2.0-flash":     {"input": 0.10, "cache_write": 0.10, "cache_read": 0.025, "output": 0.40},
}


def log_path():
    p = os.environ.get("SHIPINETICS_USAGE_LOG")
    if p:
        return p
    base = os.environ.get("XDG_DATA_HOME") or os.path.join(os.path.expanduser("~"), ".local", "share")
    return os.path.join(base, "shipinetics", "usage.tsv")


def pricing_path():
    p = os.environ.get("SHIPINETICS_PRICING_FILE")
    if p:
        return p
    base = os.environ.get("XDG_CONFIG_HOME") or os.path.join(os.path.expanduser("~"), ".config")
    return os.path.join(base, "shipinetics", "pricing.json")


def _clean_rate(obj):
    if not isinstance(obj, dict):
        return None
    out = {}
    for k in ("input", "cache_write", "cache_read", "output"):
        v = obj.get(k, 0)
        if not isinstance(v, (int, float)) or isinstance(v, bool) or v < 0:
            return None
        out[k] = float(v)
    return out


def load_user_pricing():
    p = pricing_path()
    if not os.path.isfile(p):
        return {}
    try:
        raw = json.load(open(p, encoding="utf-8"))
    except (OSError, ValueError):
        return {}
    if not isinstance(raw, dict):
        return {}
    out = {}
    for k, v in raw.items():
        if isinstance(k, str) and k.strip():
            r = _clean_rate(v)
            if r is not None:
                out[k.strip().lower()] = r
    return out


def save_user_pricing(overrides):
    cleaned = {}
    if isinstance(overrides, dict):
        for k, v in overrides.items():
            if isinstance(k, str) and k.strip():
                r = _clean_rate(v)
                if r is not None:
                    cleaned[k.strip().lower()] = r
    p = pricing_path()
    os.makedirs(os.path.dirname(os.path.abspath(p)), exist_ok=True)
    tmp = "%s.%d.tmp" % (p, os.getpid())
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(cleaned, f, indent=2, sort_keys=True)
        f.write("\n")
    os.replace(tmp, p)
    return cleaned


def load_pricing():
    merged = {k.lower(): dict(v) for k, v in DEFAULT_PRICING.items()}
    merged.update(load_user_pricing())
    return merged


def lookup_rate(model, pricing):
    m = str(model or "").strip().lower()
    if not m:
        return None
    if m in pricing:
        return pricing[m]
    best = ""
    for k in pricing:
        if m.startswith(k) and (len(m) == len(k) or m[len(k)] in "-_.:/@"):
            if len(k) > len(best):
                best = k
    return pricing[best] if best else None


def row_cost(r, pricing):
    rate = lookup_rate(r.get("model"), pricing)
    if rate is None:
        return None
    return (
        r["input"] * rate["input"]
        + r["cache_write"] * rate["cache_write"]
        + r["cache_read"] * rate["cache_read"]
        + r["output"] * rate["output"]
    ) / 1_000_000.0


def sum_cost(rows, pricing):
    """(total_usd_or_None, sorted_unpriced_models)."""
    total_usd = 0.0
    priced_any = False
    unpriced = set()
    for r in rows:
        c = row_cost(r, pricing)
        if c is None:
            unpriced.add(str(r.get("model") or "unknown"))
        else:
            total_usd += c
            priced_any = True
    return (total_usd if priced_any else None), sorted(unpriced)


def fmt_cost(v):
    if v is None:
        return "-"
    if v == 0:
        return "$0.00"
    if v < 0.01:
        return "$%.4f" % v
    if v < 1000:
        return "$%.2f" % v
    return "$%s" % format(v, ",.2f")


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
    if not project or project == "-":
        return False
    p_real = os.path.realpath(project)
    for root in roots:
        r = root.rstrip("/")
        if project == r or project.startswith(r + "/"):
            return True
        rr = os.path.realpath(r).rstrip("/")
        if p_real == rr or p_real.startswith(rr + "/"):
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


def row_harness(r):
    return "antigravity" if str(r.get("entrypoint", "")).lower().startswith("antigravity") else "claude"


def matches_filters(r, harness="all", model=""):
    if harness and harness != "all" and row_harness(r) != harness:
        return False
    if model and model.lower() not in str(r.get("model", "")).lower():
        return False
    return True


def cmd_report(args):
    path = log_path()
    roots = None if args.all else project_roots()
    backfill(roots, path)
    rows = [r for r in load_log(path)
            if in_project(r["project"], roots) and r["start"] >= since(args.days)
            and matches_filters(r, getattr(args, "harness", "all"), getattr(args, "model", ""))]
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
    usd, unpriced = sum_cost(rows, load_pricing())
    if usd is not None and not unpriced:
        print("Estimated API cost: %s (from list rates; override in %s)" % (fmt_cost(usd), pricing_path()))
    elif usd is not None:
        print("Estimated API cost: %s (+ %d unpriced model%s: %s; set rates in %s)" % (
            fmt_cost(usd), len(unpriced), "" if len(unpriced) == 1 else "s", ", ".join(unpriced), pricing_path()))
    elif unpriced:
        print("Estimated API cost: unpriced (%s; set rates in %s)" % (", ".join(unpriced), pricing_path()))
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
    usd, unpriced = sum_cost(rows, load_pricing())
    if usd is not None and not unpriced:
        print("| Est. API cost | %s |" % fmt_cost(usd))
    elif usd is not None:
        print("| Est. API cost | %s (+ unpriced: %s) |" % (fmt_cost(usd), ", ".join(unpriced)))
    elif unpriced:
        print("| Est. API cost | unpriced (%s) |" % ", ".join(unpriced))


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


def backfill_live(roots, path, stat_cache):
    """Incremental backfill for `serve`: re-parse only transcripts whose (mtime_ns, size) changed."""
    if not stat_cache:
        backfill(roots, path)
        for t in transcripts():
            try:
                st = os.stat(t)
                stat_cache[t] = (st.st_mtime_ns, st.st_size)
            except OSError:
                pass
        return
    new = {}
    for t in transcripts():
        try:
            st = os.stat(t)
        except OSError:
            continue
        sig = (st.st_mtime_ns, st.st_size)
        if stat_cache.get(t) == sig:
            continue
        stat_cache[t] = sig
        if roots is not None and not in_project(peek_cwd(t), roots):
            continue
        sid, rows = session_rows(t)
        if rows and in_project(rows[0]["project"], roots):
            new[sid] = rows
    if new:
        write_sessions(path, new, only_if_newer=False)


def build_page_data(roots, path, days, harness="all", model="", live=False, refresh_ms=5000, stat_cache=None):
    if stat_cache is not None:
        backfill_live(roots, path, stat_cache)
    else:
        backfill(roots, path)
    rows = [r for r in load_log(path) if in_project(r["project"], roots)]
    data = [{k: r[k] for k in FIELDS} for r in rows]
    name = "all projects" if roots is None else os.path.basename(roots[0]) or roots[0]
    payload = {
        "scope": name,
        "generated": datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S" if live else "%Y-%m-%d %H:%M"),
        "days": days if days and days > 0 else 0,
        "harness": harness or "all",
        "model": model or "",
        "pricing": load_pricing(),
        "default_pricing": DEFAULT_PRICING,
        "user_pricing": load_user_pricing(),
        "rows": data,
    }
    if live:
        payload["live"] = True
        payload["refresh_ms"] = refresh_ms
    return payload, rows


def render_html(payload):
    with open(os.path.join(HERE, "usage-page.html"), encoding="utf-8") as f:
        page = f.read()
    # The data goes in a JSON script block. Escape < so no value (a session title) can close it.
    # The title goes in first, so no value in the data can be mistaken for its placeholder.
    blob = json.dumps(payload)
    return page.replace("__USAGE_TITLE__", html.escape(payload["scope"])).replace("__USAGE_DATA__", blob.replace("<", "\\u003c"))


def cmd_html(args):
    path = log_path()
    roots = None if args.all else project_roots()
    payload, rows = build_page_data(
        roots, path, args.days,
        harness=getattr(args, "harness", "all"),
        model=getattr(args, "model", ""),
    )
    page = render_html(payload)
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
    if getattr(args, "open", False):
        import webbrowser
        webbrowser.open("file://" + os.path.abspath(out))
    return 0


def cmd_serve(args):
    import http.server
    import socketserver
    import threading
    import urllib.parse

    path = log_path()
    roots = None if args.all else project_roots()
    days = args.days
    harness = getattr(args, "harness", "all")
    model = getattr(args, "model", "")
    refresh_ms = max(1, getattr(args, "interval", 5)) * 1000
    lock = threading.Lock()
    stat_cache = {}

    def current_payload():
        with lock:
            payload, _ = build_page_data(
                roots, path, days, harness=harness, model=model,
                live=True, refresh_ms=refresh_ms, stat_cache=stat_cache,
            )
            return payload

    # Warm initial cache before binding so the first page load is instant.
    current_payload()

    class Handler(http.server.BaseHTTPRequestHandler):
        def log_message(self, fmt, *a):
            pass

        def do_GET(self):
            req_path = urllib.parse.urlsplit(self.path).path
            if req_path in ("/", "/index.html"):
                body = render_html(current_payload()).encode("utf-8")
                ctype = "text/html; charset=utf-8"
            elif req_path == "/api/data":
                body = json.dumps(current_payload()).encode("utf-8")
                ctype = "application/json; charset=utf-8"
            else:
                self.send_error(404)
                return
            self.send_response(200)
            self.send_header("Content-Type", ctype)
            self.send_header("Content-Length", str(len(body)))
            self.send_header("Cache-Control", "no-store")
            self.end_headers()
            self.wfile.write(body)

        def do_POST(self):
            req_path = urllib.parse.urlsplit(self.path).path
            if req_path != "/api/pricing":
                self.send_error(404)
                return
            try:
                length = int(self.headers.get("Content-Length") or "0")
                if length < 0 or length > 262144:
                    raise ValueError("invalid length")
                raw = self.rfile.read(length).decode("utf-8")
                obj = json.loads(raw) if raw else {}
                if not isinstance(obj, dict):
                    raise ValueError("expected JSON object")
            except (ValueError, UnicodeDecodeError):
                self.send_error(400)
                return
            with lock:
                save_user_pricing(obj)
            body = json.dumps(current_payload()).encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.send_header("Content-Length", str(len(body)))
            self.send_header("Cache-Control", "no-store")
            self.end_headers()
            self.wfile.write(body)

    base_cls = getattr(http.server, "ThreadingHTTPServer", http.server.HTTPServer)

    class LocalServer(base_cls):
        allow_reuse_address = True

        def server_bind(self):
            # Skip HTTPServer's socket.getfqdn("127.0.0.1") reverse DNS lookup, which can stall on macOS.
            socketserver.TCPServer.server_bind(self)
            self.server_name = "127.0.0.1"
            self.server_port = self.server_address[1]

    try:
        srv = LocalServer(("127.0.0.1", getattr(args, "port", 8765)), Handler)
    except OSError as exc:
        print("shipinetics-usage: could not bind 127.0.0.1:%d: %s" % (getattr(args, "port", 8765), exc), file=sys.stderr)
        return 2
    url = "http://127.0.0.1:%d/" % srv.server_address[1]
    print("Serving token usage at %s (Ctrl+C to stop)" % url, flush=True)
    if not getattr(args, "no_open", False):
        import webbrowser
        webbrowser.open(url)
    try:
        srv.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        srv.server_close()
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
    p.add_argument("--harness", choices=("all", "antigravity", "claude"), default="all")
    p.add_argument("--model", default="")
    sub = p.add_subparsers(dest="cmd")
    s = sub.add_parser("session", add_help=False)
    s.add_argument("id", nargs="?")
    h = sub.add_parser("html", add_help=False)
    h.add_argument("--out")
    h.add_argument("--open", action="store_true")
    sv = sub.add_parser("serve", add_help=False)
    sv.add_argument("--port", type=int, default=8765)
    sv.add_argument("--interval", type=int, default=5)
    sv.add_argument("--no-open", action="store_true")
    r = sub.add_parser("record", add_help=False)
    r.add_argument("transcript")
    r.add_argument("--cwd", default="")
    r.add_argument("--detach", action="store_true")
    b = sub.add_parser("backfill", add_help=False)
    for sp in (s, h, sv, r, b):
        sp.add_argument("--all", action="store_true", default=argparse.SUPPRESS)
        sp.add_argument("--days", type=int, default=argparse.SUPPRESS)
        sp.add_argument("--harness", choices=("all", "antigravity", "claude"), default=argparse.SUPPRESS)
        sp.add_argument("--model", default=argparse.SUPPRESS)
    try:
        args = p.parse_args(argv)
    except SystemExit:
        return 2
    cmd = {"session": cmd_session, "html": cmd_html, "serve": cmd_serve, "record": cmd_record, "backfill": cmd_backfill}.get(args.cmd, cmd_report)
    return cmd(args)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
