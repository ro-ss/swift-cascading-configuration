# Project Guidelines

## Purpose & Scope

This file & the rule files in `.claude/rules` are the canonical source of
project conventions. Before changing a file, follow each rule file whose `paths`
front matter matches it: the [scripting rules](.claude/rules/scripting.md) for
scripts & GHA workflows; the [Swift rules](.claude/rules/swift.md) for Swift
source.

Record each convention that a change settles in this file or in the applicable
rule file, in the same change.

Before changing anything, check its history (e.g., `git log -S`), so that no
change reverts an earlier one (e.g., changing A to B, then to C, then back to
A), unless the change says why the earlier one was wrong.

## Minimum Versions

- **Swift:** 6.2
- **Xcode:** 26
- **macOS:** 15

When bumping the minimum Swift or Xcode version, update all of its occurrences
together: `.swift-version`, `Package.swift`'s `swift-tools-version`, this
section & `README.md`'s Swift badge & Build row. `.xcode-version` names the
preferred Xcode (the latest stable one, e.g., `27.0`), not the minimum.

## Quick Entry Points

- `Scripts/bootstrap`
- `Scripts/format` (never run it; see [Git Workflow](#git-workflow))
- `Scripts/lint`, with flags:
  - `-A`: skip SwiftLint Analyzer rules.
  - `-L`: skip Layout linting.
  - `-V`: skip Vale prose linting.
- `Scripts/build` (debug)
- `Scripts/build '' -c release` (release)
- `Scripts/test`

## Design

- Re-export Swift Configuration from `CascadingConfiguration`, so that each
  target that depends on `CascadingConfiguration` imports it instead of
  `Configuration` & depends on Swift Configuration directly only for another of
  its products (e.g., `ConfigurationTesting`), its traits, or a newer minimum
  version
- Declare no `platforms` in `Package.swift`; instead, mark each declaration that
  uses Swift Configuration with `@available(Configuration 1.0, *)` (each `@Test`
  function, never its suite, which Swift Testing rejects), as Swift
  Configuration does, so that a package that supports older platforms can depend
  on `CascadingConfiguration`

## Code From Other Projects

- Keep each file copied verbatim from another project (e.g., a vendored copy of
  an upstream API that is not public) in a `Vendored` folder of its target
  (e.g., `Sources/CascadingConfiguration/Vendored`), which the formatting &
  linting tools skip, so that it stays easy to compare with its upstream; record
  each change to such a file in its `Vendored copy` comment

## Git Workflow

- Branch topics from `main`, the trunk
- Before committing:
  1. Add or edit tests for all new or changed behavior
  2. Never run `Scripts/format` or `Scripts/layout`, because `Scripts/layout -f`
     (which `Scripts/format` runs) rewraps every file, even when given 1 file,
     and wrongly rewraps header comments. Instead, repeatedly run the other
     steps of `Scripts/format` directly until no modifications are made,
     reviewing each run's modifications before the next run, and limiting each
     step to tracked files (e.g., `swiftformat .`, then
     `swiftformat --indent 4 $(git ls-files '*.md')`,
     `swiftlint --fix --force-exclude --quiet -- $(git ls-files '*.swift')`,
     `markdownlint-cli2 --fix -- $(git ls-files '*.md')`), because an unlimited
     `swiftlint --fix` also rewrites the dependency checkouts in `.build`; fix
     each Layout violation that `Scripts/lint` reports by hand
  3. Repeatedly run `Scripts/lint -A` & fix all violations until none are
     reported
  4. Run `Scripts/build` & `Scripts/test`, fixing every failure
  5. Manually check rules that linters do not enforce: Oxford commas; `second` &
     adjective `one` written as digits; & judgment-based rules (e.g., 1 `return`
     per function, `if` / `switch` expressions)
- **Commit messages:** Follow [commit message conventions](
    https://tbaggery.com/2008/04/19/a-note-about-git-commit-messages.html
  ), except end each subject line with a period (or with a colon iff the subject
  introduces a list)
- Never check or rewrite the formatting of an existing commit message (e.g., in
  a review); apply the commit message conventions only to a message being
  written
- Sign off every commit (`git commit -s`)
- Tag releases as `vX.Y.Z`

## File Naming

Give each file the longest standard extension for its file type that works for
its purpose (e.g., `.swiftlint.yml`, because `.swiftlint.yaml` does not work;
`ci.yaml`, because both work), except always use `.md` for Markdown.

## Content Formatting

- **Newlines:** Unix (i.e., `\n`)
- **Indentation:** Tabs (2 characters wide) unless otherwise specified; 2 spaces
  for YAML; 1 space for Markdown; 4 spaces for Swift code in Markdown. Whenever
  SwiftPM rewrites `Package.resolved` with spaces, re-indent it with tabs
- **Max line length:** 120 characters unless otherwise specified; unlimited for
  JSON & swiftformat. Tabs count as 2 characters each; the trailing newline does
  not count. Fill each line up to the limit before wrapping
  - **Markdown:** 80 characters
  - **Swift comments:** 80 characters for a comment-only line (`///` DocC or
    `//`) of prose. Any code before a trailing comment sets its line's max to
    120, as does a linter / formatter marker (e.g.,
    `// swiftformat:disable:next indent`)
- **Whitespace:** Remove unnecessary trailing whitespace; end each file with a
  single newline
- **Quoting:** Quote strings only when necessary, preferring the most literal
  format that works; among functionally equivalent quote syntaxes, prefer the
  visually lightest (e.g., single quotes over double quotes)
- **Comment periods:** End each sentence of a DocC (`///`) comment with a
  period; omit the period from the end of an ordinary (`//`) comment
- **Text:** Applies to all prose, wherever it appears (e.g., comments, strings,
  markup, commit messages & documentation):
  - **Commas:** Use Oxford commas for lists
  - **Ampersands:** Prefer `&` to `and` (omit Oxford comma before `&`), except
    use `and` in `and/or`, after a comma that separates distinct clauses (but
    not in a list) & after a comma that ends a parenthetical or a nonrestrictive
    clause (e.g., `matches a value, which has text, and coerces it`)
  - **Quotes**: The quotation marks of a quote that ends a sentence (iff the
    whole sentence is not a quote) do not enclose the sentence's terminal
    punctuation mark
  - **Iff**: Use `iff` as `if & only if`
  - **Slashes:** Pad a `/` joining 2 words / terms with spaces on both sides
    (e.g., `field-order / item-sort`, `format- / type-defaulted`), except
    `and/or` (never `&/or`); do not pad slashes in file paths, URLs, or literal
    characters
  - **Word choice:** Avoid `curate` / `curated` / `curation`; prefer `select`,
    `handle`, etc.
  - **Em dashes:** Do not use em dashes, except in `CODE_OF_CONDUCT.md`
  - **Contractions:** Never use contractions (e.g., write `it is`, not `it's`),
    not even in test data
  - **Numbers:** Write numbers as digits (e.g., `at most 1`, `3 kinds`, `1st`),
    except the pronoun `one` (e.g., `the last one wins`)
  - Always immediately follow `e.g.` & `i.e.` with a punctuation mark (e.g., `,`
    or `:`)

### Markdown Guidelines

These also govern Markdown inside DocC (`///`) comments.

- **Style:** GitHub-Flavored Markdown (GFM), ATX headings, backtick-fenced code
  blocks with language identifier, underscore emphasis, asterisk strong & hyphen
  bullets
- **HTML:** Use only GFM-supported HTML that has no native GFM equivalent
- **Tables:** Align pipes; pad each column to its longest cell (excluding the
  delimiter row) plus 1 space on each side
- **Wide blocks:** Measuring width as for max line length, surround each table
  whose widest line is wider than 80 characters & each fenced block whose widest
  line is 81 to 160 characters wide with `<!--editorconfig-checker-disable-->` &
  `<!--markdownlint-disable line-length-->` lines before it &
  `<!--markdownlint-enable line-length-->` &
  `<!--editorconfig-checker-enable-->` lines after it; surround no other table
  or fenced block with them; split each fenced block line wider than 160
  characters into lines no wider than 160 characters
- **Inline wrapping:** Fill emphasis, strong, strikethrough, link text & image
  alt text like other prose; never split a code span, URL, or inline HTML tag
  across lines: move one that does not fit whole to the next line, even if that
  line then exceeds the max line length
- **Links:** If a URL does not fit on a line, end the line with `](`, put the
  URL on its own line, indented 2 spaces deeper than the text's continuation
  lines, then put `)` on the next line at the continuation lines' indentation
- **Cross-references:** Link a referenced file from relevant inline text, never
  from the file's name (a word naming a general concept, e.g., `README`, is not
  a file name, even if a file is named after it); reference a section only via a
  link whose URL fragment targets it, except in a code comment, which names the
  file & quotes the section's heading (e.g., `Temp/todo.md "Sorting"`)

## Refactoring Rules

Unless necessary for functionality, a fix, or a standards violation, never
reformat, rename, reorder, respace, or reword anything, never remove comments &
never refactor in a way that worsens the caller interface.

Refactoring should:

- Keep clean abstractions
- Inline a utility iff it is single-use
- Replace a utility iff the new version is more correct, performant, and/or
  simpler than the existing version, in descending order of priority

Apply every rename throughout the repository (e.g., specs, `Temp/*`, code
identifiers, comments, tests & docs), including to every name derived from the
renamed one (e.g., renaming a type renames the identifiers named after it).
