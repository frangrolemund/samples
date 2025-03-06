//
//  FirewallPopover+Button.swift
//  RRouted
// 
//  Created on 11/29/23
//  Copyright © 2023 RealProven, LLC.  All rights reserved. 
//

import SwiftUI

/*
 *  Displays a button in the popover with embedded text.
 */
struct FirewallPopoverTextButton: View {
	private let text: LocalizedStringKey
	private let isProminent: Bool
	private let allowSizing: Bool
	private let action: () -> Void
	
	/*
	 *  Initialize the object.
	 */
	init(text: LocalizedStringKey, action: @escaping () -> Void) {
		self.text = text
		self.isProminent = true
		self.allowSizing = false
		self.action = action
	}
	
	/*
	 *  Initialize the object.
	 */
	init(text: LocalizedStringKey, asProminent isProminent: Bool, allowSizing: Bool, action: @escaping () -> Void) {
		self.text 		 = text
		self.isProminent = isProminent
		self.allowSizing = allowSizing
		self.action      = action
	}
	
    var body: some View {
		if isProminent {
			commonButton.buttonStyle(.borderedProminent)
		}
		else {
			commonButton.buttonStyle(.bordered)
		}
    }
	
	private var commonButton: some View {
		// - this variant of button is necessary so that the label
		//   can be designated to expand, allowing the buttons to
		//   take on equal sizes when desired.
		Button(action: action) {
			Group {
				if allowSizing {
					Text(text)
						.frame(maxWidth: .infinity)
				}
				else {
					Text(text)
				}
			}
			.padding(5)
		}
	}
}

#Preview {
	EqualWidthsHStack {
		Spacer()
		FirewallPopoverTextButton(text: "Sample") {
			print("SAMPLE #1 TAPPED")
		}
		
		FirewallPopoverTextButton(text: "Another Sample") {
			print("SAMPLE #2 TAPPED")
		}
		Spacer()
	}
	.previewDevice("Mac")
}
