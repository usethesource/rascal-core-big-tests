# Rascal Integration Test

## Usage

 1. Go to "Actions" (top menu) -> "Integration Test" (left menu) -> "Run workflow" (drop-down menu).
 2. Select which branches/tags of Rascal and Typepal to use **to build `rascal.jar`**:
      - The branch/tag of Rascal is mandatory.
      - The branch/tag of Typepal is optional:
          - If it isn't provided, then by default, `rascal.jar` is built using the dependency version of Typepal as defined in `pom.xml` of Rascal. In most cases, this is the right default, as `pom.xml` normally points to the intended dependency version of Typepal already.
          - If it is provided, then the provided branch/tag of Typepal is locally installed in the Maven repository, `pom.xml` of Rascal is locally updated to point to it, and `rascal.jar` is built using that installed dependency version of Typepal. It serves the use case of testing the effect of new changes in a non-`main` branch of Typepal on Rascal before merging those changes into `main`.
 3. Select which branches/tags of Rascal and Typepal to use **to typecheck the standard library and Typepal sources**. Both branches/tags are optional. If they aren't provided, then by default, `main` is used. In most cases, this is the right default, as it serves the use case of testing that new changes to Rascal/Typepal (as reflected in `rascal.jar`) do not break the well-typedness of the existing standard library and Typepal sources.

Note: In the distinguished `...-all` tests, the same versions of the standard library and Typepal sources are typechecked as those that are used to build `rascal.jar`.
