"""
sample JSON 유효성 검증 스크립트
사용법: python scripts/validate_json.py schema/sample_real_01.json
"""

import json
import sys

VALID_MEDIA = {"sewage", "sludge", "air", "chemical", "treated_water"}


def validate(filepath):
    with open(filepath, encoding="utf-8") as f:
        data = json.load(f)

    errors = []
    warnings = []

    # 엔티티 맵 구성
    structures = {s["id"]: s for s in data.get("structures", [])}
    machines   = {m["id"]: m for m in data.get("machines", [])}
    pipes      = {p["id"]: p for p in data.get("pipes", [])}

    def get_port_map(entity_id, entity_type):
        entity = structures.get(entity_id) if entity_type == "structure" else machines.get(entity_id)
        if entity is None:
            return None
        return {p["id"]: p for p in entity.get("ports", [])}

    # ── 파이프 검증 ──────────────────────────────────────────
    for pipe in data.get("pipes", []):
        pid = pipe.get("id", "?")

        # 1. media 유효성
        media = pipe.get("media")
        if media not in VALID_MEDIA:
            errors.append(f"[{pid}] 유효하지 않은 media: '{media}'")

        # 2. from / to 검증
        for side_name, side in [("from", pipe.get("from", {})), ("to", pipe.get("to", {}))]:
            t = side.get("type")

            if t in ("structure", "machine"):
                eid     = side.get("id")
                port_id = side.get("port")

                # 엔티티 존재 여부
                pool = structures if t == "structure" else machines
                if eid not in pool:
                    errors.append(f"[{pid}] {side_name}.id '{eid}' — {t} 없음")
                    continue

                # port 존재 여부
                port_map = get_port_map(eid, t)
                if port_id not in port_map:
                    errors.append(f"[{pid}] {side_name} '{eid}'에 port '{port_id}' 없음")
                    continue

                # direction 일관성
                direction = port_map[port_id].get("direction")
                if side_name == "from" and direction != "out":
                    warnings.append(f"[{pid}] from port '{eid}.{port_id}' direction='{direction}' (out 이어야 함)")
                if side_name == "to" and direction != "in":
                    warnings.append(f"[{pid}] to port '{eid}.{port_id}' direction='{direction}' (in 이어야 함)")

            elif t == "tee":
                ref_pipe_id = side.get("pipe_id")
                tee_id      = side.get("tee_id")

                # 참조 파이프 존재 여부
                if ref_pipe_id not in pipes:
                    errors.append(f"[{pid}] {side_name}.pipe_id '{ref_pipe_id}' — 파이프 없음")
                    continue

                # tee_id 존재 여부
                tee_ids = [tee["id"] for tee in pipes[ref_pipe_id].get("tees", [])]
                if tee_id not in tee_ids:
                    errors.append(f"[{pid}] {side_name}.tee_id '{tee_id}' — '{ref_pipe_id}'의 tees에 없음")

        # 3. tees에 선언된 TEE가 다른 파이프에서 실제로 참조되는지 (경고)
        for tee in pipe.get("tees", []):
            tee_id = tee["id"]
            referenced = any(
                (p.get("from", {}).get("tee_id") == tee_id or
                 p.get("to",   {}).get("tee_id") == tee_id)
                for p in data.get("pipes", [])
            )
            if not referenced:
                warnings.append(f"[{pid}] tee '{tee_id}' 선언됐지만 어떤 파이프도 참조하지 않음")

    return errors, warnings


def main():
    filepath = sys.argv[1] if len(sys.argv) > 1 else "schema/sample_real_01.json"

    print(f"검증 대상: {filepath}\n")
    errors, warnings = validate(filepath)

    if warnings:
        print(f"[경고] {len(warnings)}건")
        for w in warnings:
            print(f"  {w}")
        print()

    if errors:
        print(f"[오류] {len(errors)}건")
        for e in errors:
            print(f"  {e}")
        sys.exit(1)
    else:
        print(f"[OK] 오류 없음 (경고 {len(warnings)}건)")


if __name__ == "__main__":
    main()
