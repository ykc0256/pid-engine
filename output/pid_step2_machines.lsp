;;; ============================================================
;;; PID-ENGINE  Step 2 — 구조물 + 기계 배치
;;; 단위    : mm  |  삽입점: 블록 좌하단 기준
;;; 밴드 순서 (위→아래): 약품 / 공기 / 원수 / 슬러지
;;; 실행    : (load "전체경로/pid_step2_machines.lsp") 후 PID-STEP2
;;; ============================================================

;; ── 레이아웃 상수 ────────────────────────────────────────────
(setq *STR-W*        200)   ; 구조물 블록 가로 (mm)
(setq *STR-H*        100)   ; 구조물 블록 세로 (mm)
(setq *STR-GAP*      300)   ; 같은 그룹 내 구조물 세로 간격
(setq *MCH-W*         60)   ; 기계 블록 가로 (mm)
(setq *MCH-H*         60)   ; 기계 블록 세로 (mm)
(setq *MCH-V-GAP*    100)   ; 그룹 내 기계 세로 간격
(setq *GROUP-H-GAP*  200)   ; 그룹 간 가로 간격 (배관+부속품 공간)
(setq *ACC-SPACE*    400)   ; 구조물 우측 ~ 첫 기계 좌측 (배관 공간)
(setq *PROC-GAP*    3000)   ; 공정 간 가로 간격
(setq *LBL-H*         25)   ; 레이블 텍스트 높이 (구조물)
(setq *LBL-M*         18)   ; 레이블 텍스트 높이 (기계)
(setq *ORIG-X*          0)
(setq *ORIG-Y*          0)

;; 밴드 Y 시작 좌표 (위→아래: 약품/공기/원수/슬러지)
;; 필요 시 값 조정 후 재실행
(setq *BAND-Y*
  '(("chemical" .     0)   ; 약품 (현재 데이터 없음)
    ("air"      .     0)   ; 공기
    ("sewage"   .  -600)   ; 원수
    ("sludge"   . -1200)   ; 슬러지
  ))

;; ── 공정 순서 ────────────────────────────────────────────────
(setq *PROCESSES* '("PROC-A" "PROC-B"))

;; ── 구조물 데이터 ─────────────────────────────────────────────
;; (str-id  code_key  proc-id  group-no)
(setq *STRUCTURES*
  '(("STR-A01" "S_COND01" "PROC-A" 1)
    ("STR-A02" "S_COND01" "PROC-A" 1)
    ("STR-B01" "S_COND01" "PROC-B" 1)))

;; ── 기계 데이터 (외부 기계) ───────────────────────────────────
;; (id  code_key  proc-id  band  group-id  order-in-group  group-order-in-band)
;;
;; band             : "chemical" / "air" / "sewage" / "sludge"
;; order-in-group   : 그룹 내 위→아래 순서 (0-based)
;; group-order-in-band : 밴드 내 그룹 좌→우 순서 (0-based)
(setq *MACHINES*
  '(
    ; ── A공정 / 공기 밴드 ──────────────────────────────────────
    ("MCH-A11" "M_AEB0101" "PROC-A" "air"    "AEB0101"    0  0)
    ("MCH-A12" "M_AEB0101" "PROC-A" "air"    "AEB0101"    1  0)
    ("MCH-A13" "M_AEB0101" "PROC-A" "air"    "AEB0101"    2  0)
    ("MCH-A14" "M_PKA0103" "PROC-A" "air"    "PKA0103"    0  1)
    ("MCH-A15" "M_PKA0103" "PROC-A" "air"    "PKA0103"    1  1)
    ("MCH-A16" "M_PKA0103" "PROC-A" "air"    "PKA0103"    2  1)

    ; ── A공정 / 원수 밴드 ──────────────────────────────────────
    ("MCH-A01" "M_VAV0101" "PROC-A" "sewage" "VAV0101"    0  0)
    ("MCH-A02" "M_VAV0101" "PROC-A" "sewage" "VAV0101"    1  0)

    ; ── A공정 / 슬러지 밴드 ────────────────────────────────────
    ("MCH-A03" "M_PKA0102" "PROC-A" "sludge" "PKA0102-G1" 0  0)
    ("MCH-A04" "M_PKA0102" "PROC-A" "sludge" "PKA0102-G1" 1  0)
    ("MCH-A05" "M_PKA0102" "PROC-A" "sludge" "PKA0102-G1" 2  0)
    ("MCH-A06" "M_BRX01"   "PROC-A" "sludge" "BRX01"      0  1)
    ("MCH-A07" "M_BRX01"   "PROC-A" "sludge" "BRX01"      1  1)
    ("MCH-A08" "M_PKA0102" "PROC-A" "sludge" "PKA0102-G2" 0  2)
    ("MCH-A09" "M_PKA0102" "PROC-A" "sludge" "PKA0102-G2" 1  2)
    ("MCH-A10" "M_PKA0102" "PROC-A" "sludge" "PKA0102-G2" 2  2)

    ; ── B공정 / 원수 밴드 ──────────────────────────────────────
    ("MCH-B01" "M_PMP0602" "PROC-B" "sewage" "PMP0602"    0  0)
    ("MCH-B02" "M_PMP0602" "PROC-B" "sewage" "PMP0602"    1  0)
    ("MCH-B03" "M_PMP0602" "PROC-B" "sewage" "PMP0602"    2  0)

    ; ── B공정 / 슬러지 밴드 ────────────────────────────────────
    ("MCH-B04" "M_PMP0601" "PROC-B" "sludge" "PMP0601"    0  0)
    ("MCH-B05" "M_PMP0601" "PROC-B" "sludge" "PMP0601"    1  0)
  ))

;; ── 유틸리티 ─────────────────────────────────────────────────

(defun proc-idx (pid / i result)
  (setq i 0  result 0)
  (foreach p *PROCESSES*
    (if (equal p pid) (setq result i))
    (setq i (1+ i)))
  result)

(defun get-cnt (tbl key / rec)
  (setq rec (assoc key tbl))
  (if rec (cdr rec) 0))

(defun set-cnt (tbl key val)
  (if (assoc key tbl)
    (subst (cons key val) (assoc key tbl) tbl)
    (cons (cons key val) tbl)))

(defun band-y (band / rec)
  (setq rec (assoc band *BAND-Y*))
  (if rec (cdr rec) 0))

;; ── 구조물 배치 ───────────────────────────────────────────────
(defun place-structures (/ tbl str-id ckey pid grp key cnt x y)
  (setq tbl '())
  (setvar "ATTREQ" 0)
  (foreach str *STRUCTURES*
    (setq str-id (nth 0 str)
          ckey   (nth 1 str)
          pid    (nth 2 str)
          grp    (nth 3 str)
          key    (strcat pid "_" (itoa grp))
          cnt    (get-cnt tbl key))
    (setq x (+ *ORIG-X* (* (proc-idx pid) *PROC-GAP*)))
    (setq y (- *ORIG-Y* (* cnt (+ *STR-H* *STR-GAP*))))
    (command "._INSERT" ckey (list x y) 1 1 0)
    (command "._TEXT"
             (list (+ x 5) (+ y *STR-H* 10))
             *LBL-H* 0 str-id)
    (setq tbl (set-cnt tbl key (1+ cnt)))
    (princ (strcat "\n  구조물 배치: " str-id
                   "  (" (rtos x 2 0) ", " (rtos y 2 0) ")")))
  (setvar "ATTREQ" 1))

;; ── 기계 배치 ─────────────────────────────────────────────────
(defun place-machines (/ mch-id ckey pid band grp-id ord grp-ord x y proc-x)
  (setvar "ATTREQ" 0)
  (foreach mch *MACHINES*
    (setq mch-id  (nth 0 mch)
          ckey    (nth 1 mch)
          pid     (nth 2 mch)
          band    (nth 3 mch)
          grp-id  (nth 4 mch)
          ord     (nth 5 mch)
          grp-ord (nth 6 mch))

    (setq proc-x (+ *ORIG-X* (* (proc-idx pid) *PROC-GAP*)))

    ;; X: 공정 시작 + 구조물 가로 + 공간 + (그룹순서 × 그룹폭)
    (setq x (+ proc-x
               *STR-W*
               *ACC-SPACE*
               (* grp-ord (+ *MCH-W* *GROUP-H-GAP*))))

    ;; Y: 밴드 시작 Y - (그룹 내 순서 × 기계 피치)
    (setq y (- (band-y band)
               (* ord (+ *MCH-H* *MCH-V-GAP*))))

    (command "._INSERT" ckey (list x y) 1 1 0)
    (command "._TEXT"
             (list (+ x 2) (+ y *MCH-H* 8))
             *LBL-M* 0 mch-id)

    (princ (strcat "\n  기계 배치: " mch-id
                   "  band=" band
                   "  (" (rtos x 2 0) ", " (rtos y 2 0) ")")))
  (setvar "ATTREQ" 1))

;; ── 진입점 ────────────────────────────────────────────────────
(defun c:PID-STEP2 ()
  (command "._UNDO" "BE")
  (setvar "CMDECHO" 0)
  (princ "\n[Step2] 구조물 배치...\n")
  (place-structures)
  (princ "\n[Step2] 기계 배치...\n")
  (place-machines)
  (command "._ZOOM" "E")
  (setvar "CMDECHO" 1)
  (command "._UNDO" "E")
  (princ "\n[Step2] 완료.\n")
  (princ))

(princ "\nPID-STEP2 로드 완료. 커맨드라인에서 'PID-STEP2' 입력 후 실행하세요.\n")
(princ)
