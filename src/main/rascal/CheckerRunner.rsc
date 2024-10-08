module CheckerRunner

import Message;
import IO;
import String;
import Set;
import List;
import Location;
import DateTime;
import ValueIO;
import util::Reflective;
import lang::rascalcore::check::Checker;
import util::FileSystem;

RascalCompilerConfig config(PathConfig original) = rascalCompilerConfig(original[resources = original.bin]);

bool isIgnored(loc f, list[loc] ignores)
    = size(ignores) > 0 && any(i <- ignores, relativize(i, f) != f);

int main(str job="", bool printWarnings=false, loc repoFolder = |unknown:///|) {
    return actualMain(readTextValueString(#lrel[str, PathConfig], fromBase64(job)), printWarnings, repoFolder);
}

int actualMain(lrel[str, PathConfig] pcfgs, bool printWarnings, loc repoFolder) {
    println("Received: <size(pcfgs)> jobs to check");
    messages = [];
    lrel[str name, int seconds, int errors] stats = [];
    int errors = 0;
    for (<n, p> <- pcfgs) {
        println("**** Building: <n>");

        projectRoot = repoFolder + n;
        rascalFiles = [*find(s, "rsc") | s <- p.srcs, startsWith(s.path, projectRoot.path)];
        rascalFiles = sort([f | f <- rascalFiles, !isIgnored(f, p.ignores)]);

        println("**** Found <size(rascalFiles)> rascal files");
        startTime = now();
        try {
            result = check(rascalFiles, config(p));
            stopTime = now();
            for (checked <- result) {
                messages += sort([<checked.src.top, m> | m <- checked.messages]);
                if (size(checked.messages) > 0) {
                    println("*** Messages in <checked.src>:");
                    iprintln(checked.messages);
                }
            }
            dur = stopTime - startTime;
            took = (dur.hours * 60 * 60) + (dur.minutes * 60) + dur.seconds;
            errorCount = (0 | it + 1 | /error(_,_) := result);
            println("*** <n> took <took>s and had <errorCount> errors");
            stats += <n, took, errorCount>;
        }
        catch ex: {
            dur = now() - startTime;
            errors += 1;
            messages += [|unknown:///error|, error("<n> crashed with <ex>", |unkown:///|)];
            println("<n> crashed with <ex>");
            took = (dur.hours * 60 * 60) + (dur.minutes * 60) + dur.seconds;
            stats += <n, took, -1>;
        }
    }
    println("**** Done running, now printing messages");
    for (<p, m> <- messages) {
        switch (m) {
            case warning(str s, loc l): if (printWarnings) println("[WARN]: <p>: <l> <s>");
            case error(str s, loc l): {
                println("[ERROR] <p>: <l> <s>");
                errors += 1;
            }
        }
    }
    println("**** stats:");
    for (<n, t, e> <- stats) {
        println("- <n> took <t>s (<t/60>m) with <e> <e == -1? "(CRASH)":""> errors");
    }
    return errors > 0 ? 1 : 0;
}
