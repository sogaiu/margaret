# Manual Setup

The basic flow is:

* Install prerequisite tools
* Get `jeat`'s bits inside a target project
* Configure `jeat` for the target project
* Write some tests
* Try out the tests

Note that though `git subrepo` is used in the following, it should be
possible to use other methods (e.g. git submodules, git subtree,
"inlining" by copying, etc.).

0. Ensure [git-subrepo](https://github.com/ingydotnet/git-subrepo) is
   installed.

1. In the target project, use the `git subrepo clone` command to clone
   `janet-ex-as-tests` to a subdirectory named `jeat` of the target
   project.

    ```
    cd ~/src/target-project
    git subrepo clone https://github.com/sogaiu/janet-ex-as-tests jeat
    ```

2. Copy `jeat/jeat-from-jpm-test.janet` to the target project's `test`
   subdirectory.  This file is used to trigger `jeat` via `jpm test`.

    ```
    mkdir -p test
    cp jeat/jeat-from-jpm-test.janet test/
    ```

3. Copy `jeat/default.jeat.janet` as the file `.jeat.janet` to the
   target project's root directory.

    ```
    cp jeat/default.jeat.janet .jeat.janet
    ```

4. Edit `.jeat.janet` to specify target files and/or directories for
   for testing.  End result might be something like:

    ```janet
    (defn init
      []
      {# describes what to test - file and dir paths
       :jeat-target-spec
       ["spt"]
       # describes what to skip - file paths only
       #:jeat-exclude-spec
       #["spt/trace/theme.janet"]
       })
    ```

5. [Write some appropriate tests](./doc_test-writing-tips.md) if none
   exist yet.

   A simple test can be written by placing the following `(comment
   ...)` as a top-level form in a file that is the target of testing:

    ```janet
    (comment

      (+ 1 1)
      # =>
      2

      )
    ```

6. Try out the tests via `jpm`:

    ```
    jpm test
    ```

    or manually:

    ```
    janet jeat/make-and-run-tests.janet <target-file-or-dir>
    ```
