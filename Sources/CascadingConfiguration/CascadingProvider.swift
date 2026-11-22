//
// CascadingProvider.swift
// swift-cascading-configuration
//
// Copyright © 2026 Ross Goldberg. All rights reserved.
//

public import Configuration

/// A configuration provider that falls back to less specific keys when its
/// upstream providers have no value for the requested key.
///
/// A cascading lookup treats every component of a key except the last as a
/// scope. If no upstream provider has a value for the requested key,
/// `CascadingProvider` removes the innermost scope & tries again, until a value
/// is found or no scopes remain.
///
/// For example, a lookup of `a.b.setting` tries the following keys in order:
///
/// 1. `a.b.setting`
/// 2. `a.setting`
/// 3. `setting`
///
/// ## Value resolution order
///
/// Key specificity takes precedence over provider order: each step of a cascade
/// removes 1 more scope from the key of every upstream provider, and queries
/// every upstream provider before the next step. Within 1 step, upstream
/// providers are queried in the order in which they were provided.
///
/// ```swift
/// let provider = CascadingProvider(providers: [.init(x), .init(y)])
///
/// // Looking up "a.setting" queries, in order:
/// // 1. "a.setting" from x
/// // 2. "a.setting" from y
/// // 3. "setting" from x
/// // 4. "setting" from y
/// ```
///
/// ## Base scopes
///
/// An upstream provider can have a base scope: scopes that are prepended to
/// every key that it is asked for, like a namespace. Unlike a key prefix (see
/// `ConfigProvider.prefixKeys(with:)`), a cascade can remove base scopes, but
/// only below a separate floor.
///
/// ```swift
/// let provider = CascadingProvider(
///     providers: [
///         .init(EnvironmentVariablesProvider(), baseScope: ["tool"]),
///         .init(fileProvider),
///     ]
/// )
///
/// // Looking up "install.limit" queries, in order:
/// // 1. TOOL_INSTALL_LIMIT from the environment
/// // 2. "install.limit" from the file
/// // 3. TOOL_LIMIT from the environment
/// // 4. "limit" from the file
/// ```
///
/// ## Limiting the cascade
///
/// A cascade scope floor is the minimum number of scopes that a key tried by
/// the cascade keeps, not counting base scopes: `0` cascades until no scopes
/// remain, while ``CascadeScopeFloor/noCascading`` turns cascading off. Each
/// upstream provider has its own floor, which a key overrides via its context:
///
/// ```swift
/// let config = ConfigReader(provider: CascadingProvider(providers: [.init(env), .init(file)]))
///
/// // Tries "a.b.setting", then "a.setting", then "setting"
/// config.string(forKey: "a.b.setting")
///
/// // Tries "a.b.setting", then "a.setting"
/// config.string(
///     forKey: ConfigKey("a.b.setting", context: [CascadingProvider.cascadeScopeFloorContextKey: 1])
/// )
/// ```
///
/// A base scope cascade scope floor, counted in the whole key including base
/// scopes, lets the cascade remove the base scopes of an upstream provider
/// whose base scope is not empty (e.g., `0` reaches `PAGER` for `pager`, with
/// base scope `["tool"]`).
///
/// A key overrides a base scope via ``baseScopeContext(_:)``: an empty base
/// scope removes the base scope of every upstream provider, while any other
/// base scope replaces each base scope that is not empty.
///
/// `CascadingProvider` removes every entry of the cascade context (the floors &
/// the base scope) from the context before it queries its upstream providers.
/// Wrap each other provider in the same `ConfigReader` using
/// ``Configuration/ConfigProvider/ignoringCascadeContext()``, so that the
/// cascade context cannot affect its lookups.
///
/// ## Combining with other providers
///
/// `CascadingProvider` is an ordinary provider, so a `ConfigReader` can combine
/// it with others. A provider that follows it is only consulted after the whole
/// cascade finds no value:
///
/// ```swift
/// let config = ConfigReader(providers: [
///     CommandLineArgumentsProvider().ignoringCascadeContext(),          // Exact keys only
///     CascadingProvider(providers: [.init(env), .init(userFile)]),      // Cascades across both
///     CascadingProvider(providers: [.init(defaultsFile)]),              // Cascades after the above find nothing
/// ])
/// ```
///
/// `CommandLineArgumentsProvider` needs the `CommandLineArguments` trait of
/// Swift Configuration.
///
/// ## Error handling
///
/// When an upstream provider throws an error, `CascadingProvider` propagates it
/// immediately instead of trying the next provider or key.
@available(Configuration 1.0, *)
public struct CascadingProvider: Sendable {
	/// The name of the key context entry that holds a key's cascade scope floor.
	///
	/// The cascade scope floor is an integer: the minimum number of scopes, not
	/// counting base scopes, that a key tried by a cascading lookup keeps. It
	/// overrides the cascade scope floor of every upstream provider. An entry
	/// with a non-integer value is ignored, and a negative one behaves like `0`.
	public static let cascadeScopeFloorContextKey = "cascadeScopeFloor"

	/// The name of the key context entry that holds a key's base scope cascade
	/// scope floor.
	///
	/// The base scope cascade scope floor is an integer: the minimum number of
	/// scopes, counting base scopes, that a key tried by a cascading lookup
	/// keeps. It overrides the base scope cascade scope floor of every upstream
	/// provider whose base scope is not empty. An entry with a non-integer value
	/// is ignored, and a negative one behaves like `0`.
	public static let baseScopeCascadeScopeFloorContextKey = "baseScopeCascadeScopeFloor"

	/// The prefix of the names of the key context entries that hold a key's base
	/// scope.
	///
	/// A context value cannot be an array, so ``baseScopeContext(_:)`` stores the
	/// base scope as indexed entries (e.g., `baseScope.count`, `baseScope.0` &
	/// `baseScope.1`).
	public static let baseScopeContextKey = "baseScope"

	/// Returns the key context entries that override the base scope of a key.
	///
	/// An empty base scope removes the base scope of every upstream provider,
	/// while any other base scope replaces each base scope that is not empty:
	///
	/// ```swift
	/// // Looks up only PAGER, even in an environment provider whose base scope is ["tool"]
	/// config.string(forKey: ConfigKey("pager", context: CascadingProvider.baseScopeContext([])))
	/// ```
	///
	/// - Parameter baseScope: The base scope of the key.
	/// - Returns: The context entries that hold `baseScope`.
	public static func baseScopeContext(_ baseScope: [String]) -> [String: ConfigContextValue] {
		baseScope.enumerated().reduce(into: ["\(baseScopeContextKey).count": .int(baseScope.count)]) { context, element in
			context["\(baseScopeContextKey).\(element.offset)"] = .string(element.element)
		}
	}

	/// The upstream providers, in precedence order.
	private let upstreams: [UpstreamProvider]

	/// Creates a new provider.
	///
	/// - Parameter providers: The upstream providers in precedence order (1st
	///   provider has highest precedence for any single key).
	/// - Precondition: `providers` must not be empty.
	public init(providers: [UpstreamProvider]) {
		precondition(!providers.isEmpty, "CascadingProvider requires at least 1 upstream provider")
		upstreams = providers
	}
}

// MARK: - Cascade scope floor

@available(Configuration 1.0, *)
public extension CascadingProvider {
	/// The minimum number of leading scopes that a cascade keeps (e.g., `1`), so
	/// `0` is a full cascade, while ``noCascading`` turns cascading off.
	struct CascadeScopeFloor: Hashable, Sendable {
		/// The floor that turns cascading off, because no key has as many scopes.
		public static let noCascading = Self(validRawValue: .max)

		/// The minimum number of leading scopes that a cascade keeps.
		public let rawValue: Int

		/// The floor of a key context value, or `nil` if the value is not an
		/// integer; a negative integer behaves like `0`.
		fileprivate init?(contextValue: ConfigContextValue?) {
			guard case let .int(rawValue) = contextValue else {
				return nil
			}
			self.init(validRawValue: Swift.max(rawValue, 0))
		}

		private init(validRawValue: Int) {
			rawValue = validRawValue
		}

		/// This floor, increased by `count` base scopes (e.g., `1` increased by `1`
		/// is `2`), stopping at ``noCascading`` instead of overflowing.
		func increased(by count: Int) -> Self {
			let (sum, overflows) = rawValue.addingReportingOverflow(count)
			return .init(validRawValue: overflows ? Self.noCascading.rawValue : sum)
		}
	}
}

@available(Configuration 1.0, *)
extension CascadingProvider.CascadeScopeFloor: RawRepresentable {
	/// Creates the floor of `rawValue`, or `nil` if `rawValue` is negative, for
	/// an `Int` that is known only at run time.
	public init?(rawValue: Int) {
		guard rawValue >= 0 else {
			return nil
		}
		self.init(validRawValue: rawValue)
	}
}

@available(Configuration 1.0, *)
extension CascadingProvider.CascadeScopeFloor: ExpressibleByIntegerLiteral {
	/// Creates the floor of `value` (e.g., `1`).
	///
	/// - Precondition: `value` is not negative.
	public init(integerLiteral value: Int) {
		precondition(value >= 0, "A cascade scope floor cannot be negative: \(value)")
		self.init(validRawValue: value)
	}
}

// MARK: - Upstream provider

@available(Configuration 1.0, *)
public extension CascadingProvider {
	/// An upstream provider of a cascading provider, with its own base scope &
	/// floors.
	struct UpstreamProvider: Sendable {
		/// The provider to query.
		public var provider: any ConfigProvider

		/// The scopes that are prepended to every key that the provider is asked
		/// for (e.g., `["tool"]`).
		public var baseScope: [String]

		/// The minimum number of scopes, not counting base scopes, that a key tried
		/// by the cascade keeps, unless the key's context overrides it.
		public var cascadeScopeFloor: CascadeScopeFloor

		/// The minimum number of scopes, counting base scopes, that a key tried by
		/// the cascade keeps, if the base scope is not empty, unless the key's
		/// context overrides it; `nil` uses ``cascadeScopeFloor``, so the cascade
		/// never removes a base scope.
		public var baseScopeCascadeScopeFloor: CascadeScopeFloor?

		/// Creates an upstream provider.
		///
		/// - Parameters:
		///   - provider: The provider to query.
		///   - baseScope: The scopes that are prepended to every key that
		///     `provider` is asked for.
		///   - cascadeScopeFloor: The minimum number of scopes, not counting base
		///     scopes, that a key tried by the cascade keeps.
		///   - baseScopeCascadeScopeFloor: The minimum number of scopes, counting
		///     base scopes, that a key tried by the cascade keeps, if `baseScope`
		///     is not empty; `nil` uses `cascadeScopeFloor`.
		public init(
			_ provider: any ConfigProvider,
			baseScope: [String] = [],
			cascadeScopeFloor: CascadeScopeFloor = 0,
			baseScopeCascadeScopeFloor: CascadeScopeFloor? = nil,
		) {
			self.provider = provider
			self.baseScope = baseScope
			self.cascadeScopeFloor = cascadeScopeFloor
			self.baseScopeCascadeScopeFloor = baseScopeCascadeScopeFloor
		}
	}
}

// MARK: - ConfigProvider

@available(Configuration 1.0, *)
extension CascadingProvider: ConfigProvider {
	public var providerName: String {
		"CascadingProvider[providers: \(upstreams.map(\.provider.providerName).joined(separator: ", "))]"
	}

	public func value(forKey key: AbsoluteConfigKey, type: ConfigType) throws -> LookupResult {
		try cascadingValue(of: cascadingLookups(forKey: key, upstreams: upstreams)) { lookup in
			try upstreams[lookup.upstreamIndex].provider.value(forKey: lookup.key, type: type)
		}
	}

	public func fetchValue(forKey key: AbsoluteConfigKey, type: ConfigType) async throws -> LookupResult {
		var lookups = cascadingLookups(forKey: key, upstreams: upstreams)[...]
		// `upstreams` is never empty, and each upstream provider is asked for at
		// least 1 key
		let firstLookup = lookups.removeFirst()
		let firstResult = try await upstreams[firstLookup.upstreamIndex]
			.provider
			.fetchValue(forKey: firstLookup.key, type: type)
		var result = firstResult
		while result.value == nil, let lookup = lookups.popFirst() {
			result = try await upstreams[lookup.upstreamIndex].provider.fetchValue(forKey: lookup.key, type: type)
		}
		return result.value == nil ? firstResult : result
	}

	public func watchValue<Return: ~Copyable>(
		forKey key: AbsoluteConfigKey,
		type: ConfigType,
		updatesHandler: (
			_ updates: ConfigUpdatesAsyncSequence<Result<LookupResult, any Error>, Never>,
		) async throws -> Return,
	) async throws -> Return {
		// Ordered like a synchronous lookup
		let targets = cascadingLookups(forKey: key, upstreams: upstreams)
			.map { lookup in
				(provider: upstreams[lookup.upstreamIndex].provider, key: lookup.key)
			}
		var updateSequences = [any AsyncSequence<Result<LookupResult, any Error>, Never> & Sendable]()
		updateSequences.reserveCapacity(targets.count)
		return try await withTargetsWatchingValue(
			targets: .init(targets),
			updateSequences: &updateSequences,
			type: type,
		) { targetUpdateSequences in
			try await updatesHandler(
				.init(
					combineLatestMany(targetUpdateSequences)
						.map { results in
							// Return the 1st error or non-nil success from an upstream
							// provider; if every upstream result is a nil success, return the
							// most specific one
							results.first { result in
								if case let .success(lookupResult) = result {
									lookupResult.value != nil
								} else {
									true
								}
							}
								?? results[0]
						},
				),
			)
		}
	}

	public func snapshot() -> any ConfigSnapshot {
		CascadingSnapshot(upstreams: upstreams, snapshots: upstreams.map { $0.provider.snapshot() })
	}

	public func watchSnapshot<Return: ~Copyable>(
		updatesHandler: (_ updates: ConfigUpdatesAsyncSequence<any ConfigSnapshot, Never>) async throws -> Return,
	) async throws -> Return {
		var updateSequences = [any AsyncSequence<any ConfigSnapshot, Never> & Sendable]()
		updateSequences.reserveCapacity(upstreams.count)
		return try await withProvidersWatchingSnapshot(
			providers: .init(upstreams.map(\.provider)),
			updateSequences: &updateSequences,
		) { providerUpdateSequences in
			try await updatesHandler(
				.init(
					combineLatestMany(providerUpdateSequences)
						.map { [upstreams] in CascadingSnapshot(upstreams: upstreams, snapshots: $0) },
				),
			)
		}
	}
}

@available(Configuration 1.0, *)
extension CascadingProvider: CustomStringConvertible {
	public var description: String {
		"CascadingProvider[providers: \(upstreams.map { String(describing: $0.provider) }.joined(separator: ", "))]"
	}
}

@available(Configuration 1.0, *)
extension CascadingProvider: CustomDebugStringConvertible {
	public var debugDescription: String {
		"CascadingProvider[providers: \(upstreams.map { String(reflecting: $0.provider) }.joined(separator: ", "))]"
	}
}

// MARK: - Cascade context

@available(Configuration 1.0, *)
extension CascadingProvider {
	/// The entries of a key context that configure a cascade.
	struct CascadeContext {
		/// The cascade scope floor that overrides that of every upstream provider,
		/// if any.
		var cascadeScopeFloor: CascadeScopeFloor?

		/// The base scope cascade scope floor that overrides that of every upstream
		/// provider whose base scope is not empty, if any.
		var baseScopeCascadeScopeFloor: CascadeScopeFloor?

		/// The base scope that overrides that of every upstream provider whose base
		/// scope is not empty, if any; `[]` removes every base scope.
		var baseScope: [String]? // swiftlint:disable:this discouraged_optional_collection
	}

	/// Removes every entry of the cascade context from `context`.
	///
	/// - Parameter context: The key context, which keeps every other entry.
	/// - Returns: The cascade context that `context` held.
	@discardableResult
	static func removeCascadeContext(from context: inout [String: ConfigContextValue]) -> CascadeContext {
		let cascadeScopeFloor = CascadeScopeFloor(
			contextValue: context.removeValue(forKey: cascadeScopeFloorContextKey),
		)
		let baseScopeCascadeScopeFloor = CascadeScopeFloor(
			contextValue: context.removeValue(forKey: baseScopeCascadeScopeFloorContextKey),
		)
		let baseScopePrefix = "\(baseScopeContextKey)."
		let baseScopeEntries = context.filter { $0.key.hasPrefix(baseScopePrefix) }
		context = context.filter { !$0.key.hasPrefix(baseScopePrefix) }
		return .init(
			cascadeScopeFloor: cascadeScopeFloor,
			baseScopeCascadeScopeFloor: baseScopeCascadeScopeFloor,
			baseScope: baseScope(from: baseScopeEntries, prefix: baseScopePrefix),
		)
	}

	/// Returns the base scope that the indexed entries of a key context hold, or
	/// `nil` if they hold none, or if an entry is missing or has a value of
	/// another type.
	///
	/// - Parameters:
	///   - entries: The entries whose names start with `prefix`.
	///   - prefix: The prefix of the names of the entries.
	/// - Returns: The base scope, if any.
	// swiftlint:disable:next discouraged_optional_collection
	private static func baseScope(from entries: [String: ConfigContextValue], prefix: String) -> [String]? {
		guard case let .int(count) = entries["\(prefix)count"], count >= 0 else {
			return nil
		}
		let components = (0..<count)
			.compactMap { index in
				if case let .string(component) = entries["\(prefix)\(index)"] {
					component
				} else {
					nil
				}
			}
		return components.count == count ? components : nil
	}
}

// MARK: - Watching

/// Watches the value of every target, then runs the body with the collected
/// update sequences.
///
/// Each target's watch must stay open while the body runs, so the watches are
/// nested recursively: the 1st target's handler watches the remaining targets.
/// - Parameters:
///   - targets: The targets (each an upstream provider & the key to watch on
///     it) that are not yet watched, in precedence order.
///   - updateSequences: The update sequences collected so far, in precedence
///     order.
///   - type: The expected type of the configuration value.
///   - body: A closure that receives the update sequences of all targets.
/// - Returns: The value returned by the body closure.
/// - Throws: Any error thrown by an upstream provider or the body closure.
@available(Configuration 1.0, *)
private func withTargetsWatchingValue<Return: ~Copyable>(
	targets: ArraySlice<(provider: any ConfigProvider, key: AbsoluteConfigKey)>,
	updateSequences: inout [any AsyncSequence<Result<LookupResult, any Error>, Never> & Sendable],
	type: ConfigType,
	body: ([any AsyncSequence<Result<LookupResult, any Error>, Never> & Sendable]) async throws -> Return,
) async throws -> Return {
	if let target = targets.first {
		try await target.provider.watchValue(forKey: target.key, type: type) { updates in
			updateSequences.append(updates)
			return try await withTargetsWatchingValue(
				targets: targets.dropFirst(),
				updateSequences: &updateSequences,
				type: type,
				body: body,
			)
		}
	} else {
		// Recursion termination: once every update sequence is collected, execute
		// the body
		try await body(updateSequences)
	}
}

/// Watches the snapshot of every provider, then runs the body with the
/// collected update sequences.
///
/// Each provider's watch must stay open while the body runs, so the watches are
/// nested recursively: the 1st provider's handler watches the remaining
/// providers.
/// - Parameters:
///   - providers: The providers that are not yet watched, in precedence order.
///   - updateSequences: The update sequences collected so far, in precedence
///     order.
///   - body: A closure that receives the update sequences of all providers.
/// - Returns: The value returned by the body closure.
/// - Throws: Any error thrown by an upstream provider or the body closure.
@available(Configuration 1.0, *)
private func withProvidersWatchingSnapshot<Return: ~Copyable>(
	providers: ArraySlice<any ConfigProvider>,
	updateSequences: inout [any AsyncSequence<any ConfigSnapshot, Never> & Sendable],
	body: ([any AsyncSequence<any ConfigSnapshot, Never> & Sendable]) async throws -> Return,
) async throws -> Return {
	if let provider = providers.first {
		try await provider.watchSnapshot { updates in
			updateSequences.append(updates)
			return try await withProvidersWatchingSnapshot(
				providers: providers.dropFirst(),
				updateSequences: &updateSequences,
				body: body,
			)
		}
	} else {
		// Recursion termination: once every update sequence is collected, execute
		// the body
		try await body(updateSequences)
	}
}
