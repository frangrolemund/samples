//
//  MDCircularProgressView.swift
//  MetDesigner
// 
//  Created on 3/2/24
//  Copyright © 2024 RealProven, LLC.  All rights reserved. 
//

import SwiftUI

/*
 *  A standard progress indicator.
 */
struct MDCircularProgressView: View {
    var body: some View {
		ProgressView()
			.progressViewStyle(.circular)
			.scaleEffect(0.5)
    }
}

#Preview {
	Group {
		MDCircularProgressView()
	}
	.frame(width: 100, height: 100)
}
