import std/[options, typetraits, tables, sets]

import provided
import ../utils


{.push inline.}
# Basic types
proc serialize*[Serializer](self: bool, serializer: var Serializer) =
  serializer.serializeBool(self)

proc serialize*[Integer: SomeInteger, Serializer](self: Integer, serializer: var Serializer) =
  serializer.serializeInt(self)

proc serialize*[Float: SomeFloat, Serializer](self: Float, serializer: var Serializer) =
  serializer.serializeFloat(self)

proc serialize*[Serializer](self: string, serializer: var Serializer) =
  serializer.serializeString(self)

proc serialize*[Serializer](self: char, serializer: var Serializer) =
  serializer.serializeChar(self)

proc serialize*[Serializer](self: enum, serializer: var Serializer) =
  serializer.serializeString($self)

proc serialize*[Set: set, Serializer](self: Set, serializer: var Serializer) =
  serializer.collectSeq(self)

proc serialize*[Seq: seq or array; Serializer](self: Seq, serializer: var Serializer) =
  when self.type is array:
    when self.type.genericParams().get(1) is byte:
      serializer.serializeBytes(self)
    # example: {1: "one", 2: "two"}
    elif self.type.genericParams().get(1) is StaticParam:
      when self.type.genericParams().get(1).value.tupleLen == 2:
        asAddr state, serializer.serializeSeqMap(some self.len)
        for (key, value) in self:
          state.serializeSeqMapKey(key)
          state.serializeSeqMapValue(value)
        state.endSeqMap()
      else:
        asAddr state, serializer.serializeArray(self.len)
        for value in self:
          state.serializeArrayElement(value)
        state.endArray()
    else:
      asAddr state, serializer.serializeArray(self.len)
      for value in self:
        state.serializeArrayElement(value)
      state.endArray()
  else:
    when self.type.genericParams().get(0) is byte:
      serializer.serializeBytes(self)
    elif self.type.genericParams().get(0) is StaticParam:
      when self.type.genericParams().get(0).value.tupleLen == 2:
        asAddr state, serializer.serializeSeqMap(some self.len)
        for (key, value) in self:
          state.serializeSeqMapKey(key)
          state.serializeSeqMapValue(value)
        state.endSeqMap()
      else:
        serializer.collectSeq(self)
    else:
      serializer.collectSeq(self)

proc serialize*[Tuple: tuple, Serializer](self: Tuple, serializer: var Serializer) =
  when self.tupleLen == 0:
    serializer.serializeUnitTuple($self.type)
  elif Tuple.isNamedTuple():
    asAddr state, serializer.serializeNamedTuple($self.type, self.tupleLen())
    for key, value in self.fieldPairs():
      state.serializeNamedTupleField(key, value)
    state.endNamedTuple()
  else:
    asAddr state, serializer.serializeTuple($self.type, self.tupleLen())
    for value in self.fields():
      state.serializeTupleElement(value)
    state.endTuple()

proc serialize*[Unit: UnitConcept, Serializer](self: Unit, serializer: var Serializer) =
  serializer.serializeUnitStruct($self.type)

# other std types
proc serialize*[Value, Serializer](self: Option[Value], serializer: var Serializer) =
  if self.isSome:
    serializer.serializeSome(self.unsafeGet)
  else:
    serializer.serializeNone()

proc serialize*[SomeTable: Table | TableRef | OrderedTable | OrderedTableRef, Serializer](self: SomeTable, serializer: var Serializer) =
  serializer.collectMap(self)

proc serialize*[Set: SomeSet, Serializer](self: Set, serializer: var Serializer) =
  serializer.collectSeq(self)
{.pop.}
