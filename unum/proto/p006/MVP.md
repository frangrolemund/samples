MVP Requirements and Scope
--------------------------
GOAL: To show the end-to-end pipeline and core concepts of basis, language and
      deployment for a two-tier browser application.

# Technical Requirements
- non-interactive `unum` command
- basis creation
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
## Keywords 
- static
- var
- string
- while
- true
- for
- in
- this

## Reserved
- unum (as standard library system)
- init
- main

## Syntax
- variables (transient, persistent)
- expressions
- looping (while, for)
- standard library
- system composition
- system methods

## Standard System - unum
- unum.io --> the instance of unum.IOGrid
- unum.io.id --> unique id for the IOGrid, which is equivalent to user session
- unum.io.getline -> read a string until return is tapped
- unum.io.print -> print formatted text, doesn't auto-add newline
