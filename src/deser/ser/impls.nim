## Implementation of `serialize` for std types.

import std/[options, typetraits, tables, sets]

from ../magic/ser/utils {.all.} import asAddr


when defined(release):
  {.push inline.}
# Basic types
proc serialize*(self: bool, serializer: var auto) =
  mixin serializeBool

  serializer.serializeBool(self)


proc serialize*(self: SomeInteger, serializer: var auto) =
  mixin
    serializeInt8,
    serializeInt16,
    serializeInt32,
    serializeInt64,
    serializeUint8,
    serializeUint16,
    serializeUint32,
    serializeUint64

  when self is int8:
    serializer.serializeInt8(self)
  elif self is int16:
    serializer.serializeInt16(self)
  elif self is int32:
    serializer.serializeInt32(self)
  elif self is int64 | int:
    serializer.serializeInt64(self)
  elif self is uint8:
    serializer.serializeUint8(self)
  elif self is uint16:
    serializer.serializeUint16(self)
  elif self is uint32:
    serializer.serializeUint32(self)
  elif self is uint64 | uint:
    serializer.serializeUint64(self)


proc serialize*(self: SomeFloat, serializer: var auto) =
  mixin
    serializeFloat32,
    serializeFloat64

  when self is float32:
    serializer.serializeFloat32(self)
  else:
    serializer.serializeFloat64(self)


proc serialize*(self: string, serializer: var auto) =
  mixin serializeString

  serializer.serializeString(self)


proc serialize*[T: char](self: T, serializer: var auto) =
  mixin serializeChar

  serializer.serializeChar(self)


proc serialize*[T: enum](self: T, serializer: var auto) =
  mixin serializeEnum

  serializer.serializeEnum(self)


proc serialize*[T: set](self: T, serializer: var auto) =
  mixin collectSeq

  serializer.collectSeq(self)


proc serialize*(self: openArray[not byte], serializer: var auto) =
  mixin collectSeq

  serializer.collectSeq(self)


proc serialize*(self: openArray[byte], serializer: var auto) =
  mixin serializeBytes

  serializer.serializeBytes(self)


proc serialize*(self: tuple, serializer: var auto) =
  mixin
    serializeArray,
    serializeArrayElement,
    endArray

  asAddr state, serializer.serializeArray(self.tupleLen())

  for value in self.fields:
    state.serializeArrayElement(value)

  state.endArray()


# other std types
proc serialize*(self: Option, serializer: var auto) =
  mixin
    serializeSome,
    serializeNone

  if self.isSome:
    serializer.serializeSome(self.unsafeGet)
  else:
    serializer.serializeNone()


proc serialize*[SomeTable: Table | OrderedTable](self: SomeTable, serializer: var auto) =
  mixin collectMap

  serializer.collectMap(self)


proc serialize*(self: SomeSet, serializer: var auto) =
  mixin collectSeq

  serializer.collectSeq(self)


proc serialize*(self: ref, serializer: var auto) =
  mixin serialize

  serialize(self[], serializer)

when defined(release):
  {.pop.}
