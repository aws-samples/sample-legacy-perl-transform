# Perl Coding & Modernization Reference Guide

This reference pairs the **authoritative Perl style guidance** with
**modernization mappings** for transforming legacy Perl into a modern target
stack (Python 3.12). It is intended to be consumed by an automated
transformation agent so that it (a) correctly understands legacy Perl idioms
and (b) translates them faithfully and idiomatically into the target language.

**Primary authoritative source:** the official Perl documentation style guide,
`perlstyle`, maintained by the Perl core team.
Source: https://perldoc.perl.org/perlstyle (public domain Perl documentation).
Supporting authoritative references: `perlmodstyle` (Perl community best
practice for modules), and the CERT Perl Secure Coding Standard (Carnegie
Mellon SEI) for security-sensitive constructs.

> Content below paraphrases and summarizes the official `perlstyle` guidance
> for compliance with licensing restrictions; see the source URL for the full
> original text. Content was rephrased for compliance with licensing restrictions.

---

## Part 1 — Authoritative Perl style principles (from `perlstyle`)

These are the conventions a reader must assume when interpreting legacy Perl.
When reverse-engineering the behavior of a Perl program, interpret the code
against these norms.

1. **`use strict` and `use warnings` are the baseline.** Well-formed Perl
   enables both (modern Perl does this implicitly with `use v5.36` or later).
   Their presence signals the author intended lexical scoping and runtime
   warnings. Absence is a legacy smell to be fixed in modernization.
2. **Readability over cleverness.** Perl deliberately offers many ways to do a
   thing; the maintainable choice is the clearest one. The main point of a
   statement should be in the statement, not hidden in a trailing modifier —
   e.g. `open(...) or die ...` is preferred over `die ... unless open(...)`,
   while `print ... if $verbose` is preferred over `$verbose && print ...`.
3. **Parenthesize when in doubt.** Omitting parentheses is allowed but hurts
   maintainability; supply them for clarity.
4. **Mnemonic identifiers; underscores for word separation.** `$var_names_like_this`
   is preferred over camel case for readability. Letter case conventionally
   signals scope/nature: `ALL_CAPS` for constants, `Some_Caps` for
   package globals, `lower_case` for lexical (`my`/`local`) variables. A
   leading underscore marks package-private names.
5. **Hairy regexes use `/x` (or `/xx`).** The `/x` modifier lets a complex
   regex include whitespace and comments for legibility. When you see `/x`,
   embedded whitespace in the pattern is NON-significant.
6. **Always check return codes of system calls.** Idiomatic Perl pairs calls
   like `open`, `opendir`, `mkdir`, `chdir` with `or die "...: $!"`. The `$!`
   variable carries the OS error string.
7. **Prefer `last`/`next`/loop labels for mid-loop exit** rather than
   contorted top/bottom conditions. Postfix `last if COND` is idiomatic early
   termination.
8. **Use `and`/`or` (low precedence) to reduce punctuation noise;** reserve
   `&&`/`||` for expression context.
9. **Document with POD consistently** (NAME / SYNOPSIS / DESCRIPTION / OPTIONS
   for scripts, per `perlmodstyle` and common script conventions).
10. **Be consistent. Be nice.** Consistency within a file outranks any external
    rule.

---

## Part 2 — Legacy Perl constructs and their modern equivalents

The transformation agent must recognize these legacy idioms and translate them
to the idiomatic Python 3.12 equivalent WITHOUT changing observable behavior.

| Legacy Perl idiom | Meaning | Idiomatic Python 3.12 target |
|---|---|---|
| `use strict; use warnings;` | lexical scoping + runtime warnings | n/a (Python is strict by default); keep behavior, not the pragma |
| `Getopt::Long` `GetOptions('file=s'=>\$x,'verbose'=>\$v)` | CLI flag parsing: `=s` takes a string value, bare flags are booleans | `argparse` with `--file` (type=str), `--verbose`/`--dry-run` (`action="store_true"`) |
| `$x \|\|= $default` | assign default if falsy/undef | `x = x or default` / `x = x if x else default` (match falsy semantics) |
| `open(FH, "<", $file) or die "...: $!"` | open file for read; die with OS error on failure | `open(file, "r")` in a context manager; on failure raise/exit with message incl. `OSError.strerror` |
| bareword filehandle `LOGDATA` | legacy global filehandle | lexical file object / `with open(...) as f:` |
| `while (my $line = <FH>)` | read line-by-line until EOF | `for line in f:` |
| `chomp($line)` | strip trailing record separator (newline) | `line.rstrip("\n")` (NOT `.strip()` — only the trailing newline) |
| `$line =~ /REGEX/x` | match with extended (`/x`) formatting | `re.match(pattern, line, re.VERBOSE)` — preserve `/x` as `re.VERBOSE` |
| capture groups `($1,$2,...)` | positional captures | `m.group(1..n)` / tuple unpacking from `m.groups()` |
| `\d \s \w \S` etc. in regex | same PCRE-style classes | identical in Python `re`; translate the pattern verbatim |
| anchors `^...$` | start/end of string (no `/m`) | identical; without `re.MULTILINE`, `$` also allows a trailing `\n` in Perl — anchor carefully |
| anonymous hash ref `{ k => v }` | a record/dict | `dict` or a `@dataclass` for the record shape |
| `push(@arr, $x)` | append | `list.append(x)` |
| `int($status)` | numeric coercion to integer | `int(status)` |
| postfix `last if COND` | break out of loop early | `if COND: break` |
| `print "...$var...\n"` | interpolated output to STDOUT | f-string `print(f"...{var}...")` |
| `Data::Dumper` `Dumper(\@x)` | debug serialization of a structure | NOTE: Perl's Dumper format and hash-key ordering are Perl-specific; see Part 3 |
| `die "msg\n"` | fatal error to STDERR, nonzero exit | print to `sys.stderr` + `sys.exit(1)` / raise |
| `exit(0)` | success exit | `sys.exit(0)` |
| `my %CONFIG = (...)` | config constants | module-level constants / a config dataclass |

---

## Part 3 — Functional-equivalence rules (critical)

The modern app must be **functionally equivalent to the Perl source** on the
provided fixtures. Equivalence is judged by observable output, not by internal
structure.

1. **Primary equivalence target = the normal (non-dry-run) path.** The Perl
   program prints exactly:
   `Successfully processed N records from <input_file>.`
   where **N** is the number of input lines matching the regex, capped at
   `max_rows` (5000). The modern app MUST reproduce this line byte-for-byte,
   including the filename exactly as passed on the command line.
2. **Regex semantics must match exactly.** The pattern
   `^\[([\d\-\s\:]+)\]\s+([\d\.]+)\s+(\w+)\s+(\S+)\s+\-\s+(\d+)$` under `/x`
   must select the same lines in Python (`re.VERBOSE`). Lines failing the
   pattern (malformed text, blank lines, bad timestamps, a record missing the
   ` - ` separator) must be rejected identically.
3. **`chomp` vs `strip`.** Only the trailing newline is removed. Do not strip
   other whitespace, or the `$` anchor behavior and counts can diverge.
4. **`--verbose`** prints `--- Initializing Log Processor ---` before
   processing; preserve exact text and ordering.
5. **`--dry-run`** in Perl dumps the records via `Data::Dumper`. Perl hash-key
   order is NOT deterministic across the dump and the format is Perl-specific.
   Do NOT attempt byte-equivalence of the Dumper block. Instead, the modern
   dry-run should emit the SAME record data in a deterministic, documented
   format (e.g. pretty-printed JSON with stable key order), and the BRE doc must
   call out that dry-run equivalence is **semantic** (same records, same field
   values) rather than byte-identical. The normal path remains the byte-level
   equivalence gate.
6. **Early termination.** Processing stops after `max_rows` matches
   (`last if $processed_count >= 5000`). Preserve this bound.
7. **Default input file.** When `--file` is omitted, Perl falls back to
   `/var/log/app_traffic.log`. Preserve the same default and the same failure
   behavior if the file is absent.
8. **Exit codes.** Success = 0; file-open failure = nonzero with an error
   message containing the path and the OS error string.

---

## Part 4 — Modernization quality bar (target: Python 3.12)

- Use `argparse` for CLI parsing; mirror the three flags exactly.
- Use a context manager (`with open(...)`) for file handling.
- Compile the regex once with `re.VERBOSE`; keep the pattern identical.
- Represent each record as a `@dataclass` (`ts`, `ip`, `action`, `path`,
  `code: int`) — the Python analogue of the Perl anonymous hash.
- Route errors to `stderr`; use explicit exit codes.
- Include a minimal test (pytest) that runs the app against the provided
  `input-data/` fixture and asserts the `output-data/expected_normal.txt`
  baseline, proving functional equivalence.
- Follow PEP 8 and include type hints and docstrings.


---

## Part 5 — Hardening-derived rules (validated against real-world Perl idioms)

The following rules were validated by running Perl 5.38 against Python 3.12 on a
suite of programs modeled on real open-source Perl tools (pgbadger-style log
aggregation, number formatting, idiom-heavy text processing, multi-file modules,
and a 20,000-record volume test). Every case achieved byte-exact equivalence
when these rules were applied. A transformation that ignores them will silently
diverge.

### HR-1: `split` LIMIT is off-by-one vs Python `maxsplit` (HIGH RISK)
Perl `split(/re/, $str, N)` treats **N as the maximum number of fields**. Python
`str.split(sep, maxsplit)` treats **maxsplit as the number of splits**. Therefore
`split(/:/, $s, 3)` maps to `s.split(":", 2)` — always `maxsplit = N - 1`. A naive
`N -> N` mapping corrupts any input containing more than N-1 delimiters.

### HR-2: Default `sort` is string/ASCII, even on numbers
Perl `sort @list` compares as **strings** (ASCII), so `sort (10, 9, 100, 2, 33)`
yields `10 100 2 33 9`. Map bare `sort @x` to `sorted(map(str, x))` (string
compare), and only map `sort { $a <=> $b }` to a numeric key (`sorted(x, key=...)`).
Confusing the two reorders output.

### HR-3: Perl magic string auto-increment has NO Python builtin
`$s++` on a string matching `/^[A-Za-z]*$/` does alphabet-carry increment:
`aa->ab`, `Az->Ba`, `Zz->AAa`. Python has no equivalent; the transformation must
emit a helper function replicating the carry/wrap rules (z->a, Z->A, overflow
prepends a letter of the leftmost char's case). Validated helper is in the
hardening suite (`case4_edge`).

### HR-4: Perl number stringification drops trailing zeros and `.0`
`"%s"`/interpolation on `3.14000` yields `3.14`; on `42.0` yields `42`. Python
`str(42.0)` yields `42.0`. When a Perl number reaches string context, map to a
helper that prints integers without a decimal and floats without trailing zeros
(validated `perl_num_str()` in `case4_edge`).

### HR-5: `printf`/`sprintf` numeric formatting IS safe to map directly
Validated across rounding boundaries (`0.5->0`, `1.5->2`, `2.5->2`, `3.5->4`,
`0.135->0.14`, `2.675->2.67`), width, zero-pad, and left-justify: Perl's C-backed
`printf` and Python's `%`/`format` share IEEE-754 round-half-to-even, so
`printf("%.2f", x)` maps to `"%.2f" % x` (or an f-string) with identical output.
No special handling needed — this is a confirmed safe mapping.

### HR-6: `tr///` maps to explicit character operations
`tr/aeiouAEIOU//cd` (complement + delete, then `length`) = "count characters that
ARE vowels." Map `tr` counting/deletion idioms to explicit `str.translate`,
comprehensions, or `sum(1 for c in s if ...)` — not to `re.sub` blindly.

### HR-7: scalar `reverse` reverses a string; list `reverse` reverses a list
`reverse($str)` in scalar context -> `str[::-1]`. `reverse(@list)` -> `list[::-1]`
or `reversed()`. Determine context before mapping.

### HR-8: multi-file modules map cleanly
`package Foo; ... 1;` with `@EXPORT_OK` maps to a Python module with public
functions; `use Foo qw(...)` maps to `from foo import ...`. Validated end-to-end
in `case5_module` (a `Stats.pm` + `report.pl` pair) with byte-exact output.

### Volume note
Equivalence held byte-exact on a 20,000-record aggregation (float-percentage
accumulation + multi-key sort), confirming no volume-dependent drift.


---

## Part 6 — Generated-test security hygiene (scanner-clean output)

Generated pytest suites invoke the app under test with `subprocess.run(...)`.
Static analyzers (e.g. Semgrep `python.lang.security.audit.dangerous-subprocess-use-audit`)
flag any `subprocess.run` whose first argument is not a static string literal,
as an **audit** (human-review) finding — even when the call is safe. To keep
published/generated output scanner-clean:

### GT-1: Use a STATIC literal command, never a shell
Invoke the app with a **list whose first element is a string literal** and never
set `shell=True`:

```python
subprocess.run(
    ["python3", "python-app/app.py", *args],   # literal interpreter + literal relative path
    capture_output=True, cwd=REPO_ROOT, check=False,
)
```

The scanner rule (`python.lang.security.audit.dangerous-subprocess-use-audit`)
fires when the **first list element is non-literal** — e.g. `sys.executable` or a
computed `os.path.join(...)` path. Verified behavior: a literal interpreter name
plus a literal relative script path clears the rule **even when variable args
are appended** (`*args`) and `cwd` is a variable. Run from the repo root via
`cwd=REPO_ROOT` and use a relative literal path for the script. The same applies
to invoking the original Perl for differential tests: use `["perl",
"source-code/x.pl", *args]`.

### GT-2: Do NOT rely on `# nosemgrep` suppressions
Enterprise scanners (e.g. the Slingshot Semgrep config) run with inline
suppressions **disabled**, so a `# nosemgrep` comment does NOT clear this
finding. Resolve it by code shape (GT-1), not by annotation.

### GT-3: Prefer running the app in-process when it's clean to do so
Where the program exposes an importable `main(argv)` and reads/writes via
`sys.stdin`/`sys.stdout` (not `sys.stdin.fileno()`), testing by import + call is
fine and avoids subprocess entirely. But if the program reads the raw file
descriptor (`open(sys.stdin.fileno(), ...)`) or the in-process redirection
becomes fragile under the test runner, prefer the static-literal subprocess form
(GT-1) — it is simpler and reliably scanner-clean.
