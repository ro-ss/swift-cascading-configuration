//
// FailingProvider.swift
// swift-cascading-configuration
//
// Copyright © 2026 Ross Goldberg. All rights reserved.
//

import Configuration

/// An upstream provider that throws for 1 key & has no value for any other.
@available(Configuration 1.0, *)
struct FailingProvider: ConfigProvider {
	struct TestError: Error {}

	/// The key whose lookups throw.
	var failingKey: AbsoluteConfigKey

	var providerName: String {
		"FailingProvider"
	}

	func value(forKey key: AbsoluteConfigKey, type _: ConfigType) throws(TestError) -> LookupResult {
		guard key != failingKey else {
			throw TestError()
		}
		return LookupResult(encodedKey: key.description, value: nil)
	}

	func fetchValue(forKey key: AbsoluteConfigKey, type: ConfigType) throws(TestError) -> LookupResult {
		try value(forKey: key, type: type)
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
