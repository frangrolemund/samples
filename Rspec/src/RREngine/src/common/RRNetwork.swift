//
//  RRNetwork.swift
//  RREngine
// 
//  Created on 9/7/23
//  Copyright © 2023 RealProven, LLC.  All rights reserved. 
//

import Foundation

/*
 *  General purpose networking types.
 */

/// Identifies networking protocol behavior of an entity.
public enum RRNetworkProtocol : String {
   /// HTTP 1.1
   case http = "HTTP"
   
   ///  A textual description of the protocol.
   public var description: String { self.rawValue }
}


/// Describes statistics of networking I/O.
public struct RRNetworkMetrics : Sendable {
	/// Add two instances of networking metrics.
	public static func + (left: RRNetworkMetrics, right: RRNetworkMetrics) -> RRNetworkMetrics {
		return .init(bytesIn: left.bytesIn + right.bytesIn,
					 bytesOut: left.bytesOut + right.bytesOut)
	}
	
	/// Add another instance of networking metrics to this one.
	public static func += (left: inout RRNetworkMetrics, right: RRNetworkMetrics) {
		left = left + right
	}
	
	/// The number of bytes received.
	public var bytesIn: UInt
	
	/// The number of bytes sent.
	public var bytesOut: UInt
	
	///  Initialize the object.
	///
	///  - Parameter bytesIn: The number of bytes received.
	///  - Parameter bytesOut: The number of bytes sent.
	public init(bytesIn: UInt = 0, bytesOut: UInt = 0) {
		self.bytesIn  = bytesIn
		self.bytesOut = bytesOut
	}
}


/// Defines a TCP port number on which network traffic is routed.
public typealias NetworkPortValue = UInt16


///  Describes the source of a remote network connection.
public struct RRNetworkAddress {
	/// A human-readable description of the address.
	public let description: String
	
	/// The IP address of the remote.
	public let ipAddress: String
	
	/// The port on which the remote is connected.
	public let port: NetworkPortValue
}
