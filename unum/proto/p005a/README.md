## Objective - Grafitti Wall
Behavior: list of messages shared by many web consumers.

General-purpose code for a traditional multi-platform solution with:
- database
- web app that maintains the data
- multi-client sessions

Implement this in a source file to distill the smallest possible thing.


## Processes
### Variant-1 (shell)
terminal-A: mkdir grafitti && cd ./grafitti
terminal-A: unum
terminal-A: | unum version 0.01
terminal-A: | no basis found.
terminal-A: | type 'init' to get started
terminal-A: | type 'help for available commands
terminal-A: unum:paused > init
terminal-A: | the basis has been created in .unum

terminal-B: *edit wall.un*

terminal-A: unum:paused > deploy
terminal-A: | 1 file has been deployed as `default` 
terminal-A: | the system is started as http://localhost:8090
terminal-A: unum:running> 

### Variant-2 (non-interactive)
terminal-A: mkdir grafitti && cd ./grafitti
terminal-A: unum init
terminal-A: | the basis has been created in .unum
terminal-A: *edit wall.un*
terminal-A: unum status
terminal-A: | 1 file modified 
terminal-A: unum deploy
terminal-A: | 1 file has been deployed as `default` 
terminal-A: unum start
terminal-A: | +0.0s  the system is started as http://localhost:8090
terminal-A: | +4.32s [client c9a4...] connected to http://localhost:8090/


## Sub-commands
NOTE: All of these commands operate upon a basis which retains two categories 
of content in it.  These are (a) pending and (b) active.  Active content is
only that content which has been deployed.  A deployment without active content
is PAUSED.  Making any change to the configuration of the basis or the source 
code in the tree associated with the basis is pending.  When data and analytics
are applied as mandated by a systemic system, that content is also _pending_,
but requires an additional step of generating constraints dervied from it 
before it can be used for deployment.  Active content is maintained in a
historical list by date and designation of which of the active items is 
'current'.  By default, deployment will append a new active set to the history
and make it current, but prior active deployments may be made current at any
time.

### init - create a unum deployment rooted in the current directory
- initialization is *required* before all other commands because it creates the 
basis of a deployment - the hardware and platform resources used by a deployed 
unum system
- creates an unum basis in a sub-directory called .unum in the current 
directory if it doesn't exist
- if it does exist, it exits with a value of 1 and prints:
	unum: already initialized
- creates .unum/manifest which includes a unique identifier for the system and
its name, which is 'default' by default.  the unique identifier is a uuid.

### status - displays the pending modifications that will be deployed
- status provides a mechanism (much like git) to display the pending changes
that will be deployed.  it shows the list of files, configuration changes and
constraints that are different than the active ones
- there are probably two forms of this command, the default is to just enumerate
counts of files changed, configuration modifications, and constraints where
a verbose variant will list them more specifically.
- if no basis is found in the tree (ie. not initialized) it exits with a value
of 1 and prints:
	unum: not initialized
- the default behavior is to show a briefest output possible of modifications
depending on how many there are.  Some examples:
	| no changes
	| 1 file modified
	| 3 files modified
	| 1 file, 2 configurations modified
	| 4 files, 1 configuration, 4 constraints modified
	| 2 constraints modified

### deploy - compile and link all code and constraints into a running system 
- deployment *must* support a systematic choice on the part of an engineer to
replace the default system with new processing.  systematic in the sense that
nothing in the core system occurs automatically by default (probably can be
overridden during development), and requires something to make a value judgement
about the current state.
- if no basis is found in the tree (ie. not initialized) it exits with a value
of 1 and prints:
	unum: not initialized
- deployment includes _all of_ the code, configurations, and constraints of
the current deployment, which is the directory tree under the current basis.  
if the basis isn't in the current directory, the basis will be located by 
moving up the tree.  
- deployment creates a persistent history record of the deployed content within
the basis

### start
- start begins active processing of a local deployment using the configured
basis to determine resource allocations
- if no basis is found in the tree (ie. not initialized) it exits with a value
of 1 and prints:
	unum: not initialized
- if no deployment was ever created in the tree it exits with a value of 1 and 
prints:
	unum: no deployment
- if the deployment is non-functional because there is no code or an error
occurs (like the port is unavailable), it will exit with a value of 1 and 
print a contextual error:
	unum: the http port 8090 is in use
- the command will block for its duration and print logging statements to the
console prefixed with an uptime value formatted like '+####[smhd]'
- when the command begins successfully it will export an http server from 
a default port of 8090 and print the following log message:
	'the system is started as http://localhost:8090'
- when a client attaches to the server via a web browser, it will assign the
client a unique id and print the following log message:
	'[client c9a4...] connected to http://localhost:8090/'


## Standard System
- 'unum', which is reserved and may not be used
- unum.IOGrid (see 9/17/24) as a basis for all user interaction
- unum.io --> the active user's console
- unum.io.id --> unique grid identifier
	- referencing the id by itself, allow a single client connection to
	be formed and a session allocated to it without beginning any 
	UI interaction.  Upon completion of generating the id, the service
	knows about the client and can make decisions about how to support it,
	but will not proceed until further io commences, allowing custom UI
	to be directed by the deployment code as opposed to assuming what it
	is.
	- for the main grid, it represents the _user session_ and for as long
	as that session exists, that identifier will exist
- unum.io.print --> print text to the grid 
	- understands standard escape codes, ie '\n', '\t', '\r', etc.
	- supports expression escapes '\(expr)', which will replace content
	in the string with an alternate value
- unum.io.getline --> read a line until return is tapped.

## Notes
	- initial design on 09/11/24

	- source files are suffixed with '.un'

	- The `unum` command operates as a _shell_ by default when executed
	with no parameters, much like Python.  Calling it in this manner
	is described as _entering the deployment_ and provides interactive
	access to system operation

		- however, all shell commands are also available as sub-commands
		that are executed non-interactively

	- I imagine a programming abstraction of a deployment when the CLI
	starts that is initialized with the current directory and has methods
	on it.  if an .unum basis exists, then it can be loaded automatically
	otherwise, the only usable method is an 'init' to create one.  creating
	such an abstraction could allow the UI of the CLI to be built for
	different scenarios depending on preference: simple CLI, termios style
	comprehensive terminal or even GUI framework UI.

	- the `init` command creates a basis for an unum deployment in a 
	directory, and stores all of its configuration and state in a '.unum' 
	sub-directory there.

	- a deployment is not 'running' until it is deployed at least once

	- there is no requirement for 'importing' or 'including' references - 
	all external systems are automatically available and global in a 
	deployment.  The 'unum' system is always present and may not be removed.	
	- timelines begin with the 'main' timeline created when a deployment
	is first moved to running.  each timeline is analogous to a process, 
	that steps through instructions that may block for indeterminate 
	periods of time, much like a breakpoint.  when a timeline is branched
	to support a different path (ie from a new user) then it acquires an
	exact copy of its initiator.  all state in the timeline is persisted
	as long as the timeline exists, which for a 'session' could be 
	as long as the browser is open.

	- the standard system 'unum' provides a hierarchy of abstractions from
	general to specific with opinionated default behaviors that may be
	overridden, resulting in potentionally new and customized linkage to
	accommodate for new requirements.

	- the use of 'status' and 'deploy' make this into a simpler version of
	a VCS.  The dev is encouraged to use 'git' or similar in addition but
	is not required to do so and can bridge the gap between no VCS in many
	SaaS solutions and the needs of giant 'git' monorepos.  We need to
	be able to keep track of changes, be clear about deployment and offer
	a way to undo when desired.
