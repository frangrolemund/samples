//
//  ViewModifier+Util.swift
//  MetDesigner
// 
//  Created on 1/30/24
//  Copyright © 2024 Francis Grolemund.  All rights reserved. 
//

import Foundation
import SwiftUI

/*
 *  Views that need to display standardized error alert dialogs should
 *  create a @State variable of this type and pass it as a binding to
 *  the
 */
struct MDAlertInfo {
	var isDisplaying: Bool
	var message: String
	
	typealias MDAlertAction = () -> Void
	var action: MDAlertAction?
	
	// - default the info to '.none' during initialization to provide
	//   an instance for binding, but one that is not displayed.
	static var none: MDAlertInfo  {
		var ret = MDAlertInfo(message: "")
		ret.isDisplaying = false
		return ret
	}
	
	/*
	 *  Initialize the object.
	 */
	init(message: String, action: MDAlertAction? = nil) {
		self.isDisplaying = true
		self.message 	  = message
		self.action 	  = action
	}
	
	/*
	 *  Initialize the object.
	 */
	init(error: Error, action: MDAlertAction? = nil) {
		var msg = error.localizedDescription
		if let lError = error as? LocalizedError, let fReason = lError.failureReason, fReason != msg, !fReason.isEmpty {
			msg += "  \(fReason)"
		}
		self.init(message: msg, action: action)
	}
}

/*
 *  Add the modifiers to the view namespace.
 */
extension View {	
	/*
	 *  Display a MetDesigner standard error dialog.
	 */
	func errorAlert(with alertInfo: Binding<MDAlertInfo>) -> some View {
		self.modifier(MDErrorAlertModifier(alertInfo: alertInfo))
	}
	
	/*
	 *  Compute the size of the view and execute the callback.
	 */
	func onSizeChange(_ callback: @escaping (_ size: CGSize) -> Void) -> some View {
		self.modifier(MDViewSizeReporter(callback: callback))
	}		
}

/*
 *  Display a standardized error alert dialog.
 */
fileprivate struct MDErrorAlertModifier : ViewModifier {
	@Binding private var alertInfo: MDAlertInfo
	
	/*
	 *  Initialize the modifier.
	 */
	init(alertInfo: Binding<MDAlertInfo>) {
		self._alertInfo = alertInfo
		if alertInfo.wrappedValue.isDisplaying {
			MDLog.error("Alert Displayed --> \(alertInfo.wrappedValue.message)")
		}
	}
	
	/*
	 *  Adapt the body.
	 */
	func body(content: Content) -> some View {
		content.alert("MetDesigner Failure", isPresented: $alertInfo.isDisplaying, presenting: alertInfo) { info in
			Button("OK") {
				guard let action = info.action else { return }
				action()
			}
		} message: { info in
			Text(info.message).font(.title)
		}
	}
}

/*
 *  Report the size of the view to the callback.
 */
fileprivate struct MDViewSizeReporter : ViewModifier {
	let callback: (_ size: CGSize) -> Void
	
	func body(content: Content) -> some View {
		GeometryReader(content: { geometry in
			content
				.task(id: geometry.size, {
					callback(geometry.size)
				})
		})
	}
}
