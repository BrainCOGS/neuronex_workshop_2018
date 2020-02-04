# Inside workings of Julia wrapper around datajoint-python

The things that need to be done so as to use [PyCall.jl](https://github.com/JuliaPy/PyCall.jl) to wrap [datajoint](https://datajoint.io/) for Julia are reasonably light:

1. **Working with contexts and providing an equivalent to the Python @schema decorator for newly created table classes.**.  This is done in the function `d2jDecorate()`. The actual decoration needs to be done in Python itself, and the result of Python `locals()` variable listing needs to be explicitly passed to `schema` when creating a new table. (Schema uses that listing to resolve table references in dependencies across tables. In Python, even when `context=locals()` is not specified in the call to Schema, it can be inferred from the frame stack, but this does not work within `PyCall`, so it must be explicitly passed in.)
How to work with Python's `locals()` and contexts used by datajoint is perhaps the most complicated issue. It comes up
in `schema.spawn_missing_classes()` as well as in the `@schema` decorator.

2. **Reformatting reads from the database.** The results of `fetch()` come back as `PyObject`. They need to be turned into Julia format. This is done in the `d2j()` within `d2j.jl`. The function is recursive so that arbitrarily deep structures are fully decoded. The convenience methods `jfetch()` and `jfetch1()` are provided on tables to automatically do the `d2j` wrapping.

3. **Avoiding problems with stdin and stdout in Julia Jupyter notebooks.** In Julia Jupyter notebooks, Python's `stdin` and `stdout` are not the same as Julia's. This means that ordinary Python functions `print()`, `input()` and `getpass()` functions don't work (even while they work fine on the Julia REPL). To solve this, before the Python datajoint module is loaded, Python's `builtins.print()`, `builtins.input()`, and `getpass.getpass()` are overriden to now point to Julia versions of the same functions, now talking to Julia's `stdin` and `stdout`.  This solves a whole host of problems in a couple of lines.


4. **Using the DataJoint2Julia module's Python namespace.** The Python namespace being used is within the DataJoint2Julia module namespace. This means that calls to `dj.schema` and `dj.ERD()` need to be done _within_ the module's namespace, so that references to local Python variables can be adequately resolved.

There are others, but those are the main ones.
