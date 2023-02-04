#[
The MIT License (MIT)

Copyright 2019 Konstantin Epishev <lamartire@gmail.com>
Copyright (c) 2020 Nikita Gabbasov <copyleft@sosus.org>

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
the Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
]#

from std/strutils import
  isUpperAscii,
  toLowerAscii,
  toUpperAscii,
  join,
  capitalizeAscii

from std/sequtils import
  map,
  concat

from deser/pragmas import
  RenameCase


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
  let
    parts = words(str)
    capitalizedParts = map(parts[1..parts.len - 1], capitalizeAscii)

  join(concat([parts[0..0], capitalizedParts]))

func kebab(str: string): string =
  join(words(str), "-")

func cobol(str: string): string =
   kebab(str).toUpperAscii()

func pascal(str: string): string =
  let
    parts = words(str)
    capitalizedParts = map(parts, capitalizeAscii)

  join(capitalizedParts)

func path(str: string): string =
  let parts = words(str)

  join(parts, "/")

func plain(str: string): string =
  let parts = words(str)

  join(parts, " ")

func train(str: string): string =
  let
    parts = words(str)
    capitalizedParts = map(parts, capitalizeAscii)

  join(capitalizedParts, "-")

func snake(str: string): string =
  let parts = words(str)

  join(parts, "_")

func upperSnake(str: string): string =
  snake(str).toUpperAscii()

func toCase*(str: string, renameCase: RenameCase): string =
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
