# Using datajoint with Julia

This directory provides everything you need to get started using [DataJoint](https://datajoint.io/) from within the [Julia](https://julialang.org/) language.

It is a completed draft of taking the tutorial material from [Edgar Walker's Neuronexus 2018](../../..) tutorial workshop on [DataJoint](https://datajoint.io/) and translating it into something that can run within [Julia](https://julialang.org/) (with a very small bit of Julia code to help that happen). The first three tutorial notebooks [00-ConnectingToDatabase.ipynb](./00-ConnectingToDatabase.ipynb), [01-Getting started with DataJoint.ipynb](01-Getting%20started%20with%20DataJoint.ipynb), and [02-Imported and Computed Tables.ipynb](02-Imported%20and%20Computed%20Tables.ipynb) are enough to get you going. They roughly cover the same material as found in [DataJoint's main tutorial web pages ](https://tutorials.datajoint.io/beginner/building-first-pipeline/python/first-table.html), but now all within Julia.

The goal here is to be able to set up and work with DataJoint from Julia as quickly as possible. No attempts at elegance or efficiency are made. The main approach is to use Julia's [PyCall.jl](https://github.com/JuliaPy/PyCall.jl) package, which allows interoperability between Python and Julia, so as to make all the necessary Python function calls from within Julia. This has the advantage that the extra code is extremely slight-- the vast majority of the codebase needed to run in Julia is simply the already existing Python datajoint codebase.

While the elegance could be greater, [PyCall.jl](https://github.com/JuliaPy/PyCall.jl) is powerful enough that it works pretty well. People who want to live in Julia but interoperate with others using DataJoint with Matlab or Python will be able to do so.  

For example, **this datajoint Python code**

```
((Mouse() & 'dob = "2017-05-15"') * Session).fetch()
```

is functionally identical, and almost syntatically identical, to **this datajoint Julia code**

```
((Mouse() & "dob = '2017-05-15'") * Session).jfetch()
```

And **this datajoint Python code**
```
@schema
class Neuron(dj.Imported):
    definition = """
    -> Session
    ---
    activity: longblob    # electric activity of the neuron
    """
    def make(self, key):
        data_file = "data/data_{mouse_id}_{session_date}.npy".format(**key)
        data = np.load(data_file)
        key['activity'] = data
        self.insert1(key)
        print('Populated a neuron for mouse_id={mouse_id} on session_date={session_date}'.format(**key))
```

becomes this pretty similar **datajoint Julia code**

```
@pydef mutable struct Neuron <: dj.Imported
    definition = """
    -> Session
    ---
    activity: longblob    # electric activity of the neuron
    """
    
    function make(self, key)
        filename = "data/data_$(key["mouse_id"])_$(key["session_date"]).npy"
        key["activity"] = npzread(filename)
        self.insert1(key)
        println("Populated a neuron for mouse_id=$(key["mouse_id"]) on session_date=$(key["session_date"])")
    end
end
Neuron = d2jDecorate(Neuron, schema)
```

# Differences between use of datajoint in Python vs. Julia

* Use `@pydef` (as in the examples above) to declare new tables; use `d2jDecorate(MyTable, mySchema)` after declaring a table instead of preceding the declaration with `@mySchema`.
* Use `jfetch()` instead of `fetch()`
* Remember that in Julia, single quotes are for characters (`'c'`), not strings of more than one character. Hence `Mouse() & "dob = '2017-05-15'"` instead of `Mouse() & 'dob = "2017-05-15"``
* Instead of 
    
    `schema.spawn_missing_classes()`
    
 use 
 
    d2jclasses, expr = schema.spawn_missing_classes(); eval(expr)

# Known Issues

Not too many. All major known issues currently resolved. 

* To get `dj.ERD()` to display in Julia REPL or Python REPL (it works out of the box in Jupyter notebooks), add `.draw()` to the call, as in `dj.ERD(schema).draw()` ~displaying the ERD works in Julia Jupyter notebooks, but does not work in Julia REPL at terminal or Atom. (Currently it's not working for me in Python from the terminal either.)~ . 
* `schema.spawn_missing_classes()` doesn't quite work in Julia, needs fixing to address local context properly.
* Should add the Python docstrings to the Julia functions `dj.ERD()` and `jfetch()` and `jfetch1()`. And if a new `spawn_missing_classes()` is made, to that one, too.
* Add aliases for ERD, such as Diagram
* Python's errors and warnings probably also need to be redirected in Julia Jupyter notebooks (like `print()` and `input()` were).

## Improvements TO-DO

* DataJoint2Julia has only been tested on the material in the tutorials in the `julia` directory of this repo. Remains to be tested on further parts of datajoint.
* `d2j()` is probably not optimized for efficiency (neither in time nor memory space). Unclear whether that matters, though, since most of the time in fetching data from a table probably goes into accessing the server, not the `d2j` reformatting.
     
# Change Log

### 2020-01-23 Enormous code simplification, solving a whole host of issues.

* Julia's stdin and stdout on Jupyter notebooks not being the same as Python's stdin and stdout was causing problems in a ton of places, wherever text communication with the user was happening. The code got much simpler by overriding (before the Python datajoint module is imported), Python's `builtins.input`, `builtins.print` and `builtins.getpass` to Julia versions that talk to Julia's stdin and stdout.

### 2020-01-22

* important action: internally, `d2jDecorate()` now always call datajoint's `schema` with `context=locals()` explicitly defined. When this parameters is left empty, the `locals()` can be gleaned in Python, but could not be gleaned from within the `PyCall` Python environment, so we needed to specify them explicitly. Now done.
* Figured out how to decorate a Python `__call__` method from Julia, but that turns out not to be a good idea for `fetch()` because it is called internally so often. New `jfetch()` method implemented instead.  
* `d2jDecorate()` moved inside the Module: solution for `dj.ERD()` is to evaluate inside the module namespace.

### 2020-01-17

* Moved everything into a module, `DataJoint2Julia`, and now decorating the necessary datajoint Python functions so as to make it all more transparent to the user
* `d2j()` greatly improved, now fully recursive, uses multiple dispatch, and also covers `Dict()` cases
* decoration of tables with a schema, and `table.fetch()` decoration now all happen within a single call to `d2jDecorate()`
* `dj.conn()`, `schema.drop()` now decorated so dialog boxes are in Julia and don't crash in Julia Jupyter notebooks

