# PID Engine — JSON 스키마 설계

*작성일: 2026-05-08*

---

## 최상위 구조

```json
{
  "project":    { ... },
  "processes":  [ ... ],
  "structures": [ ... ],
  "machines":   [ ... ],
  "pipes":      [ ... ],
  "instruments":[ ... ]
}
```

---

## 1. project

프로젝트 메타 정보.

| 필드 | 타입 | 설명 |
|------|------|------|
| `name` | string | 프로젝트명 |
| `version` | string | 스키마 버전 |

---

## 2. processes

공정 목록. P&ID 배치 시 구역 구분의 기준이 된다.

| 필드 | 타입 | 설명 |
|------|------|------|
| `id` | string | 고유 식별자 (예: `"PROC-01"`) |
| `name` | string | 공정명 (예: `"유입펌프장"`) |
| `description` | string | 공정 설명 |

---

## 3. structures

구조물(조, 조, 수조 등) 목록.

| 필드 | 타입 | 설명 |
|------|------|------|
| `id` | string | 고유 식별자 (예: `"STR-01"`) |
| `code_key` | string | 심볼 코드 (예: `"S_COND01"`) |
| `name` | string | 구조물명 |
| `type` | string | 종류 (`"tank"`, `"chamber"`, `"basin"`, `"building"` 등) |
| `process_id` | string | 소속 공정 ID |
| `ports` | array | 배관 연결 포트 목록 |

### ports 항목

| 필드 | 타입 | 설명 |
|------|------|------|
| `id` | string | 포트 식별자 (예: `"IN1"`, `"OUT1"`) |
| `label` | string | 포트 명칭 |
| `direction` | string | `"in"` 또는 `"out"` |

---

## 4. machines

기계(펌프, 블로워, 믹서 등) 목록.

| 필드 | 타입 | 설명 |
|------|------|------|
| `id` | string | 고유 식별자 (예: `"MCH-01"`) |
| `code_key` | string | 심볼 코드 (예: `"M_PKA0102"`) |
| `tag` | string | 엔지니어링 태그 (예: `"P-001"`) |
| `name` | string | 기계명 |
| `type` | string | 종류 (`"pump"`, `"blower"`, `"mixer"`, `"screen"` 등) |
| `process_id` | string | 소속 공정 ID |
| `location` | object | 설치 위치 |
| `ports` | array | 배관 연결 포트 목록 (구조와 동일) |

### location 객체 — internal (구조물 내부)

| 필드 | 타입 | 설명 |
|------|------|------|
| `type` | string | `"internal"` |
| `structure_id` | string | 소속 구조물 ID |

### location 객체 — external (구조물 외부)

| 필드 | 타입 | 설명 |
|------|------|------|
| `type` | string | `"external"` |
| `process_id` | string | 소속 공정 ID |

---

## 5. pipes

배관 목록. 배관 하나는 두 연결점(from/to) 사이를 이으며, 부속품 정보를 포함한다.

| 필드 | 타입 | 설명 |
|------|------|------|
| `id` | string | 고유 식별자 (예: `"PIPE-01"`) |
| `media` | string | 이송 유체 (`"sewage"`, `"sludge"`, `"air"`, `"chemical"`, `"treated_water"`) |
| `size` | string | 관경 (예: `"DN200"`) |
| `from` | object | 출발 연결점 |
| `to` | object | 도착 연결점 |
| `tees` | array | 이 배관 위에 설치된 TEE 목록 (선택) |
| `from_accessories` | array | from 쪽 부속품 체인 (from에서 파이프 방향 순) |
| `to_accessories` | array | to 쪽 부속품 체인 (파이프에서 to 방향 순) |
| `inline_accessories` | array | 배관 중간 설치 부속품 |

### from / to 객체

| 필드 | 타입 | 설명 |
|------|------|------|
| `type` | string | `"structure"`, `"machine"`, `"tee"` |
| `id` | string | 연결 대상 ID (`tee` 타입은 생략) |
| `port` | string | 포트 ID (`tee` 타입은 생략) |
| `pipe_id` | string | TEE가 속한 배관 ID (`tee` 타입만 사용) |
| `tee_id` | string | TEE ID (`tee` 타입만 사용) |

### tees 항목

3D에서 배관을 클릭해 TEE를 설치하는 방식 그대로, TEE는 특정 파이프에 종속된다.

| 필드 | 타입 | 설명 |
|------|------|------|
| `id` | string | TEE 식별자 (예: `"TEE-01"`) — 다른 배관의 `from`/`to`에서 참조 |

### 부속품 항목 (accessories item)

| 필드 | 타입 | 설명 |
|------|------|------|
| `code_key` | string | 심볼 코드 (예: `"P_VAV01"`, `"FIT_FLNG"`) |
| `tag` | string | 엔지니어링 태그 (선택) |

---

## 6. instruments

계측기 목록.

| 필드 | 타입 | 설명 |
|------|------|------|
| `id` | string | 고유 식별자 (예: `"INST-01"`) |
| `tag` | string | 계측기 태그 (예: `"FT-001"`) |
| `type` | string | 계측기 종류 (`"flow_transmitter"`, `"level_transmitter"`, `"pressure_transmitter"` 등) |
| `installation` | object | 설치 방식 |

### installation 객체 — inline 타입 (배관 설치)

| 필드 | 타입 | 설명 |
|------|------|------|
| `type` | string | `"inline"` |
| `pipe_id` | string | 설치된 배관 ID |

### installation 객체 — attached 타입 (구조물/기계 부착)

| 필드 | 타입 | 설명 |
|------|------|------|
| `type` | string | `"attached"` |
| `target_type` | string | `"structure"` 또는 `"machine"` |
| `target_id` | string | 부착 대상 ID |

---

## 미디어(media) 코드표

| 코드 | 유체 |
|------|------|
| `sewage` | 오수 |
| `sludge` | 슬러지 |
| `air` | 공기 |
| `chemical` | 약품 |
| `treated_water` | 처리수 |

---

## ID 명명 규칙

| 종류 | 접두어 | 예시 |
|------|--------|------|
| Process | `PROC-` | `PROC-01` |
| Structure | `STR-` | `STR-01` |
| Machine | `MCH-` | `MCH-01` |
| TEE | `TEE-` | `TEE-01` |
| Pipe | `PIPE-` | `PIPE-01` |
| Instrument | `INST-` | `INST-01` |
