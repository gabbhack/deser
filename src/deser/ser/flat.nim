## Private module for the `inlineKeys` pragma

import std/options


type
  FlatMapSerializer*[T] = object
    ser*: ptr T
  
  FlatMapSerializeMap*[T] = object
    ser*: ptr T

  FlatMapSerializeStruct*[T] = object
    ser*: ptr T
  

proc `=copy`[T](x: var FlatMapSerializer[T], y: FlatMapSerializer[T]) {.error.}
proc `=copy`[T](x: var FlatMapSerializeMap[T], y: FlatMapSerializeMap[T]) {.error.}
proc `=copy`[T](x: var FlatMapSerializeStruct[T], y: FlatMapSerializeStruct[T]) {.error.}

proc initFlatMapSerializer*[T](serializer: var T): FlatMapSerializer {.inline.} =
  result = FlatMapSerializer(ser: serializer.addr)

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

proc serializeNamedTuple*(self: FlatMapSerializer, name: static[string], len: static[uint]): FlatMapSerializer

# FlatMapSerializeSeq
proc serializeSeqElement*[Value](self: var FlatMapSerializer, v: Value)

proc endSeq*(self: FlatMapSerializer)

# FlatMapSerializeTuple
proc serializeTupleElement*[Value](self: var FlatMapSerializer, v: Value)

proc endTuple*(self: FlatMapSerializer)

# FlatMapSerializeNamedTuple
proc serializeNamedTupleField*[Key, Value](self: FlatMapSerializer, key: Key, value: Value)

proc endNamedTuple*(self: FlatMapSerializer)
{.pop.}

proc serializeNone*(self: FlatMapSerializer) = discard

proc serializeSome*[Value](self: FlatMapSerializer, v: Value) = v.serialize(self)

proc serializeStructUnit*(self: FlatMapSerializer) = discard

proc serializeTupleUnit*(self: FlatMapSerializer) = discard

proc serializeMap*(self: FlatMapSerializer): FlatMapSerializeMap = FlatMapSerializeMap(ser: self.ser)

proc serializeStruct*(self: FlatMapSerializer, name: static[string]): FlatMapSerializeStruct = FlatMapSerializeStruct(ser: self.ser)

# FlatMapSerializeMap
proc serializeMapKey*[Value](self: var FlatMapSerializeMap, key: Value) = self.ser[].serializeMapKey(key)

proc serializeMapValue*[Value](self: var FlatMapSerializeMap, v: Value) = self.ser[].serializeMapValue(v)

proc endMap*(self: FlatMapSerializeMap) = discard

# FlatMapSerializeStruct
proc serializeField*[Value](self: var FlatMapSerializeStruct, key: static[string], v: Value) = self.ser[].serializeMapEntry(key, v)

proc endStruct*(self: FlatMapSerializeStruct) = discard
{.pop.}
