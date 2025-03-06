//
//  Subdivider.swift
//  RRouted
// 
//  Created on 11/27/23
//  Copyright © 2023 RealProven, LLC.  All rights reserved. 
//

import SwiftUI

/*
 *  A divider used to separate sub-items in a larger list with domininant dividers.
 */
struct Subdivider: View {
    var body: some View {
		Divider().padding(.init(top: 5, leading: 20, bottom: 5, trailing: 20))
    }
}

#Preview {
    Subdivider()
}
