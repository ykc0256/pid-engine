;;; ============================================================
;;; PID-ENGINE  데이터 테이블 — 상수 / 기계 / 배관 / 부속품
;;; 새 블록·배관 추가 시 이 파일만 수정
;;; ============================================================

;; ── 레이아웃 상수 ────────────────────────────────────────────
(setq *STR-W*        200)
(setq *STR-H*        100)
(setq *STR-GAP*      300)
(setq *MCH-W*         60)
(setq *MCH-H*         60)
(setq *MCH-V-GAP*    100)
(setq *GROUP-H-GAP*  200)
(setq *ACC-SPACE*    400)
(setq *PROC-MARGIN*  500)
(setq *LBL-H*         25)
(setq *LBL-M*         18)
(setq *ORIG-X*          0)
(setq *ORIG-Y*          0)

;; ── 밴드 Y (위→아래: 약품/공기/원수/슬러지) ─────────────────
(setq *BAND-Y*
  '(("chemical" . 1200)
    ("air"      .  600)
    ("sewage"   .    0)
    ("sludge"   . -600)))

;; ── 공정 순서 ────────────────────────────────────────────────
(setq *PROCESSES* '("PROC-A" "PROC-B"))

;; ── 구조물 데이터 ─────────────────────────────────────────────
(setq *STRUCTURES*
  '(("STR-A01" "S_COND01" "PROC-A" 1)
    ("STR-A02" "S_COND01" "PROC-A" 1)
    ("STR-B01" "S_COND01" "PROC-B" 1)))

;; ── 외부 기계 데이터 ──────────────────────────────────────────
;; (id  code_key  proc-id  band  group-id  order-in-group  group-order-in-band)
(setq *MACHINES*
  '(
    ("MCH-A11" "M_AEB0101" "PROC-A" "air"    "AEB0101"    0  0)
    ("MCH-A12" "M_AEB0101" "PROC-A" "air"    "AEB0101"    1  0)
    ("MCH-A13" "M_AEB0101" "PROC-A" "air"    "AEB0101"    2  0)
    ("MCH-A14" "M_PKA0103" "PROC-A" "air"    "PKA0103"    0  1)
    ("MCH-A15" "M_PKA0103" "PROC-A" "air"    "PKA0103"    1  1)
    ("MCH-A16" "M_PKA0103" "PROC-A" "air"    "PKA0103"    2  1)

    ("MCH-A01" "M_VAV0101" "PROC-A" "sewage" "VAV0101"    0  0)
    ("MCH-A02" "M_VAV0101" "PROC-A" "sewage" "VAV0101"    1  0)

    ("MCH-A03" "M_PKA0102" "PROC-A" "sludge" "PKA0102-G1" 0  0)
    ("MCH-A04" "M_PKA0102" "PROC-A" "sludge" "PKA0102-G1" 1  0)
    ("MCH-A05" "M_PKA0102" "PROC-A" "sludge" "PKA0102-G1" 2  0)
    ("MCH-A06" "M_BRX01"   "PROC-A" "sludge" "BRX01"      0  1)
    ("MCH-A07" "M_BRX01"   "PROC-A" "sludge" "BRX01"      1  1)
    ("MCH-A08" "M_PKA0102" "PROC-A" "sludge" "PKA0102-G2" 0  2)
    ("MCH-A09" "M_PKA0102" "PROC-A" "sludge" "PKA0102-G2" 1  2)
    ("MCH-A10" "M_PKA0102" "PROC-A" "sludge" "PKA0102-G2" 2  2)

    ("MCH-B01" "M_PMP0602" "PROC-B" "sewage" "PMP0602"    0  0)
    ("MCH-B02" "M_PMP0602" "PROC-B" "sewage" "PMP0602"    1  0)
    ("MCH-B03" "M_PMP0602" "PROC-B" "sewage" "PMP0602"    2  0)

    ("MCH-B04" "M_PMP0601" "PROC-B" "sludge" "PMP0601"    0  0)
    ("MCH-B05" "M_PMP0601" "PROC-B" "sludge" "PMP0601"    1  0)
  ))

;; ── 내부 기계 데이터 ──────────────────────────────────────────
;; (mch-id  code_key  str-id  slot-tag)
(setq *INT-MACHINES*
  '(("MCH-A17" "M_FDC01"  "STR-A01" "M_FDCT")
    ("MCH-A18" "M_TDIF04" "STR-A01" "M_TDIF")
    ("MCH-A19" "M_FDC01"  "STR-A02" "M_FDCT")
    ("MCH-A20" "M_TDIF04" "STR-A02" "M_TDIF")))

;; ── media 레이어/색상 ────────────────────────────────────────
(setq *MEDIA-LAYERS*
  '(("sewage"   "PID-SEWAGE"   4)
    ("sludge"   "PID-SLUDGE"   3)
    ("air"      "PID-AIR"      7)
    ("chemical" "PID-CHEMICAL" 6)))

;; ── 배관 상수 ────────────────────────────────────────────────
(setq *PORT-LEAD*      60)      ; 체인 끝 이후 꺾임 전 최소 직관 (mm)
(setq *ACC-GAP*      0.9375)  ; 포트↔부속품, 부속품↔부속품 이격 거리
(setq *VERT-CH-STEP* 100)     ; 수직 채널 X 간격 — 구조물→기계 겹침 방지

;; ── 포트 variant 치환 ────────────────────────────────────────
(setq *PORT-VARIANTS*
  '(("FIT_CONRDC" "IN"  "FIT_CONRDC_IN")
    ("FIT_CONRDC" "OUT" "FIT_CONRDC_OUT")))

;; ── 포트 각도 오버라이드 (_ANG attribute 없는 블록용) ────────────
;; 형식: (block-name  port-id  angle-deg)
(setq *PORT-ANG-OVERRIDE*
  '(("S_COND01"   "OUT1" 0)
    ("S_COND01"   "IN1"  90)
    ("M_PKA0102"  "IN1"  180)
    ("M_PKA0102"  "OUT1" 0)
    ("M_PKA0103"  "IN1"  180)
    ("M_PKA0103"  "OUT1" 0)
    ("M_VAV0101"  "IN1"  180)
    ("M_VAV0101"  "OUT1" 0)
    ("M_AEB0101"  "IN1"  270)
    ("M_AEB0101"  "OUT1" 90)
    ("M_BRX01"    "IN1"  180)
    ("M_BRX01"    "OUT1" 0)
    ("M_PMP0602"  "IN1"  180)
    ("M_PMP0602"  "OUT1" 0)
    ("M_PMP0601"  "IN1"  180)
    ("M_PMP0601"  "OUT1" 0)))

;; ── 파이프 데이터 ─────────────────────────────────────────────
;; 형식: (pipe-id  from-spec  to-spec  fa  ta  ia  tees  media)
;; from/to-spec:
;;   ("S" str-id  port-id)   구조물 포트
;;   ("M" mch-id  port-id)   기계 포트
;;   ("T" tee-id)            기등록 TEE
;; fa/ta/ia: (code_key ...) 또는 nil
;; tees:     (tee-id ...) 또는 nil
(setq *PIPES*
  '(
    ;; ─ Pass 1: TEE 의존성 없음 ────────────────────────────────

    ;; A공정 슬러지 순환 Seg1: STR → PKA0102-G1 흡입
    ("PIPE-A01"
     ("S" "STR-A01" "OUT1") ("M" "MCH-A03" "IN1")
     ("P_VAV01" "FIT_FLNG") ("P_VAV07" "P_VAV01" "FIT_FLNG")
     nil ("TEE-A1-1") "sludge")
    ("PIPE-A02"
     ("S" "STR-A02" "OUT1") ("M" "MCH-A05" "IN1")
     ("P_VAV01" "FIT_FLNG") ("P_VAV07" "P_VAV01" "FIT_FLNG")
     nil ("TEE-A1-2") "sludge")

  ))

;; ── 전역 레지스트리 ──────────────────────────────────────────
(setq *TEE-PTS*    '())
(setq *IN1-CACHE*  '())
(setq *OUT1-CACHE* '())
(setq *ENAME-CACHE* '())
(setq *PROC-X*     '())
(setq *PIPE-IDX*   0)
(setq *INT-ENAMES* '())

(princ "\npid_data 로드 완료\n")
(princ)
