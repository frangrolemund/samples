//
//  IndexImportView+Button.swift
//  MetDesigner
// 
//  Created on 1/27/24
//  Copyright © 2024 Francis Grolemund.  All rights reserved. 
//

import SwiftUI

/*
 *  A stylized, large button used to trigger index import processing.
 */
struct ImportButton : View {
	private let isSelected: Bool
	private let isEnabled: Bool
	
	/*
	 *  Initialize the object.
	 */
	init(isSelected: Bool = false, isEnabled: Bool = true, _ action: @escaping () -> Void) {
		self.isSelected = isSelected
		self.isEnabled  = isEnabled
		self.action 	= action
	}
	
	/*
	 *  The layout of the button.
	 */
	var body: some View {
		Button(action: action, label: {
			ImportButtonLabel(isSelected: isSelected, isEnabled: isEnabled)
		})
		.buttonStyle(.plain)
		.disabled(!isEnabled)
	}
	
	private let action: () -> Void
}

/*
 *  The button label is a combination of a centered image and stylized
 *  padding that scales to fit its enclosed container.
 */
fileprivate struct ImportButtonLabel : View {
	let isSelected: Bool
	let isEnabled: Bool
	
	/*
	 *  The layout of the label
	 */
	var body: some View {
		GeometryReader(content: { geometry in
			let minSide 	= min(geometry.size.width, geometry.size.height)
			let borderRect	= RoundedRectangle(cornerRadius: (minSide * 0.1).rounded())
			
			HStack {
				Spacer()
				VStack {
					Spacer()
					let oneSide = minSide * 0.4
					Image(systemName: "square.and.arrow.down.fill")
						.resizable()
						.scaledToFit()
						.frame(width: oneSide, height: oneSide)
						.foregroundStyle(Color.black.opacity(isEnabled ? 0.5 : 0.3))
					Spacer()
				}
				Spacer()
			}
			.background(content: {
				Color.black.opacity(isEnabled ? 0.05 : 0.1)
			})
			.overlay {
				borderRect
					.stroke(isSelected ? Color.accentColor : Color.secondary, lineWidth: isSelected ? 10.0 : 1.0).opacity(isSelected ? 0.5 : 1.0)
			}
			.clipShape(borderRect)			
		})
	}
}

#Preview {
	HStack {
		VStack(alignment: .center, content: {
			HStack(alignment: .center, content: {
				ImportButton {}
					.frame(width: 150, height: 150)
			})
		})
		.frame(width: 200, height: 300)

		VStack(alignment: .center, content: {
			HStack(alignment: .center, content: {
				ImportButton(isSelected: true) {}
					.frame(width: 150, height: 150)
			})
		})
		.frame(width: 200, height: 300)
		
		VStack(alignment: .center, content: {
			HStack(alignment: .center, content: {
				ImportButton(isEnabled: false) {}
					.frame(width: 150, height: 150)
			})
		})
		.frame(width: 200, height: 300)
	}
}
