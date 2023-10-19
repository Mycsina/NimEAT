import std/[algorithm, random, tables]

## OrderedTableRef ##

proc keysSnapshot*[A, B](a: OrderedTableRef[A, B]): seq[A] =
  ## Returns a static snapshot of the keys in the table.
  result = newSeqOfCap[A](a.len - 1)
  for x in a.keys:
    result.add(x)

proc valuesSnapshot*[A, B](a: OrderedTableRef[A, B]): seq[B] =
  ## Returns a static snapshot of the values in the table.
  result = newSeqOfCap[B](a.len - 1)
  for x in a.values:
    result.add(x)

proc getPosition*[A, B](a: OrderedTableRef[A, B], pos: int): B =
  ## Returns the value at the given position in the table.
  ## Expects the table to be sorted.
  var count = pos
  for x in a.values:
    if count == 0:
      return x
    count -= 1
  raise newException(IndexDefect, "Index out of bounds")

proc getFirst*[A, B](a: OrderedTableRef[A, B]): B =
  getPosition(a, 0)

proc getRand*[A, B](a: OrderedTableRef[A, B]): B =
  getPosition(a, rand(a.len - 1))
