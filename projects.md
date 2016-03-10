This page lists ideas for student summer projects, specifically related to tooling and IDE work for the Julia language. Please see the [main page](http://julialang.org/soc/ideas-page) for more information on applying, and ideas related to the core language and libraries.

These ideas are meant to serve as a foundation for a solid proposal, but you're not limited to what's specified here. We encourage you to extend and change proposals and even come up with your own when applying.

For any questions, reach out to the [Julia mailing list](https://groups.google.com/forum/#!forum/julia-users) or to the [Juno forum](http://discuss.junolab.org). If you're interested in a project but not sure how you'd get started, we're happy to help.

## Documentation search & navigation

We'd like to make finding and viewing relevant documentation a core part of the Juno/Julia experience. As well as viewing docs for a particular function, it'd be great to take advantage of the extensive Markdown docs provided by packages for other purposes. For example, a basic doc search engine could allow users to find relevant functionality even when they don't know the names of the functions involved. (This could even be extended to searching across all packages!)

Initially this project could be built as a package or as an extension to the Atom.jl package. Eventually, we'd also like to integrate the functionality with a nice UI inside of Juno, and this could serve as extension work for an enterprising student.

## Package installation UI

Juno could provide a simple way to browse available packages and view what's installed on their system. To start with, this project could simply provide a GUI that reads in package data from `~/.julia`, including available packages and installed versions, and buttons which call the relevant `Pkg.*` methods.

This could also be extended by having metadata about the package, such as a readme, github stars, activity and so on. To support this we probably need a [pkg.julialang.org](http://pkg.julialang.org) style API which provides the info in JSON format.

## Swirl-style tutorial

The [swirl](http://swirlstats.com) tutorial teaches R users through an interactive REPL experience. Something similar in Julia could provide a tutorial that takes advantage of Juno's frontend integration, e.g. for getting input and displaying results. In particular, we'd expect this project to involve building a solid *framework* for building swirl-style tutorials, and allowing the Julia community to easily create new tutorials using Julia. Some research into how Swirl itself achieves this would be a good start.

## Julia Code Analysis

The foundation for tools like refactoring, linting or autoformatting is a powerful framework for reading and writing Julia code while preserving various features of the source code; comments, original formatting, and perhaps even syntax errors. This could build on the work in JuliaParser.jl.

Related would be various tools for doing static or dynamic analysis of Julia code in order to find errors. A simple example would be linting indentation; combined with information from the parser, this could be a powerful way to reduce beginner frustration over `unexpected )` style error messages.

## Performance Linting

Concepts relevant to Julia code's performance, like 'type-stability', are often implicit in written code, making it hard for new users in particular to catch slow code early on. However, this also represents a challenge for static analysis, since in general concrete type information won't be available until runtime.

A potential solution to this is to hook into function calls (users will most likely call a function with test inputs after writing it) and then use dynamically-available information, such as the output of `code_typed`, to find performance issues such as non-concrete types, use of global variables etc, and present these as lint warnings in the IDE.

While static analysis has long been used as a tool for understanding and finding problems in code, the use of dynamically available information is unexplored (with the exception of tracing JIT compilers, which demonstrate the power of the concept). This project has plenty of interesting extensions and could have the most interesting long-term implications.

## Support for ANSI codes in the console

The Ink console has some nice features, including being able to display graphics and HTML inline. However, it could be useful to integrate some more terminal-esc features like support for ANSI colour codes.

## Workspace saving and loading

RStudio provides the option to save loaded packages and variables on shutdown, and set up the environment as before when restarting. This could be replicated in Juno using some serialisation format for Julia data (e.g. the built-in serialiser or HDF5.jl).

## Something completely different!

If there's a piece of tooling you'd like to see for Julia, don't hesitate to suggest it to us!
