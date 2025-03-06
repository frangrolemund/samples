//
//  ContentView.swift
//  Proto-1
// 
//  Created on 3/9/24
//  Copyright © 2024 RealProven, LLC.  All rights reserved. 
//

import SwiftUI

struct ContentView: View {
    var body: some View {
		GeometryReader(content: { geometry in
			ScrollView(.horizontal, showsIndicators: false, content: {
				HStack(spacing: 0) {
					// - separate implementations to support customization
					Page1()
						.frame(width: geometry.size.width)
					
					Page2()
						.frame(width: geometry.size.width)
					
					Page3()
						.frame(width: geometry.size.width)
					
					Page4()
						.frame(width: geometry.size.width)
					
					Page5()
						.frame(width: geometry.size.width)
					
					Page6()
						.frame(width: geometry.size.width)
					
					Page7()
						.frame(width: geometry.size.width)
					
					Page8()
						.frame(width: geometry.size.width)
					
					Page9()
						.frame(width: geometry.size.width)
					
					Page10()
						.frame(width: geometry.size.width)
				}
			})
			.background(.gray)
			.scrollTargetBehavior(.paging)
		})
		.ignoresSafeArea()
    }
}

protocol ProtoPage : View {
	init()
}

#Preview {
    ContentView()
}
