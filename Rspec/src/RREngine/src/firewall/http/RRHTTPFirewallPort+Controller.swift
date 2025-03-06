//
//  RRHTTPFirewallPort+Controller.swift
//  RREngine
// 
//  Created on 8/25/23
//  Copyright © 2023 RealProven, LLC.  All rights reserved. 
//

import Foundation
import NIOCore
import NIOHTTP1

/*
 *  Controller for managing HTTP port connections.
 */
struct RRHTTPFirewallPortController : RRFirewallPortController {
	typealias Config = RRHTTPFirewallPort.Config
	
	let config: Config
	
	/*
	 *  Initialize the object.
	 */
	init(with config: Config) {
		self.config = config
	}
	
	/*
	 *  Configure the child handler(s) for the protocol.
	 */
	func addChildHandler(from runtime: RRFirewallConnectionRuntime, channel: Channel) -> EventLoopFuture<Void> {
		channel.pipeline.configureHTTPServerPipeline(withErrorHandling: true).flatMap { _ in
			channel.pipeline.addHandler(RRHTTPFirewallPortHandler(with: self.config, from: runtime))
		}
	}
}

/*
 *  Manages HTTP protocol requests.
 */
fileprivate final class RRHTTPFirewallPortHandler<Runtime: RRFirewallConnectionRuntime> : ChannelInboundHandler, ObservableObject {
	public typealias InboundIn = HTTPServerRequestPart
	public typealias OutboundOut = HTTPServerResponsePart
	
	let config: RRHTTPFirewallPort.Config
	let runtime: Runtime

	/*
	 *  Initialize the object.
	 */
	init(with config: RRHTTPFirewallPort.Config, from runtime: Runtime) {
		self.config  = config
		self.runtime = runtime
	}
	
	/*
	 *  Read inbound content
	 */
	public func channelRead(context: ChannelHandlerContext, data: NIOAny) {
		//  -----
		//  DEBUG:  Intentionally crude for now.
		//  -----
		let reqPart = self.unwrapInboundIn(data)
		switch reqPart {
		case .head(let reqHead):
			self.reqHead = reqHead
			
		case .body(_):
			break
			
		case .end(_):
			guard let reqHead = self.reqHead else { return }
			if reqHead.uri == "/wait/hang" { return }		// - for debugging disconnect
			
			self.reqHead = nil
			var responseHead = httpResponseHead(request: reqHead, status: .ok)
			var buffer = context.channel.allocator.buffer(capacity: 0)
			buffer.clear()
			buffer.writeString("RR-OK [\(RRIdentifier().uuidString)] --> \(Date().description)\n")
			responseHead.headers.add(name: "content-length", value: String(buffer.readableBytes))
			let response = HTTPServerResponsePart.head(responseHead)
			context.write(self.wrapOutboundOut(response), promise: nil)
			let content = HTTPServerResponsePart.body(.byteBuffer(buffer.slice()))
			let promise = {() -> EventLoopPromise<Void>? in
				guard !reqHead.isKeepAlive else { return nil }
				let ret = context.eventLoop.makePromise(of: Void.self)
				ret.futureResult.whenComplete({ _ in
					context.close(promise: nil)
				})
				return ret
			}()
			let _ = context.write(self.wrapOutboundOut(content))
			context.writeAndFlush(self.wrapOutboundOut(.end(nil)), promise: promise)
		}
	}
	
	// - internal implementation
	private var reqHead: HTTPRequestHead?
}

/*
 *  Internal implementation.
 */
extension RRHTTPFirewallPortHandler {
	private func httpResponseHead(request: HTTPRequestHead, status: HTTPResponseStatus, headers: HTTPHeaders = HTTPHeaders()) -> HTTPResponseHead {
		return .init(version: request.version, status: status, headers: headers)
	}
}
