//
//  ContentView.swift
//  MetMinded
// 
//  Created on 1/13/24
//  Copyright © 2024 Francis Grolemund.  All rights reserved. 
//

import SwiftUI
import MetModel

struct ContentView: View {
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Hello, world!")
        }
        .padding()
		.onAppear(perform: {
			MetModel.printSample()
		})
    }
}

#Preview {
    ContentView()
}
