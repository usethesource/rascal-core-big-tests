# Rascal Typechecker Integration Test

This repo is used to run integration test on the Rascal typechecker. Its goal is to identify regressions with a new version of typechecker (maybe caused by interpreter/typepal/stdlib changes) when typechecking Rascal code *without making any intermediate releases*. The goal is to identify issues before we're in some kind of bootstrap cycle or a regular release process.

To be clear, currently it's only for the typechecker:

- It does not test the compiler or its generated code.
- It does not test the tpls and its compatibility. It explicitly ignores any tpls in any jars.
- It does not test the tutor generator.

Note: Beside typechecking, the only tests that are run are the rename tests in rascal-lsp (because they themselves run the typechecker as well).

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
| typepal | the Typepal version that is typechecked during the typechecking of libraries |
| typepal-copy | the Typepal version that is copied into rascal-all, this is always te same as `typepal.jar` |
| rascal-all | the version of the Rascal compiler that is typechecked by `rascal.jar`. This always follows the branch of `rascal.jar` |
| rascal-lsp-all | the version of rename code in rascal-lsp (that uses the Rascal compiler) that is typechecked by `rascal.jar` |



### Scenario 1: Changes in Rascal

There are changes in the Rascal project (in a PR) that might influence the typechecker. __It has no changes in Typepal that aren't released yet__.

> Only set the `rascal_branch_build` parameter to the branch you want to check

#### Effect

| asset | version |
|---|---|
| typepal.jar | extracted from `rascal/pom.xml` in `$rascal_branch_build`, is assumed to be released |
| rascal.jar | `$rascal_branch_build` |
| rascal-stdlib | branch configured in `Main.rsc` |
| typepal | branch configured in `Main.rsc` |
| typepal-copy | same as `typepal.jar` |
| rascal-all | same as `rascal.jar` |
| rascal-lsp-all | branch configured in `Main.rsc` |

### Scenario 2: Changes in Rascal and Typepal

There are changes in both the Rascal project and the Typepal project that might influence the typechecker.

> Set `rascal_branch_build` and `typepal_branch_build`

Setting `typepal_branch_build` will override the Typepal dependency in the `rascal/pom.xml`, and build it locally before building `rascal.jar`

#### Effect

| asset | version |
|---|---|
| typepal.jar | `$typepal_branch_build` |
| rascal.jar | `$rascal_branch_build` |
| rascal-stdlib | branch configured in `Main.rsc` |
| typepal | branch configured in `Main.rsc` |
| typepal-copy | same as `typepal.jar` |
| rascal-all | same as `rascal.jar` |
| rascal-lsp-all | branch configured in `Main.rsc` |

### Scenario 3: Changes in the typechecker that require changes in rascal-lsp

There are changes in the Rascal project that might influence the typechecker. And it requires changes in rascal-lsp rename code.

> Set `rascal_branch_build` and `rascal_lsp_all_branch_check`

#### Effect

| asset | version |
|---|---|
| typepal.jar | `$typepal_branch_build` |
| rascal.jar | `$rascal_branch_build` |
| rascal-stdlib | branch configured in `Main.rsc` |
| typepal | branch configured in `Main.rsc` |
| typepal-copy | same as `typepal.jar` |
| rascal-all | same as `rascal.jar` |
| rascal-lsp-all | `$rascal_lsp_all_branch_check` |

### Scenario 4: Changes in Rascal and Typepal that are "incompatible" with the main branch

There are changes in both the Rascal and the Typepal project that might influence the typechecker. And the new typechecker also requires changes in the stdlib, and thus before merging would take a bootstrap cycle (or an intermediate release without tpls).

> Set `rascal_branch_build`, `typepal_branch_build`, `rascal_branch_check`, `typepal_branch_check`.
>
> Optionally you'll also need to set `rascal_lsp_all_branch_check`, if the changes propagate that far

Setting `typepal_branch_build` will override the Typepal dependency in `rascal/pom.xml`, and build it locally before building `rascal.jar`

#### Effect

| asset | version |
|---|---|
| typepal.jar | `$typepal_branch_build` |
| rascal.jar | `$rascal_branch_build` |
| rascal-stdlib | `$rascal_branch_check` |
| typepal | `$typepal_branch_check` |
| typepal-copy | same as `typepal.jar` |
| rascal-all | same as `rascal.jar` |
| rascal-lsp-all | branch configured in `Main.rsc` or `$rascal_lsp_all_branch_check` |
