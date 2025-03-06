#  RREngine

##  Overview
RREngine provides an easily embeddable framework capable of hosting any RRouted document (repository) as an opaque web services platform.

##  Design
### Principles
* Live modification.  Changes to a running engine and its configuration are immediately available for use by clients.
* Broad and deep usability interfaces.  All the elements of a configured repository have simplified configuration, control and monitoring interfaces to easily support interactive experiences.
* Linkage-based innovation.  The engine and RRouted app by extension don't intend to innovate in well-understood and previously staked domains like user interface design or networking implementation.  The engine intentionally builds on common frameworks and patterns for those requirements and instead focuses on innovating almost entirely on _reducing the costs of distributed linkage_.   

### Concurrency
The strategy for concurrency in the engine is to offer modern concurrency conveniences while ensuring a rigor of operation that minimizes unintended side-effects.  This is espcially important when bridging between an interface implementation in SwiftUI, background Tasks and the custom, thread-based concurrency of the networking layer in SwiftNIO.   The main patterns applied are:
* All public interfaces into the engine default to `@MainActor` access, with `nonisolated` interfaces provided only when necessary to satisfy common patterns or `Foundation` protocols.   While SwiftUI will interact with interfaces that aren't designated as @MainActor, its consistent application in the public engine interfaces intends to ensure the cleanest integration.
* Objects that cannot safely guarantee @MainActor access naturally _must provide inner locking_ to best preserve thread-safety, even if the compiler would otherwise allow the behavior.
* Asynchronous behavior will be implemented almost exclusively with a combination of Swift Concurrency and Combine, only reverting to classic mechanisms for specialized cases of system framework or third-party integrations.

