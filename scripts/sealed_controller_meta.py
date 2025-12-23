#!/usr/bin/env python3
"""Extract Sealed Secrets controller overrides from a Secret manifest."""
from __future__ import annotations

import argparse
import shlex
import sys
from pathlib import Path

try:
    import yaml  # type: ignore
except ImportError:  # pragma: no cover
    yaml = None  # type: ignore


def emit(key: str, value: str) -> None:
    print(f"{key}={shlex.quote(value or '')}")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("secret_path", type=Path)
    args = parser.parse_args()

    controller_name = ""
    controller_namespace = ""

    if yaml is not None and args.secret_path.exists():
        try:
            with args.secret_path.open("r", encoding="utf-8") as handle:
                data = yaml.safe_load(handle) or {}
        except Exception:
            data = {}
        if isinstance(data, dict):
            metadata = data.get("metadata") or {}
            annotations = metadata.get("annotations") or {}
            controller_name = annotations.get(
                "sealedsecrets.bitnami.com/controller-name", ""
            ) or ""
            controller_namespace = annotations.get(
                "sealedsecrets.bitnami.com/controller-namespace", ""
            ) or ""

    emit("controller_name_from_meta", controller_name)
    emit("controller_namespace_from_meta", controller_namespace)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
