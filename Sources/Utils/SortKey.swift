//
//  SortKey.swift
//  MediaBridge
//
//  Created by Oleksii Kolomiiets on 2/8/26.
//

import Foundation
import MediaPlayer

/// A type alias for a sendable key path used for sorting.
///
/// Represents a key path from a root type to a comparable value, with sendability guarantees for concurrent contexts.
///
/// - Parameters:
///   - Root: The root type that the key path starts from
///   - Value: The comparable value type that the key path points to
public typealias SortKey<Root, Value: Comparable> = KeyPath<Root, Value> & Sendable

/// A type alias for a sendable boolean key path used for sorting.
///
/// `Bool` is deliberately not `Comparable`, so boolean sorting uses this alias
/// rather than ``SortKey``.
///
/// - Parameters:
///   - Root: The root type that the key path starts from
public typealias FlagKey<Root> = KeyPath<Root, Bool> & Sendable
