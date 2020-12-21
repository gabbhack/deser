##[
`Deser` is a deserialization and serealization library.

Installation
******
`nimble install deser`

or

```nim
requires "nim >= 1.4.2, deser"
```

Design
******

Efficient
#################
`Deser` does not use reflection or type information at runtime. Instead, it uses the magic `fieldPairs <https://nim-lang.org/docs/iterators.html#fieldPairs.i%2CT>`_ iterator to get information about types at compile time.
The resulting code is very close to the code written manually.

This code
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
const key`gensym1 = "id"
echo t.id

const key`gensym2 = "text"
echo t.text
```

  Read more about `overhead <#manual-overhead>`_


Easy to use
#################
`Deser` has a simple API for users and developers of data formats.

I'm a user
---------------
Set up the necessary `pragmas <#manual-pragmas>`_, take a third-party library (for example `deser_json <https://github.com/gabbhack/deser_json>`_) that implements the necessary data format, and use it.

I'm a data format developer
---------------
Look at the example implementation in `deser_json <https://github.com/gabbhack/deser_json>`_, read about `forSerFields <#forSerFields.t%2Cuntyped%2Cuntyped%2C%2Cuntyped>`_ and `forDesFields <#forDesFields.t%2Cuntyped%2Cuntyped%2C%2Cuntyped>`_.


Functional
#################
You can use pragmas to manage the serialization and deserialization process.

`Deser` provides the ability to `skip the necessary fields <#examples-skip-fields>`_, `inline the keys <#examples-object-flattening>`_ of a child object in the parent, and apply various functions to the object's fields, for example, to `convert types <#examples-convert-timestamp-to-time>`_.


Universal
#################
`Deser` is not limited to any data format, since it does not parse. 
This is just a small layer between your objects and the specific implementation of the serializer.

Look at the `supported data formats <#manual-supported-data-formats>`_.



Manual
******

Supported data formats
#################
* **JSON** - `deser_json <https://github.com/gabbhack/deser_json>`_


Pragmas
#################
Pragmas are special templats that tell `deser` how to handle the current field or object.

You can find out about available pragmas and their behavior in the `pragma documentation <deser/pragmas.html>`_.


Pragmas prioritization
---------------
`Deser` applies pragmas according to this priority:
1. Pragmas from field
2. Pragmas from object
3. Pragmas from parent object


Overhead
#################
This section is about what overhead `deser` has at runtime.


Pragmas with overhead
---------------
Pragmas that have an overhead are listed here. 
For more information, see the documentation of the pragmas themselves.
* `deserializeWith <deser/pragmas.html#deserializeWith.t>`_


Limitations
#################
Due to the nature of templates and type instantiation, you will need to import the `macros <https://nim-lang.org/docs/macros.html>`_ module if you are using `forSerFields <#forSerFields.t%2Cuntyped%2Cuntyped%2C%2Cuntyped>`_ or `forDesFields <#forDesFields.t%2Cuntyped%2Cuntyped%2C%2Cuntyped>`_. 
`macros` may be required if the third-party generic function uses `forSerFields` or `forDesFields`.


Examples
******

Convert timestamp to Time
#################

`Deser` has `serializeWith <deser/pragmas.html#serializeWith.t>`_ and `deserializeWith <deser/pragmas.html#deserializeWith.t>`_ pragmas.
You can pass a function to them and it will be applied to the field value.

If you just change the value, then the argument and result of the function must have the same type, which must be equal to the field type.

But these pragmas can also be used for converting types.

You can pass a function to `serializeWith <deser/pragmas.html#serializeWith.t>`_ that expects a value with a *field type*, but returns a value with a *another type*. In this case, `deser` will call your function, where the value of the field will be the argument, and send the result of the function to the serializer.

In the case of `deserializeWith <deser/pragmas.html#deserializeWith.t>`_, you can pass a function that expects a *value of some type*, and returns the result with the *field type*. `Deser` tells the deserializer to search for the type specified in the function argument in the data. The function will be called with the found value, and the field will be assigned the result of the function.

Let's say that some API returns timestamp. Then we will have such an object:

```nim
type
  User = object
    created_at: int64
```
But it's more convenient for us to work with the `Time <https://nim-lang.org/docs/times.html#Time>`_ object from the standard times library.
Fortunately, the standard library provides us `toUnix <https://nim-lang.org/docs/times.html#toUnix%2CTime>`_ and `fromUnix <https://nim-lang.org/docs/times.html#fromUnix%2Cint64>`_ functions.

`toUnix` accepts a Time object and returns int64, so we need this function for serialization. After all, the API only accepts timestamp, and we have to make `Time` again ``int64``.

`fromUnix` accepts int64 and returns the `Time` that is necessary for deserialization.

Let's finally use them
```nim
import deser

type
  User = object
    created_at {.serializeWith(toUnix), deserializeWith(fromUnix).}: Time
```


Skip fields
#################

Skip fields on serializing or/and deserializing
---------------
You can skip serialization and deserialization of a field using the `skip <deser/pragmas.html#skip.t>`_ pragma:

```nim
import deser

type
  Foo = object
    ok: bool
    uselessField {.skip.}: string
```

You can skip only serialization or only deserialization of the field using `skipSerializing <deser/pragmas.html#skipSerializing.t>`_ and `skipDeserializing <deser/pragmas.html#skipDeserializing.t>`_:

```nim
import deser

type
  Foo = object
    ok: bool
    uselessOnDes {.skipDeserializing.}: string
    uselessOnSer {.skipSerializing.}: string
```

Skip None values
---------------
By default, some json serializers serialize `None` as `null`. This meets the standard, but it doesn't always meet our expectations (because not all APIs respond correctly to null).

You can skip serialization of None values using the `skipSerializeIf <deser/pragmas.html#skipSerializeIf.t>`_ pragma.
`skipSerializeIf` expects a function that takes a value with the field type and returns bool.

```nim
import options
import deser

type
  Message = object
    text {.skipSerializeIf(isNone).}: Option[string]
    photo {.skipSerializeIf(isNone).}: Option[Photo]
```

To write less code, you can apply this pragma to an object:

```nim
import options
import deser

type
  Message {.skipSerializeIf(isNone).}  = object
    text: Option[string]
    photo: Option[Photo]
```

`Deser` check at compile time which fields are suitable by type and apply the pragma only to them.


Object flattening
#################
Consider some api that returns a page with results and metadata about pagination.

```nim
import macros, options
import deser

type
  Items = object
    results: seq[Item]
    start: int
    limit: int
    next: Option[string]
    previous: Option[string]
  
  Users = object
    results: seq[User]
    start: int
    limit: int
    next: Option[string]
    previous: Option[string]
```

Different requests contain the same fields related to pagination. 
You can simplify the code by putting these fields in a separate object.

```nim
type
  Pagination = object
    start: int
    limit: int
    next: Option[string]
    previous: Option[string]
```

You can now use this object in all pagination-related queries. The `flat <deser/pragmas.html#flat.t>`_ pragma will help with this.

```nim
import macros, options
import deser

type
  Pagination = object
    start: int
    limit: int
    next: Option[string]
    previous: Option[string]

  Items = object
    results: seq[Item]
    pagination {.flat.}: Pagination
  
  Users = object
    results: seq[User]
    pagination {.flat.}: Pagination
```

`flat` objects can be nested as many times as you want.

```nim
import macros, options
import deser

type
  PaginationUrls = object
    next: Option[string]
    previous: Option[string]

  Pagination = object
    start: int
    limit: int
    urls {.flat.}: PaginationUrls

  Items = object
    results: seq[Item]
    pagination {.flat.}: Pagination
  
  Users = object
    results: seq[User]
    pagination {.flat.}: Pagination
```

]##

import deser/[hacks, pragmas, templates, utils]
export hacks, pragmas, templates, utils

template forSerFields*(key: untyped, value: untyped, inOb: object | tuple | ref,
    actions: untyped) =
  ##[
    Data format developers should use this during serialization instead of `fieldPairs <https://nim-lang.org/docs/iterators.html#fieldPairs.i%2CT>`_

    In contrast to the `fieldPairs`, supports ref types.

    **Limitations**:
    Since this is just a template, you need to import the `macros <https://nim-lang.org/docs/macros.html>`_ module
  ]##
  runnableExamples:
    import macros
    import deser
    type
      Foo = object
        id: int
    let f = Foo(id: 123)
    forSerFields(k, v, f):
      echo k, " ", v
  actualForSerFields(`key`, `value`, `inOb`, `actions`, (), rkNothing, ())

template forDesFields*(key: untyped, value: untyped, inOb: var object |
    var tuple | ref, actions: untyped) =
  ##[
    Data format developers should use this during deserialization instead of fieldPairs.

    In contrast to the `fieldPairs`, supports ref types.

    **Limitations**:
    Since this is just a template, you need to import the `macros <https://nim-lang.org/docs/macros.html>`_ module
  ]##
  runnableExamples:
    import macros
    import deser
    type
      Foo = object
        id: int
    var f = Foo()
    forDesFields(k, v, f):
      echo k
      v = 123
    echo f.id
  actualForDesFields(`key`, `value`, `inOb`, `actions`, rkNothing, ())
