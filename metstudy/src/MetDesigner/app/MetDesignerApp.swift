//
//  MetDesignerApp.swift
//  MetDesigner
// 
//  Created on 1/13/24
//  Copyright © 2024 Francis Grolemund.  All rights reserved. 
//

import SwiftUI

@main
struct MetDesignerApp: App {
    var body: some Scene {
		DocumentGroup {
			MetDesignerDocument()
		} editor: { _ in
			MainWindowView()
		}
		.defaultPosition(.center)		// - the main window specifies its own desired frame dimensions
    }
}
