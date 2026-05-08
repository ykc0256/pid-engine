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

    def generate_v2_file(self, json_path: str | Path, output_path: str | Path) -> str:
        """Parse V2 PID JSON and generate LISP output file."""
        from .parser.pid_v2_parser import PIDV2Parser
        from .generator.pid_v2_generator import PIDV2Generator

        parser = PIDV2Parser()
        pid_data = parser.parse_file(json_path)

        # Find the reference file for template extraction
        ref_path = Path(json_path).parent.parent / "output" / "pid_test_v2_lines_1_28_jump_r3.lsp"

        generator = PIDV2Generator(reference_lsp_path=ref_path)
        lisp_code = generator.generate(pid_data)

        Path(output_path).write_text(lisp_code, encoding="utf-8")
        return lisp_code
