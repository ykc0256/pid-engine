import json
from pathlib import Path
from dataclasses import dataclass, field


@dataclass
class Rule:
    name: str
    type: str
    params: dict = field(default_factory=dict)
    body: list = field(default_factory=list)


@dataclass
class RuleSet:
    version: str
    rules: list[Rule]
    metadata: dict = field(default_factory=dict)


class RuleParser:
    def parse_file(self, path: str | Path) -> RuleSet:
        with open(path, encoding="utf-8") as f:
            data = json.load(f)
        return self._parse(data)

    def parse_string(self, text: str) -> RuleSet:
        data = json.loads(text)
        return self._parse(data)

    def _parse(self, data: dict) -> RuleSet:
        rules = [
            Rule(
                name=r["name"],
                type=r["type"],
                params=r.get("params", {}),
                body=r.get("body", []),
            )
            for r in data.get("rules", [])
        ]
        return RuleSet(
            version=data.get("version", "1.0"),
            rules=rules,
            metadata=data.get("metadata", {}),
        )
