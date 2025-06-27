module Main

import String;
import IO;
import List;
import Location;
import util::Reflective;
import util::SystemAPI;
import util::FileSystem;
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
        set[str] ignores = {} // directories to ignore
    );

alias Projects = rel[str name, Project config];

Projects projects = {
    <"rascal", project(|https://github.com/usethesource/rascal.git|, {}, srcs = ["src/org/rascalmpl/library"], ignores={"experiments", "resource", "lang/rascal/tests", "lang/rascal/syntax/test"})>,
    <"rascal-all", project(|https://github.com/usethesource/rascal.git|, {}, branch="compiled-parser-generator")>,
    <"typepal", project(|https://github.com/usethesource/typepal.git|, {"rascal"}, ignores={"examples"})>,
    <"typepal-boot", project(|https://github.com/usethesource/typepal.git|, {}, rascalLib=true, ignores={"examples"})>,
    <"salix-core", project(|https://github.com/usethesource/salix-core.git|, {"rascal"})>,
    <"salix-contrib", project(|https://github.com/usethesource/salix-contrib.git|, {"rascal", "salix-core"})>,
    <"flybytes", project(|https://github.com/usethesource/flybytes.git|, {"rascal"})>,
    <"drambiguity", project(|https://github.com/cwi-swat/drambiguity.git|, {"rascal", "salix-core"})>,
    <"rascal-git", project(|https://github.com/cwi-swat/rascal-git.git|, {"rascal"})>,
    <"php-analysis", project(|https://github.com/cwi-swat/php-analysis.git|, {"rascal", "rascal-git"})>,
    <"rascal-lsp-all", project(|https://github.com/usethesource/rascal-language-servers.git|, {"rascal-all"}, subdir="rascal-lsp", srcs=["src/main/rascal/library","src/main/rascal/lsp"])>,
    <"rascal-lsp", project(|https://github.com/usethesource/rascal-language-servers.git|, {"rascal"}, srcs=["src/main/rascal/library"], subdir="rascal-lsp")>
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



loc tplPath(loc repoFolder, str name) = (repoFolder + name) + "target/classes";

loc projectRoot(loc repoFolder, str name, Project proj) = (repoFolder + name) + proj.subdir;


tuple[list[loc], list[loc]] calcSourcePaths(str name, Project proj, loc repoFolder) {
    srcs = proj.srcs != [] ? [projectRoot(repoFolder, name, proj) + s |  s <- proj.srcs ] : getProjectPathConfig(projectRoot(repoFolder, name, proj)).srcs;
    ignores = [ s + i |  s<- srcs, s.scheme != "jar+file",  i <- proj.ignores];
    return <srcs, ignores>;
}

PathConfig generatePathConfig(str name, Project proj, loc repoFolder, false) {
    <srcs, ignores> = calcSourcePaths(name, proj, repoFolder);
    for (str dep <- proj.dependencies, <dep, projDep> <- projects) {
        <nestedSrcs, nestedIgnores> = calcSourcePaths(dep, projDep, repoFolder);
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
PathConfig generatePathConfig(str name, Project proj, loc repoFolder, true) {
    <srcs, ignores> = calcSourcePaths(name, proj, repoFolder);
    result = pathConfig(
        projectRoot = projectRoot(repoFolder, name, proj),
        srcs = srcs,
        ignores = ignores,
        bin = tplPath(repoFolder, name),
        libs = [ tplPath(repoFolder, dep) | dep <- proj.dependencies ] + (proj.rascalLib ? [|std:///|] : [])
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
    = size(ignores) > 0 && any(i <- ignores, relativize(i, f) != f);


int main(
    str memory = "4G",
    bool libs=true, // put the tpls of dependencies on the lib path
    bool update=false, // update all projects from remote
    bool full=true, // do a full clone
    bool clean=true, // do a clean of the to build folders
    loc repoFolder = |tmp:///repo/|,
    loc rascalVersion=|home:///.m2/repository/org/rascalmpl/rascal/0.41.0-RC46/rascal-0.41.0-RC46.jar|,
    set[str] tests = {/*all*/}
    ) {
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
    pcfgs = [<n, generatePathConfig(n, proj, repoFolder, libs)> | n <- buildOrder, proj <- toBuild[n]];


    if (clean) {
        for (<_, p> <- pcfgs) {
            for (f <- find(p.bin, "tpl")) {
                remove(f);
            }
        }
    }

    result = 0;

    lrel[str, int, int] stats = [];

    for (n <- buildOrder, proj <- toBuild[n]) {
        println("*** Preparing: <n>");
        p = generatePathConfig(n, proj, repoFolder, libs);
        if (clean) {
            for (f <- find(p.bin, "tpl")) {
                remove(f);
            }
        }
        println(p);
        loc projectRoot = repoFolder + n;
        rProjectRoot = resolveLocation(projectRoot);
        rascalFiles = [*find(s, "rsc") | s <- p.srcs, (startsWith(s.path, projectRoot.path) || startsWith(s.path, rProjectRoot.path))];
        rascalFiles = sort([f | f <- rascalFiles, !isIgnored(f, p.ignores)]);
        println("*** Starting: <n> (<size(rascalFiles)> to check)");
        startTime = realTime();
        runner = createProcess("java", args=[
            "-Xmx<memory>",
            "-Drascal.monitor.batch", // disable fancy progress bar
            "-Drascal.compilerClasspath=<buildFSPath(rascalVersion)>",
            "-cp", buildFSPath(rascalVersion),
            "org.rascalmpl.shell.RascalCompile",
            "-srcs", *[ "<s>" | s <- p.srcs],
            *["-libs" | p.libs != []], *[ "<l>" | l <- p.libs],
            "-bin", "<p.bin>",
            "-modules", *[ "<f>" | f <- rascalFiles]
        ]);
        try {
            while (isAlive(runner)) {
                stdOut = readWithWait(runner, 500);
                if (stdOut != "") {
                    print(stdOut);
                }
                stdErr = readFromErr(runner);
                while (stdErr != "") {
                    println(stdErr);
                    stdErr = readFromErr(runner);
                }
            }
            stopTime = realTime();
            println(readEntireStream(runner));
            println(readEntireErrStream(runner));
            code = exitCode(runner);
            result += code;
            println("*** Finished: <n> < code == 0 ? "✅" : "❌ Failed"> (<(stopTime - startTime)/1000>s)");
            stats += <n, code, (stopTime - startTime)/1000>;
        }
        catch ex :{
            println("Running the runner for <n> crashed with <ex>");
            result += 1;
        }
        finally {
            killProcess(runner);
        }
    }
    println("******\nDone running ");
    for (<n, e, t> <- stats) {
        println("- <n> <e == 0 ? "✅" : "❌"> <t>s");
    }
    return result;
}
