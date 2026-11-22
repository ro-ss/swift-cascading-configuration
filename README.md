# Swift Cascading Configuration

<!--editorconfig-checker-disable-->
[![Swift 6.2](
  https://img.shields.io/badge/Swift-6.2-F05138?logo=swift&logoColor=white
)](https://www.swift.org/install/)
[![CI](
  https://github.com/ro-ss/swift-cascading-configuration/actions/workflows/ci.yaml/badge.svg
)](
  https://github.com/ro-ss/swift-cascading-configuration/actions/workflows/ci.yaml
)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue)](LICENSE)
<!--editorconfig-checker-enable-->

Cascading scoped value lookup for [Swift
Configuration](https://github.com/apple/swift-configuration).

`CascadingProvider` is a Swift Configuration provider that falls back to less
specific keys when its upstream providers have no value for the requested key
(e.g., `a.b.setting`, then `a.setting`, then `setting`), so that a setting can
be set once for every scope, then overridden for a specific scope.

## Usage

```swift
import CascadingConfiguration

let config = ConfigReader(
    provider: CascadingProvider(
        providers: [
            .init(EnvironmentVariablesProvider(), baseScope: ["tool"]),
            .init(try await FileProvider<JSONSnapshot>(filePath: "tool.json")),
        ],
    ),
)

// Tries, in order:
// 1. TOOL_INSTALL_LIMIT from the environment
// 2. "install.limit" from the file
// 3. TOOL_LIMIT from the environment
// 4. "limit" from the file
config.int(forKey: "install.limit")
```

`CascadingConfiguration` re-exports Swift Configuration, so
`import CascadingConfiguration` also imports `Configuration`.

### Value Resolution Order

A cascading lookup treats every component of a key except the last as a scope.
Key specificity takes precedence over provider order: each step of a cascade
removes 1 more scope from the key of every upstream provider, then queries every
upstream provider, in the order in which they were provided, before the next
step.

### Base Scopes

An upstream provider can have a base scope (e.g., `["tool"]`): scopes that are
prepended to every key that it is asked for, like a namespace. Unlike a key
prefix (see `ConfigProvider.prefixKeys(with:)`), a base scope can be removed by
a cascade, but only below a separate floor (the base scope cascade scope floor).

A key overrides the base scope of every upstream provider via
`CascadingProvider.baseScopeContext(_:)`:

<!--editorconfig-checker-disable-->
<!--markdownlint-disable line-length-->
```swift
// Looks up only PAGER, even in an environment provider whose base scope is ["tool"]
config.string(forKey: ConfigKey("pager", context: CascadingProvider.baseScopeContext([])))
```
<!--markdownlint-enable line-length-->
<!--editorconfig-checker-enable-->

### Limiting the Cascade

A cascade scope floor is the minimum number of scopes, not counting base scopes,
that a key tried by the cascade keeps: `0` (the default) cascades until no
scopes remain, while `.noCascading` turns cascading off. Each upstream provider
has its own floor, which a key overrides via its context:

<!--editorconfig-checker-disable-->
<!--markdownlint-disable line-length-->
```swift
// Tries "a.b.setting", then "a.setting"
config.string(forKey: ConfigKey("a.b.setting", context: [CascadingProvider.cascadeScopeFloorContextKey: 1]))
```
<!--markdownlint-enable line-length-->
<!--editorconfig-checker-enable-->

### Combining with Other Providers

`CascadingProvider` is an ordinary provider, so a `ConfigReader` can combine it
with others. A provider that follows it is only consulted after the whole
cascade finds no value.

`CascadingProvider` removes the cascade context (the floors & the base scope)
from the context of each key before it queries its upstream providers; wrap each
other provider in the same `ConfigReader` with `ignoringCascadeContext()`, so
that the cascade context cannot affect its lookups:

<!--editorconfig-checker-disable-->
<!--markdownlint-disable line-length-->
```swift
let config = ConfigReader(providers: [
    CommandLineArgumentsProvider().ignoringCascadeContext(), // Exact keys only
    CascadingProvider(providers: [.init(env), .init(userFile)]), // Cascades across both
    CascadingProvider(providers: [.init(defaultsFile)]), // Cascades after the above find nothing
])
```
<!--markdownlint-enable line-length-->
<!--editorconfig-checker-enable-->

`CommandLineArgumentsProvider` needs the `CommandLineArguments` trait of Swift
Configuration, which a package enables by depending on Swift Configuration
directly:

```swift
.package(
    url: "https://github.com/apple/swift-configuration",
    from: "1.5.0",
    traits: [.defaults, "CommandLineArguments"],
),
```

### Watching & Errors

Fetching values, watching values & watching snapshots follow the same cascade as
a synchronous lookup. When an upstream provider throws an error,
`CascadingProvider` propagates it immediately instead of trying the next
provider or key.

## Installation

Add the package to the dependencies of your `Package.swift`:

<!--editorconfig-checker-disable-->
<!--markdownlint-disable line-length-->
```swift
.package(url: "https://github.com/ro-ss/swift-cascading-configuration", from: "0.1.0"),
```
<!--markdownlint-enable line-length-->
<!--editorconfig-checker-enable-->

Then add the `CascadingConfiguration` product to the dependencies of each target
that uses it:

<!--editorconfig-checker-disable-->
<!--markdownlint-disable line-length-->
```swift
.product(name: "CascadingConfiguration", package: "swift-cascading-configuration"),
```
<!--markdownlint-enable line-length-->
<!--editorconfig-checker-enable-->

## Requirements

| Requirement | Minimum                                                     |
| ----------- | ----------------------------------------------------------- |
| Build       | Swift 6.2 or Xcode 26                                       |
| Run         | macOS 15, iOS 18, tvOS 18, watchOS 11, visionOS 2, or Linux |

`CascadingConfiguration` declares no `platforms`, so a package that supports
older platforms can depend on it; each of its declarations is available wherever
Swift Configuration is.

## Contributing

Pull requests are welcome; see the [contribution guidelines](CONTRIBUTING.md) &
the [code of conduct](CODE_OF_CONDUCT.md). Report vulnerabilities as described
in the [security policy](SECURITY.md).

## License

`CascadingConfiguration` is available under the [MIT License](LICENSE).
