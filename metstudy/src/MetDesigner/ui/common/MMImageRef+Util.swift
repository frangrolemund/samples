//
//  MMImageRef+Util.swift
//  MetDesigner
// 
//  Created on 2/29/24
//  Copyright © 2024 RealProven, LLC.  All rights reserved. 
//

import Foundation
import MetModel
import SwiftUI

/*
 *  Utilities.
 */
extension MMImageRef {
	var asImage: Image { Image(nsImage: self.imageRef) }
}
