# The Systemic Manifesto
By: F. Grolemund, 2024

## Overview

The greatest costs of modern software development are caused by the massive 
complexity of integrating heterogenous platforms.  Due to the benefits we get 
from centralizing, scaling, specializing or distributing information 
processing, we accept these costs.  The convenience of publishing to any device,
easily reaching millions of consumers, or guarding our intellectual property on
the other side of a wire has proven that the days of isolated, independent 
computing are quickly drawing to a close. 

This complexity of integration can be simplified to a term we don't discuss much
any more: **linkage**.  When computers were mostly disconnected, software 
development often required a combionation of both compiling and then _linking_ 
of software to other libraries on the same system to benefit from modularizing 
or sharing algorithms and common implementations.  This was so useful to 
development that the _linker_ was a dedicated tool used to compute and
guarantee the most efficient interaction between dependent codebases.

When the industry moved away from platform-specific binaries and towards Just In
Time (JIT) compilation or interpreted script, the idea of linkage was hidden 
from most workflows, even though it still existed.  Although binary code is 
generated on the fly or a script quickly starts and processes a file with 
regular expressions, something deep inside the toolchain connected the code from
one codebase to another.  Maybe it was from a main program and into the system 
libraries or it was between two components of a larger program.  In both cases 
the act of linking, now dynamically, allowed the different codepaths to 
coordinate.

The purpose of these early shifts was to simplify the process of dealing with
different computing platforms (Java) or operating system variants (Unix) by
generalizing on bytecode or a language like Perl.  In scenarios where costs were
high from duplicating effort, this move quickly allowed adopters to outpace 
their peers' performance.  As the Internet became an even more valuable 
destination for commerce and entertainment, these efficiencies paid higher and
higher dividends.

At this same time, the Internet introduced a new challenge into the problem
of linkage.  In classic software, linkage was all performed on a single
hardware platform and operating system, so even if that step were automated and
obscured, developers could rely on invariants like process isolation, fast
memory accesses, and most importantly - reliabily deterministic linkage.  When 
two functions are linked together in a single process, the operation of moving
the CPU's instruction pointer from one function to an instruction in another
_cannot fail_, which becomes an indepespensible invariant while writing 
software.  Although a function may return an error computed from is processing 
for any number of reasons, the _act of invoking another function call_ will 
never generate any error.  Conversely, that hasn't largely been the behavior on
the Internet even though many still operate as if it were.

The act of calling a remote function from one system to another over
networking can fail for a myriad of reasons.  It requires the two systems are
speaking the same dialects of network protocols, of which there are infinite 
variations.  It requires the two systems agree on how data will be sent and 
received with precise expectations about the sequence of each byte and type of 
information.  It requires there's a program on the other end that is listening 
and has the capacity to respond to a request.  It requires the electricity stays
on for _every computer between the first one, through all the routers and 
gateways and into the destination and back again_.  If any one of these 
requirements are not met, the function will fail.  If we imagine that moving 
the instruction pointer on a single CPU is one-dimensional linkage, and 
understanding the domain of inputs and outputs for a local function is 
two-dimensional, in the most optimistic imagining with Internet software, 
linkage became three-dimensional.  Even though developers are mostly taught to 
program using two-dimensional ideas about computing, many are surprised to 
learn that algorithms become exceptionally (and exponentially) harder to write 
when working in three dimensions.

During these last thirty years many attempts have been made to solve these new
problems of linkage with different forms of tooling, automation or 
infrastructure, offering some relief, but were overlooking the biggest problem.
The highest costs of linkage between platforms is a not technical one, but _a 
cognitive one_.  Although a number of companies successfully build distributed 
deployments of hundreds or thousands of connected platforms using all of the 
technologies, there is no escaping the cost of doing so.  Solutions must 
consider each runtime platform, toolchains, and concurrency solutions while 
employing one or more languages like HTML/CSS, JavaScript/Typescript, Python, 
Go, Swift or Java over mostly HTTPs/TLS protocols with custom data encodings in
REST, GraphQL, or others, while modeling data conistently across computing 
platforms and then storing it in relational databases with SQL or cloud 
filesystems in specalized ways.  When startups build their first products, 
founders must navigate all of these choices themselves, shifting their 
attention from one hop in the 'full stack' to another in the path to their data
and back-again.  When startups eventually succeed, their only choice is to 
specialize each of these responsibilities with specific people and teams.  This
can be summarized in two ways:

- quickly creating new, modern software requires literal understanding of 
_binary linkage_ between dozens of different technologies and programming 
platforms.  This usually guarantees that only the most capable developers who 
can juggle and rapidly shift between many different concepts can build 
companies or solve new problems.

- growing existing successful software requires conceptual understanding of the
linkage between dozens of different technologies, efficient specializations by 
many developers, while applying strong _organizational linkage_.  This usually 
guarantees that many successful startups never grow beyond moderate success for
lack of the necessary organization and the ones who do succeed have such 
economies of scale as to make competition impossible.

There is an opportunity for much of the world's software to move beyond these
costs of linkage by revisiting our assumptions about programming.


## Linkage Volume

In order to have a meaningful discussion about _linkage_, it is first useful 
to define it more clearly.  While there are many ways in which it has been used
historicially, within this context it will be described in the following ways:

- **linkage** is the transfer of execution from one codepath to another

	NOTE: the linkage of memory symbols (eg.  global variables) is not 
	considered here since it is minimally just a local memory access and in the
	worst case a specialization of execution transfer.

- **linkage outcome** refers to the results of linkage between two codepaths 
both in explicit results like a return value and implicit ones like 
internal/state being modified.

- **objective outcome** a linkage outcome that may be predicted and achieved

- **subjective outcome** a linkage outcome that cannot be predicted or was 
predicted and not achieved.

- **linkage scenario** the finite set of attributes that influence a single 
linkage outcome.

- **linkage vector** represents the all of the permutations of a attributes of 
one dimension of a specific linkage scenario

Consider a vector **I** drawn horizontally with its beginning at the orgin and
extending outward along the x-axis.  This vector represents the linkage 
dimension of _invocation_.  If you've ever written assembly language to call
a function, it most often involves pushing your arguments onto the CPU stack,
causing the instruction pointer to jump to the remote function and then popping
responses back when the instruction returns.  In a similar way we can think
about the invocation vector as the set of all possible ways in which a function
may be called.  If the function takes a single boolean value, then the vector 
would have two discrete steps along it, one for 'true' and one for 'false'.  If
the function takes a byte value, then the vector would have 256 steps along it 
for all possibilities from 0 to 255, and so on.  When there is more than one 
parameter, the vector takes on all the possible combinations of parameter, 
multiplying their permutations.  That means a boolean and a byte would have 
permutations like `true`:`0`, `false`:`0`, `true`:`1`, `false`:`1`, and so on.
This type of linkage is the simplest and most essential, but only requires 
understanding of how to invoke a remote path of execution.  We can think of this
as _one dimensional linkage_ because we are only considering the behavior of one
aspect of executing another function.

Now imagine a vector **B** drawn vertically with its beginning at the orgin and
extending upward along the y-axis.  This vector represents the linkage dimension
of _behavior_.   Permutations along this vector represent both the implicit 
side-effects of calling the function as well as the possible results returned 
from the function.  If it indirectly updates the `errno` variable from libC, 
its possible changes are permutations.  Similarly, if the function returns a 
boolean, there are two possible permutations of returning `true` or `false`.  
This vector expresses all the ways in which the function may produce outcomes 
both objective and subjective.

Just considering these two vectors, for any single example of linkage between 
codepaths, there is a line segment along **I** from `i:0 to L` representing all
the possible ways in which is can be invoked.  Likewise there is a line segment 
along **B** from `j:0 to M` representing all the possible behaviors from the 
invocation.  If you consider that at any point of intersection **(Ii,Bj)**, 
there is one possible invocation and one possible behavior representing one 
possible outcome, the two segments represent a co-dependent relationship of 
linkage that we can treat as _two-dimensional_ and begin to draw some 
conclusions about that relationship:

**i.** Each of the points of intersection are only _a possible outcome, not a 
guaranteed one_.  That is, we may understand that a hypothetial function which 
accepts a byte and returns `true` for a non-zero value _could_ return `true` 
for a zero value, although by code inspection or testing we can confirm it 
indeed does what it says it will.

**ii.** Because each of the points of intersection are only a possible outcome,
each implicitly has a probability that intersection may generate a outcome.  
Therefore as developers we would optimistically assign a high probability to the
function returning 'true' for non-zero and low probility to the function 
returning 'true' for zero values.

**iii.** Because each permutation along vectors is discrete, we can display the 
graph as a grid of squares representing co-dependent relationships at 
**(Ii, Bj)** and assign the area between them `(LxM)` as the working set of 
possible outcomes.

**iv.** If we treat the total number of grid squares with objective outcomes as
`O` and the total number of subjective ones as `S` it naturally means that:

	O+S = LxM

**v.** Because the linkage `(LxM)` area represents the set of all permutations 
of invocation and result, we can imagine that the predictability of linkage 
outcome and by extension its expectation of quality can be generalized to the 
percentage of objective outcomes.  This will be described as the quality `Q` of
the linkage such that:

	Q = O / LxM

Everyone who learns to program implicitly gains some degree of understanding of 
this two-dimensional mental model of linkage.  Mantras like minimizing the 
number of parameters to a function or limiting its implementation to no more 
than one page of code aim to reduce the theoretical area in both the **I** and 
**B** dimensions.  Because even just this space can be large and 
complicated-enough to consider, many developers assume these are the only 
dimensions of linkage.  As one might guess, that is where modern software can 
be impacted.

Now imagine a third vector **D** drawn with its beginning at the origin and
extending into the graph along the z-axis.  This vector represents the linkage
dimension of _distribution_.  Distribution refers to all the possible ways a
non-trivial invocation (ie. not a simple instruction pointer change) can be
influenced, including:

- hardware peripheral (eg. 3d accelerator card) differences in capability or 
availability between testing and production 

- multi-process failures where the other process couldn't be started, is 
deadlocked, couldn't get necessary IPC resources, etc.

- networking failures of all kinds caused by hardware or software on any of the
devices between the the caller and the callee.

- timing differences between local and remote and even between remote 
invocations depending on networking quality at any point in time

As the overview indicated this third dimension has been quietly and more
frequently added to modern software over the last thirty years so that we're 
increasingly not working with a linkage area but with a linkage _**volume**_!.
When the distributed vector is considered in a single scenario, it would 
produce a line segment **D** from `k:0 to N` and any one outcome described as 
**(Ii, Bj, Dk)** and part of a space that is `LxMxN` in size.  The negative 
impact on `Q` that we've all anecdotally noticed in recent years is caused by 
our means of interacting with that dimension.

Consider this linkage example in Go:

	emp, err := getEmployee(5)

...if the `getEmployee()` function is simply declared locally, then the 
parameter `5` is pushed on to the stack and the instruction pointer is moved to
a different location in memory before doing its work and returning.  In this
two dimensional linkage its outcomes would be two-dimensional in **LxM**.

...however if `getEmployee()` internally calls an IPC or HTTP API, then then
its linkage is unknowingly three-dimensional and its outcomes would be expressed
as **LxMxN**.  

The implied behavior of added dimension in much of our code isn't something we 
can often reason about.  The `Q` value is much lower because many outcomes 
become subjective.  If I'm writing code and want to test a client/server design,
how do I know all of the ways that processes or systems can fail between the 
two points?  How do I plan for a slower connection than I expected during 
development?  In the best case scenario I mitigate many of the common failures 
while accepting some unresolvable ones, but in the worst case as a new or
inexperienced developer don't even realize they are possible.

Something to also notice here is that traditional programming languages don't
sufficiently represent this dimension.  In the example above we might get back 
an error for a distributed failure like a timeout, but the syntax doesn't make 
this obvious.  Turing-based languages assume objective execution of the next
line of code (ie. it will definitely happen), but in a distributed algorithm, 
our code can fail to execute that next line for a seemingly unlimited number of
reasons out of our control.  Simply returning a network error as a different
code or throwing an exception ignores the much deeper question of 'what should
a conscientious developer do with it?'

One possible solution is to rethink software archictectures running in a
distributed space.  If we're usually going to conceptually write our software 
in a two-dimensional space, perhaps we can create tools to support that mindset.


## Systemic Programming

If we accept that the amount of complexity and unpredictability of modern 
software is proportional to low quality `Q` as defined by `O / MxNxL`, then 
simplicity and accuracy will be achieved by maximizing `Q` by reducing each of 
the three dimensions.  It is from this premise that the concept of _systemic 
programming_ can be introduced.

How many software developers today know how to write great assembly for both 
ARM and Intel architectures?  How many can manually optimize for instruction
pipelining or easily distill large codebases into smallest binary files by
hand?  Likely not many, but why?

The reason they don't is that most don't need to and haven't for a long time.  
Classic compilers and linkers continued to evolve over the last thirty years 
to successfully manage complexity for all but the most demanding scenarios.  One
could argue the **I** or **B** dimensions would have been much larger for many 
of us if not for the continued advancements in that layer of tooling.  Because 
of this we might imagine that the overall linkage volume of a solution is 
constant for a given problem space, but that the volume can be sub-divided 
either by code or tooling to manage it.

Many languages and tools appear to be optimizing for _invocation_ and 
_behavior_, but rarely for _distribution_.  Why is that?

One possible reason is that in our desire to quickly and efficiently build our
next products, we all continue to use the foundational components that have 
already been built.  Notably, 'reinventing the wheel' is often not encouraged 
and if I write some SQL for a popular database, it will be quicker to deliver
my work and I won't have to learn about or write b-trees for a custom file 
format.

Another reason is that the permutations of distribution change frequently after
the code is written, especially when working with network-distributed 
algorithms.  The presence of one compute node instead of two or a temporarily 
slow connection between a service and its database could change choices.  A
developer might run more concurrent load or batch requests differently and in 
most cases it feels easier to cross that bridge later as an 'ops' problem than 
to try to manage every eventuality in the code today.

Still another reason could be that current language tools were derived from 
others that didn't need to consider distribution when they were invented.
Although there is now an increased introduction of concurrency syntax into
languages now, which further focuses on _behavior_ and sometimes 
_distribution_, many of the underlying challenges of the distributed space are 
unresolved.

What would a linker look like that more actively considered the distributed
vector but also reduced invocation and behavioral dimensions?

* it would need to reconcile many different common integrations with supporting
systems like databases, other services, custom hardware, etc.

* it would need to quickly adapt to changes in platforms or network topology

* it would have to address most concurrency pitfalls

* it would need to operate more abstractly so that processing could adapt to 
new technologies without developers needing to dive deeply into and learn yet 
another technical layer in order to deliver the same fundamental algorithms

Because each of these features mandate that our hypothetical distributed linker
coordinate with processing abstractions while intimately understanding and
adapting its runtime behavior while also bridging between systems of 
programming, platform, and services, it is obvious we need to a different 
approach for developing complex software.  To that end, we'll refer to the 
philosophy of that approach as _systemic programming_.

Systemic programming is to the development of software in which algorithms and 
processing are organized into isolated domains called systems and combined 
hierarchically from subsystems, while the tooling automatically coordinates 
its deployment across all physical and often network-connected resources.  

In order to be systemic, a solution must provide:

* a single, abstract programming language that normalizes all processing into a
common syntax that clearly defines service boundaries and data movement

* a general-purpose kernel that is deployed to all coordinating physical 
platforms to provide security, versioning, compilation, deployment, execution, 
and integration with external systems

* comprehensive runtime anaylytics that provide an immediate feedback loop back 
into deployment to automatically coordinate the behavior of service kernels 
based on runtime activity and operating statistics


### Systemic - Language

Modern development rewards specialization and siloed engineering, often 
needlessly at the expense of the system.  Consider a very common three-tiered
application made up of a web page, service and database.  This application
might include the following languages:

	UI:       HTML, CSS, browser-based JavaScript/DOM

	Service:  back-end Javascript, cloud configuration

	Database: SQL, cloud configuration

...and requires knowledge like the following to apply them:

	UI:       declarative programming, cascading styling HTTP, REST API, 
              TLS, browser modeling, API concurrency

	Service:  HTTP, service concurrency, database integration, 
              virtualization and deployment, TLS configuration, load balancing

	Database: relational theory, data modeling, backup strategies

While it is possible one of the often highly sought 'full stack' devs as a
small company could manage all this, either sooner or later, this technology
begins to shift into specialized roles where there are at least three categories
of developer and often many more and the system matures:

	UI:        front-end and design

	Service:   back-end, dev-ops

	Database:  dba or dev-ops

As this occurs, the unseen costs of linkage both technically and 
organizationally begin to emerge as all of these groups must coordinate and
make changes for every change any of them makes.  Additionally when any of 
these roles leaves or joins the organization, there is an ongoing cost for
replacing or onboarding to not only ensure equivalent experience but to also
train them in the specialized workings of each silo.

Now compare that with an intentionally abstract, systemic language: 

... one syntax uniformly describes UI, processing and storage, eliminating
cognitive context switching betwen specialized technologies

... algorithms are the only required knowledge 

... organizational linkage is optional, especially between dev and ops

... new features can be built quickly and holistically 

... code is more durable, not requiring upgrades for new platform behavior
	
The secret is that similar to traditional programming where compilation is
optimized for a local machine and linkage was deferred until all of the local 
symbols are known, _systemic programming dynamically compiles itself for
distributed machines and defers linkage until all the distributed symbols *and
behaviors* are known_.  In order to manage the massive complexity of an
internetworked computing space, we need to apply the same techniques to the
meta-layer of our architectures.


### Systemic - Kernel 

Consider the example above of a simple 3-tiered design.  Each of the tiers is 
maintained independently, either by one or many people, but all must link with 
one another precisely to operate correctly.  This shift in development occurred
gradually but as architectures increased in complexity, it quietly added 
unexpected costs and unpredictability to software development.

For example, in the old manner of development with a single platform-specific
binary, when requirements changed, a developer wrote code and then 
compiled/linked it before executing it.

	coding  -->  compile  -->  link  -->  run
	   ^                     ^
	[manual]    [        automated           ]

With the introduction of distributed linkage in addition to internal, the 
link step is shifted into the coding phase and involves coordination with the 
other components, while compiling has been deprecated for many scenarios in 
favor of interpreted languages to try to regain some iteration efficiency:

	ui:              --> coding  -->  interpret -->  
	service:    link --> coding  -->  interpret -->  run
	database:        --> coding  -->  interpret --> 
	                   ^		          ^
	           [     manual    ]     [ automated ]
 
This sequence shows that not only did much of today's software require new 
manual steps of coordinating between technologies or platforms, but in
algorithmic notation, the cost of the manual work grows with `O(n)` where 
n equals the number of coordinating tiers/platforms:

To be more specific, the manual linking 'costs' mentioned here often include
the following tasks:

* marshalling data between one system and the other

* reaching a common understanding of the data model

* achieving the performance requirements for co-dependent operations

* ensuring secure access and user privacy

* translating and reconciling with different technical solutions

* understanding and mitigating distributed failure scenarios

* ensuring transactional updates to data

* deploying and/or scaling resources according to demand

* documenting all the linkage choices so that future modifications
	can consider and/or replace them

...these are all _recently acquired costs, independent of the actual logic of 
the system AND must be performed *every* time a new product requirement is 
implemented_!

With these in mind it is alarmingly more accurate to say that the costs of
manual development work grows with `O(n^2)` as the number of systems multiplied
by the number of manual link tasks that are performed!

It is no wonder that software is so much more expensive to build today while 
performing so poorly compared to legacy achievements.  It also explains the 
noticible drop in software quality coinciding with much of the new focus on 
distributed work.  How many iterations of software refinement can a team 
realistically perform with these taxes on each iteration?  Eliminating these 
taxes is the purpose of the 'kernel' in systemic programming.

The systemic kernel (or s-kernel) refers to a general-purpose platform in a 
systemic environment that _dynamically re-links software across a distributed 
space_.  Much like conventional 'dynamic linking' means to 'resolve symbolic 
code at runtime', 'systemic linking' means to 'resolve symbolic, distributed 
services at runtime'.  It operates with full understanding of the langauge and 
the constraints of its platforms to fully automate all of the tasks described 
above and automatically deploy/re-deploy based on changes to requirements in the
programming.  The s-kernel operates as a realtime linker for the entire product 
architecture.

While it might be easy to dismiss the s-kernel 'is just another form of CI/CD' 
or 'a type of code generation', and while it applies both of those techniques,
what makes it unique is that it performs those and other tasks _holistically_ 
with complete knowledge of the system and its resources as described by its 
implementation language.  Unlike custom build tools or platform-as-code 
approaches, the s-kernel uses the application programming language to compute 
the optimal configurations for processing, platform and infrastructure based on
the best information at that moment, while allowing for a completely new 
deployment to emerge in the next based on new information.


### Systemic - Analytics
If, as the explanation of the distributed vector states, that our quality is 
much lower '...because many outcomes become subjective', how can this be 
formalized into a technical solution that increases quality?  Before that can 
be answered, we must first explain what occurred in programming to make that 
that subjectivity possible.

Prior to the introduction of the distributed vector, computing evolved through a
rigorous adherence to mathematical principles that primarily emphasized 
_deterministic behavior_.  Nearly all of the work from Turing onward developed
platforms, languages and algorithms that could be _proven_ would always operate 
in exactly the same way every time for the same inputs and environment.  Even
naturally non-deterministic domains like concurrency and parallelism could be 
tamed with deterministic primitives guaranteeing certain operating behaviors.  
This was only possible because the underlying platforms themselves were still
deterministic all the way down to the physical hardware layers.

The distributed vector changed the problem space by making many algorithms 
_proabilistic_ by association.  Unlike invocation and behavior, the distributed
outcomes could occur randomly and without notice.  My banking application might
work great for 29 days out of the month, but could suddenly fail because someone
unplugged a networking switch along the path between my desktop and the 
computing center.  I might be able to enjoy movies for most of the year with my 
streaming provider, but right around the Super Bowl, those movies might 
experience degradation or become unavailable.  Almost overnight, the industry
needed to accept the informal practice of identifying probabilities for failure
in a distributed space.  This is no more evident than in the mythical 'high 
availability' distributed systems that are operational for 99.999% of the time 
each year.  Prior to distribution, we never considered a scenario where our 
software wouldn't compute correcly for 6 minutes a year or how to even address 
that possibility.

The largest source of distribution is derived from the largely voluntary and
collaborative Internet architecture.  In return for instant, worldwide access to
information and processing, we must accept some degree of probabilism in modern
computing and measure our success in creating high-quality computing by the 
percentage of time in which the system is deterministic.  It is from this 
understanding that the role of analytics becomes apparent to the s-kernel.

If a system were built with a fixed number of interconnected distributed nodes
in an isolated data center with interconnections hardwired and limited
opportunities for failure, it is reasonably easy for existing programming 
patterns to build an efficient organization of processing across these nodes.  
In our minds as developers, we'd intuit that the configuration has a low 
probability of failure, and perhaps we'd run it that way for some period of 
time to enjoy its benefits.  If at some point in our year, we realized that to 
mitigate problems with the solid state drives (SSD) we need to offline half of 
the nodes to replace the hardware, we'd refactor the code of our algorithm to 
support dynamic rebalancing of network load while hardware fixes are performed.
In this example, the product would become more deterministic in the face of 
these challenges by analyzing and adjusting how it links the nodes together.

Since few real world scenarios on the Internet aren't as contrived as the 
example above, most teams continually reevaluate the probabilities of failure 
and attempt to align their efforts to adapt the system in response.  In a 
departure from conventional programming in which the choices of linkage are not
influenced by past behavior and in response to non-deterministic behavior, the 
solution the s-kernel applies is to collect runtime statistics about the 
behavior of the managed system and then _feed that information back into the 
compilation to improve its choices for the next iteration of deployment._  Its 
goal will be the maximization of determinism over some iterations of re-linking
and deployment, which is simply an automated approach of the example above.


## Conclusion

For all of the excitement around new methods of computation, there is a good
measure of self-criticism in the software industry.  Whether the terminology 
is the same, we've noticed how much time spent on 'linkage' doesn't by itself
add product value.  It can feel like an accomplishment to build a working mobile
app that communicates through a gateway into a back-end microservice 
architecture until you reflect upon how much effort was required to display a 
simple list of items with some trivial actions for each.  In the past year as 
the economy has cooled, many once gainfully employed fullstack devs have been 
laid off in all sectors.  If the costs are simply too high to display that 
mobile list, one can appreciate businesess deciding to simply operate without 
it.  It is sadly easy to predict that someone who is paid a high premium but 
gets less done each year will eventually not justify continued investment.

The encouraging counterpoint is that we've spent 30 years exploring countless 
areas of research in computer science.  Many aspects of hardware, language, 
operating systems, networking, distributed systems, machine learning have been
explored, understood and dramatically improved.  The fact that the value is 
still incredibly high for many businesses in this new digital economy speaks to
its vast potential.  Using this collection of research and development to now 
work smarter and much more efficiently is the next great opportunity.  If we 
can achieve instant worldwide connectivity to information and processing while
reducing the cost to near zero, the likelihood of great leaps forward are 
undeniable.

Systemic programming offers a compelling solution not because it replaces the
technologies we've built, but because it adapts, generalizes, and repositions 
them.  We don't have to imagine impossibly different ways of developing or
running programs, only to apply time-proven techniques to linking them.  As the 
complexity of software continues to increase, the time is right to _refactor 
our thinking_ about how code is integrated to regain confidence in the things 
we are building.

