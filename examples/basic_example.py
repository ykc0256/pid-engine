"""Demonstrate the full JSON -> Lisp -> execute pipeline."""
from pid_engine import Engine

engine = Engine()

lisp_code = engine.generate_only("rules/example.json")
print("=== Generated Lisp ===")
print(lisp_code)

print("\n=== Execution ===")
result = engine.run_file("rules/example.json", output_path="output/example.lisp")
print("Success:", result.success)
if result.output:
    print("Output:", result.output)
if result.error:
    print("Error:", result.error)
