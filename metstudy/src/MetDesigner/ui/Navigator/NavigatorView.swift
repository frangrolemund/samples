//
//  NavigatorView.swift
//  MetDesigner
// 
//  Created on 1/31/24
//  Copyright © 2024 Francis Grolemund.  All rights reserved. 
//

import SwiftUI

/*
 *  The navigator displays the hierarchical structure of the
 *  document elements.
 */
struct NavigatorView: View {
	@EnvironmentObject private var document: MetDesignerDocument
	@State private var hasAppeared: Bool = false
	
    var body: some View {
		Color.green
			.overlay {
				VStack {
					Spacer()
					Text("Navigator").font(.title3).foregroundStyle(.white)
					Spacer()
				}
			}
			.onAppear(perform: {
				hasAppeared = true
			})
			.onSizeChange { size in
				document.userState.navigatorWidth = size.width
			}
			.frame(width: hasAppeared ? nil : document.userState.navigatorWidth)
    }
}

#Preview {
    NavigatorView()
		.frame(width: 200, height: 500)
}
