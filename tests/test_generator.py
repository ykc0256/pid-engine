from pid_engine.parser import RuleParser
from pid_engine.generator import LispGenerator


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


def test_generates_defun():
    rs = RuleParser().parse_string(SAMPLE)
    code = LispGenerator().generate(rs)
    assert "(defun add" in code


def test_generates_params():
    rs = RuleParser().parse_string(SAMPLE)
    code = LispGenerator().generate(rs)
    assert "(defun add (a b)" in code


def test_generates_body():
    rs = RuleParser().parse_string(SAMPLE)
    code = LispGenerator().generate(rs)
    assert "(+ a b)" in code
