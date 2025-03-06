//
//  Bundle+Util.swift
//  MetModel
// 
//  Created on 1/30/24
//  Copyright © 2024 Francis Grolemund.  All rights reserved. 
//

import Foundation

/*
 *  Utilities
 */
extension Bundle {
	static var metModel: Bundle { MetModelBundle }
}

// - compute this once since there are a ton of frameworks in a real app.
fileprivate let MetModelBundle: Bundle = {
	return Bundle.allFrameworks.first(where: {$0.bundleIdentifier == "com.realproven.MetModel"}) ?? Bundle.main
}()
