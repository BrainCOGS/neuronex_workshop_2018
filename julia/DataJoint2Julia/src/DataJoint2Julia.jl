module DataJoint2Julia

using PyCall
import Dates

export dj, d2j, julia_getpass, julia_input
export d2jDecorate, decorateMethod, pyLocals
export otherGuys

const dj             = PyNULL()
const origERD        = PyNULL()
const orig_spawn_missing_classes        = PyNULL()

decorateMethod             = PyNULL()
d2j_spawn_missing_classes  = PyNULL()
include("d2j.jl")

function pyLocals()
    return py"locals()"
end

"""
function d2jDecorate(dj_class_ex, schema)

Immediately after defining a table, put it through this function

"""
function d2jDecorate(dj_class_ex, schema)
   if typeof(dj_class_ex) != PyObject || dj_class_ex.__class__.__name__ != "OrderedClass"
      error("I only know how to deal with datajoint's PyObject OrderedClass members")
   end
   name = dj_class_ex.__name__

   if !schema.exists
       error("Schema $(schema.database) does not exist on the server")
   end

   py"""
   $$name = $schema($dj_class_ex, context=locals())
   """

   out = py"$$name"
   return out
end


############################################################
#
#  Decorating various DataJoint functions for Julia purposes
#
############################################################


# =========== decorating Python Class methods ===============


function declarePythonEnvironmentFunctions()
"""
Decoration of Python class Methods should happen within the Python
environment, because it is Python that knows that class Methods, when
called from an object, need to have self inserted as the first argument.

Since Julia doesn't have objects, it is much more complicated in Julia. Even in
Python, trying decorate bound methods upon instance creation sometimes works but
sometimes not: for example, it does not work for __call__() (upon decoration, of
an instance obj's __call__ method, obj() calls the UNdecorated method while
obj.__call__() calls the decorated method -- weird!)

Thus we use the following Python function to decorate Python class Methods
within Python.
"""

py"""
def __decorateMethod(origMethod, *, newMethod=None, preMethod=None, postMethod=None):
   '''decorateMethod(origMethod, *, newMethod=None, preMethod=None, postMethod=None):

   Python function:
   Decorates a class method, adding possible preprocessing and postprocessing.
   If there is no postprocessing, the output of the decorated method will be
   the original method's output. If there IS post-processing then the output
   of the decorated method will be the post-processing function's output

   :param     origMethod     The original class method to be decorated

   :kw_param  newMethod      If other than None, should be a function that can
                             take self, followed by whatever arguments origMethod
                             takes.  When this is not None, preMethod and postMethod
                             are ignored, and the final output of the decoratedMethod
                             is the output of newMethod

   :kw_param  preMethod      If other than None, should be a function that can
                             take self, followed by whatever arguments origMethod
                             takes. Any outputs from this function are ignored.

   :kw_param  postMethod     If other than None, should be a function that can
                             take self, followed by whatever output the origMethod
                             produced, followed by whatever further arguments
                             origMethod took. The output from this postMethod
                             function will become the decorated method's final
                             output

   :return                   the decorated Method

   EXAMPLE CALL (within Python environment):

      Example.method = __decorateMethod(Example.method_,  \
      preMethod =lambda self,      *args, **kwargs: print("I'm pre-decorated with self = ", self) \
      postMethod=lambda self, out, *args, **kwargs: print("I'm post-ddecorated with out = ", out))

   '''
   def decorated(self, *args, **kwargs):
      if newMethod != None:
          return newMethod(self, *args, **kwargs)

      if preMethod != None:
         preMethod(self, *args, **kwargs)
      out = origMethod(self, *args, **kwargs)
      if postMethod == None:
         return out
      else:
         newout = postMethod(self, out, *args, **kwargs)
         return newout

   return decorated

"""

end

function otherGuys()

py"""
def __d2j_spawn_missing_classes(self, *, ___context=None):
    '''
    doc for Schema.spawn_missing_classes() should go here

    Needs to be evaluated within the module to have access to
    all the Python vars in the modules namespace
    '''
    # We're going to be asking which local variables are
    # new; and we don't want to get confused with the variables
    # used inside this function (e.g. if a table has the same
    # name as one of these vars, that would be a problem). So
    # we use local variable names preceded by three underscores,
    # which is not part of the datajoint table naming conventions.
    ___oldlocal_keys = set(locals())
    if ___context==None:
        $orig_spawn_missing_classes(self, context=locals())
    else:
        $orig_spawn_missing_classes(self, context=___context)

    # After reading the resulting locals(), we're done, we
    # can create new variables after that without worrying about
    # name clashes
    newlocals = locals()
    newlocal_keys = set(newlocals)

    newkeys = set(newlocal_keys) - set(___oldlocal_keys)
    newkeys = newkeys - {'___context', '___oldlocal_keys'}

    difflocals = { k : newlocals[k] for k in newkeys }
    d2jc, expr = $d2jLocals(difflocals)
    return d2jc, expr

"""

end

function d2jLocals(locals::Dict)
    d2jclasses = Dict()
    expr    = ""
    for k in keys(locals)
        if typeof(k) <: String && typeof(locals[k]) <: PyObject &&
            locals[k].__class__.__name__ == "OrderedClass"
            d2jclasses[k] = locals[k]
            expr = expr * "$k = d2jclasses[\"$k\"]; "
        end
    end

    return d2jclasses, Meta.parse(expr)
end


# py"""
# def __replaceMethod(origMethod, newMethod):
#    '''decorateMethod(origMethod, newMethod):
#
#    Python function:
#    Replaces a class method.
#
#    :param     origMethod     The original class method to be decorated
#    :para      newMethod      Should be a function that can
#                              take self, followed by whatever arguments origMethod
#                              takes.  The final output of the replaced method
#                              will be the output of newMethod
#
#    :return                   the new Method
#
#    EXAMPLE CALL (within Python environment):
#
#       Example.method = __replaceMethod(Example.method_,  \
#       lambda self, *args, **kwargs: print("I'm repleced! self = ", self))
#
#    '''
#    def replacing(self, *args, **kwargs):
#        return newMethod(self, *args, **kwargs)
#
#    return replacing
#
# """






# =========== decorating functions ===============

"""
decorateFunction(origFunction; preFunction=None, postFunction=None):

Decorates a Julia function method, adding possible preprocessing and postprocessing.
If there is no postprocessing, the output of the decorated function will be
the original function's output. If there IS post-processing then the output
of the decorated function will be the post-processing function's output

:param     origFunction   The original function to be decorated

:kwparam   preFunction    If other than nothing, should be a function that can
                          take whatever arguments origFunction took.
                          Any outputs from this function are ignored.

:kwparam   postFunction   If other than nothing, should be a function that can
                          take whatever output the origFunction
                          produced, followed by whatever further arguments
                          origFunction took. The output from this postFunction
                          function will become the decorated function's final
                          output

:return                   the decorated function

EXAMPLE CALL:

   myfun = decorateFunction(myfun; preFunction = (vars... ; kwargs...) -> print("I'm pre-decorated"),
        postFunction=(out, vars... ; kwargs...) -> print("I'm post-decorated with out = ", out))

"""
function decorateFunction(originalFunction; preFunction=nothing, postFunction=nothing)
    function decorated(vars... ; kwargs...)
        if preFunction != nothing
            preFunction(vars... ; kwargs...)
        end
        out = originalFunction(vars... ; kwargs...)
        if postFunction==nothing
            return out
        else
            newout = postFunction(out, vars... ; kwargs...)
            return newout
        end
        return decorated
    end
end


"""
julia_input(prompt::String="")

prints the prompt to stdout, then waits for a response on console from user,
returns that string (leading and trailing whitespace removed)
"""
function julia_input(prompt::String="")
    print(prompt)
    return chomp(readline())
end


"""
julia_getpass(prompt::String="")

prints the prompt to stdout, then waits for a response on console from user,
as the user types that response is hiffen; returns the string typed in by the
user (leading and trailing whitespace removed)
"""
function julia_getpass(;prompt::String="Password")
    sb = Base.getpass(prompt)      # put user text into secret buffer
    ans = chomp(read(sb, String))  # turn that into a string
    Base.shred!(sb)    # thus losing all security, then shred secret buffer to rpevent warning message
    return ans
end
# And also allow the prompt as a positional argument
function julia_getpass(prompt::String)
    return julia_getpass(prompt=prompt)
end

"""
When evaluating the ERD, it should be done in the same Python namespace
(this module) where the schemas and tables were defined.
"""
function myERD(source)
    return py"$origERD($source)"
end



function __init__()
    pushfirst!(PyVector(pyimport("sys")."path"), "/Users/carlos/Github/datajoint/datajoint-python")

    # In Julia Jupyter notebooks, the Julia stdin and stdout are not
    # the same as the Python stdin stdout. So here we replace Python's
    # print, input, and getpass functions (which interact with stdin and
    # stdout) with Julia versions, so they work ok in Julia Jupyter notebooks.
    # These'll also work fine on the REPL.
    function myprint(vars...;kwargs...)
        # Uncomment next line for debugging
        # println("debugging-- in Julia myprint()")
        println(vars...;kwargs...)
    end
    builtins = pyimport("builtins")
    builtins.print = myprint  # could be println, but using this for debugging flexibility
    builtins.input = julia_input
    getpass  = pyimport("getpass")
    getpass.getpass = julia_getpass

    # We don't really need the following, we're not decorating any methods
    # any more, but here so we don't lose the knowledge of how to do it:
    declarePythonEnvironmentFunctions()
    copy!(decorateMethod, py"__decorateMethod")

    # When experimenting, we use our local datajoint. Remove the next
    # line to use the system datajoint.
    # pushfirst!(PyVector(pyimport("sys")."path"), "../../datajoint-python")

    # Next line is PyCall,jl trick for persistent variables in precompiled modules
    copy!(dj, pyimport("datajoint"))
    copy!(origERD, dj.ERD)

    # Evaluate ERD in Python namespace local to this module:
    dj.ERD = myERD

    # And evaluate spawn_missing_classes also in Python namespace local to this module
    copy!(orig_spawn_missing_classes, dj.schema.spawn_missing_classes)
    otherGuys()
    dj.schema.spawn_missing_classes = py"__d2j_spawn_missing_classes"
    #dj.schema.spawn_missing_classes = decorateMethod(dj.schema.spawn_missing_classes,
    #    newMethod = d2j_spawn_missing_classes);

    # Have jfetch() be the same as fetch() but wrapped with d2j()
    # We don't decorate the Fetch object's __call__ function directly
    # because fetch() is called internally a bunch of times, and those
    # internal calls should not go through d2j()
    py"""
    def __jfetch(self, *args, **kwargs):
       return $d2j(($dj.fetch.Fetch(self))(*args, **kwargs))
    setattr($dj.expression.QueryExpression, 'jfetch', __jfetch)

    # same for jfetch1() and fetch1()
    def __jfetch1(self, *args, **kwargs):
       return $d2j(($dj.fetch.Fetch1(self))(*args, **kwargs))
    setattr($dj.expression.QueryExpression, 'jfetch1', __jfetch1)

    """

end

end  # MODULE END
