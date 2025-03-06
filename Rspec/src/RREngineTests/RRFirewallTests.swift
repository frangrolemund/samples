//
//  RRFirewallTests.swift
//  RREngineTests
// 
//  Created on 8/16/23
//  Copyright © 2023 RealProven, LLC.  All rights reserved. 
//

import XCTest
import Combine
import RREngine

/*
 *  Verifies the engine interfaces for controlling network access.
 */
@MainActor
final class RRFirewallTests: RREngineTestCase {
	/*
	 *  Tests the firewall port creation, management and basic networking.
	 */
    func testPortLifecycle() async throws {
		log.info("Building the engine.")
		let engine = createEngine()
		XCTAssertEqual(engine.operatingStatus, .running)

		log.info("Adding ports and verifying their changes.")
		// - add three ports to the engine to work with.
		// - NOTE:  These are temporary entrypoints until the trigger
		//			nodes are available.
		engine.debugAddHTTPPort()
		engine.debugAddHTTPPort()
		engine.debugAddHTTPPort()
		await observableChange(for: engine.firewall) { fw in
			fw.ports.count == 3
		}

		for i in 0..<engine.firewall.ports.count {
			let port = engine.firewall.ports[i]
			switch i {
			case 0:
				port.clientBacklog = 17
				port.isEnabled	   = false
				port.value		   = 8085
				break

			case 1:
				port.clientBacklog = 0
				port.value		   = 8086
				break

			case 2:
				port.clientBacklog = 5
				port.isEnabled	   = false
				port.value		   = 8087
				port.isEnabled	   = true
				break

			default:
				break
			}
		}

		XCTAssertEqual(engine.firewall.ports[0].clientBacklog, 17)
		XCTAssertEqual(engine.firewall.ports[0].isEnabled, false)
		XCTAssertEqual(engine.firewall.ports[0].value, 8085)

		XCTAssertEqual(engine.firewall.ports[1].clientBacklog, 0)
		XCTAssertEqual(engine.firewall.ports[1].isEnabled, true)
		XCTAssertEqual(engine.firewall.ports[1].value, 8086)

		XCTAssertEqual(engine.firewall.ports[2].clientBacklog, 5)
		XCTAssertEqual(engine.firewall.ports[2].isEnabled, true)
		XCTAssertEqual(engine.firewall.ports[2].value, 8087)

		log.info("Waiting for reconfiguration")
		for i in 0..<engine.firewall.ports.count {
			await observableChange(for: engine.firewall.ports[i]) { model in
				model.portStatus == (i == 0 ? .offline : .online)
			}
		}

		// - now shutdown the engine
		log.info("Shutting down.")
		let eRet = await engine.shutdown()
		XCTAssertTrue(eRet.isOk)
		XCTAssertEqual(engine.firewall.ports.count, 0)
    }
	
	/*
	 *  Verify connection behavior in ports.
	 */
	func testPortConnectivity() async throws {
		log.info("Building the engine.")
		let engine = createEngine()
		XCTAssertEqual(engine.operatingStatus, .running)

		// - bring up the services.
		engine.debugAddHTTPPort()
		engine.debugAddHTTPPort()
		XCTAssertEqual(engine.firewall.ports.count, 2)
		
		log.info("Waiting for ports to come online")
		engine.firewall.ports[0].value = 8083		
		engine.firewall.ports[1].value = 8084
		for p in engine.firewall.ports {
			await observableChange(for: p, until: { model in
				model.portStatus == .online
			})
		}

		// - make some simple requests
		log.info("Making simple requests...")
		let r0 = try await httpGETAsString(url: "http://localhost:8083/abc").get()
		log.info("...received '\(r0, privacy: .public)' from port 0.")
		
		let r1 = try await httpGETAsString(url: "http://localhost:8084/def").get()
		log.info("...received '\(r1, privacy: .public)' from port 1.")
		
		// - disable one port and reassign the other
		log.info("Reconfiguring...")
		engine.firewall.ports[0].isEnabled = false
		engine.firewall.ports[1].value = 8085
		await observableChange(for: engine.firewall.ports[0], until: { model in
			model.portStatus == .offline
		})
		await observableChange(for: engine.firewall.ports[1], until: { model in
			model.portStatus == .online
		})
		
		// - these should fail
		log.info("Making requests expected to fail...")
		let r2 = try? await httpGETAsString(url: "http://localhost:8083/ghi").get()
		XCTAssertNil(r2)

		let r3 = try? await httpGETAsString(url: "http://localhost:8084/jkl").get()
		XCTAssertNil(r3)

		// - this should succeed
		log.info("Making new request that should succeed...")
		let r4 = try await httpGETAsString(url: "http://localhost:8085/mno").get()
		log.info("...received '\(r4, privacy: .public)' from port 1.")
	}
}

/*
 *  Internal
 */
extension RRFirewallTests {
	private enum FWErr : Error {
		case badResult
	}
	
	/*
	 *  Issue a GET request of the given URL.
	 */
	private func httpGETAsString(url: String) async -> Result<String, Error> {
		var req 	   = URLRequest(url: URL(string: url)!)
		req.httpMethod = "GET"
		
		do {
			let resp = try await URLSession.shared.data(for: req)
			if let hResp = resp.1 as? HTTPURLResponse, hResp.statusCode == 200, let body = String(data: resp.0, encoding: .utf8) {
				return .success(body)
			}
			else {
				return .failure(FWErr.badResult)
			}
		}
		catch {
			return .failure(error)
		}
	}
}
