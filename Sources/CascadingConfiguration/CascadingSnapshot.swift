//
// CascadingSnapshot.swift
// swift-cascading-configuration
//
// Copyright © 2026 Ross Goldberg. All rights reserved.
//

import Configuration

/// A configuration snapshot that falls back to less specific keys when its
/// upstream snapshots have no value for the requested key.
@available(Configuration 1.0, *)
struct CascadingSnapshot: ConfigSnapshot {
	/// The upstream providers whose snapshots these are, in precedence order, for
	/// their settings.
	var upstreams: [CascadingProvider.UpstreamProvider]

	/// The upstream snapshots, in precedence order.
	var snapshots: [any ConfigSnapshot]

	/// The human-readable name of the snapshot, which matches that of the
	/// provider that created it.
	var providerName: String {
		"CascadingProvider[providers: \(snapshots.map(\.providerName).joined(separator: ", "))]"
	}

	/// Returns the value for the specified key, or for the most specific
	/// cascading key that has one.
	/// - Parameters:
	///   - key: The configuration key to look up.
	///   - type: The expected configuration value type.
	/// - Returns: The 1st non-nil lookup result, or the most specific nil lookup
	///   result if no upstream snapshot has a value.
	/// - Throws: The 1st error thrown by an upstream snapshot.
	func value(forKey key: AbsoluteConfigKey, type: ConfigType) throws -> LookupResult {
		try cascadingValue(of: cascadingLookups(forKey: key, upstreams: upstreams)) { lookup in
			try snapshots[lookup.upstreamIndex].value(forKey: lookup.key, type: type)
		}
	}
}
