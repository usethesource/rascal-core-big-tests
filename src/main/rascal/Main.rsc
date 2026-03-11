module Main

import String;
import IO;
import List;
import Location;
import util::Reflective;
import util::SystemAPI;
import util::FileSystem;
import util::SystemAPI;
import analysis::graphs::Graph;
import util::ShellExec;
import util::Benchmark;

data Project
    = project(
        loc repo, // git clone url
        set[str] dependencies, // other project this depends on (at a rascal level)
        bool rascalLib=false, // instead of rascal as a regular "project" dependency, us the tpls that came with the chosen rascal-version
        str branch="main", // branch to checkout from the remote
        str subdir="", // if the rascal project is not at the root of the repo
        list[str] srcs = [], // override source calculation
        set[str] ignores = {}, // directories to ignore
        bool parallel = false,
        set[str] parallelPreCheck = {},
        set[str] testPrefixes={}
    );

alias Projects = rel[str name, Project config];

Projects projects = {
    <"rascal", project(|https://github.com/usethesource/rascal.git|, {}, srcs = ["src/org/rascalmpl/library"], ignores={"experiments", "resource", "lang/rascal/tests", "lang/rascal/syntax/tests", "lang/rascal/grammar/tests", "lang/std/tests"}, parallel = true, parallelPreCheck = {"src/org/rascalmpl/library/Prelude.rsc"})>,
    <"rascal-all", project(|https://github.com/usethesource/rascal.git|, {}, branch=(getSystemProperties()["RASCAL_ALL_BRANCH"] ? "main"), ignores={"lang/rascal/tutor/examples", "NestedOr.rsc"}, parallel = true, parallelPreCheck = {"src/org/rascalmpl/library/Prelude.rsc", "src/org/rascalmpl/compiler/lang/rascalcore/check/CheckerCommon.rsc"})>,
    <"typepal", project(|https://github.com/usethesource/typepal.git|, {"rascal"}, ignores={"examples"})>,
    <"typepal-boot", project(|https://github.com/usethesource/typepal.git|, {}, rascalLib=true, ignores={"examples"})>,
    <"salix-core", project(|https://github.com/usethesource/salix-core.git|, {"rascal"})>,
    <"clair", project(|https://github.com/usethesource/clair.git|, {"rascal"})>,
    <"java-air", project(|https://github.com/usethesource/java-air.git|, {"rascal"})>,
    <"rascal-lucene", project(|https://github.com/usethesource/rascal-lucene.git|, {"rascal"})>,
    <"python-air", project(|https://github.com/cwi-swat/python-air.git|, {"rascal"})>,
    <"salix-contrib", project(|https://github.com/usethesource/salix-contrib.git|, {"rascal", "salix-core"})>,
    <"flybytes", project(|https://github.com/usethesource/flybytes.git|, {"rascal"})>,
    <"drambiguity", project(|https://github.com/cwi-swat/drambiguity.git|, {"rascal", "salix-core"})>,
    <"rascal-git", project(|https://github.com/cwi-swat/rascal-git.git|, {"rascal"})>,
    <"php-analysis", project(|https://github.com/cwi-swat/php-analysis.git|, {"rascal", "rascal-git"}, srcs=["src/main/rascal"])>,
    <"rascal-lsp-all", project(|https://github.com/usethesource/rascal-language-servers.git|, {"rascal-all"}, subdir="rascal-lsp", srcs=["src/main/rascal/library","src/main/rascal/lsp"])>,
    <"rascal-lsp", project(|https://github.com/usethesource/rascal-language-servers.git|, {"rascal", "typepal"}, srcs=["src/main/rascal/library", "src/main/rascal/lsp"], branch="fix/rename-pure-rascal", ignores = {"lang/rascal/lsp/refactor", "lang/rascal/tests/rename", "lang/rascal/lsp/IDECheckerWrapper.rsc"}, subdir="rascal-lsp", testPrefixes={"lang::rascal::tests::rename"})>
};

bool isWindows = /win/i := getSystemProperty("os.name");

str buildFSPath(loc l) {
    l = resolveLocation(l);
    if (l.scheme != "file") {
        throw "Only file schemes are supported, <l> is invalid";
    }
    path = l.path;
    if (isWindows) {
        // for windows we have to flip the \\ and remove the prefix /
        if (startsWith(path, "/")) {
            path = path[1..];
        }
        path = replaceAll(path, "/", "\\");
    }
    return path;
}

str buildCP(loc entries...) = intercalate(getSystemProperty("path.separator"), [ buildFSPath(l) | l <- entries]);


loc projectRoot(loc repoFolder, str name, Project proj) = (repoFolder + name) + proj.subdir;


tuple[list[loc], list[loc]] calcSourcePaths(str name, Project proj, loc repoFolder, loc(str) getProjectLoc) {
    srcs = proj.srcs != [] ? [projectRoot(repoFolder, name, proj) + s |  s <- proj.srcs ] : getProjectPathConfig(projectRoot(repoFolder, name, proj)).srcs;
    if (name == "rascal-all") {
        // To be able to access typepal in rascal-all (and rascal-lsp-all) without bootstrapping issues, we copy typepal sources and put them on our src path
        tpSources = repoFolder + "rascal-all/src/org/rascalmpl/typepal";
        copy(getProjectLoc("typepal") + "src/analysis/typepal", tpSources + "analysis/typepal", recursive=true);
        srcs = [src | src <- srcs, !(src.scheme == "mvn" && startsWith(src.authority, "org.rascalmpl--typepal"))] + resolveLocation(tpSources);
    }
    ignores = [ s + i |  s <- srcs, s.scheme != "jar+file",  i <- proj.ignores];
    return <srcs, ignores>;
}

PathConfig generatePathConfig(str name, Project proj, loc repoFolder, false, false, loc _packageTarget, loc(str) getProjectLoc) {
    <srcs, ignores> = calcSourcePaths(name, proj, repoFolder, getProjectLoc);
    for (str dep <- proj.dependencies, <dep, projDep> <- projects) {
        <nestedSrcs, nestedIgnores> = calcSourcePaths(dep, projDep, repoFolder, getProjectLoc);
        srcs += nestedSrcs;
        ignores += nestedIgnores;
    }
    return pathConfig(
        projectRoot = projectRoot(repoFolder, name, proj),
        srcs = srcs,
        ignores = ignores,
        bin = repoFolder + "shared-tpls",
        libs = [repoFolder + "shared-tpls"] + (proj.rascalLib ? [|std:///|] : [])
    );
}
PathConfig generatePathConfig(str name, Project proj, loc repoFolder, true, bool package, loc packageTarget, loc(str) getProjectLoc) {
    <srcs, ignores> = calcSourcePaths(name, proj, repoFolder, getProjectLoc);
    result = pathConfig(
        projectRoot = projectRoot(repoFolder, name, proj),
        srcs = srcs,
        ignores = ignores,
        bin = repoFolder + name + "target" + "classes",
        libs = [ resolve(repoFolder + dep, package ? packageTarget : |relative:///target/classes|) | dep <- proj.dependencies ] + (proj.rascalLib ? [|std:///|] : [])
    );
    /*
    if (name == "rascal-lsp-all" || name == "rascal-all") {
        // we have to add typepal to the lib path
        rascalPcfg = getProjectPathConfig(repoFolder + "rascal-all");
        result.libs += [l | l <- (rascalPcfg.srcs + rascalPcfg.libs), l.scheme == "mvn", /typepal/ := l.authority];
        if (name == "rascal-all") {
            // and remove typepal from the srcs
            result.srcs = [s | s <- result.srcs, s.scheme != "mvn", /typepal/ !:= s.authority];
        }
    }
    */
    return result;
}

int updateRepos(Projects projs, loc repoFolder, bool full) {
    int result = 0;
    void checkOutput(str name, <str output, int exitCode>) {
        if (exitCode != 0) {
            result += 1;
            println("!!<name> failed: ");
            println(output);
        }
    }
    for (<n, proj> <- projs) {
        targetFolder = repoFolder + n;
        if (exists(targetFolder)) {
            println("**** Updating <n>");
            checkOutput("fetch", execWithCode("git", args=["fetch"], workingDir=targetFolder));
            checkOutput("reset", execWithCode("git", args=["reset", "--hard", "origin/<proj.branch>"], workingDir=targetFolder));
        }
        else {
            println("**** Cloning <n>");
            extraArgs = full ? [] : ["--single-branch", "--branch", proj.branch, "--depth", "1"];
            checkOutput("clone", execWithCode("git", args=["clone", *extraArgs, proj.repo.uri, n], workingDir=repoFolder));
        }
    }
    return result;
}

bool isIgnored(loc f, list[loc] ignores)
    = size(ignores) > 0 && any(i <- ignores, (relativize(i, f) != f || i == f));

list[str] addParallelFlags(Project proj, list[loc] rascalFiles, int maxCores) {
    if (!proj.parallel) {
        return [];
    }
    result = ["--parallel", "--parallelMax", "<maxCores>"];
    for (pc <- proj.parallelPreCheck, f <- rascalFiles, endsWith(f.path, pc)) {
        result += ["--parallelPreChecks", "<f>"];
    }
    return result;
}

// Resolve this location before our working directory is irreparably changed later on
loc testWrapperLocation = resolveLocation(|cwd:///src/main/rascal/TestWrapper.rsc|);

lrel[str, int, int] stats = [];

int main(
    str memory = "4G",
    int maxCores = 4,
    bool libs=true, // put the tpls of dependencies on the lib path
    bool update=false, // update all projects from remote
    bool package=libs,
    loc packageTarget = |relative:///target/rewrittenClasses|,
    bool full=true, // do a full clone
    bool clean=true, // do a clean of the to build folders
    loc repoFolder = |tmp:///repo/|,
    loc rascalVersion=|home:///.m2/repository/org/rascalmpl/rascal/0.41.0-RC46/rascal-0.41.0-RC46.jar|,
    set[str] tests = {/*all*/}
    ) {

    loc getProjectLoc(str projectName) {
        int res = updateRepos({p | p:<projectName, _> <- projects}, repoFolder, full);
        if (res != 0) {
            return |unknown:///|;
        }
        return repoFolder + projectName;
    }

    stats = [];
    mkDirectory(repoFolder);
    int result = 0;
    toBuild = (tests == {}) ? projects : { p | p <- projects, p.name in tests};

    if (update || any(<n, _> <- toBuild, !exists(repoFolder + n))) {
        println("*** Downloading repos ***");
        result += updateRepos(toBuild, repoFolder, full);
        if (result > 0) {
            return result;
        }
    }
    else {
        println("Not downloading any dependencies");
    }


    // calculate topological order of dependency graph)
    buildOrder = order({ *(proj.dependencies * {n}) | <n, proj> <- projects, proj.dependencies != {}});
    println("*** Calculate dependency based build order: <buildOrder>");
    // filter out things that weren't requested (so we assume already build)
    buildOrder = [p | p <- buildOrder, p in toBuild.name] ;
    // and also add stuff not part of the graph (projects without any depencencies or dependants)
    buildOrder += [p.name | p <- toBuild, p.name notin buildOrder];
    println("*** Actually building: <buildOrder>");

    // prepare path configs
    println("*** Calculating class paths");
    pcfgs = [<n, generatePathConfig(n, proj, repoFolder, libs, package, packageTarget, getProjectLoc)> | n <- buildOrder, proj <- toBuild[n]];


    if (clean) {
        for (<_, p> <- pcfgs) {
            for (f <- find(p.bin, "tpl")) {
                remove(f);
            }
        }
    }

    result = 0;

    for (n <- buildOrder, proj <- toBuild[n]) {
        println("*** Preparing: <n>");
        p = generatePathConfig(n, proj, repoFolder, libs, package, packageTarget, getProjectLoc);
        if (clean) {
            for (f <- find(p.bin, "tpl")) {
                remove(f);
            }
        }
        iprintln(p);
        loc projectRoot = repoFolder + n;
        rProjectRoot = resolveLocation(projectRoot);
        rascalFiles = sort([*find(s, "rsc") | s <- p.srcs, (startsWith(s.path, projectRoot.path) || startsWith(s.path, rProjectRoot.path))]);
        sourceFiles = [f | f <- rascalFiles, !isIgnored(f, p.ignores)];
        testModules = sort([mname | f <- rascalFiles, str mname := getModuleName(f, p), any(pref <- proj.testPrefixes, startsWith(mname, pref))]);

        result += run("org.rascalmpl.shell.RascalCompile", n, rProjectRoot, p, sourceFiles, memory, rascalVersion, collectStats = true, extraArgs = [*addParallelFlags(proj, sourceFiles, maxCores), "-modules", *[ "<f>" | f <- sourceFiles]]);
        if (package) {
            result += run("org.rascalmpl.shell.RascalPackage", n, rProjectRoot, p, sourceFiles, memory, rascalVersion, extraArgs = ["-sourceLookup", "<rascalVersion>", "-relocatedClasses", "<resolve(rProjectRoot, packageTarget)>"]);
        }
        result += runTests(testModules, rascalVersion, repoFolder, n, proj, p);
    }
    println("******\nDone running ");
    for (<n, e, t> <- stats) {
        println("- <n> <e == 0 ? "✅" : "❌"> <t>s");
    }
    return result;
}

tuple[str, loc] findUniqueName(str basename, loc dir, str extension = "rsc") {
    if (!exists(dir + "<basename>.<extension>")) {
        return <basename, dir + "<basename>.<extension>">;
    }

    int n = 1;
    int MAX_N = 100;
    while (exists(dir + "<basename><n>.<extension>") && n < MAX_N) {
        n += 1;
    }
    if (n == MAX_N) {
        throw "Cannot find unique file name for <basename>.<extension> in <dir>";
    }
    return <basename, dir + "<basename><n>.<extension>">;
}

int runTests(list[str] testModules, loc rascalVersion, loc repoFolder, str projectName, Project proj, PathConfig pcfg) {
    int code = 0;
    if ({} !:= proj.testPrefixes) {
        println("*** Starting: test runner on <projectName> (<size(testModules)>)");
        destDir = getFirstFrom(pcfg.srcs);
        <testWrapperName, testWrapperDest> = findUniqueName("TestWrapper", destDir);
        copy(testWrapperLocation, testWrapperDest);
        startTime = realTime();
        try {
            pid = createProcess("java", args = ["-jar", buildFSPath(rascalVersion), testWrapperName, "--projectName", projectName, "--testModules", intercalate(",", testModules)], workingDir = projectRoot(repoFolder, projectName, proj));
            code = awaitProcess(pid);
        } catch e: {
            throw e;
        } finally {
            stopTime = realTime();
            remove(testWrapperDest);
            println("*** Finished: test runner on <projectName> < code == 0 ? "✅" : "❌ Failed with error <code>"> (<(stopTime - startTime)/1000>s)");
        }
    }
    return code;
}

int run(
    str class,
    str projectName,
    loc resolvedRoot,
    PathConfig pcfg,
    list[loc] rascalFiles,
    str memory,
    loc rascalVersion,
    bool collectStats = false,
    list[str] extraArgs = []
) {
    result = 0;
    println("*** Starting: <class> on <projectName> (<size(rascalFiles)>)");
    startTime = realTime();
    runner = createProcess("java", args=[
        "-Xmx<memory>",
        "-Drascal.monitor.batch", // disable fancy progress bar
        "-cp", buildFSPath(rascalVersion),
        class,
        "-projectRoot", "<resolvedRoot>",
        "-srcs", *[ "<s>" | s <- pcfg.srcs],
        *["-libs" | pcfg.libs != []], *[ "<l>" | l <- pcfg.libs],
        "-bin", "<pcfg.bin>",
        *extraArgs
    ]);
    try {
        code = awaitProcess(runner);
        result += code;
        stopTime = realTime();
        println("*** Finished: <class> on <projectName> < code == 0 ? "✅" : "❌ Failed with error <code>"> (<(stopTime - startTime)/1000>s)");
        if (collectStats) {
            stats += <projectName, code, (stopTime - startTime)/1000>;
        }
    }
    catch ex :{
        println("Running the runner for <projectName> crashed with <ex>");
        result += 1;
    }
    return result;
}

int awaitProcess(int runner, bool printStdOut = true, bool printStdErr = true) {
    int code = -1;
    try {
        while (isAlive(runner)) {
            stdOut = readWithWait(runner, 500);
            if (printStdOut && stdOut != "") {
                print(stdOut);
            }
            if (printStdErr) {
                stdErr = readFromErr(runner);
                while (stdErr != "") {
                    println(stdErr);
                    stdErr = readFromErr(runner);
                }
            }
        }
        if (printStdOut) {
            println(readEntireStream(runner));
        }
        if (printStdErr) {
            println(readEntireErrStream(runner));
        }
        code = exitCode(runner);
    }
    catch ex :{
        throw ex;
    }
    finally {
        killProcess(runner);
        return code;
    }
    return code;
}
