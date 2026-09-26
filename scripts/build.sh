#!/usr/bin/env bash
printf '%s\n' 'Legacy Docker entrypoint retired in Codespaces; use .devcontainer setup/start-daemon + the current QEMU runbook instead.' >&2
exit 64
