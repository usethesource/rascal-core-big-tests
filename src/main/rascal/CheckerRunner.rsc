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
    int errors = 0;
    for (p <- pcfgs) {
        println("**** Building: <p.bin>");
        rascalFiles = [*find(s, "rsc") | s <- p.srcs];
        println("**** Found <size(rascalFiles)> rascal files");
        result = check(rascalFiles, config(p));
        println(result);
        for (checked <- result) {
            for (m <- checked.messages) {
                switch (m) {
                    case warning(str s, loc l): println("[WARN]: <l> <s>");
                    case error(str s, loc l): {
                        println("[ERR] <l> <s>");
                        errors += 1;
                    }
                }
            }
        }
    }
    return errors;
}