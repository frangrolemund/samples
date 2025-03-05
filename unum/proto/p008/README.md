## Objective - Development pipeline to emit a lot message.
Behavior: bootstrap a highly-efficient systemic development pipeline with a 
C compiler to emit a log message to a central log.

## Environment
The unum experience provides the highest degree of runtime certainty by 
including everything for a deployment in a monorepo, including the full source
of the kernel, the standard system, main system, configuration and optionally 
runtime data.  It is specifically because everything is co-located that it 
can guarantee future freedom and aspirational performance.

In return for simplified systemic development, you must accept responsibility
for the code 'the whole way down' by providing and maintaining minimal, 
low-level tooling for your repo.  If you don't modify the kernel, the experience
after first build will be much like `git` with it managing the compilation from
there onwards.

The server is developed locally after bootstrapping with a C compiler that 
continues to be used to iterate on the codebase using hand-edited and 
transpiled code.

There are three categories of code:
1.  kernel (language, basis, networking)
2.  standard system (unum source and native integrations)
3.  main system (unum source)

### Assumes tooling:
- GNU make
- C compiler

## Processes
### Variant-1: kernel source clone (maintainer/custom dev) 
terminal-A: git clone git@github.com:frangrolemund/unum.git
terminal-A: cd unum
terminal-A: make
terminal-A: | <compile output>
terminal-A: | unum is bootstrapped 
terminal-A: | unum kernel is installed as trampoline in /usr/bin
terminal-A: <edit main.un>
terminal-A: ./.unum/bin/unum add main.un
terminal-A: ./.unum/bin/unum status
terminal-A: | 1 file added, no errors
terminal-A: ./.unum/bin/unum unum deploy
terminal-A: | 1 file has been deployed as 'main' as c53050c...
terminal-A: ./.unum/bin/unum start
terminal-A: | +0.0s deployment c53050c... is RUNNING
terminal-A: | +0.0s Hello World
terminal-A: | +0.0s deployment c53050c... is PAUSED

### Variant-2: kernel source clone (maintainer/custom dev) w/install
terminal-A: git clone git@github.com:frangrolemund/unum.git
terminal-A: cd unum
terminal-A: make install-unum-only
terminal-A: | <compile output>
terminal-A: | unum is bootstrapped 
terminal-A: | unum kernel is installed as trampoline in /usr/bin
terminal-A: <edit main.un>
terminal-A: unum add main.un
terminal-A: unum status
terminal-A: | 1 file added, no errors
terminal-A: unum deploy
terminal-A: | 1 file has been deployed as 'main' as c53050c...
terminal-A: unum start
terminal-A: | +0.0s deployment c53050c... is RUNNING
terminal-A: | +0.0s Hello World
terminal-A: | +0.0s deployment c53050c... is PAUSED

#### Variant-2 details:
- the repo has all kernel code and configuration under a sub-directory called
.unum to obscure it from view.  only a makefile exists by default. 
	- general development on the kernel is done in an IDE as a rule to
	efficiently create modules and write tests for them.
- the repo has a default .gitignore that doesn't include the environment or
bin directory
- the act of running 'make' 
	- creates a simple tool that will generate the platform header
	- generates a platform header file with the CC/LD pulled from the
	make environment
	- builds the default deployment
	- transpiles, builds and deploys anything in the root from the kernel
		- there should be checks that the kernel matches the tree 
		where it was built
	- if the built unum executable is installed centrally (trampoline mode),
	it can be used from the path, but will seek out the basis and 
	optionally run the preferred variant from there - it will exec the 
	basis specific version rather than use its own understanding.
		- the executable should be able to quickly determine if it
		is running in trampoline mode, perhaps missing some supporting
		file near the binary when running inside a basis.  when in
		trampoline mode, it must dramatically scale down its allowed
		operations and only invoke other unum executables.
- deployment quietly transpiles the source into C and uses the compiler used
for bootstrapping to generate a shared library for the deployment which can
be hot-swapped into the kernel
	- the user can choose to keep running 'make' instead of using the
	unum command if it just involves minor changes to existing files


## Use Cases
0.  Coordinated development between two devs using the same repo. 
1.  Clone repo with no deployment code and make, producing kernel.
2.  Run kernel from outside basis (trampoline), it finds basis kernel by 
seeking in the path hierarchy and re-executes that automatically.
3.  Modify repo code in kernel and make, re-building kernel.
4.  Clone repo with main system code and configuration and make, producing 
kernel then auto-deploying
5.  Modify main system and make, auto-deploying
6.  Modify main system and run `unum deploy`

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

### <trampoline> - execute the active unum kernel in the current tree
- enters trampoline mode if the binary detects it is not running inside the
basis.
- trampoline mode moves up the source tree to look for the `./.unum` 
sub-directory that establishes the basis and then looks for the kernel there.
- if the basis is found and a kernel is built, it re-executes that kernel with
the same command-line arguments and environment
- if no basis is found in the the tree, it exits with a value of 1 and prints
the following as series of breadcrumbs to help trampoline debugging:
	unum: could not find /Users/fran/work/concepts/.unum
	unum: could not integrate /Users/fran/work/.unum
	unum: could not find /Users/fran/.unum
	unum: could not find /Users/.unum
	unum: could not find /.unum
	unum: no basis, not a valid unum source tree

### add - add source files to a deployment
- the add command identifies source files that are to be included in a pending
deployment
- it is likely that the standard system will be automatically added during
the bootstrapping process
- source files (*.un) not explicitly added are not considered by the deployment
processing.
- if no basis is found in the tree it exits with a value of 1 and prints:
	unum: no basis, not a valid unum source tree 
- if the filename is invalid, it exits with a value of 1 and prints:
	unum: file not found, 'baz.un'

### status - displays the pending modifications that will be deployed
- status provides a mechanism (much like git) to display the pending changes
that will be deployed.  it shows the list of files, configuration changes and
constraints that are different than the active ones
- there are probably two forms of this command, the default is to just enumerate
counts of files changed, configuration modifications, and constraints where
a verbose variant will list them more specifically.
- if no basis is found in the tree it exits with a value of 1 and prints:
	unum: no basis, not a valid unum source tree 
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
replace the main system with new processing.  systematic in the sense that
nothing in the core system occurs automatically by default (probably can be
overridden during development), and requires something to make a value judgement
about the current state since code is often highly-interrelated.
- if no basis is found in the tree it exits with a value of 1 and prints:
	unum: no basis, not a valid unum source tree 
- deployment includes _all of_ the code, configurations, and constraints of
the current deployment, which is the directory tree under the current basis.  
if the basis isn't in the current directory, the basis will be located by 
moving up the tree.  
- deployment is by default a 'debug' build, but can be invoked with an 
'--optimized' flag that forces a production build.

### start
- start begins active processing of the local, active deployment using the 
configured basis to determine resource allocations
- if no basis is found in the tree it exits with a value of 1 and prints:
	unum: no basis, not a valid unum source tree 
- if the deployment is non-functional because there is no code or other error
occurs, it will exit with a value of 1 and print a contextual error:
	unum: no deployment found
- the command will block for its duration and print deployment logging 
statements to the console prefixed with an uptime value formatted like 
'+####[smhd]'

## Standard System
- `unum`, which is reserved and may not be used
- unum.log.print
	- instance method in log sub-system of `unum` that takes a single
	string by default and sends it to the deployment (systemic) log

## Notes
	- the fundamental principle of operation is that 'All errors of 
	linkage are hidden from system code and addressed entirely in the 
	kernels and the basis.`  It follows that we should see the kernels
	*block* system operation until errors are resolved.	

	- systems are inherently concurrent, which allows for designs that
	could block progress on linkage issues without impacting general system
	operation.  this produces at least equivalent availability guarantees
	to existing mechanisms (clusters, microservices), but likely much 
	greater because it allows for greater segmentation.

	- source files are suffixed with '.un'

	- a deployment is not 'running' until it is deployed at least once

	- there is no requirement for 'importing' or 'including' references - 
	all external systems are automatically available and global in a 
	deployment.  The 'unum' system is always present and may not be removed.
		- there are no restrictions for hierarchical references to
		parent or peer systems - a subsystem may public systems in _any_
		other system in the deployment

	- the standard system 'unum' provides a hierarchy of abstractions from
	general to specific with opinionated default behaviors that may be
	overridden, resulting in potentionally new and customized linkage to
	accommodate for new requirements.

	- the inclusion of 'add', 'status' and 'deploy' make this into a 
	simpler version of a VCS, that echoes the behavior of 'git.  The dev is
	encouraged to use 'git' or similar in addition for granular control of
	source behavior, but is not required - certainly in simpler scenarios.
	Unum must be able to keep track of changes, be clear about deployment 
	and offer a way to undo when desired.

	- integration into the basis occurs with native C code.  To perform
	this translation in `unum` code, a `native` keyword will be allowed
	in front of variables and functions/methods (probably systems also) to 
	indicate that they are implemented in that way.  Functions prefixed 
	with a `native' keyword may not have a body and variables prefixed with
	it may not have an initializer.  The build pipeline will auto-generate 
	a file (*.c) next to the associated source (*.un) with the same name and
	_maintain it_ in the sense that it will get augmented automatically
	when signatures change.
