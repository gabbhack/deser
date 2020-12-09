import anycase_fork

type
  RenameKind* = enum
    rkNothing,
    rkCamelCase,
    rkSnakeCase,
    rkKebabCase,
    rkPascalCase,
    rkUpperSnakeCase,
    rkUpperKebabCase

proc renamer*(x: string, rule: RenameKind): string {.compileTime.} =
  case rule
  of rkCamelCase:
      camel(x)
  of rkSnakeCase:
      snake(x)
  of rkKebabCase:
      kebab(x)
  of rkPascalCase:
      pascal(x)
  of rkUpperSnakeCase:
      upperSnake(x)
  of rkUpperKebabCase:
      cobol(x)
  else:
      x
