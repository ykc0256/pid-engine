;;; ============================================================
;;; PID-ENGINE  배치 함수 — 부속품 체인 / TEE / 구조물·기계 배치
;;; ============================================================

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

;; ins     = chain-pt - rot(IN1, ang)   → IN1이 chain-pt에 닿도록 삽입
;; next-pt = ins      + rot(OUT1, ang)  → OUT1 세계 좌표가 다음 체인점
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
;; 블록 배치 — 구조물 / 기계
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

(princ "\npid_place 로드 완료\n")
(princ)
