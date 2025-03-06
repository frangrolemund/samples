# Overview
The work here aims to find delightful, new ways of representing the [publicly 
available data sets](https://metmuseum.github.io) from the Metroplitan Museum 
of Art.  The museum provides API and index access to over 500K pieces with
associated photos, attribution and external references, which makes for an
interesting problem to solve in a mobile app with limited capacity and no
dedicated back-end support.

# Challenges
- The public REST APIs are functional for acquiring data, but require rate
limiting and provide limited associative query paths to optimize mobile usage.
In other words, any app that wishes to display content and only relies on these
APIs may only present the most simplisic experience using search options or
blind queries of arbitrary data.

- The downloadabble index (MetObjects) has more associations, but is rather
large (~300MB) and doesn't fully define the content available in the APIs (eg.
photos).  In this case, it provides more information, but is incomplete without
the APIs.

- This app won't deploy custom back-end processing, which is an often an applied
shorthand for large resource virtualization.  I'm not interested in paying for 
or maintaining back-end deployments for this project.

- Finding fresh ways of virtually digitally displaying museum artifacts that
are best experienced in person.

# Features
- SwiftUI for all interfaces.
- Structured (Swift) Concurrency.
- Localization.  NOTE: The apps here only include crude, Google-supplied translations into Ukrainian as a proof of concept only, assuming that professional translation services are essential for any serious product delivery.  
- An opaque framework API (MetModel) for conveniently interfacing with the Met Art index and RESTful APIs from both the designer and MetMinded app.
- An custom automated workflow that accomodates curated design of exhibit tours into a refined consumer app experience.

# Approach
The technique applied here is to use pre-processed data from the downloadable
index, augmented with API query data in a dedicated 'designer' app for macOS
that produces static collections of curated content.  The mobile app therefore
_only uses the curated sequences_ as a source while downloading the larger
photos on-demand as desired by the consumer.  From there, the intent is to
deliver the best possible integration of the mobile app with iOS to showcase
the work.
