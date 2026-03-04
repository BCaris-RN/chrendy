# Run with: uv run scripts/generate_semantic_bundle.py

import ast
import os
import re
from datetime import datetime

# --- CONFIGURATION ---
SOURCE_DIR = "."
OUTPUT_FILE = "SEMANTIC_BUNDLE.txt"

IGNORE_DIRS = {
    "node_modules",
    ".git",
    ".idea",
    ".vscode",
    "dist",
    "build",
    "bin",
    "obj",
    "__pycache__",
    "env",
    "venv",
    "coverage",
    "target",
}

ALLOWED_EXTENSIONS = {
    ".py",
    ".dart",
    ".js",
    ".jsx",
    ".ts",
    ".tsx",
    ".md",
    ".sh",
    ".ps1",
}


def is_ignored(path: str) -> bool:
    parts = path.split(os.sep)
    return any(ignored in parts for ignored in IGNORE_DIRS)


def _is_docstring_expr(node: ast.AST) -> bool:
    if not isinstance(node, ast.Expr):
        return False

    value = getattr(node, "value", None)
    if isinstance(value, ast.Str):
        return True

    if isinstance(value, ast.Constant) and isinstance(value.value, str):
        return True

    return False


def clean_python_ast(source_code: str) -> str:
    """Parse Python code into an AST, strip docstrings, and unparse back to text."""
    try:
        parsed = ast.parse(source_code)
        for node in ast.walk(parsed):
            if not isinstance(node, (ast.Module, ast.ClassDef, ast.FunctionDef, ast.AsyncFunctionDef)):
                continue

            body = getattr(node, "body", None)
            if not body:
                continue

            if _is_docstring_expr(body[0]):
                node.body = body[1:]

        return ast.unparse(parsed)
    except Exception as exc:
        return f"# [AST Parse Error: {exc}]\n" + source_code


def clean_c_style_code(source_code: str) -> str:
    """Strip block and line comments from Dart/JS/TS-like code."""
    code = re.sub(r"/\*[\s\S]*?\*/", "", source_code)
    code = re.sub(r"//.*", "", code)
    return os.linesep.join(line for line in code.splitlines() if line.strip())


def generate_bundle() -> None:
    print("[INFO] Generating AST-Aware Semantic Bundle...")
    processed_files = 0
    bundle_content = []

    for root, dirs, files in os.walk(SOURCE_DIR):
        dirs[:] = [d for d in dirs if d not in IGNORE_DIRS]

        for file_name in files:
            ext = os.path.splitext(file_name)[1]
            if ext not in ALLOWED_EXTENSIONS:
                continue

            file_path = os.path.join(root, file_name)
            if is_ignored(file_path):
                continue

            try:
                with open(file_path, "r", encoding="utf-8") as handle:
                    raw_code = handle.read()

                if ext == ".py":
                    cleaned_code = clean_python_ast(raw_code)
                elif ext in {".dart", ".js", ".jsx", ".ts", ".tsx"}:
                    cleaned_code = clean_c_style_code(raw_code)
                else:
                    cleaned_code = raw_code

                bundle_content.append(f"\n\n--- START SEMANTIC FILE: {file_path} ---\n")
                bundle_content.append(cleaned_code)
                bundle_content.append(f"\n--- END SEMANTIC FILE: {file_path} ---")
                processed_files += 1
            except Exception as exc:
                print(f"[WARN] Skipping {file_path}: {exc}")

    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    header = f"""/* === CODEX SEMANTIC SNAPSHOT ===
 * TIMESTAMP: {timestamp}
 * FILES INCLUDED: {processed_files}
 * STRICT_MODE: ENABLED
 * SYSTEM_ROLE: Senior Architect
 * NOTE: Comments and boilerplate have been programmatically stripped for max density.
 */"""

    with open(OUTPUT_FILE, "w", encoding="utf-8") as handle:
        handle.write(header + "".join(bundle_content))

    print(f"[OK] Semantic Bundle Created: {OUTPUT_FILE} ({processed_files} files parsed)")


if __name__ == "__main__":
    generate_bundle()
