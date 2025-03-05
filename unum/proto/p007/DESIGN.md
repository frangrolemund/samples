DESIGN for MVP
--------------

Definitions
-----------
	- `package`: the compiled and validated code of the deployment into
	bytecode with identified external dependencies
	- `core`: basic unit of computation that may be conceputal (paused,
	kernel offline) or literal (running)
	- `channel`: an integration point from one core into the cornet
	- `cornet`: the interconnected graph of cores in the deployment
	- `image`: the binary definition of processing that has been 
	optimized (possibly transpiled) for a single core

General
-------
	- core lifecycles in the deployment are a fundamental activity, as is
	their 'generation' on demand to suit different purposes.

	- a core operates like a list of interfaces into the basis, which itself
	may include the hardware resources of a remote client platform.
		- the node IS NOT (probably) synonymous with a system and may
		(a) run an entire deployment, (b) run a single system, (c)
		run a single method within a system or even (d) only host a 
		single data element.

	- I think that the code should be compiled and linked into an
	intermidiate representation that is later possibly converted again into
	a node representation (as in when working in a browser)


HTTP
----
	- keep-alive HTTP connection as a session lifecycle indicator


Standard System
---------------
	- the way to access channels; the integration is a custom keyword or
	similar that cannot be used outside the standard system.  maybe it
	is an auto-declared `unum` static method with custom behavior.

	- implemented in unum lang


Bootstrapping MVP
-----------------
1.  Compile code into a package, resolve internal linkage and linkage with the 
standard system.  (compiler/deployment-linker is reusable library)
	a. Tokenize code
	b. Generate AST and check for syntax errors
	c. Validate internal linkage
	d. Standard system baseline
		i.    precompile standard system to determine channel reqs
		ii.   auto-generate code in kernel for all required channels
		iii.  compile kernel
		iv.   compile with standard system includes in path
	e. Generate package structure
2.  CLI baseline with commands, deployment
3.  Identify deployment core requirements.
4.  Generate image for deployment core.
5.  Load image into deployment core and enmerate channels.
6.  Define channels as callbacks in deployment core.
7.  Execute core.
8.  Basic HTTP networking
9.  Core cloning for client connection

