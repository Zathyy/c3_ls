#!/usr/bin/env python3
"""
Minimal LSP test client for c3_ls.
Spawns the server, sends requests, prints responses.

Usage:
    python3 lsp_client.py [--server PATH]

Commands (interactive):
    init                         - send initialize request
    open <path>                  - send textDocument/didOpen
    comp <path> <line> <char>    - send textDocument/completion request
    shut                         - send shutdown + exit
    exit / quit                  - alias for shutdown
    help                         - list commands
"""

import argparse
import json
import os
import subprocess
import sys

DEFAULT_SERVER = os.path.join(os.path.dirname(__file__), "build", "c3_ls")
_msg_id = 0


def next_id() -> int:
    global _msg_id
    _msg_id += 1
    return _msg_id


def encode(obj: dict) -> bytes:
    body = json.dumps(obj, separators=(",", ":")).encode()
    header = f"Content-Length: {len(body)}\r\n\r\n".encode()
    return header + body


def read_response(stdout) -> dict | None:
    header = b""
    while not header.endswith(b"\r\n\r\n"):
        ch = stdout.read(1)
        if not ch:
            return None
        header += ch

    content_length = None
    for line in header.split(b"\r\n"):
        if line.startswith(b"Content-Length:"):
            content_length = int(line.split(b":")[1].strip())

    if content_length is None:
        print("[client] ERROR: no Content-Length in response header", file=sys.stderr)
        return None

    body = stdout.read(content_length)
    return json.loads(body)


def send(proc, obj: dict):
    raw = encode(obj)
    print(f"\n[client -> server]\n{json.dumps(obj, indent=2)}")
    proc.stdin.write(raw)
    proc.stdin.flush()


def recv(proc) -> dict | None:
    resp = read_response(proc.stdout)
    if resp is not None:
        print(f"\n[server -> client]\n{json.dumps(resp, indent=2)}")
    return resp


def cmd_initialize(proc, _args=None):
    send(proc, {
        "jsonrpc": "2.0",
        "method": "initialize",
        "params": {
            "processId": os.getpid(),
            "clientInfo": {"name": "lsp_client.py", "version": "0.1.0"},
            "rootUri": None,
            "workspaceFolders": [],
        },
        "id": next_id(),
    })
    recv(proc)
    # send initialized notification (no response expected)
    send(proc, {
        "jsonrpc": "2.0",
        "method": "initialized",
        "params": {},
    })


def cmd_shutdown(proc, _args=None):
    send(proc, {
        "jsonrpc": "2.0",
        "id": next_id(),
        "method": "shutdown",
    })
    recv(proc)
    send(proc, {
        "jsonrpc": "2.0",
        "method": "exit",
    })
    proc.stdin.flush()


def _path_to_uri(path: str) -> str:
    """Normalize a path or file URI to a file:// URI."""
    if path.startswith("file://"):
        return path
    return "file://" + os.path.abspath(path)


def cmd_open(proc, args: list[str]):
    """Send textDocument/didOpen notification for a file."""
    if args:
        path = args[0]
    else:
        path = input("  File path/URI: ").strip()

    uri = _path_to_uri(path)
    fs_path = uri[len("file://"):]

    try:
        with open(fs_path) as f:
            text = f.read()
    except OSError as e:
        print(f"[client] ERROR reading file: {e}", file=sys.stderr)
        return

    # notification — no response expected
    send(proc, {
        "jsonrpc": "2.0",
        "method": "textDocument/didOpen",
        "params": {
            "textDocument": {
                "uri": uri,
                "languageId": "c3",
                "version": 1,
                "text": text,
            },
        },
    })
    print("[client] didOpen sent (notification, no response)")


def cmd_completion(proc, args: list[str]):
    """Send textDocument/completion request and print results."""
    if len(args) >= 3:
        path, line_str, char_str = args[0], args[1], args[2]
    else:
        path     = input("  File path/URI: ").strip()
        line_str = input("  Line (0-based):      ").strip()
        char_str = input("  Character (0-based): ").strip()

    uri = _path_to_uri(path)

    try:
        line_num = int(line_str)
        char_num = int(char_str)
    except ValueError:
        print("[client] ERROR: line and character must be integers", file=sys.stderr)
        return

    send(proc, {
        "jsonrpc": "2.0",
        "id": next_id(),
        "method": "textDocument/completion",
        "params": {
            # CompletionParams uses VERBATIM field names (no rename_all)
            "text_document": uri,
            "position": {"line": line_num, "character": char_num},
            "context": {
                "trigger_kind": 1,   # CompletionTriggerKind.INVOKED
            },
        },
    })
    recv(proc)


COMMANDS = {
    "init": cmd_initialize,
    "open": cmd_open,
    "comp": cmd_completion,
    "shut": cmd_shutdown,
    "exit": cmd_shutdown,
    "quit": cmd_shutdown,
}


def repl(proc):
    print("LSP test client ready. Commands: " + ", ".join(COMMANDS) + ", help")
    while True:
        try:
            raw = input("\n> ").strip()
        except (EOFError, KeyboardInterrupt):
            print()
            cmd_shutdown(proc)
            break

        if not raw:
            continue

        tokens = raw.split()
        cmd, args = tokens[0].lower(), tokens[1:]

        if cmd == "help":
            print("Commands: " + ", ".join(COMMANDS))
            print("  init                      - initialize handshake")
            print("  open <path>               - didOpen a file")
            print("  comp <path> <line> <char> - request completion")
            print("  shut / exit / quit        - shutdown server")
            continue

        fn = COMMANDS.get(cmd)
        if fn is None:
            print(f"Unknown command '{cmd}'. Type 'help'.")
            continue

        fn(proc, args)

        if cmd in ("shut", "exit", "quit"):
            break


def main():
    parser = argparse.ArgumentParser(description="c3_ls LSP test client")
    parser.add_argument("--server", default=DEFAULT_SERVER,
                        help="path to server binary (default: build/c3_ls)")
    args = parser.parse_args()

    if not os.path.isfile(args.server):
        print(f"ERROR: server binary not found: {args.server}", file=sys.stderr)
        sys.exit(1)

    print(f"Starting server: {args.server}")
    proc = subprocess.Popen(
        [args.server],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=sys.stderr,  # server logs go directly to terminal
    )

    try:
        repl(proc)
    finally:
        proc.wait(timeout=3)
        print(f"Server exited with code {proc.returncode}")


if __name__ == "__main__":
    main()
