import std/[algorithm, random, tables]

## OrderedTableRef ##

iterator view*[A, B](a: OrderedTableRef[A, B]): B =
  discard

proc `high`*[A, B](a: OrderedTableRef[A, B]): int =
  ## Returns number of keys in the table.
  result = len(a) - 1

proc getPosition*[A, B](a: OrderedTableRef[A, B], pos: int): B =
  a.sort(system.cmp, SortOrder.DESCENDING)
  var count = pos
  for x in a.values:
    if count == 0:
      return x
    count -= 1
  raise newException(IndexDefect, "Index out of bounds")

proc getFirst*[A, B](a: OrderedTableRef[A, B]): B =
  getPosition(a, 0)

proc getRand*[A, B](a: OrderedTableRef[A, B]): B =
  getPosition(a, rand(a.len))
