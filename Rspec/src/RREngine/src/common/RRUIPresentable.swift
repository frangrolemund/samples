//
//  RRUIPresentable.swift
//  RREngine
// 
//  Created on 7/12/23
//  Copyright © 2023 RealProven, LLC.  All rights reserved. 
//

import Foundation

/// Formalizes the models that are represented and controlled by user interfaces.
///
/// Primarily as a convention for SwiftUI, the `RRUIPResentable` protocol intends
/// to standardize the capabilities of UI-compatible models.  As a general convention,
/// all such conforming instances of this protocol will include the `@MainActor` designation
/// again for the best clarity to the readers.
@MainActor
public protocol RRUIPresentable : ObservableObject {
	/// Identifies the type of preview that may be generated which is best implemented
	/// as an `enum` for multiple cases or `Void` if there is a single type of preview.
	associatedtype PreviewType
	
	///  Generates instances of conforming types for Xcode preview purposes.
	///
	///  Instead of the caller needing to figure out the process of building what are
	///  often complex relationships, the modeled type is responsible for building them
	///  to maintain a constistent data organization and style between development sessions.
	///
	///  - Parameter type: A designation that can control what type of preview to generate.
	///  - Returns: An instance of the conforming type that will always default to the same values described by the preview type.
	static func preview(ofPreviewType previewType: PreviewType?) -> Self
}

/*
 *  Default behavior.
 */
public extension RRUIPresentable {
	static func preview(ofPreviewType previewType: PreviewType? = nil) -> Self {
		return self.preview(ofPreviewType: previewType)
	}
}
