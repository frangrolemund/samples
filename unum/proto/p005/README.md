## Objective - Grafitti Wall
Behavior: list of messages shared by many web consumers.

General-purpose code for a traditional multi-platform solution with:
- database
- server w/APIs
- web app that maintains the data
- single client at a time

Implement this in a source file to distill the smallest possible thing.

## Process
	- console-a: `unum init`
	- console-a: `unum deploy --tail`
	- console-b: `vi grafitti.un`
	- console-b: <write code>
	- console-a: <displays delayed errors of compilation>
	- console-a: <displays questions that must be answered>

## Notes
	- the `unum init` can optionally have a system name, but doesn't need 
	it and be called `default` and will be all that exists in the directory
  	and below it.  

	- unum commands maintain an '.unum' sub-directory that acts as
	the configuration and runtime for the system repository.  logs,
	statistics, answers, databases and so on are all stored in this 
	sub-directory. 

	- `unum deploy` with no parameters means to _deploy the code in the 
	local system repository (from current directory up until we find 
	'.unum') to the local system that was named during init_.

	- `unum deploy --tail` means to _watch the local system repository
	for changes and auto-deploy to the local system_.

