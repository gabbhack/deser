import std/[options]

from ../magic/sharedutils {.all.} import maybePublic
from ../magic/ser/utils {.all.} import asAddr


template implSerializer*(selfType: typed{`type`}, public: static[bool] = false) {.dirty.} =
  bind
    maybePublic,
    Option,
    asAddr

  maybePublic(public):
    # implementation expected
    proc serializeBool(self: var selfType, value: bool)

    proc serializeInt8(self: var selfType, value: int8)
    proc serializeInt16(self: var selfType, value: int16)
    proc serializeInt32(self: var selfType, value: int32)
    proc serializeInt64(self: var selfType, value: int64)

    proc serializeUint8(self: var selfType, value: uint8)
    proc serializeUint16(self: var selfType, value: uint16)
    proc serializeUint32(self: var selfType, value: uint32)
    proc serializeUint64(self: var selfType, value: uint64)

    proc serializeFloat32(self: var selfType, value: float32)
    proc serializeFloat64(self: var selfType, value: float64)

    proc serializeChar(self: var selfType, value: char)
    proc serializeString(self: var selfType, value: string)

    proc serializeBytes(self: var selfType, value: openArray[byte])

    proc serializeNone(self: var selfType)
    proc serializeSome(self: var selfType, value: auto)

    proc serializeEnum(self: var selfType, value: enum)

    # proc serializeSeq(self: selfType, len: Option[int]): auto

    # proc serializeArray(self: selfType, len: static[int]): auto

    # proc serializeMap(self: selfType, len: Option[int]): auto

    # proc serializeStruct(self: selfType, name: static[string], len: static[int]): auto

    when defined(release):
      {.push inline.}

    proc collectSeq(self: var selfType, iter: auto) =
      when compiles(iter.len):
        let length = some iter.len
      else:
        let length = none int

      asAddr state, self.serializeSeq(length)

      for value in iter:
        state.serializeSeqElement(value)

      state.endSeq()
    
    proc collectMap(self: var selfType, iter: auto) =
      when compiles(iter.len):
        let length = some iter.len
      else:
        let length = none int
      
      asAddr state, self.serializeMap(length)

      for key, value in iter:
        state.serializeMapEntry(key, value)
      
      state.endMap()
    
    when defined(nimHasIterable):
      template collectSeq*[Value](self: var selfType, iter: iterable[Value]) =
        asAddr state, self.serializeSeq(none int)

        for value in iter:
          state.serializeSeqElement(value)

        state.endSeq()

      template collectMap*[Key; Value](self: var auto, iter: iterable[(Key, Value)]) =
        asAddr state, self.serializeMap(none int)

        for key, value in iter:
          state.serializeMapEntry(key, value)
        
        state.endMap()
    
    when defined(release):
      {.pop.}


template implSerializeSeq*(selfType: typed{`type`}, public: static[bool] = false) {.dirty.} =
  bind maybePublic

  maybePublic(public):
    proc serializeSeqElement(self: var selfType, value: auto)

    proc endSeq(self: var selfType)


template implSerializeArray*(selfType: typed{`type`}, public: static[bool] = false) {.dirty.} =
  bind maybePublic

  maybePublic(public):
    proc serializeArrayElement(self: var selfType, value: auto)

    proc endArray(self: var selfType)


template implSerializeMap*(selfType: typed{`type`}, public: static[bool] = false) {.dirty.} =
  bind maybePublic

  maybePublic(public):
    proc serializeMapKey(self: var selfType, key: auto)

    proc serializeMapValue(self: var selfType, value: auto)

    proc endMap(self: var selfType)

    when defined(release):
      {.push inline.}
    
    proc serializeMapEntry(self: var selfType, key: auto, value: auto) =
      self.serializeMapKey(key)
      self.serializeMapValue(value)

    when defined(release):
      {.pop.}


template implSerializeStruct*(selfType: typed{`type`}, public: static[bool] = false) {.dirty.} =
  bind maybePublic

  maybePublic(public):
    proc serializeStructField(self: var selfType, key: static[string], value: auto)

    proc endStruct(self: var selfType)
