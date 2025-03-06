//
//  MMNetworkClient.swift
//  MetModel
// 
//  Created on 2/24/24
//  Copyright © 2024 RealProven, LLC.  All rights reserved. 
//

import Foundation

/*
 *  The network client encapsulates all the API and file requests of the
 *  Met Art back-end systems.
 *
 *  The MetArt RESTful API: https://metmuseum.github.io
 */
actor MMNetworkClient {
	// - a common shared instance for most use cases.
	static let shared: MMNetworkClient = .init()
	
	// - the rate limiter is static so that multiple instances of the model in one
	//   process don't exceed the limits and it is set to be only half of the MetArt
	//   published limit for clients to be sure usage doesn't raise any concerns.
	private static let rateLimit: MMRateLimiter = .init(requestsPerSecond: MMRateLimiter.MetArtLimit / 2)
}

/*
 *  Implementation.
 */
extension MMNetworkClient {
	/*
	 *  Standardized rate limiting.
	 */
	private func rateLimitedRequest<T>(_ block: () async -> T) async -> T {
		await Self.rateLimit.waitForAccess()
		return await block()
	}
	
	/*
	 *  Query for object data.
	 */
	func queryMetArtObject(identifiedBy objectID: MMObjectIdentifier) async -> Result<MMObject, Error> {
		return await self.rateLimitedRequest {
			guard let url = URL(string: "https://collectionapi.metmuseum.org/public/collection/v1/objects/\(objectID)") else {
				return .failure(MMError.failedAssertion)
			}
			
			do {
				let (data, resp) = try await URLSession.shared.data(from: url)
				
				let hStatus = (resp as? HTTPURLResponse)?.statusCode
				guard hStatus == 200 else {
					return .failure(MMError.httpError(statusCode: hStatus, msg: (hStatus != nil) ? HTTPURLResponse.localizedString(forStatusCode: hStatus!): nil))
				}
				guard !data.isEmpty else {
					return .failure(MMError.httpError(statusCode: 204, msg: "No content."))
				}
				
				return .success(try MMObject.standardMMJSONDecoding(of: data))
			}
			catch {
				// ...don't log cancellations since they can easily occur.
				if !Task.isCancelled {
					MMLog.error("Failed to successfully query the MetArt REST API for the object identified as \(objectID, privacy: .public).  \(error.localizedDescription, privacy: .public)")
					if let dText = (error as? MMErrorDebuggable)?.mmDebuggableText {
						MMLog.debug("\(dText, privacy: .public)")
					}
				}
				return .failure(error)
			}
		}
	}
	
	/*
	 *  Query for file data.
	 */
	typealias MetArtFileResult = Result<Data, Error>
	func queryMetArtFile(atURL url: URL) async -> MetArtFileResult {
		return await self.rateLimitedRequest {
			do {
				// ...this is provided for local file access, mainly for testing purposes.
				guard !url.isFileURL else {
					if FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) {
						return .success(try Data(contentsOf: url))
					}
					else {
						return .failure(MMError.notFound)
					}					
				}
				
				// - otherwise, contact the network
				let (data, resp) = try await URLSession.shared.data(from: url)
				
				let hStatus = (resp as? HTTPURLResponse)?.statusCode
				guard hStatus == 200 else {
					return .failure(MMError.httpError(statusCode: hStatus, msg: (hStatus != nil) ? HTTPURLResponse.localizedString(forStatusCode: hStatus!): nil))
				}
				guard !data.isEmpty else {
					return .failure(MMError.httpError(statusCode: 204, msg: "No content."))
				}
				return .success(data)
			}
			catch {
				MMLog.error("Failed to successfully query the MetArt file data at \(url.absoluteString, privacy: .public).  \(error.localizedDescription, privacy: .public)")
				if let dText = (error as? MMErrorDebuggable)?.mmDebuggableText {
					MMLog.debug("\(dText, privacy: .public)")
				}
				return .failure(error)
			}
		}
	}
}
