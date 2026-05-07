import pytest
from pid_engine.parser import RuleParser


SAMPLE = """{
  "version": "1.0",
  "rules": [
    {
      "name": "add",
      "type": "function",
      "params": { "a": "number", "b": "number" },
      "body": [{ "op": "+", "args": ["a", "b"] }]
    }
  ]
}"""


def test_parse_version():
    rs = RuleParser().parse_string(SAMPLE)
    assert rs.version == "1.0"


def test_parse_rules_count():
    rs = RuleParser().parse_string(SAMPLE)
    assert len(rs.rules) == 1


def test_parse_rule_name():
    rs = RuleParser().parse_string(SAMPLE)
    assert rs.rules[0].name == "add"


def test_parse_rule_params():
    rs = RuleParser().parse_string(SAMPLE)
    assert "a" in rs.rules[0].params
