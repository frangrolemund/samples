//
//  EditorDebugView.swift
//  RRouted
// 
//  Created on 12/7/23
//  Copyright © 2023 RealProven, LLC.  All rights reserved. 
//

import SwiftUI
import RREngine
import Combine

struct EditorDebugView: View {
	@ObservedObject private var firewall: RRFirewall
	
	init(firewall: RRFirewall) {
		self.firewall = firewall
	}
	
    var body: some View {
		HStack {
			Spacer()
			
			VStack(alignment: .leading) {
				HStack {
					Text("Active Connections:").font(.title2)
					Spacer()
				}
				
				ScrollView {
					ForEach(firewall.ports) { port in
						PortView(port: port)
					}
				}
				
				Spacer()
			}
			.padding()
			.frame(width: 500)
			.background(.white)
			
			Spacer()
		}
		.background(.gray)
    }
}

struct PortView : View {
	@ObservedObject var port: RRFirewallPort
	
	var body: some View {
		VStack {
			if port.value != nil {
				HStack {
					Text("http://localhost:\(port.value!, format: .number.grouping(.never))").font(.title3).bold()
					Spacer()
				}
				.hidden(isHidden: port.connections.isEmpty)
				
				ForEach(port.connections) { conn in
					ConnectionView(connection: conn)
						.padding(.init(top: 0, leading: 0, bottom: 5, trailing: 0))
				}
			}
		}
	}
}

// - display a connection.
struct ConnectionView : View {
	@ObservedObject var connection: RRFirewallConnection
	
	var body: some View {
		VStack(alignment: .leading) {
			HStack {
				Text("\(connection.connectionType.description) Connection \(connection.id.briefId)").font(.subheadline)
				Button("Disconnect") {
					connection.disconnect()
				}
				.disabled(connection.connectionStatus != .online)
				Spacer()
			}
			
			VStack(alignment: .leading) {
				Text("Inbound: \(connection.networkMetrics.bytesIn)")
				Text("Outbound: \(connection.networkMetrics.bytesOut)")
			}
			.padding(.init(top: 0, leading: 5, bottom: 0, trailing: 0))
		}
		.frame(maxWidth: .infinity)
	}
}
