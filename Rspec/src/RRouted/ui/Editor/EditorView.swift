//
//  EditorView.swift
//  RRouted
// 
//  Created on 9/19/23
//  Copyright © 2023 RealProven, LLC.  All rights reserved. 
//

import SwiftUI

/*
 *  The editor displays in the dominant body of the main window and
 *  is used for the primary document visualizations and modification.
 */
struct EditorView: View {
	@EnvironmentObject private var document: RRoutedDocument
	
    var body: some View {
		EditorDebugView(firewall: document.engine.firewall)
			.firewallToolbar(with: document)
    }
}

// - display a preview of th editor.
#Preview("Editor View") {
	EditorView()
		.environmentObject(RRoutedDocument())
}
