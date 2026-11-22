//
// CascadingProviderTests.swift
// swift-cascading-configuration
//
// Copyright © 2026 Ross Goldberg. All rights reserved.
//

import CascadingConfiguration
import ConfigurationTesting
import Synchronization
import Testing

/// The bytes of a byte configuration value that the compat test expects.
private let magic: [UInt8] = [0x6d, 0x61, 0x67, 0x69, 0x63]

/// The bytes of another byte configuration value that the compat test expects.
private let magic2: [UInt8] = [0x6d, 0x61, 0x67, 0x69, 0x63, 0x32]

struct CascadingProviderTests {
	@available(Configuration 1.0, *)
	@Test
	func `get value prefers most specific key`() throws {
		let provider = CascadingProvider(
			providers: [
				.init(
					InMemoryProvider(values: ["a.b.setting": "specific", "a.setting": "middle", "setting": "general"]),
				),
			],
		)
		let result = try provider.value(forKey: ["a", "b", "setting"], type: .string)
		#expect(try result.value?.content.asString == "specific")
		#expect(result.encodedKey == "a.b.setting")
	}

	@available(Configuration 1.0, *)
	@Test
	func `get value cascades to less specific keys`() throws {
		let provider = CascadingProvider(
			providers: [.init(InMemoryProvider(values: ["a.setting": "middle", "setting": "general"]))],
		)

		let middleResult = try provider.value(forKey: ["a", "b", "c", "setting"], type: .string)
		#expect(try middleResult.value?.content.asString == "middle")
		#expect(middleResult.encodedKey == "a.setting")

		let generalResult = try provider.value(forKey: ["x", "setting"], type: .string)
		#expect(try generalResult.value?.content.asString == "general")
		#expect(generalResult.encodedKey == "setting")
	}

	@available(Configuration 1.0, *)
	@Test
	func `get value only removes innermost scopes`() throws {
		// "b.setting" is not a cascading key of "a.b.setting", whose scopes are
		// removed from the inside out
		let provider = CascadingProvider(providers: [.init(InMemoryProvider(values: ["b.setting": "unrelated"]))])
		let result = try provider.value(forKey: ["a", "b", "setting"], type: .string)
		#expect(result.value == nil)
		#expect(result.encodedKey == "a.b.setting")
	}

	@available(Configuration 1.0, *)
	@Test
	func `get value key specificity over provider order`() throws {
		let provider = CascadingProvider(
			providers: [
				.init(InMemoryProvider(name: "1st", values: ["setting": "1st general"])),
				.init(InMemoryProvider(name: "2nd", values: ["a.setting": "2nd specific"])),
			],
		)
		let result = try provider.value(forKey: ["a", "setting"], type: .string)
		#expect(try result.value?.content.asString == "2nd specific")
	}

	@available(Configuration 1.0, *)
	@Test
	func `get value provider order within key`() throws {
		let provider = CascadingProvider(
			providers: [
				.init(InMemoryProvider(name: "1st", values: ["setting": "1st"])),
				.init(InMemoryProvider(name: "2nd", values: ["setting": "2nd"])),
			],
		)
		let result = try provider.value(forKey: ["a", "setting"], type: .string)
		#expect(try result.value?.content.asString == "1st")
	}

	@available(Configuration 1.0, *)
	@Test
	func `get value error halts cascading`() throws {
		let provider = CascadingProvider(
			providers: [
				.init(FailingProvider(failingKey: ["a", "setting"])),
				.init(InMemoryProvider(values: ["setting": "unreachable"])),
			],
		)
		#expect(throws: FailingProvider.TestError.self) {
			try provider.value(forKey: ["a", "setting"], type: .string)
		}
	}

	@available(Configuration 1.0, *)
	@Test(
		arguments: [
			(nil, "1 scope"),
			(-1, "1 scope"),
			(0, "1 scope"),
			(1, "1 scope"),
			(2, nil),
			(3, nil),
			(4, nil),
		] as [(Int?, String?)],
	)
	func `scope floor limits cascade`(scopeFloor: Int?, expected: String?) throws {
		// The only value is at a key with 1 scope, so the lookup finds it unless
		// the floor is above 1
		let provider = CascadingProvider(providers: [.init(InMemoryProvider(values: ["a.setting": "1 scope"]))])
		let context: [String: ConfigContextValue] =
			scopeFloor.map { [CascadingProvider.cascadeScopeFloorContextKey: .int($0)] } ?? [:]
		let key = AbsoluteConfigKey(["a", "b", "c", "setting"], context: context)
		#expect(try provider.value(forKey: key, type: .string).value?.content.asString == expected)
		#expect(try provider.snapshot().value(forKey: key, type: .string).value?.content.asString == expected)
	}

	@available(Configuration 1.0, *)
	@Test
	func `scope floor ignored unless integer`() throws {
		let provider = CascadingProvider(providers: [.init(InMemoryProvider(values: ["setting": "general"]))])
		let key = AbsoluteConfigKey(["a", "setting"], context: [CascadingProvider.cascadeScopeFloorContextKey: "1"])
		#expect(try provider.value(forKey: key, type: .string).value?.content.asString == "general")
	}

	@available(Configuration 1.0, *)
	@Test
	func `scope floor removed from upstream context`() throws {
		let upstream = ContextRecordingProvider()
		let provider = CascadingProvider(providers: [.init(upstream)])
		let key = AbsoluteConfigKey(
			["a", "setting"],
			context: CascadingProvider.baseScopeContext(["tool"])
				.merging([
					CascadingProvider.cascadeScopeFloorContextKey: 1,
					CascadingProvider.baseScopeCascadeScopeFloorContextKey: 0,
					"environment": "production",
				]) { $1 },
		)
		_ = try provider.value(forKey: key, type: .string)
		#expect(upstream.contexts.withLock(\.self) == [["environment": "production"]])
	}

	@available(Configuration 1.0, *)
	@Test
	func `scope floor through reader`() {
		let config = ConfigReader(
			provider: CascadingProvider(providers: [.init(InMemoryProvider(values: ["setting": "general"]))]),
		)
		#expect(config.string(forKey: "a.setting") == "general")
		let limitedKey = ConfigKey("a.setting", context: [CascadingProvider.cascadeScopeFloorContextKey: 1])
		#expect(config.string(forKey: limitedKey) == nil)
	}

	@available(Configuration 1.0, *)
	@Test
	func `scope floor limits fetch`() async throws {
		let provider = CascadingProvider(providers: [.init(InMemoryProvider(values: ["setting": "general"]))])
		let key = AbsoluteConfigKey(["a", "b", "setting"], context: [CascadingProvider.cascadeScopeFloorContextKey: 1])
		let result = try await provider.fetchValue(forKey: key, type: .string)
		#expect(result.value == nil)
		#expect(result.encodedKey == "a.b.setting")
	}

	@available(Configuration 1.0, *)
	@Test
	func `scope floor limits watch`() async throws {
		let upstream = MutableInMemoryProvider(initialValues: ["setting": "general"])
		let provider = CascadingProvider(providers: [.init(upstream)])
		let key = AbsoluteConfigKey(["a", "b", "setting"], context: [CascadingProvider.cascadeScopeFloorContextKey: 1])
		try await withThrowingTaskGroup(of: Void.self) { group in
			let future1 = TestFuture<String?>(name: "future1")
			let future2 = TestFuture<String?>(name: "future2")
			group.addTask {
				try await provider.watchValue(forKey: key, type: .string) { updates in
					var iterator = updates.makeAsyncIterator()
					try await future1.fulfill(iterator.next()?.get().value?.content.asString)
					try await future2.fulfill(iterator.next()?.get().value?.content.asString)
				}
			}
			// "setting" has fewer scopes than the floor, so its value is not found
			await #expect(future1.value == nil)

			upstream.setValue("middle", forKey: "a.setting")
			await #expect(future2.value == "middle")
			try await group.waitForAll()
		}
	}

	@available(Configuration 1.0, *)
	@Test
	func `upstream scope floor limits only its upstream`() throws {
		let provider = CascadingProvider(
			providers: [
				.init(InMemoryProvider(name: "floored", values: ["setting": "floored"]), cascadeScopeFloor: 1),
				.init(InMemoryProvider(name: "full", values: ["setting": "full"])),
			],
		)
		#expect(try provider.value(forKey: ["a", "setting"], type: .string).value?.content.asString == "full")
	}

	@available(Configuration 1.0, *)
	@Test
	func `context scope floor overrides upstream scope floor`() throws {
		let provider = CascadingProvider(
			providers: [.init(InMemoryProvider(values: ["setting": "general"]), cascadeScopeFloor: .noCascading)],
		)
		let key = AbsoluteConfigKey(["a", "setting"], context: [CascadingProvider.cascadeScopeFloorContextKey: 0])
		#expect(try provider.value(forKey: key, type: .string).value?.content.asString == "general")
	}

	@available(Configuration 1.0, *)
	@Test
	func `base scope is prepended but never removed by default`() throws {
		let upstream = KeyRecordingProvider()
		let provider = CascadingProvider(providers: [
			.init(upstream, baseScope: ["tool"]),
			.init(KeyRecordingProvider()),
		])
		_ = try provider.value(forKey: ["install", "limit"], type: .string)
		#expect(upstream.keys.withLock(\.self) == ["tool.install.limit", "tool.limit"])
	}

	@available(Configuration 1.0, *)
	@Test
	func `lookups interleave upstreams by step`() throws {
		let recorder = KeyRecordingProvider()
		let provider = CascadingProvider(
			providers: [
				.init(recorder, baseScope: ["tool"], baseScopeCascadeScopeFloor: 0),
				.init(recorder, baseScope: ["org", "tool"], baseScopeCascadeScopeFloor: 0),
			],
		)
		_ = try provider.value(forKey: ["pager"], type: .string)
		#expect(recorder.keys.withLock(\.self) == ["tool.pager", "org.tool.pager", "pager", "org.pager", "pager"])
	}

	@available(Configuration 1.0, *)
	@Test(
		arguments: [
			(nil, ["tool.install.limit", "tool.limit"]),
			(0, ["tool.install.limit", "tool.limit", "limit"]),
			(1, ["tool.install.limit", "tool.limit"]),
			(2, ["tool.install.limit"]),
		] as [(Int?, [String])],
	)
	func `base scope cascade scope floor counts base scope`(floor: Int?, expected: [String]) throws {
		let recorder = KeyRecordingProvider()
		let provider = CascadingProvider(providers: [.init(recorder, baseScope: ["tool"])])
		let context: [String: ConfigContextValue] =
			floor.map { [CascadingProvider.baseScopeCascadeScopeFloorContextKey: .int($0)] } ?? [:]
		_ = try provider.value(forKey: .init(["install", "limit"], context: context), type: .string)
		#expect(recorder.keys.withLock(\.self) == expected)
	}

	@available(Configuration 1.0, *)
	@Test
	func `base scope cascade scope floor ignored without base scope`() throws {
		let recorder = KeyRecordingProvider()
		let provider = CascadingProvider(providers: [
			.init(recorder, cascadeScopeFloor: 1, baseScopeCascadeScopeFloor: 0),
		])
		_ = try provider.value(forKey: ["install", "limit"], type: .string)
		#expect(recorder.keys.withLock(\.self) == ["install.limit"])
	}

	@available(Configuration 1.0, *)
	@Test(
		arguments: [
			([], ["pager"], ["pager"]),
			(["git"], ["git.pager"], ["pager"]),
		] as [([String], [String], [String])],
	)
	func `base scope context overrides only non empty base scopes`(
		baseScope: [String],
		expectedScoped: [String],
		expectedUnscoped: [String],
	) throws {
		let scoped = KeyRecordingProvider()
		let unscoped = KeyRecordingProvider()
		let provider = CascadingProvider(providers: [.init(scoped, baseScope: ["tool"]), .init(unscoped)])
		_ = try provider.value(
			forKey: .init(["pager"], context: CascadingProvider.baseScopeContext(baseScope)),
			type: .string,
		)
		#expect(scoped.keys.withLock(\.self) == expectedScoped)
		#expect(unscoped.keys.withLock(\.self) == expectedUnscoped)
	}

	@available(Configuration 1.0, *)
	@Test
	func `invalid base scope context is ignored`() throws {
		let recorder = KeyRecordingProvider()
		let provider = CascadingProvider(providers: [.init(recorder, baseScope: ["tool"])])
		// The base scope claims 2 components, but has only 1
		let context: [String: ConfigContextValue] = ["baseScope.count": 2, "baseScope.0": "git"]
		_ = try provider.value(forKey: .init(["pager"], context: context), type: .string)
		#expect(recorder.keys.withLock(\.self) == ["tool.pager"])
	}

	@available(Configuration 1.0, *)
	@Test
	func `base scope context entries`() {
		#expect(CascadingProvider.baseScopeContext([]) == ["baseScope.count": 0])
		#expect(
			CascadingProvider.baseScopeContext(["org", "tool"])
				== ["baseScope.count": 2, "baseScope.0": "org", "baseScope.1": "tool"],
		)
	}

	@available(Configuration 1.0, *)
	@Test
	func `scope floor stops at no cascading`() throws {
		let recorder = KeyRecordingProvider()
		let provider = CascadingProvider(providers: [
			.init(recorder, baseScope: ["tool"], cascadeScopeFloor: .noCascading),
		])
		_ = try provider.value(forKey: ["install", "limit"], type: .string)
		#expect(recorder.keys.withLock(\.self) == ["tool.install.limit"])
	}

	@available(Configuration 1.0, *)
	@Test
	func `cascade scope floor raw value`() {
		#expect(CascadingProvider.CascadeScopeFloor(rawValue: 1) == 1)
		#expect(CascadingProvider.CascadeScopeFloor(rawValue: -1) == nil)
		#expect(CascadingProvider.CascadeScopeFloor.noCascading.rawValue == .max)
	}

	@available(Configuration 1.0, *)
	@Test
	func `fetch value cascades`() async throws {
		let provider = CascadingProvider(
			providers: [
				.init(InMemoryProvider(name: "1st", values: ["setting": "1st general"])),
				.init(InMemoryProvider(name: "2nd", values: ["a.setting": "2nd specific"])),
			],
		)

		let specificResult = try await provider.fetchValue(forKey: ["a", "b", "setting"], type: .string)
		#expect(try specificResult.value?.content.asString == "2nd specific")
		#expect(specificResult.encodedKey == "a.setting")

		let absentResult = try await provider.fetchValue(forKey: ["a", "other"], type: .string)
		#expect(absentResult.value == nil)
		#expect(absentResult.encodedKey == "a.other")
	}

	@available(Configuration 1.0, *)
	@Test
	func `snapshot cascades`() throws {
		let provider = CascadingProvider(
			providers: [
				.init(InMemoryProvider(name: "1st", values: ["setting": "1st general"])),
				.init(InMemoryProvider(name: "2nd", values: ["a.setting": "2nd specific"])),
			],
		)
		let snapshot = provider.snapshot()
		#expect(snapshot.providerName == provider.providerName)

		let specificResult = try snapshot.value(forKey: ["a", "b", "setting"], type: .string)
		#expect(try specificResult.value?.content.asString == "2nd specific")

		let generalResult = try snapshot.value(forKey: ["x", "setting"], type: .string)
		#expect(try generalResult.value?.content.asString == "1st general")
	}

	@available(Configuration 1.0, *)
	@Test
	func `watch value cascades`() async throws {
		let upstream = MutableInMemoryProvider(initialValues: ["setting": "general"])
		let provider = CascadingProvider(providers: [.init(upstream)])
		try await withThrowingTaskGroup(of: Void.self) { group in
			let future1 = TestFuture<String?>(name: "future1")
			let future2 = TestFuture<String?>(name: "future2")
			group.addTask {
				try await provider.watchValue(forKey: ["a", "setting"], type: .string) { updates in
					var iterator = updates.makeAsyncIterator()
					try await future1.fulfill(iterator.next()?.get().value?.content.asString)
					try await future2.fulfill(iterator.next()?.get().value?.content.asString)
				}
			}
			await #expect(future1.value == "general")

			upstream.setValue("specific", forKey: "a.setting")
			await #expect(future2.value == "specific")
			try await group.waitForAll()
		}
	}

	@available(Configuration 1.0, *)
	@Test
	func `watch value key specificity over provider order`() async throws {
		let first = MutableInMemoryProvider(name: "1st", initialValues: ["setting": "1st general"])
		let second = MutableInMemoryProvider(name: "2nd", initialValues: [:])
		let provider = CascadingProvider(providers: [.init(first), .init(second)])
		try await withThrowingTaskGroup(of: Void.self) { group in
			let future1 = TestFuture<String?>(name: "future1")
			let future2 = TestFuture<String?>(name: "future2")
			let future3 = TestFuture<String?>(name: "future3")
			group.addTask {
				try await provider.watchValue(forKey: ["a", "setting"], type: .string) { updates in
					var iterator = updates.makeAsyncIterator()
					try await future1.fulfill(iterator.next()?.get().value?.content.asString)
					try await future2.fulfill(iterator.next()?.get().value?.content.asString)
					try await future3.fulfill(iterator.next()?.get().value?.content.asString)
				}
			}
			await #expect(future1.value == "1st general")

			// The 2nd provider's specific value beats the 1st provider's general
			// value
			second.setValue("2nd specific", forKey: "a.setting")
			await #expect(future2.value == "2nd specific")

			// Within 1 key, the 1st provider's value beats the 2nd provider's value
			first.setValue("1st specific", forKey: "a.setting")
			await #expect(future3.value == "1st specific")
			try await group.waitForAll()
		}
	}

	@available(Configuration 1.0, *)
	@Test
	func `watch snapshot cascades`() async throws {
		let upstream = MutableInMemoryProvider(initialValues: ["setting": "general"])
		let provider = CascadingProvider(providers: [.init(upstream)])
		try await withThrowingTaskGroup(of: Void.self) { group in
			let future1 = TestFuture<String?>(name: "future1")
			let future2 = TestFuture<String?>(name: "future2")
			group.addTask {
				try await provider.watchSnapshot { updates in
					var iterator = updates.makeAsyncIterator()
					let key: AbsoluteConfigKey = ["a", "setting"]
					try await future1.fulfill(
						iterator.next()?.value(forKey: key, type: .string).value?.content.asString,
					)
					try await future2.fulfill(
						iterator.next()?.value(forKey: key, type: .string).value?.content.asString,
					)
				}
			}
			await #expect(future1.value == "general")

			upstream.setValue("specific", forKey: "a.setting")
			await #expect(future2.value == "specific")
			try await group.waitForAll()
		}
	}

	@available(Configuration 1.0, *)
	@Test
	func `later provider consulted after whole cascade`() {
		let config = ConfigReader(
			providers: [
				CascadingProvider(
					providers: [.init(InMemoryProvider(name: "primary", values: ["setting": "primary"]))],
				),
				CascadingProvider(
					providers: [
						.init(
							InMemoryProvider(name: "later", values: ["a.setting": "later specific", "other": "later"]),
						),
					],
				),
			],
		)
		// The primary cascade's general value beats the later provider's specific
		// value
		#expect(config.string(forKey: "a.setting") == "primary")
		// The later provider cascades by itself once the primary cascade finds
		// nothing
		#expect(config.string(forKey: "a.b.other") == "later")
	}

	@available(Configuration 1.0, *)
	@Test
	func compat() async throws {
		let upstream = InMemoryProvider(
			name: "test",
			values: [
				"string": "Hello",
				"other.string": "Other Hello",
				"int": 42,
				"other.int": 24,
				"double": 3.14,
				"other.double": 2.72,
				"bool": true,
				"other.bool": false,
				"bytes": ConfigValue(.bytes(magic), isSecret: false),
				"other.bytes": ConfigValue(.bytes(magic2), isSecret: false),
				"stringy.array": ConfigValue(.stringArray(["Hello", "World"]), isSecret: false),
				"other.stringy.array": ConfigValue(.stringArray(["Hello", "Swift"]), isSecret: false),
				"inty.array": ConfigValue(.intArray([42, 24]), isSecret: false),
				"other.inty.array": ConfigValue(.intArray([16, 32]), isSecret: false),
				"doubly.array": ConfigValue(.doubleArray([3.14, 2.72]), isSecret: false),
				"other.doubly.array": ConfigValue(.doubleArray([0.9, 1.8]), isSecret: false),
				"booly.array": ConfigValue(.boolArray([true, false]), isSecret: false),
				"other.booly.array": ConfigValue(.boolArray([false, true, true]), isSecret: false),
				"byteChunky.array": ConfigValue(.byteChunkArray([magic, magic2]), isSecret: false),
				"other.byteChunky.array": ConfigValue(.byteChunkArray([magic, magic2, magic]), isSecret: false),
			],
		)

		// The compat test expects no value for keys like "absent.string", which a
		// cascade would find at "string", so give every key a cascade scope floor
		// that prevents cascading
		let provider = CascadingProvider(providers: [.init(upstream, cascadeScopeFloor: .noCascading)])
		try await ProviderCompatTest(provider: provider).runTest()
	}

	@available(Configuration 1.0, *)
	@Test
	func `provider name`() {
		let provider = CascadingProvider(
			providers: [
				.init(InMemoryProvider(name: "1st", values: [:])),
				.init(InMemoryProvider(name: "2nd", values: [:])),
			],
		)
		#expect(
			provider.providerName == "CascadingProvider[providers: InMemoryProvider[1st], InMemoryProvider[2nd]]",
		)
	}

	@available(Configuration 1.0, *)
	@Test
	func description() {
		let provider = CascadingProvider(providers: [.init(InMemoryProvider(name: "1st", values: [:]))])
		#expect(provider.description == "CascadingProvider[providers: InMemoryProvider[1st, 0 values]]")
	}
}
