module TestWrapper

import IO;
import List;
import String;
import util::Test;

int main(
    str testModules = ""
    ) {
    int result = 0;
    mnames = split(",", testModules);
    for (str mname <- mnames) {
        failed = [r.message | r:testResult(_, false, _) <- runTests(mname)];
        result += size(failed);

        for (m <- failed) {
            print(m);
        }
    }

    return result;
}
