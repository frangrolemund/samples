MVP Requirements and Scope
--------------------------
GOAL: To show the end-to-end pipeline and core concepts of basis, language and
      deployment for a two-tier browser application.

# Technical Requirements
- non-interactive `unum` command
- basis creation
- compilation, linking
- nodes
- HTTP server
- HTML generation
- unum language compilation (rudimentary)
- local file storage in the basis for static data (see 9/21)
- system instantiation, transactional behavior
- ingress integration
- command help
- automated testing for all CLI and browser interactions
- arrays

## NON-Requirements (DEFERRED)
- interactive unum shell
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

# Language
## tokens
  static
  var
  string
  []
  ()
  {}
  "
  .
  +
  =
  ==
  <
  ;
  :
  &
  system
  public
  while
  true
  false
  for
  in
  this
  init
  break

## types
- array
	- append() method
	- iterable behavior

## Reserved
- unum (as standard library system)
- this.pause(reason: string) - ??

## Syntax
- variables (transient, persistent)
- expressions
- looping (while, for)
- standard library
- system composition
- system methods

## Standard System - unum
- unum.Terminal
	- system declaration for a client terminal instance
- unum.Terminal.id
	- constant property on a terminal indicating a unique identifier for
	the terminal session
- unum.Terminal.accept()
	- static method to instantiate a Terminal instance and accept a
	client connection
	- instance method to accept on an existing Terminal instance
- unum.Terminal.print()
	- instance method to print text to a terminal
- unum.Terminal.getline()
	- instance method to retrieve a string of text from a client terminal
- unum.Terminal.pauseOnDisconnect
	- instance property controlling whether the Terminal will pause itself
	when the client disconnects
- unum.Terminal.isConnected
	- instance property indicating whether the client is connected
- unum.Log
	- system declaration for a logger instance - likely possible to create
	multiple loggers so that they can be compartmentalized and viewed
	independently if desired
- unum.log
	- static property of the default logger (unum.Log) instance
- unum.Log.info()
	- instance method to write a line of informational text to the log
-  
