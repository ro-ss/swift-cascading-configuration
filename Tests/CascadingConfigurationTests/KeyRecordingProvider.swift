//
// KeyRecordingProvider.swift
// swift-cascading-configuration
//
// Copyright © 2026 Ross Goldberg. All rights reserved.
//

import Configuration
import Synchronization

/// An upstream provider that records every key that it is asked for, in dot
/// notation, and has no values.
@available(Configuration 1.0, *)
final class KeyRecordingProvider: ConfigProvider {
	/// The keys looked up so far, in lookup order.
	let keys = Mutex<[String]>([])

	var providerName: String {
		"KeyRecordingProvider"
	}

	func value(forKey key: AbsoluteConfigKey, type _: ConfigType) -> LookupResult {
		let encodedKey = key.components.joined(separator: ".")
		keys.withLock { $0.append(encodedKey) }
		return .init(encodedKey: encodedKey, value: nil)
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
