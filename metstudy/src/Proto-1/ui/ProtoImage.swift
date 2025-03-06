//
//  ProtoImage.swift
//  Proto-1
// 
//  Created on 3/10/24
//  Copyright © 2024 RealProven, LLC.  All rights reserved. 
//

import SwiftUI

struct ProtoImage: View {
	let img: ImageResource
	let insetBy: CGSize
	
	init(_ img: ImageResource, insetBy insetSize: CGSize = .zero) {
		self.img 	 = img
		self.insetBy = insetSize
	}
	
    var body: some View {
		GeometryReader(content: { geometry in
			Color.clear
				.overlay {
					Image(img)
						.resizable()
						.aspectRatio(contentMode: .fit)
						.frame(width: geometry.size.width - insetBy.width, height: geometry.size.height - insetBy.height)
				}
				.clipped()
		})
    }
}

#Preview {
	ProtoImage(.advertisementforNorwichStoneWareFactory39)
}
