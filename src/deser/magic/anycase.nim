from std/strutils import
  isUpperAscii,
  toLowerAscii,
  toUpperAscii,
  join,
  capitalizeAscii

from std/sequtils import
  map,
  concat


type
  RenameCase* = enum
    CamelCase
    CobolCase
    KebabCase
    PascalCase
    PathCase
    SnakeCase
    PlainCase
    TrainCase
    UpperSnakeCase


{.push used, compileTime.}
func words(str: string): seq[string] =
  var
    newStr = ""
    waitStringEnd = false
  for ch in str:
    if waitStringEnd and (ch.isUpperAscii or ch in {'_', '-'}):
      waitStringEnd = false

      result.add newStr
      newStr.setLen 0
      if ch.isUpperAscii:
        newStr.add ch.toLowerAscii

    elif ch.isUpperAscii:
      waitStringEnd = true
      newStr.add ch.toLowerAscii

    else:
      waitStringEnd = true
      newStr.add ch

  if newStr.len != 0:
    result.add newStr


func camel(str: string): string =
  let parts = words(str)
  let capitalizedParts = map(parts[1..parts.len - 1], capitalizeAscii)

  result = join(concat([parts[0..0], capitalizedParts]))


func kebab(str: string): string =
  result = join(words(str), "-")


func cobol(str: string): string =
  result = kebab(str).toUpperAscii()


func pascal(str: string): string =
  let parts = words(str)
  let capitalizedParts = map(parts, capitalizeAscii)

  result = join(capitalizedParts)


func path(str: string): string =
  let parts = words(str)

  result = join(parts, "/")


func plain(str: string): string =
  let parts = words(str)

  result = join(parts, " ")


func train(str: string): string =
  let parts = words(str)
  let capitalizedParts = map(parts, capitalizeAscii)

  result = join(capitalizedParts, "-")


func snake(str: string): string =
  let parts = words(str)

  result = join(parts, "_")


func upperSnake(str: string): string =
  result = snake(str).toUpperAscii()


func toCase(str: string, renameCase: RenameCase): string =
  case renameCase
  of CamelCase:
    str.camel
  of CobolCase:
    str.cobol
  of KebabCase:
    str.kebab
  of PascalCase:
    str.pascal
  of PathCase:
    str.path
  of PlainCase:
    str.plain
  of SnakeCase:
    str.snake
  of TrainCase:
    str.train
  of UpperSnakeCase:
    str.upperSnake
{.pop.}
