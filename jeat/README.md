# janet-ex-as-tests (jeat)

intention is to use [jeat-tools](https://github.com/sogaiu/jeat-tools) for
installation, uninstallation, etc. tasks.

what follows are mostly notes atm.

## relevant files

### main bits

* `make-and-run-tests.janet` - drives the creating and running of tests

* `to-test.janet` - based on pieces below, used by make-and-run-tests.janet

* `loc-jipper.janet` - from janet-location-zipper
* `location.janet` - from janet-peg
* `zip-support.janet` and `zipper.janet` - from janet-zipper

* `default.jeat.janet` - sample conf file, when placed in root of project dir
                       should be named `.jeat.janet` or placed in a sub dir
                       named `.jeat` and arrange for appropriate importing
                       via a sibling file named `init.janet`

### conveniences

* `init.janet` - makes imports simpler

### integration with jpm

* `jeat-from-jpm-test.janet` - for integration with `jpm test`,
                             placed in a project's `test` subdir

## configuration per project

each project that uses jeat should have a configuration file for jeat
in the project's root directory.  the file should be named
`.jeat.janet` (or arrange for appropriate equivalent setup via a
`.jeat` directory with `init.janet`)

having a file makes writing upgrading / updating easier and can also
separate out project-specific details more clearly.

sample content for `.jeat.janet`:

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

if it exists, `.jeat.janet` is read by `make-and-run-tests.janet`

