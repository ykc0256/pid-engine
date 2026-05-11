;;; ============================================================
;;; PID-ENGINE  Step 4 — 배관 그리기
;;; 전제: pid_step2_machines.lsp 로드 + PID-STEP2 실행 완료
;;; 실행: (load "전체경로/pid_step4_pipes.lsp") 후 PID-STEP4
;;; ============================================================

;; ── media 레이어/색상 ────────────────────────────────────────
;; (media  layer-name  aci-color)
(setq *MEDIA-LAYERS*
  '(("sewage"   "PID-SEWAGE"   4)   ; 원수  = cyan
    ("sludge"   "PID-SLUDGE"   3)   ; 슬러지 = green
    ("air"      "PID-AIR"      7)   ; 공기  = white
    ("chemical" "PID-CHEMICAL" 6))) ; 약품  = magenta

(defun init-layers (/ rec)
  (foreach rec *MEDIA-LAYERS*
    (if (null (tblsearch "LAYER" (nth 1 rec)))
      (command "._-LAYER" "N" (nth 1 rec) "C" (itoa (nth 2 rec)) (nth 1 rec) ""))
    ))

(defun set-media-layer (media / rec)
  (setq rec (assoc media *MEDIA-LAYERS*))
  (setvar "CLAYER" (if rec (nth 1 rec) "0")))

;; ── 파이프 데이터 (위상 정렬 순서) ───────────────────────────
;; 형식: (pipe-id  from-spec  to-spec  tees-list  media)
;; from/to-spec:
;;   ("S" str-id  port-id)  — 구조물 포트
;;   ("M" mch-id  port-id)  — 기계 포트
;;   ("T" tee-id)           — 기등록 TEE 좌표
;; tees-list: (tee-id ...) 또는 nil

(setq *PIPES*
  '(
    ;; ─ Pass 1: TEE 의존성 없음 ────────────────────────────────
    ("PIPE-A01" ("S" "STR-A01" "OUT1") ("M" "MCH-A03" "IN1")  ("TEE-A1-1") "sludge")
    ("PIPE-A02" ("S" "STR-A02" "OUT1") ("M" "MCH-A05" "IN1")  ("TEE-A1-2") "sludge")
    ("PIPE-A05" ("M" "MCH-A03" "OUT1") ("M" "MCH-A06" "IN1")  ("TEE-A2-1") "sludge")
    ("PIPE-A06" ("M" "MCH-A05" "OUT1") ("M" "MCH-A07" "IN1")  ("TEE-A2-2") "sludge")
    ("PIPE-A09" ("M" "MCH-A06" "OUT1") ("M" "MCH-A08" "IN1")  ("TEE-A3-1") "sludge")
    ("PIPE-A10" ("M" "MCH-A07" "OUT1") ("M" "MCH-A10" "IN1")  ("TEE-A3-2") "sludge")
    ("PIPE-A13" ("M" "MCH-A08" "OUT1") ("S" "STR-A01" "IN1")  ("TEE-A4-1") "sludge")
    ("PIPE-A14" ("M" "MCH-A10" "OUT1") ("S" "STR-A02" "IN1")  ("TEE-A4-2") "sludge")
    ("PIPE-A17" ("M" "MCH-A11" "OUT1") ("M" "MCH-A18" "IN1")  ("TEE-A5-1") "air")
    ("PIPE-A18" ("M" "MCH-A13" "OUT1") ("M" "MCH-A20" "IN1")  ("TEE-A5-2") "air")
    ("PIPE-A21" ("M" "MCH-A14" "OUT1") ("M" "MCH-A06" "IN2")  ("TEE-A6-1") "air")
    ("PIPE-A22" ("M" "MCH-A16" "OUT1") ("M" "MCH-A07" "IN2")  ("TEE-A6-2") "air")
    ("PIPE-A25" ("M" "MCH-A17" "OUT1") ("M" "MCH-A01" "IN1")  nil          "sewage")
    ("PIPE-A26" ("M" "MCH-A19" "OUT1") ("M" "MCH-A02" "IN1")  nil          "sewage")
    ("PIPE-B01" ("S" "STR-B01" "OUT1") ("M" "MCH-B03" "IN1")  ("TEE-B2")   "sewage")
    ("PIPE-B04" ("S" "STR-B01" "OUT2") ("M" "MCH-B04" "IN1")  ("TEE-B3")   "sludge")

    ;; ─ Pass 2: Pass 1 TEE 의존 ────────────────────────────────
    ("PIPE-A03" ("T" "TEE-A1-1") ("T" "TEE-A1-2") ("TEE-A1-3") "sludge")
    ("PIPE-A07" ("T" "TEE-A2-1") ("T" "TEE-A2-2") ("TEE-A2-3") "sludge")
    ("PIPE-A11" ("T" "TEE-A3-1") ("T" "TEE-A3-2") ("TEE-A3-3") "sludge")
    ("PIPE-A15" ("T" "TEE-A4-1") ("T" "TEE-A4-2") ("TEE-A4-3") "sludge")
    ("PIPE-A19" ("T" "TEE-A5-1") ("T" "TEE-A5-2") ("TEE-A5-3") "air")
    ("PIPE-A23" ("T" "TEE-A6-1") ("T" "TEE-A6-2") ("TEE-A6-3") "air")
    ("PIPE-B02" ("T" "TEE-B2")   ("M" "MCH-B01" "IN1") ("TEE-B1") "sewage")
    ("PIPE-B05" ("T" "TEE-B3")   ("M" "MCH-B05" "IN1") nil        "sludge")

    ;; ─ Pass 3: Pass 2 TEE 의존 ────────────────────────────────
    ("PIPE-A04" ("T" "TEE-A1-3") ("M" "MCH-A04" "IN1")  nil "sludge")
    ("PIPE-A08" ("M" "MCH-A04" "OUT1") ("T" "TEE-A2-3")  nil "sludge")
    ("PIPE-A12" ("T" "TEE-A3-3") ("M" "MCH-A09" "IN1")  nil "sludge")
    ("PIPE-A16" ("M" "MCH-A09" "OUT1") ("T" "TEE-A4-3")  nil "sludge")
    ("PIPE-A20" ("M" "MCH-A12" "OUT1") ("T" "TEE-A5-3")  nil "air")
    ("PIPE-A24" ("M" "MCH-A15" "OUT1") ("T" "TEE-A6-3")  nil "air")
    ("PIPE-B03" ("T" "TEE-B1")  ("M" "MCH-B02" "IN1")   nil "sewage")
  ))

;; ── TEE 위치 레지스트리 ──────────────────────────────────────
(setq *TEE-PTS* '())

(defun tee-pt (tee-id / rec)
  (setq rec (assoc tee-id *TEE-PTS*))
  (if rec (cdr rec) nil))

;; TEE 위치 = 직각 라우팅의 꺾임점(elbow)
;; 꺾임점: (to.x, from.y)  — H 먼저 이동 후 V
(defun elbow-pt (fp tp)
  (list (car tp) (cadr fp)))

;; 파이프 위의 TEE 등록
;; 1개 TEE → elbow, 2개 이상 → 균등 분할 (현재 항상 최대 1개)
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

;; ── 엔티티 캐시 ──────────────────────────────────────────────
(setq *ENAME-CACHE* '())

;; 선택셋에서 삽입점이 pt 와 일치하는 INSERT 반환 (±1mm)
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

;; 외부 기계 삽입점 계산 (Step 2 공식)
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

;; 엔티티 캐시 구축 (SSGET 1회 후 일괄 처리)
(defun build-ename-cache (/ all-ss pt en str-en)
  (setq *ENAME-CACHE* '()
        all-ss (ssget "X" '((0 . "INSERT"))))
  (if (null all-ss)
    (progn (princ "\n  [경고] INSERT 엔티티 없음") (exit)))

  (foreach str *STRUCTURES*
    (setq pt (str-insert-pt (nth 0 str))
          en (if pt (find-in-ss pt all-ss) nil))
    (if en
      (setq *ENAME-CACHE* (cons (cons (nth 0 str) en) *ENAME-CACHE*))
      (princ (strcat "\n  [경고] " (nth 0 str) " 캐싱 실패"))))

  (foreach mch *MACHINES*
    (setq pt (mch-insert-pt (nth 0 mch))
          en (if pt (find-in-ss pt all-ss) nil))
    (if en
      (setq *ENAME-CACHE* (cons (cons (nth 0 mch) en) *ENAME-CACHE*))
      (princ (strcat "\n  [경고] " (nth 0 mch) " 캐싱 실패"))))

  (foreach imch *INT-MACHINES*
    (setq str-en (cdr (assoc (nth 2 imch) *ENAME-CACHE*)))
    (if str-en
      (progn
        (setq pt (get-slot-pt str-en (nth 3 imch))
              en (if pt (find-in-ss pt all-ss) nil))
        (if en
          (setq *ENAME-CACHE* (cons (cons (nth 0 imch) en) *ENAME-CACHE*))
          (princ (strcat "\n  [경고] " (nth 0 imch) " 캐싱 실패"))))
      (princ (strcat "\n  [경고] " (nth 2 imch) " 구조물 미캐시"))))

  (princ (strcat "\n  캐시 완료: " (itoa (length *ENAME-CACHE*)) "개")))

;; ── 포트 좌표 조회 ───────────────────────────────────────────
(defun port-pt (ent-id port-id / en pt)
  (setq en (cdr (assoc ent-id *ENAME-CACHE*)))
  (if (null en)
    (progn (princ (strcat "\n  [경고] " ent-id " 캐시 없음")) nil)
    (progn
      (setq pt (get-slot-pt en port-id))
      (if (null pt)
        (princ (strcat "\n  [경고] " ent-id "." port-id " 포트 없음")))
      pt)))

;; ── from/to 스펙 → 좌표 ──────────────────────────────────────
(defun resolve-pt (spec / type)
  (setq type (nth 0 spec))
  (cond
    ((or (equal type "S") (equal type "M"))
     (port-pt (nth 1 spec) (nth 2 spec)))
    ((equal type "T")
     (tee-pt (nth 1 spec)))
    (T nil)))

;; ── 직각 배관 그리기 ─────────────────────────────────────────
;; H 먼저 → V: from → (to.x, from.y) → to
;; 수직/수평 단일 직선은 LINE 사용
(defun draw-pipe-ortho (fp tp / elbow dx dy)
  (setq dx (abs (- (car tp)  (car fp)))
        dy (abs (- (cadr tp) (cadr fp))))
  (cond
    ((and (< dx 0.5) (< dy 0.5)) nil)            ; 동일점 — 무시
    ((< dx 0.5)                                   ; 수직 단일 직선
     (command "._LINE" fp tp ""))
    ((< dy 0.5)                                   ; 수평 단일 직선
     (command "._LINE" fp tp ""))
    (T                                            ; L형: H → V
     (setq elbow (list (car tp) (cadr fp)))
     (command "._PLINE" fp elbow tp ""))))

;; TEE 접합 심볼 (소원)
(defun draw-tee-symbol (pt)
  (command "._CIRCLE" (list (car pt) (cadr pt)) 8))

;; ── 배관 전체 처리 ───────────────────────────────────────────
(defun place-pipes (/ pipe-id from-spec to-spec tee-ids media fp tp)
  (foreach pipe *PIPES*
    (setq pipe-id   (nth 0 pipe)
          from-spec (nth 1 pipe)
          to-spec   (nth 2 pipe)
          tee-ids   (nth 3 pipe)
          media     (nth 4 pipe)
          fp        (resolve-pt from-spec)
          tp        (resolve-pt to-spec))
    (if (and fp tp)
      (progn
        (set-media-layer media)
        (draw-pipe-ortho fp tp)
        (if tee-ids
          (progn
            (register-tees fp tp tee-ids)
            (foreach tid tee-ids
              (draw-tee-symbol (tee-pt tid)))))
        (princ (strcat "\n  배관: " pipe-id " [" media "]")))
      (princ (strcat "\n  [건너뜀] " pipe-id)))))

;; ── 진입점 ────────────────────────────────────────────────────
(defun c:PID-STEP4 ()
  (command "._UNDO" "BE")
  (setvar "CMDECHO" 0)
  (setq *TEE-PTS* '())
  (princ "\n[Step4] 레이어 초기화...\n")
  (init-layers)
  (princ "\n[Step4] 엔티티 캐시 구축...\n")
  (build-ename-cache)
  (princ "\n[Step4] 배관 그리기 (직각 라우팅)...\n")
  (place-pipes)
  (setvar "CLAYER" "0")
  (command "._ZOOM" "E")
  (setvar "CMDECHO" 1)
  (command "._UNDO" "E")
  (princ "\n[Step4] 완료.\n")
  (princ))

(princ "\nPID-STEP4 로드 완료. 커맨드라인에서 'PID-STEP4' 입력 후 실행하세요.\n")
(princ)
