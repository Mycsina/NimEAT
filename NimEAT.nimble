# Package

version       = "0.1.0"
author        = "mycsina"
description   = "NEAT (NeuroEvolution of Augmenting Topologies) implementation in Nim"
license       = "MIT"
srcDir        = "."
bin           = @["xor_example"]

# Dependencies

requires "nim >= 2.0.0"
requires "nimgraphviz >= 0.1.0"

# Tasks

task test, "Run all tests":
  for testDir in ["genotype", "network", "species", "population", "mutations", "params", "serialization", "integration"]:
    let testPath = "tests/" & testDir
    for file in listFiles(testPath):
      if file.endsWith(".nim"):
        echo "Running: " & file
        exec "nim c -r " & file

task testFast, "Run unit tests only (no integration)":
  for testDir in ["genotype", "network", "species", "population"]:
    let testPath = "tests/" & testDir
    for file in listFiles(testPath):
      if file.endsWith(".nim"):
        echo "Running: " & file
        exec "nim c -r " & file

task bench, "Run benchmarks":
  exec "nim c -d:release -r tests/benchmarks/bench_evolution.nim"

task runxor, "Run XOR example":
  exec "nim c -d:release -r xor_example.nim"

task clear, "Clear binaries and text files":
  exec "rm -f xor_example"
  # Clean up test binaries
  for testDir in ["genotype", "network", "species", "population", "mutations", "integration", "benchmarks"]:
    let testPath = "tests/" & testDir
    for file in listFiles(testPath):
      if file.endsWith(".nim"):
        let binary = file[0 .. ^5] # Remove .nim extension
        exec "rm -f " & binary
  # Clean up data files
  exec "rm -f *.txt"
  exec "rm -f *.json"
  exec "rm -f *.png"
