//
//  MDStyling.swift
//  MetDesigner
// 
//  Created on 2/7/24
//  Copyright © 2024 Francis Grolemund.  All rights reserved. 
//

import Foundation
import SwiftUI
import AppKit

/*
 *  UI styling constants
 */

extension ShapeStyle where Self == Color {
	static var accentColor: Color { .accentColor }
	static var darkGray: Color { .init(white: 0.4) }
	static var lightGray: Color { .init(white: 0.85) }
	
	static var selectionColor: Color { .accentColor }
	static var barBackground: Color { .init(white: 0.98) }
}
