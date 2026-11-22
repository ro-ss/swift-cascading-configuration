// swift-tools-version:6.2

private import PackageDescription

private let swiftSettings = [
	// Defines `Configuration 1.0`, the availability that the vendored code from
	// Swift Configuration uses
	SwiftSetting.enableExperimentalFeature(
		"AvailabilityMacro=Configuration 1.0:macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0",
	),
	.enableUpcomingFeature("ExistentialAny"),
	.enableUpcomingFeature("ImmutableWeakCaptures"),
	.enableUpcomingFeature("InferIsolatedConformances"),
	.enableUpcomingFeature("InternalImportsByDefault"),
	.enableUpcomingFeature("MemberImportVisibility"),
	.enableUpcomingFeature("NonisolatedNonsendingByDefault"),
	.strictMemorySafety(),
	.treatAllWarnings(as: .error),
]

_ = Package(
	name: "swift-cascading-configuration",
	products: [.library(name: "CascadingConfiguration", targets: ["CascadingConfiguration"])],
	dependencies: [
		.package(url: "https://github.com/apple/swift-collections", from: "1.3.0"),
		.package(url: "https://github.com/apple/swift-configuration", from: "1.5.0"),
	],
	targets: [
		.target(
			name: "CascadingConfiguration",
			dependencies: [
				.product(name: "Configuration", package: "swift-configuration"),
				.product(name: "DequeModule", package: "swift-collections"),
			],
			swiftSettings: swiftSettings,
		),
		.testTarget(
			name: "CascadingConfigurationTests",
			dependencies: [
				"CascadingConfiguration",
				.product(name: "ConfigurationTesting", package: "swift-configuration"),
			],
			swiftSettings: swiftSettings,
		),
	],
	swiftLanguageModes: [.v6],
)
