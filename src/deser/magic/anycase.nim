import std/macros
from std/strutils import isUpperAscii, toLowerAscii, toUpperAscii, join, capitalizeAscii
from std/sequtils import map, concat


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


proc renameAllInRec(node: NimNode, to: RenameCase) =
  for i in node:
    case i.kind
    of nnkIdentDefs:
      case i[0].kind
      of nnkIdent:
        i[0] = nnkPragmaExpr.newTree(
          i[0],
          nnkPragma.newTree(
            newCall(
              ident "renamed",
              newLit i[0].strVal.toCase to
            )
          )
        )
      of nnkPragmaExpr:
        const blackList = ["renamed", "renameDeserialize", "renameSerialize"]
        block success:
          for pragma in i[0][1]:
            case pragma.kind
            of nnkIdent, nnkCall:
              let id =
                if pragma.kind == nnkIdent:
                  pragma
                else:
                  pragma[0]
              if id.strVal in blackList:
                break success
            else:
              expectKind pragma, {nnkIdent, nnkPragmaExpr}

          i[0][1].add newCall(
            ident "renamed",
            newLit i[0][0].strVal.toCase to
          )
      else:
        expectKind i[0], {nnkIdent, nnkPragmaExpr}
    of nnkRecCase:
      renameAllInRec i, to
    of nnkOfBranch:
      renameAllInRec i[1], to
    of nnkElse:
      renameAllInRec i[0], to
    of nnkNilLit:
      discard
    else:
      expectKind i, {nnkIdentDefs, nnkRecCase, nnkOfBranch, nnkElse, nnkNilLit}
{.pop.}
