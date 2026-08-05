# oida

A Swift linter shaped around how we write Swift at [Oda](https://oda.com). It began as a fork of
[SwiftLint](https://github.com/realm/SwiftLint), whose engine it still runs on, and it is heading somewhere
narrower: the rules we actually want, none of the ones we do not, and decisions made rather than configured.

    oida lint            # report what it finds
    oida lint --fix      # fix what can be fixed
    oida lint --format   # hand the corrected files to the swift-format inside Xcode

Rules live in `.oida.yml`, and a rule is suppressed with `// oida:disable:next <rule>`. Everything
[SwiftLint documents](README-swiftlint.md) still applies, with those two names changed; what follows is what is
ours.

## The shape of a list is decided by counting it

Three or more elements go one per line, two or fewer go on one line — and **both directions hold**, so removing
an argument brings a call back to one line instead of leaving it in the shape it had when it was longer. One
definition drives arguments, parameters and conditions, because SwiftSyntax conforms all three to
`WithTrailingCommaSyntax`.

```swift
guard let name,
    !name.isEmpty,
    UIImage(systemName: name) != nil
else { return nil }
```

Three is a house choice rather than a reading of data. Measured across a real codebase, authors were a coin
flip at three arguments, decisive at four, near-unanimous at five. Three takes the contested band and settles
it, so nobody has to have an opinion.

Two exceptions, both structural. A list stays **open** whatever its count when the breaks carry something a
join would destroy: a comment, a multiline string, a closure body. A list stays **closed** whatever its count
when it describes one value rather than a set of arguments — `CGRect(x:y:width:height:)`,
`Color(red:green:blue:)` — because coordinates and components are read as a group, and stacking them hides the
shape they describe.

`multiline_call_arguments`, `multiline_parameters`, `multiline_conditions`.

## Layout is swift-format's, and this tool runs it

`--format` hands the corrected files to the `swift-format` inside Xcode, and to the one a
`.swift-format-version` file pins: the selected Xcode is asked first, and if its formatter is the wrong version
every installed Xcode is searched for the right one. So nothing has to run `xcode-select` before linting, and no
machine can quietly format by a version the project did not choose. That is deliberate: Xcode's Format File
(⇧⌃I) runs the same binary, so the tree and the keystroke cannot disagree. This tool decides what swift-format
has no opinion about — which lists split, which join, how imports are grouped — and never indentation.

Replacing swift-format with our own indentation rule was tried and dropped: while ⇧⌃I has to keep working,
reproducing it exactly is the best possible outcome, which makes the reimplementation redundant and starts a
chase after every Xcode release.

## Imports come in three groups

Apple's frameworks, then the project's own modules, then third-party ones; alphabetical inside a group, no
blank line between groups. Correctable, so `--fix` sorts them. Which modules are yours is configuration
(`our_modules`); which are Apple's is knowledge about the SDK and lives in the rule.

`grouped_imports`.

## A key path is for an API that takes one

`\.name` should tell a reader the parameter *is* a `KeyPath` — the SwiftUI environment, SwiftSyntax,
`removingDuplicates(by:)`. Spending it as closure shorthand costs that signal to save four characters, so
`--fix` writes `{ $0.name }` instead. It matches only the standard-library functions where the coercion is
possible — the same list `prefer_key_path` uses, since the two rules enforce opposite conventions over exactly
that set and must not drift apart.

`key_path_only_where_the_api_takes_one`.

## The boundaries a codebase is built on

These encode architectural decisions, which is why they can never go upstream. Each carries the paths it
applies to, since a built-in rule takes no path filters from the run.

| Rule | What it protects |
|---|---|
| `no_direct_presentation` | Screens signal through a navigator; SwiftUI's own presentation belongs to the navigation layer |
| `navigation_destination_only_in_navigation` | A local routing table is a screen the navigator cannot reach, restore or deep-link to |
| `no_presentation_state_outside_navigation` | A view reports finishing; it never carries a Bool saying whether it is on screen |
| `no_legacy_router_readers` | Reading a retired router resolves to a dead default and silently no-ops |
| `assets_come_from_the_generated_enum` | A named asset is looked up in the main bundle, so it finds nothing once the asset moves into a package |
| `no_user_defaults_in_app_code` | Persist through injected storage that fails loudly, not defaults that return `false` for a missing key |
| `keychain_built_only_at_the_root` | A preview or test building its own credential store reads the real device keychain |
| `value_storage_built_only_at_the_root` | Building storage mid-tree is a global by another name, and splits the table two views watch |
| `no_print_in_app_code` | Console output is invisible in a shipped build |
| `no_live_uikit_frame_reads` | Measuring a live UIKit bar from a body-reachable property wedges the view |
| `multiline_string_opens_on_its_own_line` | Opening a literal inside a call ties its contents to how the call wraps, so a reformat edits the value |
| `tienda_api_kit_is_ui_free` | A networking layer imports no UI framework |
| `environment_key_needs_judgement` | An environment key needs a branch that reads a different value than its parent |
| `environment_value_reassertion` | Re-injecting a value you already read means it was never context |

## Releases

A tag builds and publishes a macOS binary with its SHA256. A consuming repository pins the version, verifies
the checksum, and caches the binary outside its own tree — so there is nothing to install, nothing to keep in
step, and no way to lint by rules the repository did not choose.

arm64 only: the package builds a macro plugin, and SwiftPM cannot build one for two architectures in a single
invocation.

## Credit

The engine, and most of the rules, are [SwiftLint](https://github.com/realm/SwiftLint) — MIT, and the licence
travels with this code in `LICENSE`. Everything above is ours.
