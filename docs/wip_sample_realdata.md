# 실제 샘플 데이터 수집 (작업 중)

*최종 업데이트: 2026-05-08*

> 다음 작업: 이 문서를 기반으로 `schema/sample_real_01.json` 작성
> 미완료 항목: 관경(pipe size), 계측기(현재 없음)

---

## 1. 공정 (Processes)

| ID | 명칭 |
|----|------|
| PROC-A | A공정 |
| PROC-B | B공정 |

---

## 2. 구조물 (Structures)

| ID | code_key | 공정 | 명칭 |
|----|----------|------|------|
| STR-A01 | S_COND01 | PROC-A | 조정조 A-1 |
| STR-A02 | S_COND01 | PROC-A | 조정조 A-2 |
| STR-B01 | S_COND01 | PROC-B | 조정조 B-1 |

구조물 포트 부속품 (공통): `P_VAV01 → FIT_FLNG`

---

## 3. 기계 (Machines)

### A공정 — 외부 (external)

| code_key | 수량 | 유체 | 비고 |
|----------|------|------|------|
| M_VAV0101 | 2 | 원수 | |
| M_PKA0102 | 3 | 슬러지 | 펌프, group1 (1예비) |
| M_BRX01 | 2 | 슬러지 | 처리기계 |
| M_PKA0102 | 3 | 슬러지 | 펌프, group2 (1예비) |
| M_AEB0101 | 3 | 공기 | 송풍기 (1예비) |
| M_PKA0103 | 3 | 공기 | 송풍기 (1예비) |

### A공정 — 내부 (internal)

| 구조물 | code_key | 수량 |
|--------|----------|------|
| STR-A01 | M_FDC01 | 1 |
| STR-A01 | M_TDIF04 | 1 |
| STR-A02 | M_FDC01 | 1 |
| STR-A02 | M_TDIF04 | 1 |

### B공정 — 외부 (external)

| code_key | 수량 | 유체 | 비고 |
|----------|------|------|------|
| M_PMP0602 | 3 | 원수 | 펌프 |
| M_PMP0601 | 2 | 슬러지 | 펌프 |

---

## 4. 흐름 토폴로지 (Flow Topology)

### A공정 슬러지 순환

```
STR → [TEE패턴] → M_PKA0102(group1) → [TEE패턴] → M_BRX01 → [TEE패턴] → M_PKA0102(group2) → [TEE패턴] → STR
```

**TEE 패턴 (구조물2 ↔ 펌프3, 1예비) 반복 적용:**
```
STR-A01 ── PIPE ──(TEE-1)──────────────── PKA0102-1 (운전)
                     │
                   PIPE
                     │
                  (TEE-3) ──── PIPE ──── PKA0102-2 (예비)
                     │
                   PIPE
                     │
STR-A02 ── PIPE ──(TEE-2)──────────────── PKA0102-3 (운전)
```

*이 패턴이 각 연결 구간(STR→PKA, PKA→BRX, BRX→PKA, PKA→STR)에 동일하게 적용됨*

### A공정 공기

```
M_AEB0101 × 3 (1예비) ── [TEE패턴] ──► M_TDIF04 (STR 내부)
M_PKA0103 × 3 (1예비) ── [TEE패턴] ──► M_BRX01
```

### A공정 원수

```
M_FDC01 (내부) ── 1:1 직결 ──► M_VAV0101
```

### B공정 원수 (M_PMP0602 × 3)

```
PMP0602-1 ── PIPE ──(TEE-B1)── PIPE ──(TEE-B2)── PMP0602-3
                        │              │
                      PIPE           PIPE
                        │              │
                    PMP0602-2       STR-B01
```

### B공정 슬러지 (M_PMP0601 × 2)

```
STR-B01 ── PIPE ──(TEE-B3)── PIPE ── PMP0601-1
                      │
                    PIPE
                      │
                  PMP0601-2
```

---

## 5. 부속품 규칙 (Accessories Rules)

### 펌프류 (M_PMP0601, M_PMP0602, M_PKA0102)

| 구분 | 위치 | 부속품 (순서대로) |
|------|------|-----------------|
| 운전 흡입 | `to_accessories` | P_VAV07, P_VAV01, FIT_FLNG |
| 예비 흡입 | `to_accessories` | P_VAV07, FIT_FLNG |
| 운전 토출 | `from_accessories` | P_VAV07, P_VAV04, P_VAV01, FIT_FLNG |
| 예비 토출 | `from_accessories` | P_VAV07, P_VAV04, FIT_FLNG |

### 송풍기류 (M_AEB0101, M_PKA0103)

| 구분 | 위치 | 부속품 (순서대로) |
|------|------|-----------------|
| 운전 토출 | `from_accessories` | P_VAV07, P_VAV04, P_VAV03, FIT_FLNG |
| 예비 토출 | `from_accessories` | P_VAV07, P_VAV04, FIT_FLNG |

### TEE 간 배관 (inline_accessories)

| 라인 종류 | 부속품 |
|-----------|--------|
| 슬러지 / 원수 | FIT_FLNG, P_VAV01, FIT_FLNG |
| 공기 | FIT_FLNG, P_VAV04, FIT_FLNG |

### 부속품 code_key 코드표

| code_key | 종류 |
|----------|------|
| P_VAV01 | 게이트밸브 |
| P_VAV03 | 버터플라이밸브 |
| P_VAV04 | 체크밸브 |
| P_VAV07 | 플렉시블조인트 |
| FIT_FLNG | 플랜지 |

---

## 6. 계측기 (Instruments)

현재 없음 — 추후 추가 예정

---

## 7. 스키마 업데이트 필요 사항

- [x] 모든 엔티티에 `code_key` 필드 추가 (structures, machines, accessories)
- [x] 외부 기계 `location`: `structure_id` 제거, `process_id`만 유지
- [x] 부속품 `type` → `code_key` 로 변경
