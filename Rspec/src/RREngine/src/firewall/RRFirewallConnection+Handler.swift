//
//  RRFirewallConnection+Handler.swift
//  RREngine
// 
//  Created on 9/3/23
//  Copyright © 2023 RealProven, LLC.  All rights reserved. 
//

import Foundation
import NIOCore

/*
 *  The connection lifecycle handler that tracks basic traffic statistics and the
 *  presence of the connection.
 *  DESIGN: This object interfaces with the runtime(s) specifically (and not the model) so
 *  		the model can be isolated from what may be verbose background events as a rule,
 *			or at least until it requires more info.
 */
final class RRFirewallConnectionHandler : ChannelInboundHandler, ChannelOutboundHandler {
	typealias InboundIn = ByteBuffer
	typealias OutboundOut = ByteBuffer
	typealias OutboundIn = ByteBuffer
	
	/*
	 *  Initialize the object.
	 */
	init(withPortRuntime portRuntime: (any RRFirewallPortRunnable)?, andConnectionRuntime connRuntime: RRFirewallConnectionRuntime?) {
		self.portRuntime 	   = portRuntime
		self.connectionRuntime = connRuntime
	}
	
	/*
	 *  Data is inbound, record the stats.
	 */
	func channelRead(context: ChannelHandlerContext, data: NIOAny) {
		let count = UInt(max(self.unwrapInboundIn(data).readableBytes, 0))
		
		Task {
			connectionRuntime?.notifyNetworkTrafficMetrics(.init(bytesIn: count))
			await portRuntime?.notifyNetworkTrafficMetrics(.init(bytesIn: count))
		}
				
		// - send to the next handler.
		context.fireChannelRead(data)
	}
		
	/*
	 *  Data is outbound, record the stats.
	 */
	func write(context: ChannelHandlerContext, data: NIOAny, promise: EventLoopPromise<Void>?) {
		let count = UInt(max(self.unwrapOutboundIn(data).readableBytes, 0))
		
		Task {
			connectionRuntime?.notifyNetworkTrafficMetrics(.init(bytesOut: count))
			await portRuntime?.notifyNetworkTrafficMetrics(.init(bytesOut: count))
		}
		
		// - send to the next handler.
		context.write(data, promise: promise)
	}
			
	/*
	 *  The handler will be disconnected.
	 */
	deinit {
		self.discardConnection()
	}
	
	/*
	 *  Complete the disconnection process.
	 */
	private func discardConnection() {
		guard let connectionRuntime = connectionRuntime else { return }
		self.connectionRuntime = nil
		self.portRuntime	   = nil
		connectionRuntime.notifyDisconnected()
	}
	
	// - internal
	private var portRuntime: (any RRFirewallPortRunnable)?
	private var connectionRuntime: RRFirewallConnectionRuntime?
}
