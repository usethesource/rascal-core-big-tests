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

RascalCompilerConfig config(PathConfig original) = getRascalCoreCompilerConfig(original[resources = original.bin]);

bool isIgnored(loc f, list[loc] ignores)
    = size(ignores) > 0 && any(i <- ignores, relativize(i, f) != f);

int main(str job="", bool printWarnings=false) {
    return actualMain(readTextValueString(#lrel[str, PathConfig], fromBase64(job)), printWarnings);
}

int actualMain(lrel[str, PathConfig] pcfgs, bool printWarnings) {
    println("Received: <size(pcfgs)> jobs to check");
    messages = [];
    lrel[str name, int seconds, int errors] stats = [];
    int errors = 0;
    for (<n, p> <- pcfgs) {
        try {
            println("**** Building: <n>");

            rascalFiles = [*find(s, "rsc") | s <- p.srcs];
            rascalFiles = sort([f | f <- rascalFiles, !isIgnored(f, p.ignores)]);

            println("**** Found <size(rascalFiles)> rascal files");
            startTime = now();
            result = check(rascalFiles, config(p));
            stopTime = now();
            for (checked <- result) {
                messages += sort([<checked.src.top, m> | m <- checked.messages]);
                println("*** Messages in <checked.src>:");
                iprintln(checked.messages);
            }
            dur = stopTime - startTime;
            took = (dur.hours * 60 * 60) + (dur.minutes * 60) + dur.seconds;
            errorCount = (0 | it + 1 | /error(_,_) := result);
            println("*** <n> took <took>s and had <errorCount> errors");
            stats += <n, took, errorCount>;
        }
        catch ex: {
            errors += 1;
            messages += [|unknown:///error|, error("<n> crashed with <ex>", |unkown:///|)];
            println("<n> crashed with <ex>");
            stats += <n, 0, -1>;
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
        println("- <n> took <t>s (<t/60>m) with <e> errors");
    }
    return errors;
}
