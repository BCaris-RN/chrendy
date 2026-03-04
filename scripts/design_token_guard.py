#!/usr/bin/env python3
"""Enforce locked design tokens in source code.

Checks for:
- Raw color literals (hex / Dart `0xAARRGGBB`) in UI source files.
- Off-scale font sizes in CSS and Flutter text styles.

The guard uses a JSON lockfile so enforcement is machine-readable and CI-safe.
"""

from __future__ import annotations

import argparse
import fnmatch
import json
import math
import re
import sys
from dataclasses import dataclass
from pathlib import Path

SUPPORTED_EXTENSIONS = {
    ".css",
    ".scss",
    ".sass",
    ".less",
    ".js",
    ".jsx",
    ".ts",
    ".tsx",
    ".dart",
}

IGNORE_DIR_NAMES = {
    ".git",
    "node_modules",
    "dist",
    "build",
    ".next",
    "coverage",
    "__pycache__",
    "experimental",  # spike sandbox is intentionally excluded from production token enforcement
}

HEX_LITERAL_RE = re.compile(r"#(?:[0-9a-fA-F]{3}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})\b")
DART_COLOR_RE = re.compile(r"0x([0-9a-fA-F]{8})\b")
CSS_FONT_SIZE_RE = re.compile(r"(font-size\s*:\s*)(\d+(?:\.\d+)?)(px\b)", re.IGNORECASE)
DART_FONT_SIZE_RE = re.compile(r"(fontSize\s*:\s*)(\d+(?:\.\d+)?)\b")


@dataclass(frozen=True)
class ColorToken:
    token_id: str
    hex_value: str  # normalized #RRGGBB
    css_replacement: str | None = None
    dart_replacement: str | None = None


@dataclass(frozen=True)
class FontSizeToken:
    token_id: str
    value_px: float
    css_replacement: str | None = None
    dart_replacement: str | None = None


@dataclass
class Violation:
    path: str
    line: int
    col: int
    code: str
    message: str
    suggestion: str | None = None


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Validate source files against locked design tokens.")
    parser.add_argument("--root", default=".", help="Repo root to scan (default: current directory).")
    parser.add_argument(
        "--lockfile",
        default="templates/guardrails/design_tokens.lock.json",
        help="Path to design token lockfile JSON.",
    )
    parser.add_argument(
        "--file-list",
        help="Optional newline-delimited file list (changed files). When provided, only these files are scanned.",
    )
    parser.add_argument(
        "--autofix",
        action="store_true",
        help="Autofix raw CSS hex literals when an exact token mapping is available.",
    )
    return parser.parse_args()


def normalize_path(path: str) -> str:
    return path.replace("\\", "/").lstrip("./")


def line_col_from_offset(text: str, offset: int) -> tuple[int, int]:
    line = text.count("\n", 0, offset) + 1
    last_newline = text.rfind("\n", 0, offset)
    col = offset + 1 if last_newline < 0 else offset - last_newline
    return line, col


def normalize_hex(value: str) -> str:
    raw = value.strip().upper()
    if raw.startswith("0X"):
        hex_part = raw[2:]
        if len(hex_part) == 8:
            # Dart colors are AARRGGBB; compare palette by RGB.
            return f"#{hex_part[2:]}"
        raise ValueError(f"Unsupported 0x hex color length: {value}")
    if not raw.startswith("#"):
        raise ValueError(f"Expected hex literal: {value}")
    body = raw[1:]
    if len(body) == 3:
        return "#" + "".join(ch * 2 for ch in body)
    if len(body) == 6:
        return "#" + body
    if len(body) == 8:
        # CSS #RRGGBBAA -> compare by RGB only for palette lookup.
        return "#" + body[:6]
    raise ValueError(f"Unsupported hex literal length: {value}")


def load_json(path: Path) -> dict:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError:
        print(f"[ERROR] Lockfile not found: {path}")
        sys.exit(2)
    except json.JSONDecodeError as exc:
        print(f"[ERROR] Failed to parse lockfile JSON ({path}): {exc}")
        sys.exit(2)


def load_lockfile(path: Path) -> tuple[list[ColorToken], list[FontSizeToken], list[str]]:
    data = load_json(path)
    section = data.get("designTokenGuard", data)

    color_entries = section.get("colors", [])
    font_entries = section.get("fontSizesPx", [])
    ignore_globs = [str(item) for item in section.get("ignoreGlobs", [])]

    colors: list[ColorToken] = []
    for entry in color_entries:
        if not isinstance(entry, dict):
            continue
        token_id = str(entry.get("id", "")).strip()
        hex_value = str(entry.get("hex", "")).strip()
        if not token_id or not hex_value:
            continue
        colors.append(
            ColorToken(
                token_id=token_id,
                hex_value=normalize_hex(hex_value),
                css_replacement=(str(entry["css"]) if "css" in entry else None),
                dart_replacement=(str(entry["dart"]) if "dart" in entry else None),
            )
        )

    fonts: list[FontSizeToken] = []
    for entry in font_entries:
        if not isinstance(entry, dict):
            continue
        token_id = str(entry.get("id", "")).strip()
        raw_value = entry.get("value")
        if not token_id or raw_value is None:
            continue
        try:
            value_px = float(raw_value)
        except (TypeError, ValueError):
            continue
        fonts.append(
            FontSizeToken(
                token_id=token_id,
                value_px=value_px,
                css_replacement=(str(entry["css"]) if "css" in entry else None),
                dart_replacement=(str(entry["dart"]) if "dart" in entry else None),
            )
        )

    if not colors and not fonts:
        print(f"[ERROR] Lockfile contains no `colors` or `fontSizesPx` entries: {path}")
        sys.exit(2)

    return colors, fonts, ignore_globs


def is_supported_source(path: Path) -> bool:
    return path.suffix.lower() in SUPPORTED_EXTENSIONS and path.is_file()


def should_skip_file(path: Path, root: Path, extra_ignore_globs: list[str]) -> bool:
    rel = normalize_path(str(path.relative_to(root)))
    parts = set(rel.split("/"))
    if parts & IGNORE_DIR_NAMES:
        return True
    for pattern in extra_ignore_globs:
        if fnmatch.fnmatch(rel, pattern):
            return True
    return False


def iter_candidate_files(root: Path, file_list: Path | None, extra_ignore_globs: list[str]) -> list[Path]:
    candidates: list[Path] = []
    seen: set[Path] = set()

    if file_list is not None:
        for raw in file_list.read_text(encoding="utf-8").splitlines():
            item = raw.strip().lstrip("\ufeff")
            if not item:
                continue
            path = (root / item).resolve() if not Path(item).is_absolute() else Path(item)
            try:
                rel_to_root = path.resolve().relative_to(root.resolve())
            except Exception:
                continue
            full = root / rel_to_root
            if full in seen or not is_supported_source(full) or should_skip_file(full, root, extra_ignore_globs):
                continue
            seen.add(full)
            candidates.append(full)
        return candidates

    for path in root.rglob("*"):
        if path in seen or not is_supported_source(path):
            continue
        if should_skip_file(path, root, extra_ignore_globs):
            continue
        seen.add(path)
        candidates.append(path)
    return candidates


def format_float(value: float) -> str:
    if math.isclose(value, round(value)):
        return str(int(round(value)))
    return f"{value:g}"


def nearest_font_token(value: float, tokens: list[FontSizeToken]) -> FontSizeToken | None:
    if not tokens:
        return None
    return min(tokens, key=lambda token: abs(token.value_px - value))


def analyze_file(
    path: Path,
    root: Path,
    color_tokens: list[ColorToken],
    font_tokens: list[FontSizeToken],
    autofix: bool,
) -> tuple[list[Violation], int]:
    try:
        original = path.read_text(encoding="utf-8")
    except UnicodeDecodeError:
        original = path.read_text(encoding="utf-8", errors="ignore")

    rel = normalize_path(str(path.relative_to(root)))
    ext = path.suffix.lower()
    is_css_like = ext in {".css", ".scss", ".sass", ".less"}
    is_dart = ext == ".dart"

    color_lookup = {token.hex_value: token for token in color_tokens}
    font_values = {token.value_px for token in font_tokens}

    violations: list[Violation] = []
    autofixed_count = 0
    content = original

    if is_css_like:
        def replace_hex(match: re.Match[str]) -> str:
            nonlocal autofixed_count
            literal = match.group(0)
            offset = match.start()
            line, col = line_col_from_offset(content, offset)
            normalized = normalize_hex(literal)
            token = color_lookup.get(normalized)
            suggestion = token.css_replacement if token and token.css_replacement else None

            if autofix and suggestion:
                autofixed_count += 1
                return suggestion

            violations.append(
                Violation(
                    path=rel,
                    line=line,
                    col=col,
                    code="TOKEN_COLOR_LITERAL",
                    message=f"Raw color literal `{literal}` is not allowed in production UI code.",
                    suggestion=(f"Use token `{suggestion}`." if suggestion else None),
                )
            )
            return literal

        content = HEX_LITERAL_RE.sub(replace_hex, content)
    else:
        for match in HEX_LITERAL_RE.finditer(content):
            literal = match.group(0)
            line, col = line_col_from_offset(content, match.start())
            normalized = normalize_hex(literal)
            token = color_lookup.get(normalized)
            suggestion = None
            if token:
                suggestion = token.dart_replacement if is_dart and token.dart_replacement else token.css_replacement
            violations.append(
                Violation(
                    path=rel,
                    line=line,
                    col=col,
                    code="TOKEN_COLOR_LITERAL",
                    message=f"Raw color literal `{literal}` is not allowed in production UI code.",
                    suggestion=(f"Use token `{suggestion}`." if suggestion else None),
                )
            )

    if is_dart:
        for match in DART_COLOR_RE.finditer(content):
            literal = "0x" + match.group(1)
            line, col = line_col_from_offset(content, match.start())
            normalized = normalize_hex(literal)
            token = color_lookup.get(normalized)
            suggestion = token.dart_replacement if token and token.dart_replacement else None
            violations.append(
                Violation(
                    path=rel,
                    line=line,
                    col=col,
                    code="TOKEN_DART_COLOR_LITERAL",
                    message=f"Raw Flutter color literal `{literal}` is not allowed in production UI code.",
                    suggestion=(f"Use token `{suggestion}`." if suggestion else None),
                )
            )

    for match in CSS_FONT_SIZE_RE.finditer(content):
        raw_value = float(match.group(2))
        if raw_value in font_values:
            continue
        line, col = line_col_from_offset(content, match.start(2))
        nearest = nearest_font_token(raw_value, font_tokens)
        suggestion = None
        if nearest:
            if nearest.css_replacement:
                suggestion = f"Use `{nearest.css_replacement}` ({format_float(nearest.value_px)}px token)."
            else:
                suggestion = f"Nearest allowed size: {format_float(nearest.value_px)}px (`{nearest.token_id}`)."
        violations.append(
            Violation(
                path=rel,
                line=line,
                col=col,
                code="TOKEN_FONT_SIZE_OFF_SCALE",
                message=f"Font size `{format_float(raw_value)}px` is not in locked token scale.",
                suggestion=suggestion,
            )
        )

    if is_dart:
        for match in DART_FONT_SIZE_RE.finditer(content):
            raw_value = float(match.group(2))
            if raw_value in font_values:
                continue
            line, col = line_col_from_offset(content, match.start(2))
            nearest = nearest_font_token(raw_value, font_tokens)
            suggestion = None
            if nearest:
                if nearest.dart_replacement:
                    suggestion = f"Use `{nearest.dart_replacement}` ({format_float(nearest.value_px)}px token)."
                else:
                    suggestion = f"Nearest allowed size: {format_float(nearest.value_px)}px (`{nearest.token_id}`)."
            violations.append(
                Violation(
                    path=rel,
                    line=line,
                    col=col,
                    code="TOKEN_DART_FONT_SIZE_OFF_SCALE",
                    message=f"Flutter `fontSize: {format_float(raw_value)}` is not in locked token scale.",
                    suggestion=suggestion,
                )
            )

    if autofix and content != original:
        path.write_text(content, encoding="utf-8")

    return violations, autofixed_count


def main() -> int:
    args = parse_args()
    root = Path(args.root).resolve()
    lockfile = (root / args.lockfile).resolve() if not Path(args.lockfile).is_absolute() else Path(args.lockfile)
    file_list = None
    if args.file_list:
        file_list = (root / args.file_list).resolve() if not Path(args.file_list).is_absolute() else Path(args.file_list)

    color_tokens, font_tokens, extra_ignore_globs = load_lockfile(lockfile)
    candidates = iter_candidate_files(root, file_list, extra_ignore_globs)

    print(f"[INFO] Design token guard scanning {len(candidates)} file(s)")
    print(f"[INFO] Lockfile: {normalize_path(str(lockfile.relative_to(root)) if lockfile.is_relative_to(root) else str(lockfile))}")

    all_violations: list[Violation] = []
    autofixed_total = 0

    for path in candidates:
        violations, autofixed_count = analyze_file(path, root, color_tokens, font_tokens, args.autofix)
        all_violations.extend(violations)
        autofixed_total += autofixed_count

    if args.autofix and autofixed_total:
        print(f"[FIXED] Applied {autofixed_total} CSS token autofix replacement(s).")

    if all_violations:
        for item in all_violations:
            loc = f"{item.path}:{item.line}:{item.col}"
            print(f"[ERROR] {loc} [{item.code}] {item.message}")
            if item.suggestion:
                print(f"        {item.suggestion}")
        print(f"[ERROR] Design token guard failed with {len(all_violations)} violation(s).")
        return 1

    print("[OK] Design token guard passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
