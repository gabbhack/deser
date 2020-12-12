import anycase_fork

type
  RenameKind* = enum
    ##[
    Variants of cases.

    **rkNothing** - The default value in `renameAll <pragmas.html>`_. The name will not be changed.

    **rkCamelCase** - Any to camelCase.

    **rkSnakeCase** - Any to snake_case.

    **rkKebabCase** - Any to kebab-case.

    **rkPascalCase** - Any to PascalCase.

    **rkUpperSnakeCase** - Any to SNAKE_CASE.

    **rkUpperKebabCase** - Any to KEBAB-CASE
    ]##
    rkNothing,
    rkCamelCase,
    rkSnakeCase,
    rkKebabCase,
    rkPascalCase,
    rkUpperSnakeCase,
    rkUpperKebabCase

proc renamer*(x: string, rule: RenameKind): string {.compileTime.} =
  ## for internal use only
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
