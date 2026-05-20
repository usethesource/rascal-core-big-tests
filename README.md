# Rascal Typechecker Integration Test

This repo is used to run integration test on the rascal typechecker. It's goal is to identify regressions with a new version of typechecker (maybe caused by interpreter/typepal/stdlib changes) in typechecking rascal code *without making any intermediate releases*. The goal is to identify issues before we're in some kind of bootstrap cycle or a regular release process.

To clear, currently it's only for the typechecker:

- it does not test the compiler or it's generated code
- it does not test the tpls and it's compatibility. It explicatly ignores any tpls in any jars.
- it does not test the tutor generator.

## Scenarios

The integration test has some parameters that are a bit complex to use, so this section will discuss a few common scenarios and how to use the parameters.

It always start with: 

> Go to "Actions" (top menu) -> "Integration Test" (left menu) -> "Run workflow" (drop-down menu).


For every scenario there will be the following details that we care for:

| asset | explained |
|---|---|
| typepal.jar | the typepal.jar that gets packaged into rascal.jar |
| rascal.jar | the rascal.jar that gets build. Contains the stdlib and typechecker used |
| rascal-stdlib | the standard lib that is typechecked and used to typecheck all the downstream libraries |
| typepal | the typepal version that is typechecked during the typechecking of libraries |
| typepal-copy | the typepal version that is copied into rascal-all |
| rascal-all | the version of the rascal compiler that is typechecked by `rascal.jar` |
| rascal-lsp-all | the version of rename code in rascal-lsp (that uses the rascal-compiler) that is typechecked by `rascal.jar` |



### Changes in rascal

There are changes the rascal project (in a PR) that might influence the typechecker. __It has no changes in typepal that aren't released yet__.

> Only set the `rascal_branch_build` parameter to the branch you want to check

Note that the typechecking of the rascal stdlib will be targeting main, while typechecking of the compiler itself will target the `rascal_branch_build`.

| asset | version |
|---|---|
| typepal.jar | extracted from `rascal/pom.xml` in `rascal_branch_build`, is assumed to be released |
| rascal.jar | `rascal_branch_build` |
| rascal-stdlib | `main` |
| typepal | `main` |
| typepal-copy | same as `typepal.jar` |
| rascal-all | `rascal_branch_build` |
| rascal-lsp-all | `main` |


### Changes in rascal&typepal

There are changes in both rascal & typepal project that might influence the typechecker. 


## Usage

 1. Go to "Actions" (top menu) -> "Integration Test" (left menu) -> "Run workflow" (drop-down menu).
 2. Select which branches/tags of Rascal and Typepal to use **to build `rascal.jar`**:
      - The branch/tag of Rascal is mandatory.
      - The branch/tag of Typepal is optional:
          - If it isn't provided, then by default, `rascal.jar` is built using the dependency version of Typepal as defined in `pom.xml` of Rascal. In most cases, this is the right default, as `pom.xml` normally points to the intended dependency version of Typepal already.
          - If it is provided, then the provided branch/tag of Typepal is locally installed in the Maven repository, `pom.xml` of Rascal is locally updated to point to it, and `rascal.jar` is built using that installed dependency version of Typepal. It serves the use case of testing the effect of new changes in a non-`main` branch of Typepal on Rascal before merging those changes into `main`.
 3. Select which branches/tags of Rascal and Typepal to use **to typecheck the standard library and Typepal sources**. Both branches/tags are optional. If they aren't provided, then by default, `main` is used. In most cases, this is the right default, as it serves the use case of testing that new changes to Rascal/Typepal (as reflected in `rascal.jar`) do not break the well-typedness of the existing standard library and Typepal sources.

Note: In the distinguished `...-all` tests, the same versions of the standard library and Typepal sources are typechecked as those that are used to build `rascal.jar`.
