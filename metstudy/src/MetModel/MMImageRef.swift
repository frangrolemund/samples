//
//  MMImageRef.swift
//  MetModel
// 
//  Created on 2/29/24
//  Copyright © 2024 RealProven, LLC.  All rights reserved. 
//

import Foundation

#if os(macOS)
	import AppKit
#elseif os(iOS)
	import UIKit
#endif

///  A platform-specific image reference.
public struct MMImageRef {
	var size: CGSize {
		#if os(macOS)
			return CGSize(width: self.imageRef.size.width, height: self.imageRef.size.height)
		#else
			return .zero
		#endif
	}
	
	/// The UI image reference.
	#if os(macOS)
	public let imageRef: NSImage
	#endif
	
	/// The raw file data associated with the image, if available.
	public let data: Data?
}

extension MMImageRef {
	/*
	 *  Attempt to load an image reference from its data.
	 */
	static func fromData(_ data: Data, withFileData: Bool = false) async -> MMImageRef? {
		await Task(priority: .background) {
			#if os(macOS)
				if let img = NSImage(data: data) {
					return .init(imageRef: img, data: withFileData ? data : nil)
				}
			#endif

			// - no conversion was possible.
			return nil
		}.value
	}
}
