module TestWrapper

import IO;
import List;
import String;
import util::Test;

int main(
    str projectName = "",
    str testModules = ""
    ) {
    list[str] failed = [];
    for (str mname <- split(" ", testModules)) {
        failed += [r.message | r:testResult(_, false, _) <- runTests(mname)];
    }

    if (failed != []) {
        println("<projectName>: <size(failed)> tests failed:");
    } else {
        println("<projectName>: all tests succeeded");
    }
    return size(failed);
}
