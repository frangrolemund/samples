// ****************************************************
// Variant-1:  simple execution as immediate processing
// - sequential programming
// - client connection with primitive UI
// - deployment lifecycle, RUNNING to PAUSED
// ****************************************************

// - every deployment is itself an unnamed system with an implicit scope
//   around all of the files in its root folder
// - system processing is inherently independent from one another and will 
//   always operate _concurrently_ within the deployment
// - all of the code in a system outside of function declarations is
//   described as 'immediate processing', referring to its behavior to execute 
//   right after initialization of static/instance properties and optional 
//   init() instance invocation
// - system methods may not be executed externally until immedate processing
//   completes

// - declaring this static indicates it is persisted with the system
// - all system properties, both static and instance are used with transactional
//   guarantees
static var messages: [string]


<**** create database/table in basis during deployment
<**** server core #1 w/database interface


// - the standard system, `unum` provides a set of core services for 
//   integrating with the basis in a relatively flat hierarchy that are
//   always available and do not need to be imported before use.
// - a Terminal provides a textual grid-based interface for a user with
//   keyboard and mouse input.

// ...all systems support default initialization unless they only have a
//    parameterized init() method.
// ...there is no default Terminal for convenenience because unum deployments
//    are inherently distributed and single-use scenarios (like this) are
//    the exception, not the rule
const term = unum.Terminal.accept()


<**** server core #1 requires Terminal.accept, which communicates with basis
<**** Invoke accept()
<****   - socket(), bind(), listen(), accept()
<**** parse rudimentary HTTP 1.1 inbound request
<**** clearly invalid client, disconnect
<**** malformed request, return http status 400 (bad request)
<**** good request, parse it fully, retain the socket, package the combination
<**** create core #2 (client) and insert it into graph, retain socket w/core
<****	core #2 exists in same kernel as core #1
<**** instantiate Terminal, save request context to core #2, return into core #1


// - first re-print the persisted messages after a restart
for m in messages {
	term.print(m)
}


<**** core #2 safely gets array from database (concurrent with core #1)
<**** core #2 loops, sending print to terminal
<**** terminal formats items as custom html


// - get information on the user
term.print("what is your name?\n")


<**** core #2 terminal formats item as custom html


var name = term.getline()


<**** core #2 terminal creates html form with input and button
<**** terminal sends response to client
<**** terminal waits for POST reply from client
<**** if disconnect, malformed, etc, pause the system
<**** if ok, translate post back into method return


term.print("message: ")


<**** core #2 terminal formats item as custom html


var msg = term.getline()


<**** core #2 terminal creates html form with input and button
<**** terminal sends response to client
<**** if disconnect, malformed, etc, pause the system
<**** if ok, translate post back into method return


// - appending the messages saves it persistently
messages.append(name + " > " + msg)


<**** core #2 transfers msg to core #1
<**** core #1 starts transaction, saves data, completes transaction
<**** core #1 pauses current system 


// *************************
// - upon reaching this point, the deployment is PAUSED because it completed
//   immedate processing and may only be restarted, in which case the session 
//   will be discarded and a different connection may be initiated.

// - a deployment in a PAUSED state retains all of its operating data for
//   examination through the interface to the basis (CLI)

// - there is no concept of a deployment being EXITED in unum because a system 
//   that does not exist is simply discarded along with its resources.  The 
//   deployment is never auto-discarded because it may have important persisted
//   data that would be lost if it were.  Furthermore there's not a clear 
//   notion of what it would mean to _exit_ a distributed system made up of one
//   server and three clients.  Would it mean all four exit their related 
//   processes, or just the server?

// - a restart discards any transient data and resources (connections)

