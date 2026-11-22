//
// IgnoringCascadeContextTests.swift
// swift-cascading-configuration
//
// Copyright © 2026 Ross Goldberg. All rights reserved.
//

import CascadingConfiguration
import Testing

struct IgnoringCascadeContextTests {
	@available(Configuration 1.0, *)
	@Test
	func `ignoring cascade context`() throws {
		let upstream = InMemoryProvider(values: [
			AbsoluteConfigKey(["foo"]): "bar",
			AbsoluteConfigKey(["baz"], context: ["environment": "production"]): "qux",
		])
		let floorContext = CascadingProvider.baseScopeContext(["tool"])
			.merging([
				CascadingProvider.cascadeScopeFloorContextKey: 1,
				CascadingProvider.baseScopeCascadeScopeFloorContextKey: 0,
			]) { $1 }

		// The in-memory provider only matches a key with the same context, so the
		// cascade context hides its value
		let flooredKey = AbsoluteConfigKey(["foo"], context: floorContext)
		#expect(try upstream.value(forKey: flooredKey, type: .string).value == nil)

		let ignoring = upstream.ignoringCascadeContext()
		#expect(try ignoring.value(forKey: flooredKey, type: .string).value?.content.asString == "bar")
		#expect(try ignoring.value(forKey: ["foo"], type: .string).value?.content.asString == "bar")

		// The rest of the context is kept
		let flooredContextKey = AbsoluteConfigKey(
			["baz"],
			context: floorContext.merging(["environment": "production"]) { $1 },
		)
		#expect(try ignoring.value(forKey: flooredContextKey, type: .string).value?.content.asString == "qux")
	}
}
