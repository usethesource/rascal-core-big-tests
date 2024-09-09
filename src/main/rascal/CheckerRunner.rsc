module CheckerRunner

import Message;
import IO;
import String;
import Set;
import List;
import ValueIO;
import util::Reflective;
import lang::rascalcore::check::Checker;
import util::FileSystem;

RascalCompilerConfig config(PathConfig original) = getRascalCoreCompilerConfig(original[resources = original.bin]);

int main(str job="") {
    pcfgs = readTextValueString(#list[PathConfig], fromBase64(job));
    println("Received: <size(pcfgs)> jobs to check");
    messages = [];
    int errors = 0;
    for (p <- pcfgs) {
        println("**** Building: <p.bin>");
        rascalFiles = [*find(s, "rsc") | s <- p.srcs];
        println("**** Found <size(rascalFiles)> rascal files");
        result = check(rascalFiles, config(p));
        for (checked <- result) {
            messages += sort([<checked.src.top, m> | m <- checked.messages]);
        }
    }
    println("Done running, now printing messages");
    for (<p, m> <- messages) {
        switch (m) {
            case warning(str s, loc l): println("[WARN]: <p>: <l> <s>");
            case error(str s, loc l): {
                println("[ERROR] <p>: <l> <s>");
                errors += 1;
            }
        }
    }
    return errors;
}