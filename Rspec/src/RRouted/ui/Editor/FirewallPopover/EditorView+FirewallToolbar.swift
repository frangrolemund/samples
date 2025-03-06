//
//  EditorView+FirewallToolbar.swift
//  RRouted
// 
//  Created on 9/27/23
//  Copyright © 2023 RealProven, LLC.  All rights reserved. 
//

import AppKit
import SwiftUI
import Combine
import RREngine

/*
 *  Implements the modifier(s) that manage the firewall configuration from the toolbar.
 */
struct EditorViewFirewallToolbar : ViewModifier {
	@ObservedObject private var watcher: FirewallIconWatcher
	@State private var isShowingFirewallPopover: Bool = false
	@State private var minPopoverHeight: CGFloat = 0
	
	/*
	 *  Initialize the object.
	 */
	init(document: RRoutedDocument) {
		self.watcher = .init(with: document)
	}
	
	func body(content: Content) -> some View {
		content
			.toolbar {
			ToolbarItem(placement: .primaryAction) {
				HStack {
					FirewallToolbarButton(isShowingFirwallPopover: $isShowingFirewallPopover, watcher: watcher)
					.popover(isPresented: $isShowingFirewallPopover, arrowEdge: .bottom) {
						let maxHeight = ((NSScreen.main?.frame.height ?? 1100) * 0.6).rounded()
						Group {
							if watcher.settings.hasAuthorizedFirewall {
								FirewallPopoverConfigView(document: watcher.document)
							}
							else {
								FirewallPopoverPermissionsView(settings: watcher.settings)
									.padding()
							}
						}
						.frame(minHeight: min(minPopoverHeight, maxHeight), maxHeight: maxHeight)
						.frame(width: 300)
						.onDisappear(perform: {
							guard !watcher.settings.hasSeenFirewallConfiguration else { return }
							watcher.settings.hasSeenFirewallConfiguration = true
						})
						.onPreferenceChange(FirewallPopoverSectionHeight.self, perform: { totalHeight in
							minPopoverHeight = totalHeight + 50
						})
					}
				}
			}
		}
		.onReceive(watcher.objectWillChange, perform: { _ in
			if !self.watcher.settings.hasSeenFirewallConfiguration && !self.watcher.firewall.ports.isEmpty {
				self.isShowingFirewallPopover = true
			}
		})
	}
}

/*
 *  Internal.
 */
extension EditorViewFirewallToolbar {
	// - for the configuration view, the segments will expand/contract and are in
	//   a scroll view, which doesn't propagate its own size up through the hierarchy
	//   in the way needed here.  The solution is that each section in the
	//   configuration will send a height value that will be combined to size the popover.
	struct FirewallPopoverSectionHeight: PreferenceKey {
		static let defaultValue: CGFloat = 0
		static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
			value = value + nextValue()
		}
	}
}

/*
 *  Convenience
 */
extension View {
	func firewallToolbar(with document: RRoutedDocument) -> some View {
		modifier(EditorViewFirewallToolbar(document: document))
	}
}

/*
 *  The button displayed in the toolbar.
 */
fileprivate struct FirewallToolbarButton : View {
	@Binding private var isShowingFirwallPopover: Bool
	@ObservedObject private var watcher: FirewallIconWatcher
	
	init(isShowingFirwallPopover: Binding<Bool>, watcher: FirewallIconWatcher) {
		self._isShowingFirwallPopover = isShowingFirwallPopover
		self.watcher 				  = watcher
	}
	
	var body: some View {
		Button {
			isShowingFirwallPopover.toggle()
		} label: {
			switch watcher.status {
			case .unauthorized:
				Label("Unauthorized", systemImage: "wifi.exclamationmark")

			case .offline:
				Label("Offline", systemImage: "wifi.slash")

			case .warning:
				Label("Partially Configured", systemImage: "wifi.exclamationmark")
				
			case .error:
				Label("Error", systemImage: "wifi.exclamationmark")
				
			case .online:
				Label("Online", systemImage: "wifi")
			}
		}
		.buttonStyle(.borderless)		// - necessary to get color
		.tint(watcher.status.color)
		.font(.title3)					// - sizing for the button
		.padding(.init(top: 0, leading: 0, bottom: 0, trailing: 5))
	}
}

/*
 *  This class is responsible for identifying changes to the display of
 *  the firewall icon so it can be presented accurately.
 */
@MainActor
fileprivate final class FirewallIconWatcher : ObservableObject {
	let document: RRoutedDocument
	var settings: RRUserSettings { self.document.settings }
	var firewall: RRFirewall { self.document.engine.firewall }
	@Published private (set) var status: FirewallIconStatus = .unauthorized
	
	/*
	 *  Initialize the object.
	 */
	init(with document: RRoutedDocument) {
		self.document = document
		recomputeStatus()
		
		self.fwToken = self.firewall.objectWillChange.receive(on: RunLoop.main).sink(receiveValue: { [weak self] (_) in
			self?.recomputeStatus()
		})
		
		self.sToken = self.settings.objectWillChange.receive(on: RunLoop.main).sink(receiveValue: { [weak self] (_) in
			self?.recomputeStatus()
		})
	}
	
	enum FirewallIconStatus {
		case unauthorized
		case offline
		case warning
		case error
		case online
		
		var color: Color {
			switch self {
			case .unauthorized:
				return .black
				
			case .offline:
				return RRouted.brand.disabledColor
				
			case .warning:
				return RRouted.brand.warningColor
				
			case .error:
				return RRouted.brand.errorColor
				
			case .online:
				return RRouted.brand.okColor
			}
		}
	}
	
	/*
	 *  Recompute the state using the provided entities.
	 */
	private func recomputeStatus() {
		let newStatus: FirewallIconStatus
		
		if settings.hasAuthorizedFirewall {
			switch firewall.firewallStatus {
			case .offline:
				newStatus = .offline
				
			case .warning:
				newStatus = .warning
				
			case .error:
				newStatus = .error
				
			case .online:
				newStatus = .online
			}
		}
		else {
			newStatus = .unauthorized
		}
		
		self.status = newStatus
	}
	
	private var fwToken: AnyCancellable?
	private var sToken: AnyCancellable?
}
