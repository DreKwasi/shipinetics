#!/usr/bin/env python3
"""check-plugin.py: checks that the plugin is complete and that each harness can load it.

Usage: python3 scripts/check-plugin.py [repo]   (default: the folder above this script)

It checks, without a model and without the network:
- plugin.json, .claude-plugin/plugin.json, .claude-plugin/marketplace.json, hooks.json and
  hooks/hooks.json are valid JSON, and both manifests have the same name and version.
- Each hook command names a script that exists, and git tracks that script as executable.
- Each file in bin/ is tracked as executable.
- Each skills/<name>/SKILL.md and each agents/<name>.md starts with a frontmatter block that has a
  name and a description, and a skill's name is its folder name.
Exit codes: 0 ok, 1 a check failed.
"""
import json
import os
import re
import subprocess
import sys

root = os.path.abspath(sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), ".."))
problems = []


def load(rel):
    try:
        with open(os.path.join(root, rel), encoding="utf-8") as f:
            return json.load(f)
    except FileNotFoundError:
        problems.append("%s: missing" % rel)
    except ValueError as e:
        problems.append("%s: not valid JSON (%s)" % (rel, e))
    return None


def modes():
    """{path: mode} for each file that git tracks, or None outside a git checkout."""
    try:
        out = subprocess.run(["git", "-C", root, "ls-files", "-s"], capture_output=True, text=True, check=True).stdout
    except (OSError, subprocess.CalledProcessError):
        return None
    m = {}
    for line in out.splitlines():
        meta, _, path = line.partition("\t")
        m[path] = meta.split()[0]
    return m


def frontmatter(rel):
    try:
        with open(os.path.join(root, rel), encoding="utf-8") as f:
            text = f.read()
    except OSError:
        problems.append("%s: missing" % rel)
        return None
    m = re.match(r"---\r?\n(.*?)\r?\n---\r?\n", text, re.S)
    if not m:
        problems.append("%s: no frontmatter block at the top" % rel)
        return None
    fields = {}
    for line in m.group(1).splitlines():
        k, sep, v = line.partition(":")
        if sep and not line.startswith((" ", "\t")):
            fields[k.strip()] = v.strip()
    for key in ("name", "description"):
        if not fields.get(key):
            problems.append("%s: the frontmatter has no %s" % (rel, key))
    return fields


tracked = modes()


def executable(rel, why):
    if tracked is None:
        return
    mode = tracked.get(rel)
    if mode is None:
        problems.append("%s: %s, but git doesn't track it" % (rel, why))
    elif mode != "100755":
        problems.append("%s: %s, but git tracks it as %s, not 100755. Run: git update-index --chmod=+x %s" % (rel, why, mode, rel))


# Manifests
a = load("plugin.json")
c = load(".claude-plugin/plugin.json")
load(".claude-plugin/marketplace.json")
if isinstance(a, dict) and isinstance(c, dict):
    for key in ("name", "version"):
        if a.get(key) != c.get(key):
            problems.append("plugin.json and .claude-plugin/plugin.json have a different %s (%r, %r)" % (key, a.get(key), c.get(key)))


# Hooks: Claude Code's hooks/hooks.json and Antigravity's hooks.json
def commands(node):
    if isinstance(node, dict):
        if node.get("type") == "command" and isinstance(node.get("command"), str):
            yield node["command"]
        for v in node.values():
            yield from commands(v)
    elif isinstance(node, list):
        for v in node:
            yield from commands(v)


for rel in ("hooks/hooks.json", "hooks.json"):
    data = load(rel)
    if data is None:
        continue
    for cmd in commands(data):
        m = re.search(r"(?:\$\{CLAUDE_PLUGIN_ROOT\}\"?|\.)/((?:scripts|bin)/[^\s\"']+)", cmd)
        if not m:
            problems.append("%s: can't find the script in the hook command %r" % (rel, cmd))
            continue
        script = m.group(1)
        if not os.path.isfile(os.path.join(root, script)):
            problems.append("%s: the hook command names %s, which doesn't exist" % (rel, script))
        else:
            executable(script, "a hook in %s runs it" % rel)

# Tools in bin/
for name in sorted(os.listdir(os.path.join(root, "bin"))):
    if os.path.isfile(os.path.join(root, "bin", name)):
        executable("bin/" + name, "it is a tool in bin/")

# Skills and subagents
for name in sorted(os.listdir(os.path.join(root, "skills"))):
    if not os.path.isdir(os.path.join(root, "skills", name)):
        continue
    fields = frontmatter("skills/%s/SKILL.md" % name)
    if fields and fields.get("name") and fields["name"] != name:
        problems.append("skills/%s/SKILL.md: the name is %r, but the folder is %r" % (name, fields["name"], name))
for name in sorted(os.listdir(os.path.join(root, "agents"))):
    if name.endswith(".md"):
        frontmatter("agents/" + name)

if problems:
    print("check-plugin: %d problem(s)" % len(problems))
    for p in problems:
        print("- " + p)
    sys.exit(1)
print("check-plugin: ok")
