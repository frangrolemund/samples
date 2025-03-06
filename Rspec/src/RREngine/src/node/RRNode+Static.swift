//
//  RRNode+Static.swift
//  RREngine
// 
//  Created on 11/23/23
//  Copyright © 2023 RealProven, LLC.  All rights reserved. 
//

import Foundation

/*
 *  A static node exposes only configuration and state, but performs no processing of its own.
 *  DESIGN: This would appear to be a contradition in terms with the definition of a node, but
 *  		I have a suspicion that there are some very specialized scenarios where we need
 * 			it to exist in context other nodes, but has little to no processing to perform.
 */
@MainActor
protocol RRStaticNodeInternal : RRStaticDynamoInternal where Config: RRNodeConfigurable {}
