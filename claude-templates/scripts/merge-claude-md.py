#!/usr/bin/env python3
"""Merge an existing CLAUDE.md with the base template.

Preserves custom sections while injecting template structure.
Uses markers to identify template-managed vs custom content.

Usage:
    python merge-claude-md.py --base base/CLAUDE.md --existing ~/project/CLAUDE.md --output ~/project/CLAUDE.md
    python merge-claude-md.py --base base/CLAUDE.md --output ~/project/CLAUDE.md  # No existing file
"""

import argparse
import re
import sys
from pathlib import Path

MARKER_START = "<!-- claude-templates: managed-start -->"
MARKER_END = "<!-- claude-templates: managed-end -->"

# Sections in the base template that are "managed" (will be replaced on re-migration)
MANAGED_HEADERS = {
    "Quality Standards",
    "Error Handling Philosophy",
    "Communication Style",
    "Git Workflow",
    "Architecture & Conventions",
    "When to Read Reference Files",
    "Security",
    "Auto-Update Memory (MANDATORY)",
    "Context Discipline",
}


def parse_sections(content: str) -> list[tuple[str, str]]:
    """Split markdown into (header, body) tuples.

    The first element may have header="" for content before the first heading.
    """
    sections = []
    current_header = ""
    current_lines = []

    for line in content.splitlines(keepends=True):
        match = re.match(r"^(#{1,3})\s+(.+)", line)
        if match:
            # Save previous section
            sections.append((current_header, "".join(current_lines)))
            current_header = match.group(2).strip()
            current_lines = [line]
        else:
            current_lines.append(line)

    sections.append((current_header, "".join(current_lines)))
    return sections


def merge(base_content: str, existing_content: str | None) -> str:
    """Merge base template with existing CLAUDE.md content."""
    if existing_content is None:
        return base_content

    # Strip any previous managed markers from existing content
    existing_clean = existing_content
    existing_clean = re.sub(
        rf"{re.escape(MARKER_START)}.*?{re.escape(MARKER_END)}\n?",
        "",
        existing_clean,
        flags=re.DOTALL,
    )

    existing_sections = parse_sections(existing_clean)
    base_sections = parse_sections(base_content)

    # Collect custom sections (headers not in the managed set)
    custom_sections = []
    for header, body in existing_sections:
        if header == "":
            # Preamble content before first heading -- check if it's just the title
            stripped = body.strip()
            if stripped and not stripped.startswith("# Project Guidelines"):
                custom_sections.append(("", body))
        elif header == "Project Guidelines":
            # Skip the title -- we'll use the template's title
            continue
        elif header == "Project-Specific":
            # Preserve existing project-specific section contents
            custom_sections.append((header, body))
        elif header not in MANAGED_HEADERS:
            custom_sections.append((header, body))

    # Build output: template content (marked as managed) + custom sections
    output_parts = []

    # Template content with markers
    output_parts.append(MARKER_START + "\n")
    output_parts.append(base_content.rstrip() + "\n")
    output_parts.append(MARKER_END + "\n")

    # Append custom sections
    if custom_sections:
        output_parts.append("\n## Project-Specific\n\n")
        for header, body in custom_sections:
            if header and header != "Project-Specific":
                # Re-emit as a subsection under Project-Specific
                output_parts.append(f"### {header}\n")
                # Strip the original heading line from body
                body_lines = body.splitlines(keepends=True)
                if body_lines and re.match(r"^#{1,3}\s+", body_lines[0]):
                    body_lines = body_lines[1:]
                output_parts.append("".join(body_lines))
            elif header == "Project-Specific":
                # Preserve body as-is (minus heading)
                body_lines = body.splitlines(keepends=True)
                if body_lines and re.match(r"^#{1,3}\s+", body_lines[0]):
                    body_lines = body_lines[1:]
                output_parts.append("".join(body_lines))
            else:
                output_parts.append(body)

    return "".join(output_parts)


def main():
    parser = argparse.ArgumentParser(description="Merge CLAUDE.md files")
    parser.add_argument("--base", required=True, help="Path to base template CLAUDE.md")
    parser.add_argument("--existing", help="Path to existing project CLAUDE.md")
    parser.add_argument("--output", "-o", required=True, help="Output file path")
    args = parser.parse_args()

    base_path = Path(args.base)
    if not base_path.exists():
        print(f"Error: base template not found: {base_path}", file=sys.stderr)
        sys.exit(1)

    base_content = base_path.read_text()

    existing_content = None
    if args.existing:
        existing_path = Path(args.existing)
        if existing_path.exists():
            existing_content = existing_path.read_text()

    result = merge(base_content, existing_content)

    output_path = Path(args.output)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(result)

    if existing_content:
        print(f"Merged: {args.base} + {args.existing} -> {args.output}")
    else:
        print(f"Copied: {args.base} -> {args.output}")


if __name__ == "__main__":
    main()
