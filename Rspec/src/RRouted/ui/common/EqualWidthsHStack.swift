//
//  EqualWidthsHStack.swift
//  RRouted
// 
//  Created on 11/28/23
//  Copyright © 2023 RealProven, LLC.  All rights reserved. 
//

import Foundation
import SwiftUI

/*
 *  Compute equal widths of items in the stack, usually buttons.
 *  NOTE: Largely based on the _Composing custom layouts in SwiftUI_ sample.
 */
struct EqualWidthsHStack : Layout {
	/*
	 *  Compute the total size, which is equal to all the sub-views taking
	 *  on the maximum width of their group.
	 */
	func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
		guard !subviews.isEmpty else { return .zero }
		
		let maxSize    = maximumSubviewSize(subviews: subviews)
		let totalSpace = interSubviewSpacing(subviews: subviews).reduce(0) { $0 + $1 }
		let ret = CGSize(width: maxSize.width * CGFloat(subviews.count) + totalSpace, height: maxSize.height)
		return ret
	}
	
	/*
	 *  Place the subviews in the stack.
	 */
	func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
		let maxSize = maximumSubviewSize(subviews: subviews)
		let spacing = interSubviewSpacing(subviews: subviews)
		
		var offset: CGFloat = bounds.minX
		for i in 0..<subviews.count {
			let svSize = subviews[i].sizeThatFits(.unspecified)
			let pvs    = ProposedViewSize(width: maxSize.width, height: svSize.height)
			subviews[i].place(at: .init(x: offset, y: bounds.minY + (bounds.height - svSize.height) / 2), anchor: .topLeading, proposal: pvs)
			offset += (maxSize.width + spacing[i])
		}
	}
	
	/*
	 *  Compute the normalized size that will fully enclose any sub-view.
	 */
	private func maximumSubviewSize(subviews: Subviews) -> CGSize {
		guard !subviews.isEmpty else { return .zero }
		return subviews.reduce(CGSize.zero) { partialResult, sv in
			let svSize = sv.sizeThatFits(.unspecified)
			return .init(width: max(partialResult.width, svSize.width), height: max(partialResult.height, svSize.height))
		}
	}
	
	/*
	 *  Compute the space between each of the subviews in the list.
	 */
	private func interSubviewSpacing(subviews: Subviews) -> [CGFloat] {
		return subviews.indices.map { idx in
			return idx == (subviews.count - 1) ? 0 : subviews[idx].spacing.distance(to: subviews[idx + 1].spacing, along: .horizontal)
		}
	}
}
