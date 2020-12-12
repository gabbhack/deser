##[
``Deser`` is a deserialization and serealization library.

Design
******

Efficiency
#################
``Deser`` does not use reflection or type information at runtime. Instead, it uses the magic `fieldPairs <https://nim-lang.org/docs/iterators.html#fieldPairs.i%2CT>`_ iterator to get information about types at compile time.
The resulting code is very close to the code written manually. You can verify this yourself using `expandMacros <https://nim-lang.org/docs/macros.html#expandMacros.m%2Ctyped>`_.

This code:
```nim
import macros
import deser

type
  Test = object
    id: int
    text: string

let t = Test(id: 321, text: "123")

forSerFields(key, value, t):
  echo value
```

will be transformed at compile time into something like this:
```nim
var isSkip`gensym1 = false
if not isSkip`gensym1:
  const key = "id"
  echo t.id

var isSkip`gensym2 = false
if not isSkip`gensym2:
  const key = "text"
  echo t.text
```

The compiler is smart enough to omit unused constants and skip the `isSkip` check. `isSkip` is needed to check `skipSerializeIf` at runtime.


Easy to use
#################
``Deser`` is easy to use for both ordinary developers and developers of serializers for various data formats.

Ordinary developers only need to set up the necessary `pragmas <#manual-pragmas>`_, take a third-party library that implements the necessary data format, and use it.

In many existing serializers, developers widely use `fieldPairs <https://nim-lang.org/docs/iterators.html#fieldPairs.i%2CT>`_. Therefore, ``deser`` provides similar solutions: `forSerFields <#forSerFields.t%2Cuntyped%2Cuntyped%2C%2Cuntyped>`_ for serialization and `forDesFields <#forDesFields.t%2Cuntyped%2Cuntyped%2C%2Cuntyped>`_ for deserialization.

Functional
#################
You can use pragmas to manage the serialization and deserialization process.

``Deser`` provides the ability to skip the necessary fields, inline the keys of a child object in the parent, and apply various functions to the object's fields, for example, to convert types.

Manual
******

Pragmas
#################
Pragmas are special templats that tell ``deser`` how to handle the current field or object.

You can find out about available pragmas and their behavior in the `pragma documentation <deser/pragmas.html>`_.

Examples
******

Convert timestamp to Time
#################

``Deser`` has `serializeWith <deser/pragmas.html#serializeWith.t>`_ and `deserializeWith <deser/pragmas.html#deserializeWith.t>`_ pragmas.
You can pass a function to them and it will be applied to the field value.

If you just change the value, then the argument and result of the function must have the same type, which must be equal to the field type.

But these pragmas can also be used for converting types.

You can pass a function to `serializeWith <deser/pragmas.html#serializeWith.t>`_ that expects a value with a *field type*, but returns a value with a *another type*. In this case, `deser` will call your function, where the value of the field will be the argument, and send the result of the function to the serializer.

In the case of `deserializeWith <deser/pragmas.html#deserializeWith.t>`_, you can pass a function that expects a *value of some type*, and returns the result with the *field type*. In this case, `deser` tells the deserializer to search for the type specified in the function argument in the data. The function will be called with the found value, and the field will be assigned the result of the function.

Let's say that some API returns timestamp. Then we will have such an object:
```nim
type
  User = object
    created_at: int64
```
But it's more convenient for us to work with the `Time <https://nim-lang.org/docs/times.html#Time>`_ object from the standard times library.
Fortunately, the standard library provides us `toUnix <https://nim-lang.org/docs/times.html#toUnix%2CTime>`_ and `fromUnix <https://nim-lang.org/docs/times.html#fromUnix%2Cint64>`_ functions.

``toUnix`` accepts a Time object and returns int64, so we need this function for serialization. After all, the API only accepts timestamp, and we have to make `Time` again ``int64``.

``fromUnix`` accepts int64 and returns the Time that is necessary for deserialization.

Let's finally use them
```nim
type
  User = object
    created_at {.serializeWith(toUnix), deserializeWith(fromUnix).}: Time
```
]##

import deser/[hacks, pragmas, templates, utils]
export hacks, pragmas, templates, utils

template forSerFields*(key: untyped, value: untyped, inOb: object | tuple | ref, actions: untyped) =
  ## Data format developers should use this during serialization instead of fieldPairs
  runnableExamples:
    import macros
    type
      Foo = object
        id: int
    let f = Foo(id: 123)
    forSerFields(k, v, f):
      echo k, " ", v
  actualForSerFields(`key`, `value`, `inOb`, `actions`, (), (), ())

template forDesFields*(key: untyped, value: untyped, inOb: var object | var tuple | ref, actions: untyped) =
  ## Data format developers should use this during deserialization instead of fieldPairs
  runnableExamples:
    import macros
    type
      Foo = object
        id: int
    var f = Foo()
    forDesFields(k, v, f):
      echo k
      v = 123
    echo f.id
  actualForDesFields(`key`, `value`, `inOb`, `actions`, (), ())
