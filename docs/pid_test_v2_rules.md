# PID TEST V2 자동도면 LISP 엔진 상세 생성 규칙 최종 정리

## 0. 문서 목적

이 문서는 **도면 생성 TEST 엔진 개발 v2**의 현재 기준 규칙을 정리한 문서이다.

현재 목표는 다음이다.

```text
PID_TEST_V2 JSON
→ 공정별 instance 배치
→ 구조물/기계/구조물성 기계 배치
→ PORT/chain/TEE/ref 해석
→ 직각 배관 라우팅
→ 배관 교차 점프 표시
→ AutoCAD LISP 생성
```

이 문서는 다른 AI나 개발자가 같은 JSON을 받아도 동일한 도면 생성 로직을 구현할 수 있도록 세부 규칙을 기록한다.

---

## 1. 현재 기준 파일

```text
입력 JSON:
PID_TEST_V2_Final_Case_Lines_1_28.json

결과 LISP:
PID_TEST_V2_Final_Result_Lines_1_28_Jump_R3.lsp
```

현재 JSON은 `line_1 ~ line_28`, `line_7A/7B`, `line_11A/11B`, `line_15A/15B`, `line_19A/19B`, `line_23A/23B`, `line_27A/27B`를 포함한다.

---

## 2. 전체 처리 흐름

권장 처리 순서는 다음이다.

```text
1. JSON 로드
2. processes 정렬
3. instances 분류
4. 공정 구역 좌표 산정
5. 구조물 배치
6. 구조물 내부기계 배치
7. 외부기계 media lane 배치
8. block insert 및 PORT 속성 수집
9. STRUCTURE_LIKE 예외 판정
10. connection graph 분석
11. endpoint chain 생성
12. connection.chain의 TEE/ref 생성
13. trunk/segment 관계 분석
14. segment chain 배치
15. 직각 배관 후보 생성
16. bbox 관통 검사
17. 기존 배관 동일선상 겹침 검사
18. 단순 교차점 검출
19. 점프 표시 생성
20. media별 layer/color 적용
21. AutoCAD LISP 출력
```

---

## 3. JSON 기본 구조

```json
{
  "schema_version": "PID_TEST_V2",
  "layout_rules": {},
  "processes": [],
  "instances": [],
  "connections": []
}
```

`process_connections`는 현재 기본 구조에 포함하지 않는다. 실제 공정 연결은 `connections`와 각 instance의 `process_id`를 통해 추론한다.

---

## 4. layout_rules

현재 기준값:

```json
"layout_rules": {
  "process_direction": "LEFT_TO_RIGHT",
  "structure_position": "LEFT",
  "machine_position": "RIGHT_OF_STRUCTURE",
  "lane_order": ["CHEMICAL", "AIR", "RAW_WATER", "SLUDGE"],
  "default_line_class": "WATER",
  "default_size": "100A"
}
```

### 4.1 공정 방향

```text
process_direction = LEFT_TO_RIGHT
```

공정은 `processes.order`가 낮은 순서대로 좌측에서 우측으로 배치한다.

### 4.2 media lane 순서

위에서 아래 순서:

```text
CHEMICAL
AIR
RAW_WATER
SLUDGE
```

### 4.3 media priority

media priority는 JSON에 넣지 않고 엔진 고정 규칙으로 둔다.

```text
RAW_WATER > SLUDGE > AIR > CHEMICAL
```

여러 media를 가지는 instance의 대표 media는 위 우선순위로 정한다.

---

## 5. instance 규칙

기본 instance 예:

```json
{
  "id": "PMP1",
  "code_key": "M_PMP01",
  "instance_type": "MACHINE",
  "process_id": "PROC_001",
  "media": ["SLUDGE"],
  "series_id": "PMP_A",
  "location_type": "OUTSIDE_STRUCTURE"
}
```

### 5.1 code_key 접두사

```text
S_     = 구조물
M_     = 기계
FIT_   = 피팅
P_VAV  = 밸브 또는 밸브류 부속품
```

### 5.2 instance_type

```text
STRUCTURE = 구조물
MACHINE   = 기계
```

### 5.3 location_type

```text
PROCESS_AREA       = 구조물 또는 공정 기준 배치
OUTSIDE_STRUCTURE  = 구조물 오른쪽 media lane에 배치
INSIDE_STRUCTURE   = 구조물 내부 슬롯에 배치
```

### 5.4 series_id

같은 media lane 안에서 같은 계열로 묶기 위한 ID이다.

중요:

```text
같은 code_key라도 series_id가 다르면 다른 계열로 본다.
```

예:

```text
PMP_A = PMP1, PMP2, PMP3
BRX   = BRX1, BRX2
PMP_B = PMP4, PMP5, PMP6
```

---

## 6. STRUCTURE_LIKE 예외 규칙

현재 중요한 보정 규칙이다.

```text
M_BRX01은 JSON에서는 MACHINE으로 유지한다.
하지만 배관 라우팅/TEE/꺾임 판단에서는 STRUCTURE_LIKE로 취급한다.
```

### 6.1 JSON은 변경하지 않는다

BRX instance는 다음 상태를 유지한다.

```json
{
  "id": "BRX1",
  "code_key": "M_BRX01",
  "instance_type": "MACHINE",
  "location_type": "OUTSIDE_STRUCTURE"
}
```

### 6.2 엔진 내부 판정만 변경한다

엔진 내부에 다음과 같은 판정 함수를 둔다.

```text
isStructureLike(instance):
  true if instance_type == STRUCTURE
  true if code_key in STRUCTURE_LIKE_CODE_KEYS
```

현재 `STRUCTURE_LIKE_CODE_KEYS`:

```text
M_BRX01
```

### 6.3 배관 규칙 적용

BRX ↔ PMP 연결은 다음처럼 처리한다.

```text
실제 JSON 타입 = MACHINE 유지
배치 = SLUDGE lane 기계 배치 유지
배관 판단 = 구조물처럼 처리
BRX ↔ PMP = S↔M 연결 규칙 적용
TEE = PMP 쪽 기준 생성
꺾임 = BRX 쪽 우선
```

---

## 7. 구조물 내부기계 규칙

구조물 블록은 내부기계 슬롯 속성을 가진다.

예: `S_COND01`

```text
INSIDE1_CODE
INSIDE1_OFFSET
INSIDE2_CODE
INSIDE2_OFFSET
```

내부기계 배치:

```text
내부기계 삽입점 = parent_structure 삽입점 + INSIDEn_OFFSET
```

`INSIDEn_CODE`는 prefix 매칭을 허용한다.

```text
INSIDE1_CODE = M_TDIF
M_TDIF04     = 허용
```

---

## 8. PORT 속성 규칙

각 블록은 다음 속성을 가진다.

```text
PORT1_TYPE
PORT1_OFFSET
PORT1_ANGLE
PORT2_TYPE
PORT2_OFFSET
PORT2_ANGLE
...
```

### 8.1 PORT_TYPE

```text
IN
OUT
```

`PORT1 = IN`이라고 가정하면 안 된다. 반드시 속성을 읽는다.

### 8.2 PORT_OFFSET

```text
포트 월드좌표 = 블록 삽입점 + rotate(PORT_OFFSET, 블록 회전각)
```

### 8.3 PORT_ANGLE

```text
0도   = 오른쪽
90도  = 위
180도 = 왼쪽
270도 = 아래
```

중요:

```text
PORT_ANGLE은 전체 배관 방향이 아니다.
PORT_ANGLE은 포트 주변 local lead 방향이다.
```

즉, BRX port가 270도라도 전체 경로가 무조건 아래로 진행되면 안 된다.

---

## 9. connection 구조

기본 예:

```json
{
  "id": "line_25",
  "media": "SLUDGE",
  "line_class": "SLUDGE",
  "size": "100A",
  "from": { "id": "COND1", "port": 3 },
  "chain": [{ "type": "TEE", "id": "TEE16" }],
  "to": {
    "id": "PMP4",
    "port": 2,
    "chain": [
      { "code_key": "P_VAV07" },
      { "code_key": "P_VAV01" },
      { "code_key": "FIT_FLNG" }
    ]
  }
}
```

### 9.1 endpoint 종류

장비/구조물 포트:

```json
{ "id": "PMP1", "port": 1 }
```

ref/TEE:

```json
{ "ref": "TEE4" }
```

---

## 10. from/to 방향 제한

기존 `OUT → IN` 강제 규칙은 사용하지 않는다.

현재 규칙:

```text
장비/구조물/REF 간 main connection은 IN↔IN, OUT↔OUT, OUT↔IN 모두 허용한다.
```

단, 부속품 chain 내부는 IN/OUT 방향을 유지한다.

---

## 11. endpoint chain 규칙

### 11.1 chain 배열 순서

endpoint의 `chain` 배열은 **포트 쪽에서 바깥쪽 방향** 순서로 해석한다.

예:

```json
"chain": [
  { "code_key": "P_VAV01" },
  { "code_key": "FIT_FLNG" }
]
```

의미:

```text
장비/구조물 포트 → P_VAV01 → FIT_FLNG → 외부 배관
```

### 11.2 PORT_TYPE 기준 부착

`from.chain`, `to.chain`은 from/to 이름으로 방향을 결정하지 않는다.

```text
chain 배치 기준 = endpoint 포트의 PORT_TYPE + PORT_ANGLE
```

PORT_TYPE = IN:

```text
외부 배관 → chain IN ... chain OUT → 장비 IN
```

PORT_TYPE = OUT:

```text
장비 OUT → chain IN ... chain OUT → 외부 배관
```

---

## 12. 부속품 gap 규칙

일반 부속품 사이 gap:

```text
0.9375mm
```

중요:

```text
0.9375는 배관선 길이가 아니다.
부속품 포트 사이 이격거리이다.
```

따라서 일반 부속품 사이 gap에는 LINE을 생성하지 않는다.

---

## 13. PIPE chain item 규칙

직관은 일반 부속품 블록이 아니라 특수 item으로 처리한다.

예:

```json
{
  "type": "PIPE",
  "code_key": "PIPE_10",
  "length": 10
}
```

규칙:

```text
블록 삽입 없음
실제 배관선 생성
지정 length만큼 진행
일반 부속품 gap 0.9375 적용 안 함
```

---

## 14. TEE/ref 규칙

`connection.chain`에 있는 TEE는 실제 블록이 아니라 가상 분기점/ref 좌표이다.

```json
"chain": [
  { "type": "TEE", "id": "TEE13" }
]
```

규칙:

```text
TEE는 반드시 선택된 parent path 위에 있어야 한다.
임의 좌표에 만들지 않는다.
```

---

## 15. TEE 위치 규칙

TEE 위치 기준과 배관 꺾임 기준은 다르다.

```text
TEE 위치 기준 ≠ 배관 꺾임 기준
```

### 15.1 기계 ↔ 기계

```text
M↔M TEE 위치 = PORT_TYPE OUT 쪽 endpoint 근처
```

### 15.2 구조물 ↔ 기계

```text
S↔M TEE 위치 = 기계 쪽
S↔M 꺾임 위치 = 구조물 쪽 우선
```

### 15.3 STRUCTURE_LIKE ↔ 기계

BRX 같은 STRUCTURE_LIKE는 구조물로 판단한다.

```text
BRX↔PMP TEE 위치 = PMP 쪽
BRX↔PMP 꺾임 위치 = BRX 쪽 우선
```

### 15.4 TEE 이후 직관

```text
TEE → 진행방향 50mm 직관 → 이후 꺾임 허용
```

현재 기준:

```text
TEE_AFTER_LEAD = 50mm
```

---

## 16. chain 이후 직관 규칙

chain 최종 부속품 이후 바로 꺾으면 안 된다.

```text
chain 최종 외곽 포트
→ 10mm lead
→ 50mm 추가 직관
→ 이후 꺾임 허용
```

즉 chain이 있는 endpoint는 최소 다음 직선 거리를 확보한다.

```text
10mm + 50mm = 60mm
```

---

## 17. trunk / segment 규칙

### 17.1 trunk line

trunk line은 TEE 좌표 산정용 parent path로 사용한다.

예:

```text
line_7   : TEE1  → TEE3  → TEE2
line_11  : TEE4  → TEE6  → TEE5
line_15  : TEE7  → TEE9  → TEE8
line_19  : TEE11 → TEE12 → TEE10
line_23  : TEE14 → TEE15 → TEE13
line_27  : TEE17 → TEE18 → TEE16
```

### 17.2 segment line

segment line은 실제 배관과 chain을 출력한다.

예:

```text
line_19A = TEE12 → FLNG-VAV-FLNG → TEE10
line_19B = TEE12 → FLNG-VAV-FLNG → TEE11
```

### 17.3 trunk 출력 금지

segment line이 존재하면 trunk line은 실제 배관선으로 그리지 않는다.

```text
line_19  = 좌표 계산용
line_19A = 실제 출력
line_19B = 실제 출력
```

---

## 18. segment chain 배치 규칙

기본 segment chain은 전체 묶음을 구간 중앙에 배치한다.

예:

```json
"chain": [
  { "code_key": "FIT_FLNG" },
  { "code_key": "P_VAV01" },
  { "code_key": "FIT_FLNG" }
]
```

전체 길이:

```text
각 부속품 IN~OUT 축 길이 합
+ gap 0.9375 × (부속품 개수 - 1)
```

배관선 출력:

```text
from REF → 첫 번째 부속품 IN
마지막 부속품 OUT → to REF
```

부속품 사이 gap에는 선을 그리지 않는다.

---

## 19. 배관 라우팅 규칙

배관은 항상 직각으로만 생성한다.

허용:

```text
수평 + 수직
수직 + 수평
수평 + 수직 + 수평
수직 + 수평 + 수직
bbox 우회 dogleg
```

금지:

```text
대각선
포트 방향을 전역 경로로 강제
부속품 gap 내부 배관선
S_/M_/STRUCTURE_LIKE bbox 관통
기존 배관과 같은 선상 겹침
```

---

## 20. PORT_ANGLE과 전역 라우팅 관계

`PORT_ANGLE`은 다음 구간에만 사용한다.

```text
포트 lead
chain 배치 방향
TEE 전/후 직관 방향
```

전체 경로는 상대 endpoint 위치, 장애물, 겹침 여부, 길이, 꺾임 수로 후보 선택한다.

중요 예시:

```text
BRX port = 270도
PMP port = 180도
```

이 경우에도 BRX 포트가 270도라는 이유만으로 TEE를 아래쪽에 강제로 만들면 안 된다.

올바른 처리:

```text
1. BRX 270도는 local lead에만 적용
2. PMP 방향으로 갈 수 있는 직각 후보 생성
3. 선택된 BRX↔PMP parent path 위에 TEE 배치
4. BRX가 STRUCTURE_LIKE이면 꺾임은 BRX 쪽 우선, TEE는 PMP 쪽 우선
```

---

## 21. bbox 관통 방지

배관은 다음 bbox를 관통하면 안 된다.

```text
S_ 구조물 bbox
M_ 기계 bbox
STRUCTURE_LIKE bbox
```

예외:

```text
1. 자기 endpoint의 정상 port lead
2. 내부기계와 parent_structure 간 허용 연결부
3. parent_structure 내부 허용 영역
```

---

## 22. 배관 겹침 회피

P&ID에서는 십자 교차는 가능하지만 같은 선 위로 겹치는 것은 금지한다.

허용:

```text
수평선과 수직선이 한 점에서 교차
```

금지:

```text
같은 X 또는 같은 Y 위에서 일정 길이 이상 겹침
```

겹침 발생 시 offset 후보를 생성한다.

현재 후보 offset:

```text
25mm, -25mm, 50mm, -50mm, 75mm, -75mm
```

---

## 23. 배관 교차 점프 표시 규칙

현재 추가된 기능이다.

### 23.1 목적

배관과 배관이 단순히 지나갈 때, 실제 접속이 아니라 통과선임을 표시한다.

표현:

```text
직각 교차점에 반원형 점프 표시 생성
```

### 23.2 적용 조건

점프 표시를 적용하는 경우:

```text
1. 수평 배관과 수직 배관이 교차한다.
2. 교차점이 두 배관 segment의 내부에 있다.
3. 해당 교차점이 TEE/ref/endpoint/port/chain 접속점이 아니다.
4. 의도된 연결점이 아닌 단순 통과점이다.
```

### 23.3 제외 조건

점프 표시를 하지 않는 경우:

```text
TEE 좌표
REF 좌표
endpoint port 좌표
chain 첫/마지막 port 좌표
동일 connection 내부 연속 segment의 bend point
```

### 23.4 점프 반경

현재 기준:

```text
JUMP_RADIUS = 3mm
```

### 23.5 점프 표시 대상 선

현재 보정 기준:

```text
수직 배관 쪽에 점프 표시 우선 적용
```

이유:

```text
나중에 그려지는 라인만 점프 표시하면 이미 그려진 PMP4↔COND1 등 일부 교차점이 누락될 수 있다.
따라서 전체 배관 segment를 수집한 뒤 교차점을 후처리로 검출한다.
필요하면 기존 수직 배관 segment도 분할 후 점프 표시를 생성한다.
```

### 23.6 점프 처리 방식

점프 표시가 필요한 수직 segment는 다음처럼 분할한다.

```text
기존 수직선:
A → B

교차점 C, 반경 R = 3mm

출력:
A → C-R
반원 ARC
C+R → B
```

수평 segment에 점프를 적용할 경우도 동일하게 교차점 주변을 끊고 ARC를 삽입한다.

---

## 24. media별 배관 색상

AutoCAD color index 기준:

```text
RAW_WATER = 4
SLUDGE    = 3
AIR       = 7
CHEMICAL  = 6
```

권장 레이어:

```text
PID_PIPE_RAW_WATER
PID_PIPE_SLUDGE
PID_PIPE_AIR
PID_PIPE_CHEMICAL
```

---

## 25. 현재 instance 구성

```text
PROC_001
- COND1, COND2
- TDIF1/FDC1, TDIF2/FDC2
- AEB1, AEB2, AEB3
- PKA1, PKA2, PKA3
- VAV1, VAV2
- PMP1, PMP2, PMP3
- BRX1, BRX2
- PMP4, PMP5, PMP6

PROC_002
- COND3
```

---

## 26. 현재 connection 전체 목록

| Line | Media | From | Chain | To |
|---|---|---|---|---|
| `line_1` | `RAW_WATER` | `FDC1.P1 + chain(P_VAV01-FIT_FLNG)` | `-` | `VAV1.P1` |
| `line_2` | `RAW_WATER` | `FDC2.P1 + chain(P_VAV01-FIT_FLNG)` | `-` | `VAV2.P1` |
| `line_3` | `RAW_WATER` | `VAV1.P2` | `-` | `COND3.P1` |
| `line_4` | `RAW_WATER` | `VAV2.P2` | `-` | `COND3.P3` |
| `line_5` | `AIR` | `AEB1.P1 + chain(P_VAV07-P_VAV01-FIT_FLNG)` | `TEE:TEE1` | `TDIF1.P1` |
| `line_6` | `AIR` | `AEB3.P1 + chain(P_VAV07-P_VAV01-FIT_FLNG)` | `TEE:TEE2` | `TDIF2.P1` |
| `line_7` | `AIR` | `TEE1` | `TEE:TEE3` | `TEE2` |
| `line_7A` | `AIR` | `TEE1` | `FIT_FLNG → P_VAV01 → FIT_FLNG` | `TEE3` |
| `line_7B` | `AIR` | `TEE2` | `FIT_FLNG → P_VAV01 → FIT_FLNG` | `TEE3` |
| `line_8` | `AIR` | `TEE3` | `-` | `AEB2.P1 + chain(P_VAV07-P_VAV01-FIT_FLNG)` |
| `line_9` | `SLUDGE` | `COND1.P2 + chain(P_VAV01-FIT_FLNG)` | `TEE:TEE4` | `PMP1.P1 + chain(P_VAV07-P_VAV01-FIT_FLNG)` |
| `line_10` | `SLUDGE` | `COND2.P2 + chain(P_VAV01-FIT_FLNG)` | `TEE:TEE5` | `PMP3.P1 + chain(P_VAV07-P_VAV01-FIT_FLNG)` |
| `line_11` | `SLUDGE` | `TEE4` | `TEE:TEE6` | `TEE5` |
| `line_11A` | `SLUDGE` | `TEE4` | `FIT_FLNG → P_VAV01 → FIT_FLNG` | `TEE6` |
| `line_11B` | `SLUDGE` | `TEE5` | `FIT_FLNG → P_VAV01 → FIT_FLNG` | `TEE6` |
| `line_12` | `SLUDGE` | `TEE6` | `-` | `PMP2.P1 + chain(P_VAV07-FIT_FLNG)` |
| `line_13` | `SLUDGE` | `PMP1.P2 + chain(P_VAV07-P_VAV01-FIT_FLNG)` | `TEE:TEE7` | `BRX1.P1` |
| `line_14` | `SLUDGE` | `PMP3.P2 + chain(P_VAV07-P_VAV01-FIT_FLNG)` | `TEE:TEE8` | `BRX2.P1` |
| `line_15` | `SLUDGE` | `TEE7` | `TEE:TEE9` | `TEE8` |
| `line_15A` | `SLUDGE` | `TEE7` | `FIT_FLNG → P_VAV01 → FIT_FLNG` | `TEE9` |
| `line_15B` | `SLUDGE` | `TEE8` | `FIT_FLNG → P_VAV01 → FIT_FLNG` | `TEE9` |
| `line_16` | `SLUDGE` | `PMP2.P2 + chain(P_VAV07-FIT_FLNG)` | `-` | `TEE9` |
| `line_17` | `AIR` | `BRX1.P3` | `TEE:TEE10` | `PKA1.P1 + chain(P_VAV07-P_VAV01-FIT_FLNG)` |
| `line_18` | `AIR` | `BRX2.P3` | `TEE:TEE11` | `PKA3.P1 + chain(P_VAV07-P_VAV01-FIT_FLNG)` |
| `line_19` | `AIR` | `TEE11` | `TEE:TEE12` | `TEE10` |
| `line_19A` | `AIR` | `TEE12` | `FIT_FLNG → P_VAV01 → FIT_FLNG` | `TEE10` |
| `line_19B` | `AIR` | `TEE12` | `FIT_FLNG → P_VAV01 → FIT_FLNG` | `TEE11` |
| `line_20` | `AIR` | `TEE12` | `-` | `PKA2.P1 + chain(P_VAV07-FIT_FLNG)` |
| `line_21` | `SLUDGE` | `PMP4.P1 + chain(P_VAV07-P_VAV01-FIT_FLNG)` | `TEE:TEE13` | `BRX1.P2` |
| `line_22` | `SLUDGE` | `PMP6.P1 + chain(P_VAV07-P_VAV01-FIT_FLNG)` | `TEE:TEE14` | `BRX2.P2` |
| `line_23` | `SLUDGE` | `TEE14` | `TEE:TEE15` | `TEE13` |
| `line_23A` | `SLUDGE` | `TEE15` | `FIT_FLNG → P_VAV01 → FIT_FLNG` | `TEE13` |
| `line_23B` | `SLUDGE` | `TEE15` | `FIT_FLNG → P_VAV01 → FIT_FLNG` | `TEE14` |
| `line_24` | `SLUDGE` | `PMP5.P1 + chain(P_VAV07-FIT_FLNG)` | `-` | `TEE15` |
| `line_25` | `SLUDGE` | `COND1.P3` | `TEE:TEE16` | `PMP4.P2 + chain(P_VAV07-P_VAV01-FIT_FLNG)` |
| `line_26` | `SLUDGE` | `COND2.P3` | `TEE:TEE17` | `PMP6.P2 + chain(P_VAV07-P_VAV01-FIT_FLNG)` |
| `line_27` | `SLUDGE` | `TEE17` | `TEE:TEE18` | `TEE16` |
| `line_27A` | `SLUDGE` | `TEE18` | `FIT_FLNG → P_VAV01 → FIT_FLNG` | `TEE16` |
| `line_27B` | `SLUDGE` | `TEE18` | `FIT_FLNG → P_VAV01 → FIT_FLNG` | `TEE17` |
| `line_28` | `SLUDGE` | `TEE18` | `-` | `PMP5.P2 + chain(P_VAV07-FIT_FLNG)` |

---

## 27. line_17 ~ line_28 추가 규칙 요약

### 27.1 AIR 후단 PKA 연결

```text
line_17 : BRX1.P3 → TEE10 → PKA1.P1 + to.chain(P_VAV07, P_VAV01, FIT_FLNG)
line_18 : BRX2.P3 → TEE11 → PKA3.P1 + to.chain(P_VAV07, P_VAV01, FIT_FLNG)
line_19 : TEE11 → TEE12 → TEE10       trunk, 실제 출력 없음
line_19A: TEE12 → FLNG-VAV-FLNG → TEE10
line_19B: TEE12 → FLNG-VAV-FLNG → TEE11
line_20 : TEE12 → PKA2.P1 + to.chain(P_VAV07, FIT_FLNG)
```

### 27.2 SLUDGE BRX/PMP_B 연결

```text
line_21 : PMP4.P1 + from.chain(P_VAV07, P_VAV01, FIT_FLNG) → TEE13 → BRX1.P2
line_22 : PMP6.P1 + from.chain(P_VAV07, P_VAV01, FIT_FLNG) → TEE14 → BRX2.P2
line_23 : TEE14 → TEE15 → TEE13       trunk, 실제 출력 없음
line_23A: TEE15 → FLNG-VAV-FLNG → TEE13
line_23B: TEE15 → FLNG-VAV-FLNG → TEE14
line_24 : PMP5.P1 + from.chain(P_VAV07, FIT_FLNG) → TEE15
```

주의:

```text
PMP4/PMP5/PMP6의 line_21~24 연결 포트는 port 1이다.
```

### 27.3 SLUDGE COND/PMP_B 연결

```text
line_25 : COND1.P3 → TEE16 → PMP4.P2 + to.chain(P_VAV07, P_VAV01, FIT_FLNG)
line_26 : COND2.P3 → TEE17 → PMP6.P2 + to.chain(P_VAV07, P_VAV01, FIT_FLNG)
line_27 : TEE17 → TEE18 → TEE16       trunk, 실제 출력 없음
line_27A: TEE18 → FLNG-VAV-FLNG → TEE16
line_27B: TEE18 → FLNG-VAV-FLNG → TEE17
line_28 : TEE18 → PMP5.P2 + to.chain(P_VAV07, FIT_FLNG)
```

주의:

```text
line_28에서 PMP5 port는 port 2로 적용한다.
```

---

## 28. 최종 핵심 규칙 요약

```text
1. JSON은 설계/공정 데이터 성격을 유지한다.
2. BRX는 JSON에서 MACHINE으로 유지한다.
3. M_BRX01은 LISP/엔진 내부에서만 STRUCTURE_LIKE로 취급한다.
4. PORT_ANGLE은 local lead 전용이며 전역 경로를 지배하지 않는다.
5. main connection은 OUT→IN만 강제하지 않는다.
6. endpoint chain은 포트 쪽에서 바깥쪽 순서로 해석한다.
7. 일반 부속품 gap 0.9375에는 배관선을 그리지 않는다.
8. TEE는 선택된 parent path 위에 생성한다.
9. trunk line은 segment가 있으면 실제 출력하지 않는다.
10. segment chain은 구간 중앙 배치를 기본으로 한다.
11. 모든 배관은 직각으로 생성한다.
12. S_/M_/STRUCTURE_LIKE bbox 관통은 금지한다.
13. 같은 선상 배관 겹침은 금지한다.
14. 단순 십자 교차는 허용하되 점프 표시를 생성한다.
15. 점프 반경은 3mm이다.
16. TEE/ref/endpoint 접속점에는 점프 표시를 생성하지 않는다.
17. media별 배관 색상을 적용한다.
```
