---
id: infrastructure-config-path-valued-config
domain: infrastructure
category: config
applies_to: [general]
confidence: verified
sources:
  - https://man7.org/linux/man-pages/man5/systemd.exec.5.html
  - https://developer.apple.com/library/archive/documentation/MacOSX/Conceptual/BPSystemStartup/Chapters/CreatingLaunchdJobs.html
  - https://12factor.net/config
last_verified: 2026-09-03
related: [infrastructure-config-environment-config, platforms-processes-background-services, platforms-environment-path-resolution, backend-python-boundaries-runtime-validation, backend-node-boundaries-runtime-validation]
---

# A Config Value That Is a Filesystem Path

## When this applies

A service reads a filesystem path from an env var or config key (an input/spool
directory, an output dir, a data file, a socket), and the process is started by
something that owns the working directory: launchd, systemd, cron, a container
entrypoint, a supervisor, or a CI runner. Also a CLI whose required flag (`--out`,
`--spool`) names the directory it writes into.

General per-environment config shape → [infrastructure-config-environment-config].
Locating *binaries* rather than data → [platforms-environment-path-resolution].

## Do this

1. **Require the value to be absolute, and crash at startup when it is not.**
   Validate it with the rest of the config schema, before any request or scan
   runs, and put the received value verbatim in the error message so the
   operator sees what the unit actually passed:

```python
p = Path(raw).expanduser()
if not p.is_absolute():
    raise ValueError(f"SIGNAL_DIR must be an absolute path, got: {raw!r}")
```

2. **Expand `~` before testing absoluteness.** `~/data/signals` is a legitimate
   operator-supplied value whose raw form is relative; expanding first accepts
   it while still rejecting `./data/signals` and `signals`.

3. **Separate "directory missing" from "directory empty" at startup.** Stat the
   resolved directory and crash when it is absent. A glob/scan over a missing
   directory returns an empty result rather than an error, so a misconfigured
   path is indistinguishable at runtime from a correct path with no work in it.

| Case | Do |
|------|----|
| Path names a directory the service reads from | Reject non-absolute; stat it at startup and crash when absent |
| Path names a file or directory the service creates | Reject non-absolute; assert the parent directory exists and is writable at startup |
| Value legitimately anchors to the repo/package rather than the host | Resolve it against a root the code derives from its own module location, and name that root in the config key (`…_RELATIVE_TO_PACKAGE`) — never against the process CWD |
| The service must also run from a developer shell | Keep the absolute-only rule and supply an absolute path in the dev env file; per [infrastructure-config-environment-config], a required key gets no default |

## Edge cases

| Case | Then |
|------|------|
| The unit sets no `WorkingDirectory` | The CWD is the manager's default, not the install directory: `/` for launchd and for systemd **system** units, and the user's home directory for systemd **user** units. The same relative path resolves to three different places across those managers |
| A container image sets `WORKDIR` | The CWD is defined but owned by the image, so it changes with a base-image or Dockerfile edit that no config review covers — keep the absolute-only rule |
| The relative path happens to work in staging | The launcher there sets a `WorkingDirectory` that production's does not; treat a passing relative path as an accident, not as validation |
| Tests exercise the loader with relative paths | Assert the rejection: pass `""`, `"./data/x"`, `"x"`, and `"relative/path"` and require the exception type and the received value in the message ([testing-quality-minimum-case-set]) |
| The path arrives through a CLI flag declared required (argparse `required=True`, the equivalent in any parser) | `required` checks presence, not content: `--out ""` satisfies it, and `os.path.realpath("")`/`abspath("")` resolve to the process CWD, so output lands wherever the command happened to run. Reject the empty string before resolving (`if not args.out: parser.error("--out must be a non-empty absolute path")`) and keep `""` in the rejection tests |
| The value arrives already absolute but with a symlink or `..` | Resolve it once at startup and store the resolved form, so every later component agrees on one path |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Resolve a relative config path against the CWD | Reject it at startup and require an absolute value | The launcher owns the CWD; under launchd and systemd system units it is `/`, so the path silently names a directory that does not exist |
| `os.chdir()` at startup so relative paths work | Reject the relative value and let the operator supply an absolute one | A chdir makes every path in the process depend on startup ordering, and it hides the misconfiguration instead of reporting it |
| Log a warning and continue when the configured directory is absent | Crash at startup with the received value | A scan of a missing directory yields an empty result, so the service reports a healthy idle state forever while processing nothing |
| Default the key to `./data/<name>` for developer convenience | No default; validate presence and absoluteness at startup | The dev-friendly relative default becomes the production value the moment the real one is missing |
| Rely on a parser's `required=True` to guarantee a usable output directory | Reject empty and non-absolute values yourself before `realpath` | Presence is all the parser checks; an empty value resolves to the CWD with no error |

## Sources

- https://man7.org/linux/man-pages/man5/systemd.exec.5.html — `WorkingDirectory=`: "If not set, defaults to the root directory when systemd is running as a system instance and the respective user's home directory if run as user"
- https://developer.apple.com/library/archive/documentation/MacOSX/Conceptual/BPSystemStartup/Chapters/CreatingLaunchdJobs.html — LaunchAgent plist keys; `WorkingDirectory` is documented in `launchd.plist(5)` as "This optional key is used to specify a directory to chdir(2) to before running the job" — optional, with no directory inherited from the installer
- https://12factor.net/config — config lives in the environment and is what varies between deploys
- https://docs.python.org/3/library/argparse.html#required — "if an option is marked as required, parse_args() will report an error if that option is not present at the command line" — presence only
- https://docs.python.org/3/library/os.path.html#os.path.abspath — "Return a normalized absolutized version of the pathname path. On most platforms, this is equivalent to calling normpath(join(os.getcwd(), path))" — the empty path is the CWD
- Local reproduction 2026-09-03 (CPython 3): `parse_args(["--out", ""])` → `Namespace(out='')` and `os.path.realpath('')` → the current directory. Field reproduction 2026-08-28 (a code-generation CLI): `generate openapi SRC --out ""` returned rc 0 and wrote `openapi.json` into the repository root; an independent test-quality audit found it and confirmed the new rejection tests fail with the fix reverted
- Local reproduction 2026-08-04 (macOS 25.1, launchd): a LaunchAgent with `ProgramArguments` and `RunAtLoad` and **no** `WorkingDirectory` key recorded `cwd=/` and `PWD=/`; a relative `./data/signals` lookup from that job reported "No such file or directory". An independently launchd-spawned process (`loginwindow`) also reports cwd `/` under `lsof`
- Local reproduction 2026-08-04 (CPython 3.14.6): `glob.glob("/nonexistent-xyz/*.json")` returns `[]` and `Path("/nonexistent-xyz").glob("*.json")` yields nothing, both without raising, while `os.listdir` on the same path raises `FileNotFoundError` — the empty-scan result is what makes a bad path silent. `Path("~/data").expanduser().is_absolute()` is `True` while `Path("./data").expanduser().is_absolute()` is `False`
