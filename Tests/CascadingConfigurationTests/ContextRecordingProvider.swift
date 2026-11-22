//
// ContextRecordingProvider.swift
// swift-cascading-configuration
//
// Copyright © 2026 Ross Goldberg. All rights reserved.
//

import Configuration
import Synchronization

/// An upstream provider that records the context of every key that it is asked
/// for, and has no values.
@available(Configuration 1.0, *)
final class ContextRecordingProvider: ConfigProvider {
	/// The contexts of the keys looked up so far, in lookup order.
	let contexts = Mutex<[[String: ConfigContextValue]]>([])

	var providerName: String {
		"ContextRecordingProvider"
	}

	func value(forKey key: AbsoluteConfigKey, type _: ConfigType) -> LookupResult {
		contexts.withLock { $0.append(key.context) }
		return LookupResult(encodedKey: key.description, value: nil)
	}

	func fetchValue(forKey key: AbsoluteConfigKey, type: ConfigType) -> LookupResult {
		value(forKey: key, type: type)
	}

	func watchValue<Return: ~Copyable>(
		forKey key: AbsoluteConfigKey,
		type: ConfigType,
		updatesHandler: (
			_ updates: ConfigUpdatesAsyncSequence<Result<LookupResult, any Error>, Never>,
		) async throws -> Return,
	) async throws -> Return {
		try await watchValueFromValue(forKey: key, type: type, updatesHandler: updatesHandler)
	}

	func snapshot() -> any ConfigSnapshot {
		InMemoryProvider(values: [:]).snapshot()
	}

	func watchSnapshot<Return: ~Copyable>(
		updatesHandler: (_ updates: ConfigUpdatesAsyncSequence<any ConfigSnapshot, Never>) async throws -> Return,
	) async throws -> Return {
		try await watchSnapshotFromSnapshot(updatesHandler: updatesHandler)
	}
}
