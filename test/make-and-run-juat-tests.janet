(-> ["janet"
     "./janet-usages-as-tests/make-and-run-tests.janet"
     # specify file and/or directory paths relative to project root
     "./margaret/meg.janet"
     "./examples"
     ]
    (os/execute :p)
    os/exit)

