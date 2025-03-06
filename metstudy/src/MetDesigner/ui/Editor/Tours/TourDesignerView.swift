//
//  TourDesignerView.swift
//  MetDesigner
// 
//  Created on 1/31/24
//  Copyright © 2024 Francis Grolemund.  All rights reserved. 
//

import SwiftUI

/*
 *  Provides an interactive editor for designing virtual tours.
 */
struct TourDesignerView: View {
	@EnvironmentObject private var document: MetDesignerDocument
	@State private var hasAppeared: Bool = false
	
    var body: some View {
		Color.yellow
			.overlay {
				VStack {
					Spacer()
					Text("Tour Designer").font(.title3)
					Spacer()
				}
			}
			.onAppear(perform: {
				hasAppeared = true
			})
			.onSizeChange { size in
				document.userState.tourEditorHeight = size.height
			}
			.frame(height: hasAppeared ? nil : document.userState.tourEditorHeight)
    }
}

#Preview {
    TourDesignerView()
		.frame(width: 600, height: 500)
}
