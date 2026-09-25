#!/usr/bin/env python3
"""Validate providers.json and labels.json.

Checks what a JSON Schema alone cannot:
- both files against their schema (schemas/*.json);
- every provider key and every label key is unique;
- every provider category names a label that exists in labels.json.

Exits non-zero and prints one line per problem. Requires `jsonschema` (pip install jsonschema).
"""
import json
import sys
from collections import Counter
from pathlib import Path

from jsonschema import Draft7Validator, FormatChecker

ROOT = Path(__file__).resolve().parent.parent


def load(name: str):
    with open(ROOT / name, encoding="utf-8") as handle:
        return json.load(handle)


def schema_errors(data, schema_file: str, label: str) -> list[str]:
    validator = Draft7Validator(load(schema_file), format_checker=FormatChecker())
    return [
        f"{label}: {'/'.join(str(p) for p in error.absolute_path) or '(root)'}: {error.message}"
        for error in sorted(validator.iter_errors(data), key=lambda e: list(e.absolute_path))
    ]


def duplicates(items, label: str) -> list[str]:
    counts = Counter(item.get("key") for item in items if isinstance(item, dict))
    return [f"{label}: duplicate key '{key}' ({count} times)" for key, count in sorted(counts.items()) if count > 1]


def main() -> int:
    providers = load("providers.json")
    labels = load("labels.json")

    problems = []
    problems += schema_errors(labels, "schemas/labelsSchema.json", "labels.json")
    problems += schema_errors(providers, "schemas/providersSchema.json", "providers.json")
    problems += duplicates(labels, "labels.json")
    problems += duplicates(providers, "providers.json")

    label_keys = {label.get("key") for label in labels if isinstance(label, dict)}
    for provider in providers:
        if not isinstance(provider, dict):
            continue
        for category in provider.get("categories", []):
            if category not in label_keys:
                problems.append(
                    f"providers.json: '{provider.get('key')}' uses category '{category}', which labels.json does not define"
                )

    for problem in problems:
        print(problem)
    if problems:
        print(f"{len(problems)} problem(s)")
        return 1
    print(f"OK: {len(providers)} providers, {len(labels)} labels")
    return 0


if __name__ == "__main__":
    sys.exit(main())
