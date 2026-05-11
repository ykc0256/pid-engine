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
| `id` | string | 포트 식별자 (예: `"IN1"`, `"OUT1"`) — CAD 블록 attribute TAG와 동일한 이름 사용 |
| `label` | string | 포트 명칭 |
| `direction` | string | `"in"` 또는 `"out"` |

> **CAD 연동 규칙**: `id` 값은 해당 CAD 블록 내 invisible attribute의 TAG 이름과 반드시 일치해야 한다. 포트 좌표는 JSON에 저장하지 않으며, CAD 블록 attribute의 삽입점(insertion point)이 노즐 좌표로 사용된다.

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
| `ports` | array | 배관 연결 포트 목록 (structures ports 항목과 동일, CAD 연동 규칙 동일 적용) |

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

---

## CAD 블록 설계 규칙

### 블록 이름

`code_key` 값을 CAD 블록 이름으로 사용한다.

| JSON 필드 | CAD 블록 |
|-----------|----------|
| `code_key: "M_PKA0102"` | 블록명: `M_PKA0102` |
| `code_key: "S_COND01"` | 블록명: `S_COND01` |
| `code_key: "P_VAV01"` | 블록명: `P_VAV01` |

### 노즐(포트) 표현 방식

각 블록 내부에 노즐 위치마다 **invisible attribute**를 배치한다.

| 항목 | 규칙 |
|------|------|
| Attribute TAG | JSON `port.id`와 동일 (`IN1`, `OUT1`, `IN2` 등) |
| Attribute 가시성 | **Invisible** (도면에 표시 안 됨) |
| 배치 위치 | 노즐 중심점에 정확히 클릭하여 배치 |
| 좌표 기준 | Attribute **삽입점(insertion point)** = 노즐 좌표 |

### 내부 기계 슬롯 표현 방식

구조물 블록 내부에 내부 기계의 삽입 위치를 나타내는 **슬롯 attribute**를 배치한다.

| 항목 | 규칙 |
|------|------|
| Attribute TAG | 내부 기계 `code_key`의 **DB `parent_key`** 값 사용 |
| Attribute 가시성 | **Invisible** |
| 배치 위치 | 해당 기계가 삽입될 위치에 정확히 배치 |
| 좌표 기준 | Attribute 삽입점 = 내부 기계 블록의 삽입 좌표 |

**예시:**

| 내부 기계 code_key | DB parent_key | 구조물 슬롯 TAG |
|--------------------|---------------|-----------------|
| `M_FDC01` | `M_FDCT` | `M_FDCT` |
| `M_FDC02` | `M_FDCT` | `M_FDCT` |
| `M_TDIF04` | `M_TDIF` | `M_TDIF` |

**LISP 흐름:**
```
① JSON에서 내부 기계 code_key 확인 (예: M_FDC01)
② DB 조회: M_FDC01의 parent_key = M_FDCT
③ 구조물 블록에서 TAG="M_FDCT" attribute 검색 → 삽입 좌표 획득
④ 해당 좌표에 M_FDC01 블록 삽입
```

### LISP 엔진의 좌표 추출 방식

```
① 블록 삽입 (레이아웃 규칙에 따라 결정된 위치에 배치)
② 블록 내 attribute 중 TAG = port.id 인 것 검색
③ 해당 attribute의 insertion point 추출 → 노즐 좌표
④ 노즐 좌표 기준으로 부속품 및 배관 연결
```

### 포트 이름 규칙

| 이름 | 의미 |
|------|------|
| `IN1`, `IN2`, ... | 유입 노즐 (복수일 경우 번호 부여) |
| `OUT1`, `OUT2`, ... | 유출 노즐 (복수일 경우 번호 부여) |
