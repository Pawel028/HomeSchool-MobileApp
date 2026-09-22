#!/usr/bin/env python3
"""Cross-checks every API call `lib/data/*_repository.dart` makes against openapi/openapi.json.

For each `lib/data/*_repository.dart` file, extracts every literal `/v1/...` path plus the ApiClient method
(get/post/put/patch/delete) it's called with, turns the Dart string-interpolated segments (`$childId` etc.)
into OpenAPI-style `{param}` placeholders, and confirms that path+method exists in the OpenAPI contract.

Usage: python3 tools/verify_api_paths.py [--openapi PATH] [--data-dir PATH]
Exit code 0 if every call matches a contract path+method, 1 otherwise (with a report either way).
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

# Matches `_api.<method>(\n?  '<path>'` (single or double quoted), across the common call shapes used in
# lib/data/*_repository.dart: `_api.get('/v1/x')`, `_api.post(\n  '/v1/x/$id',`, etc.
CALL_RE = re.compile(
    r"_api\.(get|post|put|patch|delete)\(\s*['\"]([^'\"]+)['\"]",
    re.MULTILINE,
)

# A Dart string-interpolated segment: `$name` or `${expr}`.
INTERP_RE = re.compile(r"\$\{[^}]+\}|\$[A-Za-z_][A-Za-z0-9_]*")


def dart_path_to_openapi(path: str) -> str:
    """`/v1/children/$childId/plan` -> `/v1/children/{param}/plan` (param name is not preserved: the
    contract's own path-parameter name may differ, e.g. `child_id` vs the Dart-side `childId`)."""
    return INTERP_RE.sub("{param}", path)


def openapi_path_pattern(openapi_path: str) -> re.Pattern[str]:
    """Turns `/v1/children/{child_id}/plan` into a regex matching the normalised Dart path
    `/v1/children/{param}/plan` (or any other placeholder name)."""
    escaped = re.escape(openapi_path)
    escaped = re.sub(r"\\\{[^}]+\\\}", r"\\{[^}]+\\}", escaped)
    return re.compile(f"^{escaped}$")


def extract_calls(dart_source: str, file_name: str) -> list[tuple[str, str, int]]:
    calls = []
    for match in CALL_RE.finditer(dart_source):
        method = match.group(1).upper()
        path = match.group(2)
        if not path.startswith("/v1/"):
            continue
        line = dart_source.count("\n", 0, match.start()) + 1
        calls.append((method, dart_path_to_openapi(path), line))
    return calls


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    repo_root = Path(__file__).resolve().parent.parent
    parser.add_argument(
        "--openapi",
        default=str(repo_root.parent / "api-contracts" / "openapi" / "openapi.json"),
        help="Path to openapi.json (default: ../api-contracts/openapi/openapi.json next to this repo checkout)",
    )
    parser.add_argument("--data-dir", default=str(repo_root / "lib" / "data"), help="Directory of *_repository.dart files")
    args = parser.parse_args()

    openapi_path = Path(args.openapi)
    if not openapi_path.exists():
        print(f"ERROR: openapi.json not found at {openapi_path}", file=sys.stderr)
        return 1
    spec = json.loads(openapi_path.read_text())
    paths: dict[str, dict] = spec.get("paths", {})
    patterns = [(p, openapi_path_pattern(p), {m.upper() for m in methods if m in ("get", "post", "put", "patch", "delete")})
                for p, methods in paths.items()]

    data_dir = Path(args.data_dir)
    dart_files = sorted(data_dir.glob("*_repository.dart"))
    if not dart_files:
        print(f"ERROR: no *_repository.dart files found under {data_dir}", file=sys.stderr)
        return 1

    total = 0
    mismatches: list[str] = []
    for dart_file in dart_files:
        source = dart_file.read_text()
        calls = extract_calls(source, dart_file.name)
        for method, norm_path, line in calls:
            total += 1
            match = next((p for p, pattern, methods in patterns if pattern.match(norm_path) and method in methods), None)
            if match is None:
                # Distinguish "path doesn't exist at all" from "path exists but not with this method".
                path_exists = any(pattern.match(norm_path) for _, pattern, _ in patterns)
                reason = f"method {method} not allowed there" if path_exists else "no matching path in the contract"
                mismatches.append(f"{dart_file.name}:{line}: {method} {norm_path}  ({reason})")

    print(f"Checked {total} API call(s) across {len(dart_files)} repository file(s) against {len(paths)} contract paths.")
    if mismatches:
        print(f"\n{len(mismatches)} MISMATCH(ES):")
        for m in mismatches:
            print(f"  - {m}")
        return 1

    print("All repository API calls match the OpenAPI contract.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
