"""Download the latest CI web preview for a branch and serve it locally.

Local Flutter builds are blocked on the main dev machine (Windows Smart App
Control rejects the SDK's unsigned impellerc.exe), so the web app is built by
the web-preview job in .github/workflows/build-android.yml and this script
only downloads and serves it. Needs the GitHub CLI, logged in.

Run from mobile/:
  python tool/preview_ci_web.py                 # current branch, waits for a running build
  python tool/preview_ci_web.py --run 123456    # a specific workflow run
  python tool/preview_ci_web.py --serve-only    # re-serve the last download
"""

import argparse
import functools
import http.server
import json
import shutil
import subprocess
import sys
from pathlib import Path

REPO = "nisakib07/daily_tracker"
WORKFLOW = "build-android.yml"
ARTIFACT = "money-master-web-preview"
MOBILE_ROOT = Path(__file__).resolve().parent.parent
OUT_DIR = MOBILE_ROOT / "build" / "ci_web_preview"


def gh(*args: str, capture: bool = True) -> str:
    exe = shutil.which("gh") or r"C:\Program Files\GitHub CLI\gh.exe"
    result = subprocess.run(
        [exe, *args], check=True, capture_output=capture, text=True
    )
    return result.stdout if capture else ""


def current_branch() -> str:
    return subprocess.run(
        ["git", "rev-parse", "--abbrev-ref", "HEAD"],
        cwd=MOBILE_ROOT,
        check=True,
        capture_output=True,
        text=True,
    ).stdout.strip()


def recent_runs(branch: str) -> list[dict]:
    return json.loads(
        gh(
            "run", "list", "--repo", REPO, "--workflow", WORKFLOW,
            "--branch", branch, "--limit", "10",
            "--json", "databaseId,status,headSha,displayTitle",
        )
    )


def try_download(run_id: int) -> bool:
    shutil.rmtree(OUT_DIR, ignore_errors=True)
    try:
        gh(
            "run", "download", str(run_id), "--repo", REPO,
            "--name", ARTIFACT, "--dir", str(OUT_DIR),
        )
    except subprocess.CalledProcessError:
        return False
    return (OUT_DIR / "index.html").exists()


def download_latest(branch: str) -> None:
    runs = recent_runs(branch)
    if not runs:
        sys.exit(f"No CI runs found for branch '{branch}'. Push it first.")

    newest = runs[0]
    if newest["status"] != "completed":
        print(f"Waiting for CI run {newest['databaseId']} ({newest['displayTitle']})...")
        gh("run", "watch", str(newest["databaseId"]), "--repo", REPO,
           "--interval", "15", capture=False)

    for run in runs:
        if try_download(run["databaseId"]):
            print(f"Downloaded preview from run {run['databaseId']} "
                  f"(commit {run['headSha'][:7]}: {run['displayTitle']})")
            return
        print(f"Run {run['databaseId']} has no web preview, trying an older one...")
    sys.exit(f"No downloadable web preview found for branch '{branch}'.")


class NoCacheHandler(http.server.SimpleHTTPRequestHandler):
    # Every download replaces the files under the same names, so the browser
    # must never serve a stale main.dart.js from its cache.
    extensions_map = {
        **http.server.SimpleHTTPRequestHandler.extensions_map,
        ".wasm": "application/wasm",
        ".mjs": "text/javascript",
        ".js": "text/javascript",
    }

    def end_headers(self) -> None:
        self.send_header("Cache-Control", "no-store")
        super().end_headers()


def serve(port: int) -> None:
    if not (OUT_DIR / "index.html").exists():
        sys.exit(f"Nothing to serve in {OUT_DIR}. Run without --serve-only first.")
    handler = functools.partial(NoCacheHandler, directory=str(OUT_DIR))
    server = http.server.ThreadingHTTPServer(("127.0.0.1", port), handler)
    print(f"Serving Money Master web preview at http://127.0.0.1:{port}", flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--branch", help="branch to preview (default: current)")
    parser.add_argument("--run", type=int, help="workflow run id to preview")
    parser.add_argument("--port", type=int, default=52710)
    parser.add_argument("--serve-only", action="store_true",
                        help="serve the last download without fetching")
    args = parser.parse_args()

    if not args.serve_only:
        if args.run:
            if not try_download(args.run):
                sys.exit(f"Run {args.run} has no downloadable web preview.")
        else:
            download_latest(args.branch or current_branch())
    serve(args.port)


if __name__ == "__main__":
    main()
