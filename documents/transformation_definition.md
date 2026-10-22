# Transformation Definition: Perl5-to-Python312-Modernization

This document describes the custom AWS Transform definition used in this sample.
It is the natural-language specification you provide to AWS Transform custom when
creating the transformation. Use it verbatim (or adapt it) with `atx` to
(re)create the definition in your own account.

## Name

`Perl5-to-Python312-Modernization`

## Purpose

Transform legacy Perl 5 programs into functionally equivalent, idiomatic
Python 3.12 applications, using a pre-generated and human-reviewed Business Rule
Extract (BRE) plus an authoritative Perl coding/modernization reference guide,
then validate the generated app against the Perl program's actual output.

## Expected repository inputs (four-folder structure + reference + BRE)

```
<repo>/
├── source-code/                 # the legacy Perl program(s)
├── input-data/                  # input fixtures
├── output-data/                 # authoritative baselines captured from real Perl
├── reference/                   # perl-coding-and-modernization-guide.md
└── business-rules-extraction/   # reviewed BRE (produced in Stage 1)
```

## Two-stage workflow

1. **Stage 1 — Business Rule Extraction (BRE).** Run the AWS-managed
   `AWS/business-rules-extraction` transformation on `source-code/` to produce a
   rewrite-ready specification under `business-rules-extraction/`. Review it (the
   human gate) and correct any gaps before generation.
2. **Stage 2 — Generate and validate.** Run `Perl5-to-Python312-Modernization`.
   It consumes the reviewed BRE and the reference guide, generates the Python 3.12
   application under `python-app/` plus a pytest suite, runs the tests against the
   `output-data/` baselines, and self-corrects (fixing the app, never the
   baselines) until all in-scope behaviors match.

## Exit criteria (program-agnostic)

A run is COMPLETE when:

1. **Behavioral equivalence** — the generated Python reproduces the source's
   output for every in-scope behavior: byte-exact for deterministic output, or
   documented semantic equivalence where the source output is intentionally
   non-deterministic (for example `Data::Dumper`, whose hash-key order varies).
2. **Coverage** — a pytest suite under `python-app/tests/` covers all in-scope
   behaviors against the baselines. The number of test cases is whatever fully
   covers *this* program — there is no fixed list.
3. **Tests pass** — the generated pytest suite runs green.
4. **Runs clean** — the entry point compiles and runs under Python 3.12.
5. **Standard library only**; PEP 8; type hints; docstrings.
6. **Record modeling is conditional** — use an `@dataclass` only if the source
   constructs records/structured rows; a stream/byte utility needs none.
7. **Specification fidelity** — honor the reviewed BRE and the reference guide,
   including its hardening rules.

Behaviors the source does not exhibit are marked **NOT APPLICABLE**, not PARTIAL.

## Creating the definition with the CLI

Start the AWS Transform CLI in interactive mode and describe the transformation,
providing this document and the reference guide as references:

```bash
atx
# then: "Create a custom transformation named Perl5-to-Python312-Modernization
#        using the specification in documents/transformation_definition.md and
#        the reference guide in reference/perl-coding-and-modernization-guide.md"
```

Review, then publish to your organization's registry.
