##[
`Deser` is a deserialization and serealization library.

Installation
******
`nimble install deser`

or

```nim
requires "nim >= 1.4.4, deser"
```

Design
******

Efficient
#################
`Deser` does not use reflection or type information at runtime. Instead, it uses Nim macros and templates to get information about types at compile-time.

But not all the work can be done at compile-time, read more about `overhead <#manual-overhead>`_


Easy to use
#################
`Deser` has a simple API for users and developers of data formats.

I'm a user
---------------
Set up the necessary `pragmas <#manual-pragmas>`_, take a third-party library (for example `deser_json <https://github.com/gabbhack/deser_json>`_) that implements the necessary data format, and use it.

I'm a data format developer
---------------
Look at the example implementation in `deser_json <https://github.com/gabbhack/deser_json>`_, read about `startDes <deser/des.html#startDes.m%2Ctyped%2Cuntyped>`_, `forDes <deser/des.html#forDes.m%2Cuntyped%2Cuntyped%2Ctyped%2Cuntyped>`_ and `forSer <deser/ser.html#forSer.m%2Cuntyped%2Cuntyped%2Ctyped%2Cuntyped>`_.


Functional
#################
You can use pragmas to manage the serialization and deserialization process.
- `Skip fields <#examples-skip-fields>`_
- `Flatten objects <#examples-object-flattening>`_
- `Convert types <#examples-convert-timestamp-to-time>`_
- `Object variants <#examples-object-variants>`_


Universal
#################
`Deser` is not limited to any data format, since it does not parse data. 
This is just a small layer between your objects and the specific implementation of the serializer.

Look at the `supported data formats <#manual-supported-data-formats>`_.



Manual
******

Supported data formats
#################
* **JSON** - `deser_json <https://github.com/gabbhack/deser_json>`_


Pragmas
#################
Pragmas are special templates that tell `deser` how to handle the current field or object.

You can find out about available pragmas and their behavior in the `pragma documentation <deser/pragmas.html>`_.


Overhead
#################
This section is about what overhead `deser` has at runtime.

TODO


Limitations
#################
- Limited support for reference objects
Due to some limitations from the Nim macro system, we can't get complete information about reference types. This prevents deser from getting instantiated types with generics objects.
To support reference types, format developers must dereference the object before passing it to the deser macros.

Deser supports reference objects as flat objects.

- No support for tuples yet
- Support only one `case` field per "level"


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
import deser

type
  User {.des, ser.} = object
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
  User {.des, ser.} = object
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
  Foo {.des, ser.} = object
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
By default, some JSON serializers serialize `None` as `null`. This meets the standard, but it doesn't always meet our expectations (because not all APIs respond correctly to null).

You can skip serialization of None values using the `skipSerializeIf <deser/pragmas.html#skipSerializeIf.t>`_ pragma.
`skipSerializeIf` expects a function that takes a value with the field type and returns bool.

```nim
import
  options,
  deser

type
  Message = object
    text {.skipSerializeIf(isNone).}: Option[string]
    photo {.skipSerializeIf(isNone).}: Option[Photo]
```


Object flattening
#################
Consider some api that returns a page with results and metadata about pagination.

```nim
import 
  macros, options,
  deser

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


Object variants
#################

Deser supports object variants with any nesting level. But only one `case` per level.


]##

import
  options,
  deser/[des, ser, pragmas, macro_utils, errors, results]

export des, ser, pragmas, macro_utils, errors, options, results
