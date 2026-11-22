//
// ConfigProvider+IgnoringCascadeContext.swift
// swift-cascading-configuration
//
// Copyright © 2026 Ross Goldberg. All rights reserved.
//

public import Configuration

@available(Configuration 1.0, *)
public extension ConfigProvider {
	/// Creates a new configuration provider that removes the cascade context from
	/// the context of each key before a lookup.
	///
	/// The cascade context (the cascade scope floor, the base scope cascade scope
	/// floor & the base scope) is only meaningful to ``CascadingProvider``, which
	/// removes it before it queries its own upstream providers. Every other
	/// provider in the same `ConfigReader` receives the key with the cascade
	/// context still in its context, which can change the result of a provider
	/// that uses the context: `InMemoryProvider`, for example, only returns a
	/// value whose key has the same context.
	///
	/// Apply this method to every provider that you combine with a
	/// ``CascadingProvider`` without passing it to that ``CascadingProvider``,
	/// even one that ignores the context today, so that lookups keep working if
	/// the provider starts to use the context:
	///
	/// ```swift
	/// let config = ConfigReader(providers: [
	///     overridesProvider.ignoringCascadeContext(),
	///     CascadingProvider(providers: [.init(envProvider), .init(fileProvider)]),
	/// ])
	///
	/// // The overrides provider looks up "a.setting" with an empty context.
	/// let value = config.string(
	///     forKey: ConfigKey("a.setting", context: [CascadingProvider.cascadeScopeFloorContextKey: 1])
	/// )
	/// ```
	///
	/// - Returns: A provider which removes the cascade context from the context
	///   of each key.
	func ignoringCascadeContext() -> KeyMappingProvider<Self> {
		KeyMappingProvider(upstream: self) { key in
			var key = key
			CascadingProvider.removeCascadeContext(from: &key.context)
			return key
		}
	}
}
