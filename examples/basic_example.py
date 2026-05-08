"""Demonstrate the full JSON -> Lisp -> execute pipeline."""
from pid_engine import Engine

engine = Engine()

# --- V1 example (original skeleton) ---
lisp_code = engine.generate_only("rules/example.json")
print("=== Generated Lisp (V1) ===")
print(lisp_code)

print("\n=== Execution (V1) ===")
result = engine.run_file("rules/example.json", output_path="output/example.lisp")
print("Success:", result.success)
if result.output:
    print("Output:", result.output)
if result.error:
    print("Error:", result.error)

# --- V2 example ---
print("\n=== Generating PID V2 LISP ===")
lisp_v2 = engine.generate_v2_file(
    "rules/pid_test_v2_lines_1_28.json",
    "output/generated_v2.lsp",
)
print(f"Generated {len(lisp_v2.splitlines())} lines -> output/generated_v2.lsp")
print("First 10 lines:")
for line in lisp_v2.splitlines()[:10]:
    print(" ", line)
