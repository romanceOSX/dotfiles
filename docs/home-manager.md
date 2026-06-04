# Flakes

## What are flakes?
flake's declare inputs which point to other flakes living remotely, these
map 'input names' to 'references'

These inputs get fetched, evaluated, and passed to the output
function as a set of attributes, 'self' refers to the current flake


