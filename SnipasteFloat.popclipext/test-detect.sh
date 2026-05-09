#!/bin/bash
# Standalone test for is_mermaid_first_line. Source the script under test.
set -u

# Source-only mode: prevent main() from running when we source the script.
SNIPASTE_FLOAT_TEST_MODE=1 source "$(dirname "$0")/snipaste-float.sh"

pass=0
fail=0

assert_match() {
    local label="$1" input="$2"
    if is_mermaid_first_line "$input"; then
        printf 'PASS: %s\n' "$label"; pass=$((pass+1))
    else
        printf 'FAIL: %s (expected match)\n' "$label"; fail=$((fail+1))
    fi
}

assert_no_match() {
    local label="$1" input="$2"
    if is_mermaid_first_line "$input"; then
        printf 'FAIL: %s (expected no match)\n' "$label"; fail=$((fail+1))
    else
        printf 'PASS: %s\n' "$label"; pass=$((pass+1))
    fi
}

# Positive cases.
assert_match "flowchart with direction"  $'flowchart TD\nA --> B'
assert_match "graph LR"                  $'graph LR\nA --> B'
assert_match "sequenceDiagram"           $'sequenceDiagram\nAlice->>Bob: hi'
assert_match "classDiagram"              $'classDiagram\nclass Foo'
assert_match "stateDiagram"              $'stateDiagram\n[*] --> S1'
assert_match "stateDiagram-v2"           $'stateDiagram-v2\n[*] --> S1'
assert_match "erDiagram"                 $'erDiagram\nCUSTOMER ||--o{ ORDER : places'
assert_match "gantt"                     $'gantt\ntitle My Plan'
assert_match "pie"                       $'pie\n"A" : 50\n"B" : 50'
assert_match "leading whitespace"        $'   flowchart TD\nA --> B'
assert_match "uppercase keyword"         $'FLOWCHART TD\nA --> B'
assert_match "trailing whitespace on kw" $'flowchart   \nA --> B'

# Negative cases.
assert_no_match "java class"             $'class Foo {\n}'
assert_no_match "empty"                  ""
assert_no_match "mindmap (not in list)"  $'mindmap\nroot((x))'
assert_no_match "fenced block"           $'```mermaid\nflowchart TD\nA --> B\n```'
assert_no_match "leading text"           $'Some preamble\nflowchart TD'

# Note: english prose starting with "graph " (e.g. "graph theory is the
# study of graphs") will match here. That is by design — the rule is
# strictly "first-line starts with keyword". Such selections fail mmdc
# render and fall through to plain-text pinning, so the user-visible
# behaviour is correct, just with a small extra mmdc-startup latency.

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[[ "$fail" -eq 0 ]]
