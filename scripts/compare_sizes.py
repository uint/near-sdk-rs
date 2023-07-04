#!/usr/bin/env python3

# Requires:
# `pip install GitPython`
import os
import tempfile
import glob
from git import Repo

this_file = os.path.abspath(os.path.realpath(__file__))
project_root = os.path.dirname(os.path.dirname(this_file))

def common_entries(*dcts):
    if not dcts:
        return
    for i in set(dcts[0]).intersection(*dcts[1:]):
        yield (i,) + tuple(d[i] for d in dcts)

def compare_sizes(old, new):
    def fmt(name, old, new):
        return name + " | " + str(old) + " | " + str(new)

    return "".join(*map(fmt, common_entries(old, new)))

def list_dirs(path):
    entries = map(lambda p: os.path.join(path, p), os.listdir(path))
    return filter(os.path.isdir, entries)

class ProjectInstance:
    def __init__(self, root_dir):
        self.root_dir = root_dir

    def examples_dir(self):
        return os.path.join(self.root_dir, "examples")

    def build_artifacts(self):
        import subprocess

        return subprocess.run(os.path.join(self.examples_dir(), "build_all_docker.sh"), stdout = subprocess.DEVNULL)

    def sizes(self):
        self.build_artifacts()

        artifact_paths = glob.glob(self.examples_dir() + '/*/res/*.wasm')
        return {os.path.basename(path):os.stat(path).st_size for path in artifact_paths}

cur_branch = ProjectInstance(project_root)
repo = Repo(project_root)

def report(master, this_branch):
    def diff(old, new):
        diff = (new - old)/old

        res = "{0:+.0%}".format(diff)
        if diff < -.1:
            res = f"<div class=\"good\">{res}</div>"
        elif diff > .1:
            res = f"<div class=\"bad\">{res}</div>"

        return res

    header = """# Contract size report

Sizes are given in bytes.

| contract | master | this branch | difference |
| - | - | - | - |"""

    combined = [(name,master,branch,diff(master, branch)) for name, master, branch in common_entries(master, this_branch)]
    rows = [f"| {name} | {old} | {new} | {diff} |" for name, old, new, diff in combined]

    return "\n".join([header, *rows])

try:
    with tempfile.TemporaryDirectory() as tempdir:
        repo.git.worktree("add", tempdir, "master")
        master = ProjectInstance(tempdir)

        master_sizes = master.sizes()
        cur_sizes = cur_branch.sizes()
        print(report(master_sizes, cur_sizes))
finally:
    repo.git.worktree("prune")
