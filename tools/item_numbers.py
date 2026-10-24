#!/usr/bin/env python3
"""Item numbers for the rig tools: data/items/items.json and data/items/gathered.json merged into one name -> number table.
   A name or a number used in both tables (or twice in one) is an error: the rig stops instead of picking one.
   item_numbers.py NAME   prints the number (empty line when there is no such item); exit 3 on a duplicate."""
import json
import sys

TABLES = ("items", "gathered")


def _entries(node, found):
    if isinstance(node, dict):
        for key, value in node.items():
            if isinstance(value, dict) and "number" in value:
                found.append((key, value["number"]))
            else:
                _entries(value, found)


def load_numbers(root="data/items"):
    """name -> number over both tables; raises ValueError on a duplicate name or number."""
    numbers = {}
    owner = {}
    for table in TABLES:
        found = []
        with open("%s/%s.json" % (root, table), encoding="utf-8") as handle:
            _entries(json.load(handle), found)
        for name, number in found:
            if name in numbers:
                raise ValueError("duplicate item name %r (%s and %s)" % (name, owner[name], table))
            clash = [n for n, v in numbers.items() if v == number]
            if clash:
                raise ValueError("duplicate item number %s: %r (%s) and %r (%s)" % (number, clash[0], owner[clash[0]], name, table))
            numbers[name] = number
            owner[name] = table
    return numbers


if __name__ == "__main__":
    try:
        print(load_numbers().get(sys.argv[1], ""))
    except ValueError as error:
        print("item table error: %s" % error, file=sys.stderr)
        sys.exit(3)
