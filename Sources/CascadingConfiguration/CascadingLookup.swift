//
// CascadingLookup.swift
// swift-cascading-configuration
//
// Copyright © 2026 Ross Goldberg. All rights reserved.
//

import Configuration

/// 1 key that a cascading lookup asks 1 upstream provider for: the index of the
/// upstream provider & the key, including the base scope of the upstream
/// provider, without the cascade context.
@available(Configuration 1.0, *)
typealias CascadingLookup = (upstreamIndex: Int, key: AbsoluteConfigKey)

/// Returns every key that a cascading lookup of `key` tries, from the most
/// specific step to the least, and in precedence order within each step.
///
/// Each step removes 1 more scope from the key of every upstream provider, and
/// an upstream provider tries no key that has fewer scopes than its own floor,
/// so upstream providers whose base scopes differ in length still try their
/// keys in order of specificity (e.g., for `pager`, with base scope cascade
/// scope floor `0` & base scopes `["tool"]` & `["org", "tool"]`: `tool.pager`,
/// `org.tool.pager`, `pager`, `org.pager`, then `pager`).
/// - Parameters:
///   - key: The requested key, whose context may hold the cascade context.
///   - upstreams: The upstream providers, in precedence order.
/// - Returns: Every key to try, each with the index of its upstream provider.
@available(Configuration 1.0, *)
func cascadingLookups(
	forKey key: AbsoluteConfigKey,
	upstreams: [CascadingProvider.UpstreamProvider],
) -> [CascadingLookup] {
	var context = key.context
	let cascadeContext = CascadingProvider.removeCascadeContext(from: &context)
	guard let name = key.components.last else {
		return upstreams.indices.map { (upstreamIndex: $0, key: .init(key.components, context: context)) }
	}
	let scope = key.components.dropLast()
	// Could change: 1 floor for every upstream provider, if each upstream
	// provider that needs another floor goes in another `CascadingProvider`,
	// which then also cascades only after this one finds nothing
	let plans = upstreams.map { upstream in
		let baseScope = upstream.baseScope.isEmpty ? [] : cascadeContext.baseScope ?? upstream.baseScope
		let fullScope = baseScope + scope
		let floor =
			if
				!baseScope.isEmpty,
				let baseScopeFloor = cascadeContext.baseScopeCascadeScopeFloor ?? upstream.baseScopeCascadeScopeFloor
			{
				baseScopeFloor
			} else {
				(cascadeContext.cascadeScopeFloor ?? upstream.cascadeScopeFloor).increased(by: baseScope.count)
			}
		return (scope: fullScope, floor: Swift.min(floor.rawValue, fullScope.count))
	}
	let stepCount = plans.lazy.map { $0.scope.count - $0.floor }.max() ?? 0
	return (0...stepCount)
		.flatMap { step in
			plans.enumerated()
				.compactMap { upstreamIndex, plan in
					let depth = plan.scope.count - step
					return depth >= plan.floor
						? (
							upstreamIndex: upstreamIndex,
							key: .init(.init(plan.scope.prefix(depth)) + [name], context: context),
						)
						: nil
				}
		}
}

/// Resolves a value by trying every lookup, in order.
/// - Parameters:
///   - lookups: The lookups to try, in order. Must not be empty.
///   - lookUp: A closure that runs a lookup.
/// - Returns: The 1st non-nil lookup result, or the most specific nil lookup
///   result if no lookup finds a value.
/// - Throws: The 1st error thrown by the closure.
@available(Configuration 1.0, *)
func cascadingValue(
	of lookups: [CascadingLookup],
	lookUp: (_ lookup: CascadingLookup) throws -> LookupResult,
) throws -> LookupResult {
	var lookups = lookups[...]
	// There is at least 1 upstream provider, and each one is asked for at least 1
	// key
	let firstResult = try lookUp(lookups.removeFirst())
	var result = firstResult
	while result.value == nil, let lookup = lookups.popFirst() {
		result = try lookUp(lookup)
	}
	return result.value == nil ? firstResult : result
}
