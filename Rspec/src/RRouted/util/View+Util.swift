//
//  View+Util.swift
//  RRouted
// 
//  Created on 11/25/23
//  Copyright © 2023 RealProven, LLC.  All rights reserved. 
//

import SwiftUI

typealias RRUIAction = () -> Void

/*
 *  Modifier to allow the hidden modifier to be conditionally applied.
 */
struct ConditionalHiddenView : ViewModifier {
	let isHidden: Bool
	
	func body(content: Content) -> some View {
		if isHidden {
			content.hidden()
		}
		else {
			content
		}
	}
}

/*
 *  Custom modifiers.
 */
extension View {
	func hidden(isHidden: Bool) -> some View {
		modifier(ConditionalHiddenView(isHidden: isHidden))
	}
}
