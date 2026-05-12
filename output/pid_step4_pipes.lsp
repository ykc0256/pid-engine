;;; ============================================================
;;; PID-ENGINE  Step 4 — 전체 통합 (구조물·기계·배관·부속품)
;;; 이 파일 하나만 로드하면 PID-STEP4 한 번으로 전부 생성됨
;;; 실행: (load "전체경로/pid_step4_pipes.lsp") → PID-STEP4
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

;; ── 포트 variant 치환 ────────────────────────────────────────
(setq *PORT-LEAD*      60)      ; 체인 끝 이후 꺾임 전 최소 직관 (mm)
(setq *ACC-GAP*      0.9375)  ; 포트↔부속품, 부속품↔부속품 이격 거리
(setq *VERT-CH-STEP* 100)     ; 수직 채널 X 간격 — 구조물→기계 겹침 방지

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
(setq *PIPE-IDX*   0)          ; 배관 순서 카운터 (수직 채널 계산용)
(setq *INT-ENAMES* '())        ; 내부기계 ename 사전 (INSERT 직후 캡처)

;; ============================================================
;; 유틸리티
;; ============================================================

(defun get-cnt (tbl key / rec)
  (setq rec (assoc key tbl))
  (if rec (cdr rec) 0))

(defun set-cnt (tbl key val)
  (if (assoc key tbl)
    (subst (cons key val) (assoc key tbl) tbl)
    (cons (cons key val) tbl)))

;; ============================================================
;; 레이아웃 함수 (Step 2)
;; ============================================================

(defun band-y (band / rec)
  (setq rec (assoc band *BAND-Y*))
  (if rec (cdr rec) 0))

(defun get-proc-x (pid / rec)
  (setq rec (assoc pid *PROC-X*))
  (if rec (cdr rec) 0))

(defun compute-proc-x (/ proc-max pid grp-ord cur x w)
  (setq proc-max '())
  (foreach mch *MACHINES*
    (setq pid     (nth 2 mch)
          grp-ord (nth 6 mch))
    (setq cur (get-cnt proc-max pid))
    (if (> grp-ord cur)
      (setq proc-max (set-cnt proc-max pid grp-ord))))
  (setq x *ORIG-X*  *PROC-X* '())
  (foreach p *PROCESSES*
    (setq *PROC-X* (set-cnt *PROC-X* p x))
    (setq w (+ *STR-W* *ACC-SPACE*
               (* (1+ (get-cnt proc-max p))
                  (+ *MCH-W* *GROUP-H-GAP*))))
    (setq x (+ x w *PROC-MARGIN*)))
  (princ (strcat "\n  PROC-A X: " (rtos (get-proc-x "PROC-A") 2 0)
                 "  PROC-B X: " (rtos (get-proc-x "PROC-B") 2 0))))

(defun str-insert-pt (target-id / tbl cnt key str result)
  (setq tbl '()  result nil)
  (foreach str *STRUCTURES*
    (setq key (strcat (nth 2 str) "_" (itoa (nth 3 str)))
          cnt (get-cnt tbl key))
    (if (equal (nth 0 str) target-id)
      (setq result (list (get-proc-x (nth 2 str))
                         (- *ORIG-Y* (* cnt (+ *STR-H* *STR-GAP*))))))
    (setq tbl (set-cnt tbl key (1+ cnt))))
  result)

;; ============================================================
;; 수학 / 각도 유틸리티 (Step 4)
;; ============================================================

(defun get-attr (blk-en tag dxf / en ed result)
  (setq en (entnext blk-en)  result nil)
  (while (and en (not result))
    (setq ed (entget en))
    (cond
      ((equal (cdr (assoc 0 ed)) "ATTRIB")
       (if (equal (strcase (cdr (assoc 2 ed))) (strcase tag))
         (setq result (cdr (assoc dxf ed))))
       (setq en (entnext en)))
      ((equal (cdr (assoc 0 ed)) "SEQEND")
       (setq en nil))
      (T (setq en (entnext en)))))
  result)

(defun port-ang (ent-id port-id / en blk-name rec val)
  (setq en (cdr (assoc ent-id *ENAME-CACHE*)))
  (if (null en) 0
    (progn
      ;; 1. 오버라이드 테이블 우선 — _ANG attribute 없는 블록 대응
      (setq blk-name (cdr (assoc 2 (entget en)))  rec nil)
      (foreach row *PORT-ANG-OVERRIDE*
        (if (and (equal (nth 0 row) blk-name)
                 (equal (nth 1 row) port-id))
          (setq rec row)))
      (if rec
        (nth 2 rec)
        ;; 2. attribute에서 읽기 (값 있을 때만)
        (progn
          (setq val (get-attr en (strcat port-id "_ANG") 1))
          (if val (atoi val) 0))))))

(defun rot-off (ox oy ang / a)
  (setq a (if (numberp ang) ang (atoi ang)))
  (cond ((= a 0)   (list ox      oy))
        ((= a 90)  (list (- oy)  ox))
        ((= a 180) (list (- ox)  (- oy)))
        ((= a 270) (list oy      (- ox)))
        (T         (list ox      oy))))

;; 각도(0/90/180/270)를 단위 방향벡터로 변환
(defun dir-vec (ang)
  (rot-off 1 0 ang))

;; pt에서 ang 방향으로 dist mm 이동한 점 (ang=nil이면 pt 그대로)
(defun lead-pt (pt ang dist / dv)
  (if (or (null ang) (null pt))
    pt
    (progn
      (setq dv (dir-vec ang))
      (list (+ (car pt)  (* (car  dv) dist))
            (+ (cadr pt) (* (cadr dv) dist))))))

(defun dom-ang (fp tp / dx dy)
  (setq dx (- (car tp) (car fp))
        dy (- (cadr tp) (cadr fp)))
  (cond ((>= (abs dx) (abs dy)) (if (>= dx 0) 0 180))
        (T                      (if (>= dy 0) 90 270))))

;; ============================================================
;; 블록 포트 오프셋 캐시 (블록 원점(0,0) 삽입 시 attribute 좌표 = 블록 공간 좌표)
;; ============================================================

;; 블록을 (0,0)에 삽입해 IN1/OUT1 좌표를 한 번에 읽고 캐시
(defun warm-port-cache (/ bn pre-en en i1 o1)
  (foreach bn '("P_VAV01" "P_VAV04" "P_VAV07" "P_VAV03"
                "FIT_FLNG" "FIT_CONRDC_IN" "FIT_CONRDC_OUT")
    (setvar "ATTREQ" 0)
    (setq pre-en (entlast))
    (command "._INSERT" bn '(0.0 0.0) 1 1 0)
    (setq en (if pre-en (entnext pre-en) (entlast))
          i1 (get-attr en "IN1"  10)
          o1 (get-attr en "OUT1" 10))
    (command "._U")
    (setvar "ATTREQ" 1)
    (if i1 (setq i1 (list (car i1) (cadr i1))) (setq i1 '(0.0 0.0)))
    (if o1 (setq o1 (list (car o1) (cadr o1))) (setq o1 i1))
    (setq *IN1-CACHE*  (cons (cons bn i1) *IN1-CACHE*))
    (setq *OUT1-CACHE* (cons (cons bn o1) *OUT1-CACHE*))
    (princ (strcat "\n  " bn
                   "  IN1=("  (rtos (car i1) 2 3) "," (rtos (cadr i1) 2 3) ")"
                   "  OUT1=(" (rtos (car o1) 2 3) "," (rtos (cadr o1) 2 3) ")")))
  (princ "\n  포트 캐시 완료"))

(defun get-in1-offset  (bn / r) (if (setq r (assoc bn *IN1-CACHE*))  (cdr r) '(0.0 0.0)))
(defun get-out1-offset (bn / r) (if (setq r (assoc bn *OUT1-CACHE*)) (cdr r) '(0.0 0.0)))

;; ============================================================
;; 부속품 체인
;; ============================================================

(defun resolve-blk (ckey port-id / ptype rec)
  (setq ptype
    (cond ((equal (substr port-id 1 3) "OUT") "OUT")
          ((equal (substr port-id 1 2) "IN")  "IN")
          (T nil)))
  (setq rec nil)
  (foreach row *PORT-VARIANTS*
    (if (and (equal (nth 0 row) ckey)
             (equal (nth 1 row) ptype))
      (setq rec row)))
  (if rec (nth 2 rec) ckey))

;; ins      = chain-pt - rot(IN1, ang)   → IN1이 chain-pt에 닿도록 삽입
;; next-pt  = ins      + rot(OUT1, ang)  → OUT1 세계 좌표가 다음 체인점
(defun place-acc (block-name chain-pt ang / in1 out1 rin rout ins)
  (setq in1  (get-in1-offset  block-name)
        out1 (get-out1-offset block-name)
        rin  (rot-off (car in1)  (cadr in1)  ang)
        rout (rot-off (car out1) (cadr out1) ang)
        ins  (list (- (car chain-pt)  (car rin))
                   (- (cadr chain-pt) (cadr rin))))
  (setvar "ATTREQ" 0)
  (command "._INSERT" block-name ins 1 1 ang)
  (setvar "ATTREQ" 1)
  (list (+ (car ins) (car rout))
        (+ (cadr ins) (cadr rout))))

(defun place-chain (chain-pt ang port-id acc-list / pt)
  (setq pt chain-pt)
  (foreach ckey acc-list
    (setq pt (lead-pt pt ang *ACC-GAP*))
    (setq pt (place-acc (resolve-blk ckey port-id) pt ang)))
  pt)

;; ============================================================
;; TEE 관리
;; ============================================================

(defun tee-pt (tee-id / rec)
  (setq rec (assoc tee-id *TEE-PTS*))
  (if rec (cdr rec) nil))

(defun elbow-pt (fp tp)
  (list (car tp) (cadr fp)))

(defun register-tees (fp tp tee-ids / n i step x y)
  (setq n (length tee-ids)  i 1)
  (if (= n 1)
    (setq *TEE-PTS* (cons (cons (car tee-ids) (elbow-pt fp tp)) *TEE-PTS*))
    (foreach tid tee-ids
      (setq step (/ (* i 1.0) (+ n 1))
            x    (+ (car  fp) (* step (- (car  tp) (car  fp))))
            y    (+ (cadr fp) (* step (- (cadr tp) (cadr fp)))))
      (setq *TEE-PTS* (cons (cons tid (list x y)) *TEE-PTS*))
      (setq i (1+ i)))))

(defun draw-tee-sym (pt)
  (command "._CIRCLE" (list (car pt) (cadr pt)) 8))

;; ============================================================
;; 엔티티 캐시
;; ============================================================

(defun get-slot-pt (blk-en tag / en ed result)
  (setq en (entnext blk-en)  result nil)
  (while (and en (not result))
    (setq ed (entget en))
    (cond
      ((equal (cdr (assoc 0 ed)) "ATTRIB")
       (if (equal (strcase (cdr (assoc 2 ed))) (strcase tag))
         (progn
           (setq result (cdr (assoc 10 ed)))
           ;; Z 제거 — 3D 좌표가 섞이면 배관에 대각선 발생
           (if result (setq result (list (car result) (cadr result))))))
       (setq en (entnext en)))
      ((equal (cdr (assoc 0 ed)) "SEQEND")
       (setq en nil))
      (T (setq en (entnext en)))))
  result)

(defun find-in-ss (target-pt ss / i en ed ins found)
  (setq found nil  i 0)
  (if ss
    (while (and (< i (sslength ss)) (not found))
      (setq en  (ssname ss i)
            ed  (entget en)
            ins (cdr (assoc 10 ed)))
      (if (and (< (abs (- (car  ins) (car  target-pt))) 1.0)
               (< (abs (- (cadr ins) (cadr target-pt))) 1.0))
        (setq found en)
        (setq i (1+ i)))))
  found)

(defun mch-insert-pt (target-id / mch result)
  (setq result nil)
  (foreach mch *MACHINES*
    (if (equal (nth 0 mch) target-id)
      (setq result
        (list (+ (get-proc-x (nth 2 mch))
                 *STR-W* *ACC-SPACE*
                 (* (nth 6 mch) (+ *MCH-W* *GROUP-H-GAP*)))
              (- (band-y (nth 3 mch))
                 (* (nth 5 mch) (+ *MCH-H* *MCH-V-GAP*)))))))
  result)

(defun build-ename-cache (/ all-ss pt en str-en rec)
  (setq *ENAME-CACHE* '()
        all-ss (ssget "X" '((0 . "INSERT"))))
  (if (null all-ss)
    (progn (princ "\n  [경고] INSERT 없음") (exit)))

  (foreach str *STRUCTURES*
    (setq pt (str-insert-pt (nth 0 str))
          en (if pt (find-in-ss pt all-ss) nil))
    (if en (setq *ENAME-CACHE* (cons (cons (nth 0 str) en) *ENAME-CACHE*))
           (princ (strcat "\n  [경고] " (nth 0 str) " 캐싱 실패"))))

  (foreach mch *MACHINES*
    (setq pt (mch-insert-pt (nth 0 mch))
          en (if pt (find-in-ss pt all-ss) nil))
    (if en (setq *ENAME-CACHE* (cons (cons (nth 0 mch) en) *ENAME-CACHE*))
           (princ (strcat "\n  [경고] " (nth 0 mch) " 캐싱 실패"))))

  (foreach imch *INT-MACHINES*
    (setq rec (assoc (nth 0 imch) *INT-ENAMES*))
    (if rec
      ;; INSERT 직후 캡처한 ename 재사용 (find-in-ss 불필요)
      (setq *ENAME-CACHE* (cons rec *ENAME-CACHE*))
      ;; fallback: ssget 탐색
      (progn
        (setq str-en (cdr (assoc (nth 2 imch) *ENAME-CACHE*)))
        (if str-en
          (progn
            (setq pt (get-slot-pt str-en (nth 3 imch))
                  en (if pt (find-in-ss pt all-ss) nil))
            (if en (setq *ENAME-CACHE* (cons (cons (nth 0 imch) en) *ENAME-CACHE*))
                   (princ (strcat "\n  [경고] " (nth 0 imch) " 캐싱 실패"))))
          (princ (strcat "\n  [경고] " (nth 2 imch) " 구조물 미캐시"))))))

  (princ (strcat "\n  캐시 완료: " (itoa (length *ENAME-CACHE*)) "개")))

;; ============================================================
;; 좌표 해석
;; ============================================================

(defun port-pt (ent-id port-id / en pt)
  (setq en (cdr (assoc ent-id *ENAME-CACHE*)))
  (if (null en)
    (progn (princ (strcat "\n  [경고] " ent-id " 캐시 없음")) nil)
    (progn
      (setq pt (get-slot-pt en port-id))
      (if (null pt) (princ (strcat "\n  [경고] " ent-id "." port-id " 없음")))
      pt)))

(defun resolve-spec (spec / type pt ang)
  (setq type (nth 0 spec))
  (cond
    ((or (equal type "S") (equal type "M"))
     (setq pt  (port-pt (nth 1 spec) (nth 2 spec))
           ang (if pt (port-ang (nth 1 spec) (nth 2 spec)) nil))
     (list pt ang))
    ((equal type "T")
     (list (tee-pt (nth 1 spec)) nil))
    (T (list nil nil))))

;; ============================================================
;; 배치 함수 (Step 2)
;; ============================================================

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
    (setq x (get-proc-x pid))
    (setq y (- *ORIG-Y* (* cnt (+ *STR-H* *STR-GAP*))))
    (command "._INSERT" ckey (list x y) 1 1 0)
    (command "._TEXT"
             (list (+ x 5) (+ y *STR-H* 10))
             *LBL-H* 0 str-id)
    (setq tbl (set-cnt tbl key (1+ cnt)))
    (princ (strcat "\n  구조물: " str-id
                   "  (" (rtos x 2 0) ", " (rtos y 2 0) ")")))
  (setvar "ATTREQ" 1))

(defun place-machines (/ mch-id ckey pid band grp-id ord grp-ord x y)
  (setvar "ATTREQ" 0)
  (foreach mch *MACHINES*
    (setq mch-id  (nth 0 mch)
          ckey    (nth 1 mch)
          pid     (nth 2 mch)
          band    (nth 3 mch)
          grp-id  (nth 4 mch)
          ord     (nth 5 mch)
          grp-ord (nth 6 mch))
    (setq x (+ (get-proc-x pid) *STR-W* *ACC-SPACE*
               (* grp-ord (+ *MCH-W* *GROUP-H-GAP*))))
    (setq y (- (band-y band) (* ord (+ *MCH-H* *MCH-V-GAP*))))
    (command "._INSERT" ckey (list x y) 1 1 0)
    (command "._TEXT"
             (list (+ x 2) (+ y *MCH-H* 8))
             *LBL-M* 0 mch-id)
    (princ (strcat "\n  외부기계: " mch-id
                   "  (" (rtos x 2 0) ", " (rtos y 2 0) ")")))
  (setvar "ATTREQ" 1))

(defun find-str-ename (str-id / pt ss i en ed ins found)
  (setq pt (str-insert-pt str-id)  found nil)
  (if (null pt)
    (princ (strcat "\n  [경고] " str-id " 삽입점 계산 실패"))
    (progn
      (setq ss (ssget "X" '((0 . "INSERT"))))
      (if ss
        (progn
          (setq i 0)
          (while (and (< i (sslength ss)) (not found))
            (setq en  (ssname ss i)
                  ed  (entget en)
                  ins (cdr (assoc 10 ed)))
            (if (and (< (abs (- (car  ins) (car  pt))) 1.0)
                     (< (abs (- (cadr ins) (cadr pt))) 1.0))
              (setq found en)
              (setq i (1+ i))))))))
  found)

(defun place-internal-machines (/ mch-id ckey str-id slot-tag blk-en pt pre-en en)
  (setq *INT-ENAMES* '())
  (setvar "ATTREQ" 0)
  (foreach mch *INT-MACHINES*
    (setq mch-id   (nth 0 mch)
          ckey     (nth 1 mch)
          str-id   (nth 2 mch)
          slot-tag (nth 3 mch))
    (setq blk-en (find-str-ename str-id))
    (if (null blk-en)
      (princ (strcat "\n  [경고] " str-id " 블록 없음 — " mch-id " 건너뜀"))
      (progn
        (setq pt (get-slot-pt blk-en slot-tag))
        (if (null pt)
          (princ (strcat "\n  [경고] " str-id " 슬롯 '" slot-tag "' 없음 — " mch-id " 건너뜀"))
          (progn
            ;; INSERT 직전 마지막 엔티티 기록 → entnext로 INSERT 엔티티 정확히 캡처
            (setq pre-en (entlast))
            ;; 슬롯 좌표 출력 (배치 위치 진단용)
            (princ (strcat "\n  [슬롯] " mch-id " → (" (rtos (car pt) 2 2)
                           ", " (rtos (cadr pt) 2 2) ")"))
            (command "._INSERT" ckey (list (car pt) (cadr pt)) 1 1 0)
            ;; entlast는 SEQEND를 반환 — entnext(pre-en)이 실제 INSERT 엔티티
            (setq en (if pre-en (entnext pre-en) (entlast)))
            (setq *INT-ENAMES* (cons (cons mch-id en) *INT-ENAMES*))
            (command "._TEXT"
                     (list (+ (car pt) 2) (+ (cadr pt) 35))
                     *LBL-M* 0 mch-id)
            (princ (strcat "\n  내부기계: " mch-id
                           "  슬롯=" slot-tag)))))))
  (setvar "ATTREQ" 1))

;; ============================================================
;; 레이어
;; ============================================================

(defun init-layers ()
  (foreach rec *MEDIA-LAYERS*
    (if (null (tblsearch "LAYER" (nth 1 rec)))
      (command "._-LAYER" "N" (nth 1 rec) "C" (itoa (nth 2 rec)) (nth 1 rec) ""))))

(defun set-media-layer (media / rec)
  (setq rec (assoc media *MEDIA-LAYERS*))
  (setvar "CLAYER" (if rec (nth 1 rec) "0")))

;; ============================================================
;; 배관 그리기
;; ============================================================

(defun draw-ortho (fp tp / dx dy elbow)
  (setq dx (abs (- (car tp)  (car fp)))
        dy (abs (- (cadr tp) (cadr fp))))
  (cond
    ((and (< dx 0.5) (< dy 0.5)) nil)
    ((< dx 0.5) (command "._LINE" fp tp ""))
    ((< dy 0.5) (command "._LINE" fp tp ""))
    (T
     (setq elbow (list (car tp) (cadr fp)))
     (command "._PLINE" fp elbow tp ""))))

;; 구조물→기계 전용: 수직(V) 먼저, 수평(H) 나중
;; *PIPE-IDX* 기반 채널 오프셋으로 같은 구조물 열에서 나오는 배관 겹침 방지
(defun draw-ortho-str-mch (fp tp / dx dy chan-x)
  (setq dx     (abs (- (car  tp) (car  fp)))
        dy     (abs (- (cadr tp) (cadr fp)))
        chan-x (+ (car fp) (* *PIPE-IDX* *VERT-CH-STEP*)))
  (cond
    ((and (< dx 0.5) (< dy 0.5)) nil)
    ((< dx 0.5) (command "._LINE" fp tp ""))
    ((< dy 0.5) (command "._LINE" fp tp ""))
    (T
     (if (< (abs (- chan-x (car fp))) 0.5)
       ;; idx=0: 바로 V→H
       (command "._PLINE" fp (list (car fp) (cadr tp)) tp "")
       ;; idx>0: 짧은 H 이동(채널 확보) → V → H
       (command "._PLINE"
         fp
         (list chan-x (cadr fp))
         (list chan-x (cadr tp))
         tp "")))))

(defun draw-with-inline (fp tp ia port-id / ang mid acc-end)
  (setq ang     (dom-ang fp tp)
        mid     (list (/ (+ (car fp) (car tp)) 2.0)
                      (/ (+ (cadr fp) (cadr tp)) 2.0))
        acc-end (place-chain mid ang port-id ia))
  (draw-ortho fp mid)
  (draw-ortho acc-end tp))

(defun process-pipe (pipe / pid fspec tspec fa ta ia tees media
                          fres tres fp-base tp-base fp-ang tp-ang
                          pipe-fp pipe-tp fp-outer tp-outer str-to-mch)
  (setq pid        (nth 0 pipe)
        fspec      (nth 1 pipe)
        tspec      (nth 2 pipe)
        fa         (nth 3 pipe)
        ta         (nth 4 pipe)
        ia         (nth 5 pipe)
        tees       (nth 6 pipe)
        media      (nth 7 pipe)
        str-to-mch (and (equal (nth 0 fspec) "S") (equal (nth 0 tspec) "M")))

  (set-media-layer media)

  ;; FROM 체인 배치
  (setq fres    (resolve-spec fspec)
        fp-base (nth 0 fres)
        fp-ang  (nth 1 fres))
  (if (and fp-base fp-ang fa)
    (setq pipe-fp (place-chain fp-base fp-ang (nth 2 fspec) fa))
    (setq pipe-fp fp-base))

  ;; TO 체인 배치
  (setq tres    (resolve-spec tspec)
        tp-base (nth 0 tres)
        tp-ang  (nth 1 tres))
  (if (and tp-base tp-ang ta)
    (setq pipe-tp (place-chain tp-base tp-ang (nth 2 tspec) ta))
    (setq pipe-tp tp-base))

  (if (and pipe-fp pipe-tp)
    (progn
      ;; 노즐 방향으로 *PORT-LEAD* mm 직관 후 꺾임 (rules §16)
      ;; TEE 출발(ang=nil)은 리드 없이 그대로 사용
      (setq fp-outer (lead-pt pipe-fp fp-ang *PORT-LEAD*)
            tp-outer (lead-pt pipe-tp tp-ang *PORT-LEAD*))

      ;; FROM 리드 선분 (체인 끝 → 꺾임 시작점)
      (if (not (equal fp-outer pipe-fp))
        (command "._LINE" pipe-fp fp-outer ""))

      ;; TO 리드 선분 (체인 끝 → 꺾임 시작점)
      (if (not (equal tp-outer pipe-tp))
        (command "._LINE" pipe-tp tp-outer ""))

      ;; 메인 배관 (fp-outer ↔ tp-outer)
      (if ia
        (draw-with-inline fp-outer tp-outer ia "IN1")
        (if str-to-mch
          (draw-ortho-str-mch fp-outer tp-outer)  ; 구조물→기계: V 먼저
          (draw-ortho fp-outer tp-outer)))

      ;; TEE는 메인 구간 기준으로 등록
      (if tees
        (progn
          (register-tees fp-outer tp-outer tees)
          (foreach tid tees
            (draw-tee-sym (tee-pt tid)))))

      (princ (strcat "\n  배관: " pid " [" media "]")))
    (princ (strcat "\n  [건너뜀] " pid))))

(defun place-pipes ()
  (setq *PIPE-IDX* 0)
  (foreach pipe *PIPES*
    (process-pipe pipe)
    (setq *PIPE-IDX* (1+ *PIPE-IDX*))))

;; ============================================================
;; PID-DIAGN — 구조 진단 커맨드 (PID-STEP4 실행 후 사용)
;; 내부기계 슬롯 좌표, 부속품 IN1 오프셋, 포트 위치/각도 출력
;; ============================================================

(defun c:PID-DIAGN (/ pt ang off blk-en roff ins)
  (setvar "CMDECHO" 0)
  (setq *PROC-X* '()  *IN1-CACHE* '()  *OUT1-CACHE* '()  *ENAME-CACHE* '()  *INT-ENAMES* '())
  (princ "\n========== PID-DIAGN 시작 ==========\n")

  ;; [A] 부속품 IN1 오프셋 + BLOCK-ADV 통과거리
  (princ "\n--- [A] 부속품 IN1 오프셋 / *BLOCK-ADV* 통과거리 ---")
  (foreach bn '("P_VAV01" "P_VAV07" "FIT_FLNG")
    (setq i1  (get-in1-offset bn)
          adv (assoc bn *BLOCK-ADV*))
    (princ (strcat "\n  " bn
                   "  IN1=(" (rtos (car i1) 2 4) "," (rtos (cadr i1) 2 4) ")"
                   "  ADV=" (if adv (rtos (nth 1 adv) 2 3) "없음(0)"))))

  ;; [B] 포트 위치 & 각도
  (compute-proc-x)
  (build-ename-cache)
  (princ "\n--- [B] 포트 위치 & 각도 ---")
  (foreach spec '(("STR-A01" "OUT1") ("STR-A02" "OUT1")
                  ("MCH-A03" "IN1")  ("MCH-A05" "IN1"))
    (setq pt  (port-pt  (nth 0 spec) (nth 1 spec))
          ang (port-ang (nth 0 spec) (nth 1 spec)))
    (if pt
      (princ (strcat "\n  " (nth 0 spec) "." (nth 1 spec)
                     " = (" (rtos (car pt) 2 2) ", " (rtos (cadr pt) 2 2) ")"
                     "  ang=" (itoa ang) "deg"))
      (princ (strcat "\n  " (nth 0 spec) "." (nth 1 spec) " = NOT FOUND"))))

  ;; [C] 내부기계 슬롯 좌표 (구조물 블록에서 직접 읽음)
  (princ "\n--- [C] 내부기계 슬롯 좌표 ---")
  (foreach mch *INT-MACHINES*
    (setq blk-en (find-str-ename (nth 2 mch))
          pt     (if blk-en (get-slot-pt blk-en (nth 3 mch)) nil))
    (if pt
      (princ (strcat "\n  " (nth 0 mch) " [" (nth 3 mch) "]"
                     " = (" (rtos (car pt) 2 2) ", " (rtos (cadr pt) 2 2) ")"))
      (princ (strcat "\n  " (nth 0 mch) " [" (nth 3 mch) "] = NOT FOUND"))))

  ;; [D] FROM 체인 삽입 위치 추적 (STR-A01 OUT1 기준)
  (princ "\n--- [D] FROM 체인 삽입 위치 (STR-A01→ ang=0) ---")
  (setq pt (port-pt "STR-A01" "OUT1")  ang 0)
  (if pt
    (foreach ckey '("P_VAV01" "FIT_FLNG")
      (setq pt   (lead-pt pt ang *ACC-GAP*)
            off  (get-in1-offset (resolve-blk ckey "OUT1"))
            roff (rot-off (car off) (cadr off) ang)
            ins  (list (- (car pt) (car roff)) (- (cadr pt) (cadr roff))))
      (princ (strcat "\n  " ckey
                     "  IN1목표=(" (rtos (car pt) 2 2) "," (rtos (cadr pt) 2 2) ")"
                     "  삽입점=(" (rtos (car ins) 2 2) "," (rtos (cadr ins) 2 2) ")")))
    (princ "\n  STR-A01.OUT1 없음"))

  ;; [E] TO 체인 삽입 위치 추적 (MCH-A03 IN1 기준, ang=180)
  (princ "\n--- [E] TO 체인 삽입 위치 (MCH-A03 IN1← ang=180) ---")
  (setq pt (port-pt "MCH-A03" "IN1")  ang 180)
  (if pt
    (foreach ckey '("P_VAV07" "P_VAV01" "FIT_FLNG")
      (setq pt   (lead-pt pt ang *ACC-GAP*)
            off  (get-in1-offset (resolve-blk ckey "IN1"))
            roff (rot-off (car off) (cadr off) ang)
            ins  (list (- (car pt) (car roff)) (- (cadr pt) (cadr roff))))
      (princ (strcat "\n  " ckey
                     "  IN1목표=(" (rtos (car pt) 2 2) "," (rtos (cadr pt) 2 2) ")"
                     "  삽입점=(" (rtos (car ins) 2 2) "," (rtos (cadr ins) 2 2) ")")))
    (princ "\n  MCH-A03.IN1 없음"))

  (princ "\n\n========== PID-DIAGN 완료 ==========\n")
  (setvar "CMDECHO" 1)
  (princ))

;; ============================================================
;; PID-CHECK — 기존 진단 커맨드
;; ============================================================

(defun c:PID-CHECK (/ ok pt val bn off)
  (setvar "CMDECHO" 0)
  (setq *PROC-X* '()  *IN1-CACHE* '()  *OUT1-CACHE* '()  *ENAME-CACHE* '())
  (princ "\n========== PID-CHECK 시작 ==========\n")

  ;; 1. 공정 X 계산
  (compute-proc-x)

  ;; 2. 엔티티 캐시
  (princ "\n--- [1] 엔티티 캐시 ---")
  (build-ename-cache)

  ;; 3. STR-A01 포트 확인
  (princ "\n--- [2] STR-A01 포트 ---")
  (setq pt (port-pt "STR-A01" "OUT1"))
  (if pt
    (princ (strcat "\n  STR-A01.OUT1 = (" (rtos (car pt) 2 2) ", " (rtos (cadr pt) 2 2) ")"))
    (princ "\n  STR-A01.OUT1 = NOT FOUND"))
  (setq val (port-ang "STR-A01" "OUT1"))
  (princ (strcat "\n  STR-A01 OUT1_ANG = " (itoa val) " deg"))

  (setq pt (port-pt "STR-A01" "IN1"))
  (if pt
    (princ (strcat "\n  STR-A01.IN1  = (" (rtos (car pt) 2 2) ", " (rtos (cadr pt) 2 2) ")"))
    (princ "\n  STR-A01.IN1  = NOT FOUND"))

  ;; 4. MCH-A03 포트 확인
  (princ "\n--- [3] MCH-A03 포트 ---")
  (setq pt (port-pt "MCH-A03" "IN1"))
  (if pt
    (princ (strcat "\n  MCH-A03.IN1  = (" (rtos (car pt) 2 2) ", " (rtos (cadr pt) 2 2) ")"))
    (princ "\n  MCH-A03.IN1  = NOT FOUND"))
  (setq val (port-ang "MCH-A03" "IN1"))
  (princ (strcat "\n  MCH-A03 IN1_ANG  = " (itoa val) " deg"))

  (setq pt (port-pt "MCH-A03" "OUT1"))
  (if pt
    (princ (strcat "\n  MCH-A03.OUT1 = (" (rtos (car pt) 2 2) ", " (rtos (cadr pt) 2 2) ")"))
    (princ "\n  MCH-A03.OUT1 = NOT FOUND"))

  ;; 5. 부속품 블록 IN1 오프셋 확인
  (princ "\n--- [4] 부속품 IN1 오프셋 (원점 삽입 기준) ---")
  (foreach bn '("P_VAV01" "P_VAV07" "FIT_FLNG")
    (setq off (get-in1-offset bn))
    (if off
      (princ (strcat "\n  " bn " IN1 = (" (rtos (car off) 2 3) ", " (rtos (cadr off) 2 3) ")"))
      (princ (strcat "\n  " bn " IN1 = FAILED (블록 없음?)"))))

  (princ "\n\n========== PID-CHECK 완료 ==========\n")
  (setvar "CMDECHO" 1)
  (princ))

;; ============================================================
;; 진입점
;; ============================================================

(defun c:PID-STEP4 (/ *saved-osmode*)
  (setvar "CMDECHO" 0)
  (setq *saved-osmode* (getvar "OSMODE"))
  (setvar "OSMODE" 0)
  (setq *TEE-PTS* '()  *IN1-CACHE* '()  *OUT1-CACHE* '()  *ENAME-CACHE* '()  *PIPE-IDX* 0  *INT-ENAMES* '())

  (princ "\n[Step4] 포트 캐시 워밍...\n")
  (warm-port-cache)  ; UNDO BE 전 — 임시 삽입이 메인 UNDO에 포함 안 되도록

  (command "._UNDO" "BE")

  (princ "\n[Step4] 공정 X 좌표 계산...\n")
  (compute-proc-x)

  (princ "\n[Step4] 구조물 배치...\n")
  (place-structures)

  (princ "\n[Step4] 외부 기계 배치...\n")
  (place-machines)

  (princ "\n[Step4] 내부 기계 배치...\n")
  (place-internal-machines)

  (princ "\n[Step4] 레이어 초기화...\n")
  (init-layers)

  (princ "\n[Step4] 엔티티 캐시 구축...\n")
  (build-ename-cache)

  (princ "\n[Step4] 배관 + 부속품 생성...\n")
  (place-pipes)

  (setvar "CLAYER" "0")
  (command "._ZOOM" "E")
  (command "._UNDO" "E")
  (setvar "OSMODE" *saved-osmode*)
  (setvar "CMDECHO" 1)
  (princ "\n[Step4] 완료.\n")
  (princ))

(princ "\nPID-STEP4 로드 완료. 'PID-STEP4' 입력 후 실행하세요.\n")
(princ)
