//
//  RRoutedApp.swift
//  Realrouted
// 
//  Created on 7/6/23
//  Copyright © 2023 RealProven, LLC.  All rights reserved. 
//

import AppKit
import SwiftUI

@main
struct RRoutedApp: App {
    var body: some Scene {
		let screenFrame    = NSScreen.main?.frame ?? .init(x: 0, y: 0, width: 1440, height: 900)
		let width 		   = (screenFrame.width * 0.6).rounded()
		let height		   = min((width / (16.0 / 9.0)).rounded(), (screenFrame.height * 0.7).rounded())
		let winSize:CGSize = .init(width: width, height: height)
		
		DocumentGroup(newDocument: { RRoutedDocument() }) { configuration in
			MainWindowView()
		}
		.defaultPosition(.center)
		.defaultSize(winSize)
    }
}
