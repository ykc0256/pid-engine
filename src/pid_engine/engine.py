from pathlib import Path
from .parser import RuleParser
from .generator import LispGenerator
from .runtime import Executor
from .runtime.executor import ExecutionResult


class Engine:
    def __init__(self, interpreter: str | None = None):
        self.parser = RuleParser()
        self.generator = LispGenerator()
        self.executor = Executor(interpreter)

    def run_file(self, json_path: str | Path, output_path: str | Path | None = None) -> ExecutionResult:
        ruleset = self.parser.parse_file(json_path)
        lisp_code = self.generator.generate(ruleset)

        if output_path:
            Path(output_path).write_text(lisp_code, encoding="utf-8")

        return self.executor.run(lisp_code)

    def run_string(self, json_text: str) -> ExecutionResult:
        ruleset = self.parser.parse_string(json_text)
        lisp_code = self.generator.generate(ruleset)
        return self.executor.run(lisp_code)

    def generate_only(self, json_path: str | Path) -> str:
        ruleset = self.parser.parse_file(json_path)
        return self.generator.generate(ruleset)
