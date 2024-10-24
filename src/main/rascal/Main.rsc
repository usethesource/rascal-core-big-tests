module Main

import String;
import IO;
import List;
import util::Reflective;
import util::SystemAPI;
import util::FileSystem;
import analysis::graphs::Graph;
import util::ShellExec;

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
    <"rascal-all", project(|https://github.com/usethesource/rascal.git|, {})>,
    <"typepal", project(|https://github.com/usethesource/typepal.git|, {"rascal"}, ignores={"examples"})>,
    <"typepal-boot", project(|https://github.com/usethesource/typepal.git|, {}, rascalLib=true, ignores={"examples"})>,
    <"salix-core", project(|https://github.com/usethesource/salix-core.git|, {"rascal"})>,
    <"salix-contrib", project(|https://github.com/usethesource/salix-contrib.git|, {"rascal", "salix-core"})>,
    <"flybytes", project(|https://github.com/usethesource/flybytes.git|, {"rascal"})>,
    //<"drambiguity", project(|https://github.com/cwi-swat/drambiguity.git|, {"rascal", "salix-core"})>,
    <"drambiguity", project(|https://github.com/SWAT-engineering/drambiguity.git|, {"rascal", "salix-core"}, branch="chore/update-rascal-dependencies")>,
    <"rascal-git", project(|https://github.com/cwi-swat/rascal-git.git|, {"rascal"})>,
    <"php-analysis", project(|https://github.com/cwi-swat/php-analysis.git|, {"rascal", "rascal-git"})>,
    <"rascal-core", project(|https://github.com/usethesource/rascal-core.git|, {"rascal", "typepal"}, branch="master")>,
    <"rascal-lsp-all", project(|https://github.com/usethesource/rascal-language-servers.git|, {"rascal", "typepal", "rascal-core"}, subdir="rascal-lsp")>,
    <"rascal-lsp", project(|https://github.com/usethesource/rascal-language-servers.git|, {"rascal"}, ignores={"lang/rascal/lsp/refactor", "lang/rascal/tests/rename"}, subdir="rascal-lsp")>
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

tuple[list[loc], list[loc]] calcSourcePaths(str name, Project proj, loc repoFolder) {
    loc projectRoot = (repoFolder + name) + proj.subdir;
    srcs = proj.srcs != [] ? [projectRoot + s |  s <- proj.srcs ] : getProjectPathConfig(projectRoot).srcs;
    ignores = [ s + i |  s<- srcs, i <- proj.ignores];
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
        srcs = srcs,
        ignores = ignores,
        bin = repoFolder + "shared-tpls",
        libs = [repoFolder + "shared-tpls"] + (proj.rascalLib ? [|lib://rascal/|] : [])
    );
}
PathConfig generatePathConfig(str name, Project proj, loc repoFolder, true) {
    <srcs, ignores> = calcSourcePaths(name, proj, repoFolder);
    return pathConfig(
        srcs = srcs,
        ignores = ignores,
        bin = tplPath(repoFolder, name),
        libs = [ tplPath(repoFolder, dep) | dep <- proj.dependencies ] + (proj.rascalLib ? [|lib://rascal/|] : [])
    );
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


int main(
    str memory = "4G",
    bool libs=true, // put the tpls of dependencies on the lib path
    bool update=false, // update all projects from remote
    bool printWarnings = false, // print warnings in the final overview
    bool full=true, // do a full clone
    bool clean=true, // do a clean of the to build folders
    loc repoFolder = |tmp:///repo/|,
    loc rascalVersion=|home:///.m2/repository/org/rascalmpl/rascal/0.40.7/rascal-0.40.7.jar|,
    loc typepalVersion=|home:///.m2/repository/org/rascalmpl/typepal/0.14.0/typepal-0.14.0.jar|,
    loc rascalCoreVersion=|home:///.m2/repository/org/rascalmpl/rascal-core/0.12.4/rascal-core-0.12.4.jar|,
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

    // build class path
    classPath = buildCP(typepalVersion, rascalCoreVersion, rascalVersion);



    println("*** Starting nested rascal call with supplied version ***");
    println(classPath);
    runner = createProcess("java", args=[
        "-Xmx<memory>",
        "-Drascal.monitor.batch", // disable fancy progress bar
        "-Drascal.compilerClasspath=<classPath>",
        "-cp", classPath,
        "org.rascalmpl.shell.RascalShell",
        "CheckerRunner",
        "--repoFolder", "<repoFolder>",
        "--job",
        toBase64("<pcfgs>"),
        *["--printWarnings" | true := printWarnings]
    ]);
    //], envVars=("TRACKIO" : "true"));

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
        println(readEntireStream(runner));
        println(readEntireErrStream(runner));
        result = exitCode(runner);
    }
    catch ex :{
        println("Running the runner crashed with <ex>");
        result += 1;
    }
    finally {
        killProcess(runner);
    }

    println("Nested runner is done, result: <result>");

    return result;
}
