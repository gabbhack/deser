import
  times,
  deser, deser_json

proc fromOptionDateString(x: Option[string]): Option[DateTime] =
  if x.isSome():
    some(parse(x.get(), "yyyy-MM-dd"))
  else:
    none(DateTime)

proc toOptionDateString(x: Option[DateTime]): Option[string] =
  if x.isSome():
    some(x.get().format("yyyy-MM-dd"))
  else:
    none(string)

proc fromDateString(x: string): DateTime =
  parse(x, "yyyy-MM-dd")

proc toDateString(x: DateTime): string =
  x.format("yyyy-MM-dd")

type
  Data* {.des, ser.} = object
    shift: Shift
    balance*: float

  Shift* {.des, ser.} = object
    quoted*: bool
    date* {.serializeWith(toDateString), deserializeWith(
        fromDateString).}: DateTime
    description*: string
    start* {.serializeWith(toOptionDateString), deserializeWith(
        fromOptionDateString).}: Option[DateTime]
    finish* {.serializeWith(toOptionDateString), deserializeWith(
        fromOptionDateString).}: Option[DateTime]
    rate*: float
    qty: Option[float]
    id*: int64

let shift = Shift(
    quoted: true,
    date: parse("2000-01-01", "yyyy-MM-dd"),
    description: "abcdef",
    start: none(DateTime),
    finish: none(DateTime),
    rate: 462.11,
    qty: some(10.0),
    id: getTime().toUnix()
)


let data = Data(
    balance: 0.00,
    shift: shift
)

let js = data.toJson()
echo js
assert data == Data.fromJson(js)
