#  Overview
RRouted provides zero-cost distributed computing infrastructure for system design and prototyping.

#  Design
## Opportunities
The current state of cloud computing introduces significant and often unforseeable costs on many organizations that wish to cheaply host their business operations on the Internet.  These costs include:
* Expertise is often required in cloud infrastructure to avoid significant utility-style costs of bandwidh, compute and storage.
* Logic is naturally distributed across disparate compute entities (VMs, hosts, containers) with specialized failure patterns.
* Software platforms and frameworks retain legacy workflows of (1) coding then (2) building/deploying new distributed logic, which requires multiple layers of slow and progressive testing of the larger distributed design.
* The linkage between distributed systems is an often manual effort of protocol design using common variations of networking protocols based on combinations of HTTPs, gRPC, SOAP, WebSocket, GraphQL, etc.  When any linkage between entities changes, it can easily mandate cascading, manual modifications across different codebases. 
* Product designers and client developers can't easily design the ideal data flows with their back-end because it takes too long to prototype concepts.



