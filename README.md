# Perl to Python Modernization with AWS Transform custom

Transform legacy **Perl 5** programs into functionally equivalent, idiomatic
**Python 3.12** applications using [AWS Transform custom](https://docs.aws.amazon.com/transform/latest/userguide/custom.html).

This sample provides a ready-to-use custom transformation definition, a sample
Perl workload with baselines, and an authoritative Perl-to-Python reference
guide. AWS Transform custom analyzes the Perl source, extracts business rules,
generates the Python application, and validates functional equivalence against
the original program's output.

The approach mirrors the AWS Prescriptive Guidance pattern
[Transform Easytrieve to modern languages by using AWS Transform custom](https://docs.aws.amazon.com/prescriptive-guidance/latest/patterns/transform-easytrieve-modern-languages.html),
extended here to a Perl source and a Python target.

---

## Architecture

![Target architecture: Perl to Python modernization with AWS Transform custom](docs/architecture.png)

Legacy Perl is staged in a standardized four-folder structure with an
authoritative reference guide. AWS Transform custom extracts business rules
(human-reviewed), then generates the Python 3.12 application and validates it
against baselines captured from the original Perl program, iterating until the
behavior matches. Equivalence is proven by test: byte-exact for deterministic
output, and documented semantic comparison for non-deterministic output (such as
`Data::Dumper`).

---

## How it works

A two-stage, human-gated workflow:

```
┌──────────────┐   ┌─────────────────────┐   ┌──────────────────────────┐
│ Prepare      │──▶│ Stage 1: Business   │──▶│ Stage 2: Generate +      │
│ inputs       │   │ Rule Extraction     │   │ validate (Python 3.12)   │
│ (4 folders + │   │ (+ human review)    │   │ generate → test → fix    │
│  reference)  │   │                     │   │ until equivalent         │
└──────────────┘   └─────────────────────┘   └──────────────────────────┘
```

1. **Prepare inputs** — a standardized four-folder structure plus an
   authoritative reference guide (see [Repository structure](#repository-structure)).
2. **Stage 1 — Business Rule Extraction (BRE).** The AWS-managed
   `AWS/business-rules-extraction` transformation statically analyzes the Perl
   source and produces a rewrite-ready specification. A human reviews it before
   generation.
3. **Stage 2 — Generate and validate.** The custom
   `Perl5-to-Python312-Modernization` transformation consumes the reviewed BRE
   and the reference guide, generates the Python app and a pytest suite, runs the
   tests against the baselines, and self-corrects until all in-scope behaviors
   match the original.

---

## Prerequisites

| Requirement | Notes |
|-------------|-------|
| AWS account | with the `AWSTransformCustomFullAccess` managed policy |
| AWS Transform CLI (`atx`) | latest — install: `curl -fsSL https://transform-cli.awsstatic.com/install.sh \| bash` (Windows: `irm https://transform-cli.awsstatic.com/install.ps1 \| iex`) |
| Node.js 22+ | required by the `atx` CLI |
| Git | the working directory must be a Git repository |
| Perl 5 | to capture authoritative baselines from the original program |
| Python 3.12 | target runtime, to run and test the generated app |

> **Platform:** AWS Transform custom runs on Linux, macOS, and native Windows
> (Windows Terminal + PowerShell). On Windows you may also run it under WSL.

Configure and verify credentials:

```bash
aws configure            # region: a supported AWS Transform region, e.g. us-east-1
aws sts get-caller-identity
atx update
atx custom def list --json   # confirms your permissions work
```

---

## Quick start

From the repository root:

### 1. Capture baselines from the original Perl

```bash
cd test
perl source-code/log_processor.pl --file input-data/app_traffic.log > output-data/expected_normal.txt
# (the sample ships baselines already; regenerate if you change the program)
cd ..
git init && git add . && git commit -m "Initial commit"
```

### 2. Create and publish the transformation definition (one-time)

```bash
atx
# Tell the agent: create a custom transformation named
# Perl5-to-Python312-Modernization using
# documents/transformation_definition.md and
# documents/perl-coding-and-modernization-guide.md as references. Then publish it.
```

See [`documents/transformation_definition.md`](documents/transformation_definition.md)
for the full specification.

### 3. Stage 1 — extract business rules

```bash
atx custom def exec -n AWS/business-rules-extraction -p ./test -x -t
# Review the generated business-rules-extraction/ directory before continuing.
```

### 4. Stage 2 — generate and validate

```bash
atx custom def exec -n Perl5-to-Python312-Modernization -p ./test -x -t
```

The agent generates `test/python-app/` and iterates until the pytest suite
passes and output matches the baselines.

### 5. Verify independently

```bash
cd test
python3 python-app/log_processor.py --file input-data/app_traffic.log \
  | diff - output-data/expected_normal.txt && echo "EQUIVALENT"
cd python-app && python3 -m pytest -q
```

---

## Repository structure

```
sample-perl-to-python-transform/
├── README.md                              # this file
├── LICENSE                                # MIT-0
├── CONTRIBUTING.md
├── CODE_OF_CONDUCT.md
├── documents/
│   ├── transformation_definition.md       # the custom TD specification
│   └── perl-coding-and-modernization-guide.md  # authoritative Perl→Python reference
└── test/                                  # sample Perl workload
    ├── source-code/
    │   └── log_processor.pl                # legacy Perl program
    ├── input-data/
    │   ├── app_traffic.log                 # normal fixture
    │   └── empty_match.log                 # zero-match fixture
    └── output-data/                        # authoritative Perl baselines
        ├── expected_normal.txt
        ├── expected_verbose.txt
        ├── expected_dryrun.txt
        └── expected_zero.txt
```

After a run, AWS Transform custom adds `test/business-rules-extraction/` (Stage 1)
and `test/python-app/` (Stage 2, the generated application and tests).

---

## Validated results

This transformation definition was validated beyond the sample program, with
every run independently verified (byte-for-byte diff against the Perl baseline
plus the generated pytest suite):

| Program | Source | Idioms exercised | Result |
|---------|--------|------------------|--------|
| `log_processor.pl` (this sample) | original | regex capture, records, dry-run | byte-exact, tests pass |
| `transpose` | perl-utils (MIT) | `split` limit, array-of-arrays, output-separator globals | COMPLETE, 27/27 criteria, byte-exact |
| `sponge` | perl-utils (MIT) | stdin soak, `"-"` = STDOUT | byte-exact, tests pass |
| `paragrep` | perl-utils (MIT) | regex paragraph matching, `-i`, `-e` | COMPLETE, byte-exact, tests pass |

Additional offline stress tests covered number/rounding formatting, Perl magic
string increment, default string-vs-numeric sort, `tr///`, and a 20,000-record
volume run — all byte-exact. Equivalence for `Data::Dumper`-style output is
**semantic** (same records and values) rather than byte-exact, because Perl's
hash-dump order is non-deterministic.

> **Note on scope.** This approach targets deterministic, CLI/stdin-driven
> programs. Programs with network calls, databases, concurrency, or real-time
> behavior (e.g. interactive TTY tools) are out of scope for byte-exact
> equivalence and need a different validation strategy.

---

## Best practices

- **Standardized four-folder structure** (`source-code`, `input-data`,
  `output-data`, plus `reference`), validated before transformation.
- **Baseline-driven validation** — capture baselines from the real Perl
  interpreter; byte-exact for deterministic output, documented semantic
  comparison for non-deterministic output.
- **Use authoritative reference material** — the included
  `perl-coding-and-modernization-guide.md` encodes Perl→Python mapping rules,
  including hardening rules (e.g. `split` LIMIT → `maxsplit` is N-1; default
  `sort` is string/ASCII; Perl magic string increment has no Python builtin).
- **Human review gate** before generation — review the BRE and correct gaps.
- **Continual learning** — after each successful run, review and approve the
  knowledge items AWS Transform proposes so later runs improve.
- **Verify independently** — never rely on run status alone; diff the generated
  output against the baseline and run the tests yourself.

---

## Links

- [AWS Transform custom documentation](https://docs.aws.amazon.com/transform/latest/userguide/custom.html)
- [AWS Prescriptive Guidance: Transform Easytrieve to modern languages](https://docs.aws.amazon.com/prescriptive-guidance/latest/patterns/transform-easytrieve-modern-languages.html)
- [AWS Transform pricing](https://aws.amazon.com/transform/pricing/)

---

## Security

See [CONTRIBUTING.md](CONTRIBUTING.md#security-issue-notifications) for how to
report security issues.

## License

This sample is licensed under the MIT-0 License. See [LICENSE](LICENSE).
