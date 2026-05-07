import subprocess
import shutil
import tempfile
from pathlib import Path
from dataclasses import dataclass


@dataclass
class ExecutionResult:
    success: bool
    output: str
    error: str


class Executor:
    """Runs generated Lisp code via an available Lisp interpreter."""

    INTERPRETERS = ["sbcl", "clisp", "ecl"]

    def __init__(self, interpreter: str | None = None):
        self.interpreter = interpreter or self._detect_interpreter()

    def run(self, lisp_code: str) -> ExecutionResult:
        if self.interpreter is None:
            return ExecutionResult(
                success=False,
                output="",
                error="No Lisp interpreter found. Install sbcl, clisp, or ecl.",
            )

        with tempfile.NamedTemporaryFile(
            suffix=".lisp", mode="w", delete=False, encoding="utf-8"
        ) as f:
            f.write(lisp_code)
            tmp_path = Path(f.name)

        try:
            result = subprocess.run(
                self._build_command(tmp_path),
                capture_output=True,
                text=True,
                timeout=30,
            )
            return ExecutionResult(
                success=result.returncode == 0,
                output=result.stdout.strip(),
                error=result.stderr.strip(),
            )
        except subprocess.TimeoutExpired:
            return ExecutionResult(success=False, output="", error="Execution timed out.")
        finally:
            tmp_path.unlink(missing_ok=True)

    def _build_command(self, path: Path) -> list[str]:
        if self.interpreter == "sbcl":
            return ["sbcl", "--script", str(path)]
        if self.interpreter == "clisp":
            return ["clisp", str(path)]
        return [self.interpreter, str(path)]

    def _detect_interpreter(self) -> str | None:
        for interp in self.INTERPRETERS:
            if shutil.which(interp):
                return interp
        return None
