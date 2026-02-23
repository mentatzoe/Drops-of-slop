#!/usr/bin/env python3
"""Deep-merge MCP and settings JSON files from base + selected overlays.

Usage:
    python merge-configs.py --type mcp --output .mcp.json base/mcp.json overlays/web-dev/mcp.json
    python merge-configs.py --type settings --output .claude/settings.json base/settings.json overlays/web-dev/settings.json

    # Migration mode: use existing config as starting base
    python merge-configs.py --type mcp --base existing/.mcp.json --output .mcp.json overlays/web-dev/mcp.json
    python merge-configs.py --type settings --base existing/settings.json --output .claude/settings.json base/settings.json
"""

import argparse
import json
import sys
from copy import deepcopy
from pathlib import Path


def deep_merge(base: dict, overlay: dict) -> dict:
    """Recursively merge overlay into base. Overlay values win for scalars.
    Lists are concatenated. Dicts are merged recursively."""
    result = deepcopy(base)
    for key, value in overlay.items():
        if key.startswith("_"):
            # Skip comment fields
            continue
        if key in result:
            if isinstance(result[key], dict) and isinstance(value, dict):
                result[key] = deep_merge(result[key], value)
            elif isinstance(result[key], list) and isinstance(value, list):
                # Concatenate lists, deduplicating strings
                combined = result[key][:]
                for item in value:
                    if item not in combined:
                        combined.append(item)
                result[key] = combined
            else:
                result[key] = deepcopy(value)
        else:
            result[key] = deepcopy(value)
    return result


def merge_mcp_configs(files: list[Path], base: Path | None = None) -> dict:
    """Merge multiple mcp.json files, combining mcpServers.

    If base is provided, it is loaded as the initial state so that
    custom servers not overridden by any overlay file are preserved.
    """
    result = {"mcpServers": {}}
    env_vars = []

    if base and base.exists():
        with open(base) as fh:
            base_data = json.load(fh)
        if "mcpServers" in base_data:
            result["mcpServers"] = deepcopy(base_data["mcpServers"])
        if "_comment" in base_data:
            env_vars.append(base_data["_comment"])

    for f in files:
        if not f.exists():
            continue
        with open(f) as fh:
            data = json.load(fh)

        # Collect env var comments
        if "_comment" in data:
            env_vars.append(data["_comment"])

        # Merge mcpServers
        if "mcpServers" in data:
            for server_name, server_config in data["mcpServers"].items():
                if server_name in result["mcpServers"]:
                    print(
                        f"Warning: MCP server '{server_name}' defined in multiple configs. "
                        f"Using definition from {f}.",
                        file=sys.stderr,
                    )
                result["mcpServers"][server_name] = deepcopy(server_config)

    # Combine env var comments
    if env_vars:
        all_vars = set()
        for comment in env_vars:
            # Extract var names from comments like "Required env vars: FOO, BAR"
            if ":" in comment:
                vars_part = comment.split(":", 1)[1].strip()
                for var in vars_part.split(","):
                    var = var.strip().rstrip(".")
                    if var and var.lower() != "none":
                        all_vars.add(var)
        if all_vars:
            result["_comment"] = f"Required env vars: {', '.join(sorted(all_vars))}"

    return result


def merge_settings_configs(files: list[Path], base: Path | None = None) -> dict:
    """Merge multiple settings.json files using deep merge.

    If base is provided, it is loaded as the initial state so that
    custom settings not overridden by any overlay file are preserved.
    """
    result = {}
    if base and base.exists():
        with open(base) as fh:
            result = json.load(fh)
    for f in files:
        if not f.exists():
            continue
        with open(f) as fh:
            data = json.load(fh)
        result = deep_merge(result, data)
    return result


def main():
    parser = argparse.ArgumentParser(description="Deep-merge Claude Code config files")
    parser.add_argument(
        "--type",
        choices=["mcp", "settings"],
        required=True,
        help="Type of config to merge",
    )
    parser.add_argument(
        "--output", "-o", required=True, help="Output file path"
    )
    parser.add_argument(
        "--base", "-b", type=Path, default=None,
        help="Existing config to use as starting base (for migration merging)"
    )
    parser.add_argument(
        "files", nargs="+", type=Path, help="Config files to merge (in order)"
    )
    args = parser.parse_args()

    if args.type == "mcp":
        result = merge_mcp_configs(args.files, base=args.base)
    else:
        result = merge_settings_configs(args.files, base=args.base)

    output_path = Path(args.output)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    with open(output_path, "w") as fh:
        json.dump(result, fh, indent=2)
        fh.write("\n")

    print(f"Merged {len(args.files)} config(s) -> {output_path}")


if __name__ == "__main__":
    main()
