# Rascal Typechecker Integration Test

This repo is used to run integration test on the Rascal typechecker. Its goal is to identify regressions with a new version of typechecker (maybe caused by interpreter/typepal/stdlib changes) when typechecking Rascal code *without making any intermediate releases*. The goal is to identify issues before we're in some kind of bootstrap cycle or a regular release process.

To be clear, currently it's only for the typechecker:

- It does not test the compiler or its generated code.
- It does not test the tpls and its compatibility. It explicitly ignores any tpls in any jars.
- It does not test the tutor generator.

Note: Beside typechecking, the only tests that are run are the rename tests in rascal-lsp (because they themselves run the typechecker as well).

To start a new run, do, go to this page: [Integration Test actions](https://github.com/usethesource/rascal-core-big-tests/actions/workflows/run-integration-test.yml) and click the button in the right top corner for "Run workflow".

<img width="1271" height="230" alt="image" src="https://github.com/user-attachments/assets/6dc59d25-524c-413b-b1fb-5b6574e09ed9" />

## Sources/branches used in the integration test

The intergration test checks out libraries based on the configuration in the `projects` global variable in the `src/main/rascal/Main.rsc` file. However, for some scenarios you can override that. The following section describes how you can override this.

## Scenarios

The integration test has some parameters that are a bit complex to use, so this section will discuss a few common scenarios and how to use the parameters. The end goal of the parameters is to configure the following assets:

| Asset | Explained | Controlled by |
|:---|:---|:--|
| rascal.jar | the rascal.jar that gets build. Contains the stdlib and typechecker used | `$rascal_branch_build` |
| typepal.jar | the typepal.jar that gets packaged into rascal.jar | `rascal/pom.xml` or `$typepal_branch_build` |
| rascal-stdlib | the standard lib that is typechecked and used to typecheck all the downstream libraries | `Main.rsc` or `$rascal_branch_check` |
| typepal | the Typepal version that is typechecked during the typechecking of libraries | `Main.rsc` or `$typepal_branch_check` |
| rascal-lsp | the version of rascal-lsp that is typechecked during the typechecking of libraries | `Main.rsc` or `$rascal_lsp_branch_check` |
| rascal-all | the version of the Rascal compiler that is typechecked by `rascal.jar`. | `rascal.jar` |
| typepal-copy | the Typepal version that is copied into rascal-all. | `typepal.jar` |
| rascal-lsp-all | the version of rename code in rascal-lsp (that uses the Rascal compiler) that is typechecked by `rascal.jar` |  `Main.rsc` or `$rascal-lsp-all` |


### Scenario 1: Changes in Rascal

There are changes in the Rascal project (in a PR) that might influence the typechecker. __It has no changes in Typepal that aren't released yet__.

1.  set the `rascal_branch_build` parameter to the branch you want to check

#### Effect

| Asset | Version |
|:---|:---|
| rascal.jar | `$rascal_branch_build` |
| typepal.jar | extracted from `rascal/pom.xml` in `$rascal_branch_build`, is assumed to be released |
| rascal-stdlib | branch configured in `Main.rsc` |
| typepal | branch configured in `Main.rsc` |
| rascal-lsp | branch configured in `Main.rsc` |
| rascal-all | same as `rascal.jar` |
| typepal-copy | same as `typepal.jar` |
| rascal-lsp-all | branch configured in `Main.rsc` |

### Scenario 2: Changes in Rascal and Typepal

There are changes in both the Rascal project and the Typepal project that might influence the typechecker.

1. Set `rascal_branch_build`
2. Set `typepal_branch_build`

Setting `typepal_branch_build` will override the Typepal dependency in the `rascal/pom.xml`, and build it locally before building `rascal.jar`

#### Effect

| Asset | Version |
|:---|:---|
| rascal.jar | `$rascal_branch_build` |
| typepal.jar | `$typepal_branch_build` |
| rascal-stdlib | branch configured in `Main.rsc` |
| typepal | branch configured in `Main.rsc` |
| rascal-lsp | branch configured in `Main.rsc` |
| rascal-all | same as `rascal.jar` |
| typepal-copy | same as `typepal.jar` |
| rascal-lsp-all | branch configured in `Main.rsc` |

### Scenario 3: Changes in the typechecker that require changes in rascal-lsp

There are changes in the Rascal project that might influence the typechecker. And it requires changes in rascal-lsp rename code.

1. Set `rascal_branch_build`
2. Set `rascal_lsp_branch_check`
3. Set `rascal_lsp_all_branch_check`

#### Effect

| Asset | Version |
|:---|:---|
| rascal.jar | `$rascal_branch_build` |
| typepal.jar | `$typepal_branch_build` |
| rascal-stdlib | branch configured in `Main.rsc` |
| typepal | branch configured in `Main.rsc` |
| rascal-lsp | `$rascal_lsp_branch_check` |
| rascal-all | same as `rascal.jar` |
| typepal-copy | same as `typepal.jar` |
| rascal-lsp-all | `$rascal_lsp_all_branch_check` |

### Scenario 4: Changes in Rascal and Typepal that are "incompatible" with the main branch

There are changes in both the Rascal and the Typepal project that might influence the typechecker. And the new typechecker also requires changes in the stdlib, and thus before merging would take a bootstrap cycle (or an intermediate release without tpls).

1. Set `rascal_branch_build`
2. Set `typepal_branch_build`
3. Set `rascal_branch_check`
4. Set `typepal_branch_check`.
5. Optionally you'll also need to set `rascal_lsp_all_branch_check`, if the changes propagate that far

Setting `typepal_branch_build` will override the Typepal dependency in `rascal/pom.xml`, and build it locally before building `rascal.jar`

#### Effect

| Asset | Version |
|:---|:---|
| rascal.jar | `$rascal_branch_build` |
| typepal.jar | `$typepal_branch_build` |
| rascal-stdlib | `$rascal_branch_check` |
| typepal | `$typepal_branch_check` |
| rascal-lsp | branch configured in `Main.rsc` |
| rascal-all | same as `rascal.jar` |
| typepal-copy | same as `typepal.jar` |
| rascal-lsp-all | branch configured in `Main.rsc` or `$rascal_lsp_all_branch_check` |
