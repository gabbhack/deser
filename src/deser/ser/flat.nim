## Private module for the `inlineKeys` pragma

import std/options


type
  FlatMapSerializer*[T] = object
    ser*: ptr T
  
  FlatMapSerializeMap*[T] = object
    ser*: ptr T

  FlatMapSerializeStruct*[T] = object
    ser*: ptr T
  
  FlatMapSerializeNamedTuple*[T] = object
    ser*: ptr T
  

proc `=copy`[T](x: var FlatMapSerializer[T], y: FlatMapSerializer[T]) {.error.}
proc `=copy`[T](x: var FlatMapSerializeMap[T], y: FlatMapSerializeMap[T]) {.error.}
proc `=copy`[T](x: var FlatMapSerializeStruct[T], y: FlatMapSerializeStruct[T]) {.error.}
proc `=copy`[T](x: var FlatMapSerializeNamedTuple[T], y: FlatMapSerializeNamedTuple[T]) {.error.}

{.push inline.}
## FlatMapSerializer
# Unsupported procedures
{.push error: "can ony flatten structs and maps".}
proc serializeBool*(self: FlatMapSerializer, v: bool)

proc serializeInt*[Value: SomeInteger](self: FlatMapSerializer, v: Value)

proc serializeFloat*[Value: SomeFloat](self: FlatMapSerializer, v: Value)

proc serializeChar*(self: FlatMapSerializer, v: char)

proc serializeBytes*(self: FlatMapSerializer, v: openArray[byte])

proc serializeSeq*(self: FlatMapSerializer, len: Option[uint]): FlatMapSerializer

proc serializeTuple*(self: FlatMapSerializer, len: static[uint]): FlatMapSerializer

proc serializeSeqMap*(self: FlatMapSerializer, len: Option[int]): FlatMapSerializer

proc serializeArray*(self: FlatMapSerializer, len: static[int]): FlatMapSerializer

# FlatMapSerializeSeq
proc serializeSeqElement*[Value](self: var FlatMapSerializer, v: Value)

proc endSeq*(self: FlatMapSerializer)

# FlatMapSerializeTuple
proc serializeTupleElement*[Value](self: var FlatMapSerializer, v: Value)

proc endTuple*(self: FlatMapSerializer)

# FlatMapSerializeSeqMap
proc serializeSeqMapKey*[T](self: FlatMapSerializer, key: T)

proc serializeSeqMapValue*[T](self: FlatMapSerializer, v: T)

proc endSeqMap*(self: FlatMapSerializer)

# FlatMapSerializeArray
proc serializeArrayElement*[T](self: FlatMapSerializer, v: T)

proc endArray*(self: FlatMapSerializer)
{.pop.}

proc serializeNone*(self: FlatMapSerializer) = discard

proc serializeSome*[Value](self: FlatMapSerializer, v: Value) = v.serialize(self)

proc serializeUnitStruct*(self: FlatMapSerializer) = discard

proc serializeUnitTuple*(self: FlatMapSerializer) = discard

proc serializeMap*[T](self: FlatMapSerializer[T]): FlatMapSerializeMap[T] =
  FlatMapSerializeMap[T](ser: self.ser)

proc serializeStruct*[T](self: FlatMapSerializer[T], name: static[string]): FlatMapSerializeStruct[T] =
  FlatMapSerializeStruct[T](ser: self.ser)

proc serializeNamedTuple*[T](self: FlatMapSerializer[T], name: static[string], len: static[uint]): FlatMapSerializeNamedTuple[T] =
  FlatMapSerializeNamedTuple[T](ser: self.ser)

# FlatMapSerializeMap
proc serializeMapKey*[Value](self: FlatMapSerializeMap, key: Value) =
  self.ser[].serializeMapKey(key)

proc serializeMapValue*[Value](self: FlatMapSerializeMap, v: Value) =
  self.ser[].serializeMapValue(v)

proc endMap*(self: FlatMapSerializeMap) = discard

# FlatMapSerializeStruct
proc serializeStructField*[Value](self: FlatMapSerializeStruct, key: static[string], v: Value) =
  self.ser[].serializeMapEntry(key, v)

proc endStruct*(self: FlatMapSerializeStruct) = discard

# FlatMapSerializeNamedTuple
proc serializeNamedTupleField*[Key, Value](self: FlatMapSerializeNamedTuple, key: Key, value: Value) =
  self.ser[].serializeNamedTupleField(key, value)

proc endNamedTuple*(self: FlatMapSerializeNamedTuple) = discard

{.pop.}
