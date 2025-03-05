MVP Requirements and Scope
--------------------------
GOAL: To show the end-to-end pipeline and core concepts of basis, language and
      deployment to display a single log message

# Technical Requirements
- non-interactive `unum` command
- trampoline
- basis creation
- compilation, linking
- nodes
- unum language compilation (rudimentary)
- command help
- automated testing for compiler
- automated testing for CLI interactions

## NON-Requirements (DEFERRED)
- HTTP server
- HTML generation
- ingress integration
- interactive unum shell
- arrays
- CSS
- JavaScript
- database integration
- TLS
- WebSocket
- ingress via CLI
- basis via CLI
- deployment history via CLI
- back-end distributed
- language: interfaces, alias, non-string, system defn
- system instantiation, transactional behavior
- local file storage in the basis for static data (see 9/21)

# Language
## tokens
  system
  public
  func
  native		--> (assumes auto-gen of integration?)
  static
  const
  string
  {}
  ()
  "
  .
  //
  /*
  */

## types
- unum

## Reserved
- unum (as standard library system)

## Syntax
- function calling
- strings
- anonymous systems
- system folders
- expressions
- standard system
- system composition
- system methods

## Standard System - unum
- unum.log.print()
	- emit a simple string to the deployment log

# Tasks
1. Basic repo creation w/README, MANIFESTO
2. Makefile --> config tool --> config.h
3. Basis source organization.
4. Xcode project
5. Stub kernel in basis w/stub commands and help
6. Trampoline determination and invocation.
