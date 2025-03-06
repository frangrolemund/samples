//
//  Page1.swift
//  Proto-1
// 
//  Created on 3/10/24
//  Copyright © 2024 RealProven, LLC.  All rights reserved. 
//

import SwiftUI

struct Page1: ProtoPage {
    var body: some View {
		ProtoImage(.advertisementforNorwichStoneWareFactory39, insetBy: .init(width: -50, height: -50))
    }
}

#Preview {
    Page1()
		.ignoresSafeArea()
}
