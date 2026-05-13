;;; ============================================================
;;; PID-ENGINE  유틸리티 — 공통함수 / 수학 / 포트캐시 / 엔티티캐시
;;; ============================================================

;; ============================================================
;; 공통 유틸리티
;; ============================================================

(defun get-cnt (tbl key / rec)
  (setq rec (assoc key tbl))
  (if rec (cdr rec) 0))

(defun set-cnt (tbl key val)
  (if (assoc key tbl)
    (subst (cons key val) (assoc key tbl) tbl)
    (cons (cons key val) tbl)))

;; ============================================================
;; 레이아웃 계산
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
;; 수학 / 각도 유틸리티
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
      (setq blk-name (cdr (assoc 2 (entget en)))  rec nil)
      (foreach row *PORT-ANG-OVERRIDE*
        (if (and (equal (nth 0 row) blk-name)
                 (equal (nth 1 row) port-id))
          (setq rec row)))
      (if rec
        (nth 2 rec)
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

(defun dir-vec (ang)
  (rot-off 1 0 ang))

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
;; 포트 오프셋 캐시
;; insert=visual-center 규칙: hw = (OUT1_raw - IN1_raw)/2
;; → in1_offset = -hw, out1_offset = +hw
;; ============================================================

(defun warm-port-cache (/ bn pre-en en i1r o1r hw in1 out1)
  (foreach bn '("P_VAV01" "P_VAV04" "P_VAV07" "P_VAV03"
                "FIT_FLNG" "FIT_CONRDC_IN" "FIT_CONRDC_OUT")
    (setvar "ATTREQ" 0)
    (setq pre-en (entlast))
    (command "._INSERT" bn '(0.0 0.0) 1 1 0)
    (setq en  (if pre-en (entnext pre-en) (entlast))
          i1r (get-attr en "IN1"  10)
          o1r (get-attr en "OUT1" 10))
    (command "._U")
    (setvar "ATTREQ" 1)
    (if (and i1r o1r)
      (progn
        (setq hw   (list (* 0.5 (- (car o1r)  (car i1r)))
                         (* 0.5 (- (cadr o1r) (cadr i1r))))
              in1  (list (- (car hw)) (- (cadr hw)))
              out1 hw))
      (setq in1 '(0.0 0.0)  out1 '(0.0 0.0)))
    (setq *IN1-CACHE*  (cons (cons bn in1)  *IN1-CACHE*))
    (setq *OUT1-CACHE* (cons (cons bn out1) *OUT1-CACHE*))
    (princ (strcat "\n  " bn
                   "  IN1=("  (rtos (car in1)  2 3) "," (rtos (cadr in1)  2 3) ")"
                   "  OUT1=(" (rtos (car out1) 2 3) "," (rtos (cadr out1) 2 3) ")")))
  (princ "\n  포트 캐시 완료"))

(defun get-in1-offset  (bn / r) (if (setq r (assoc bn *IN1-CACHE*))  (cdr r) '(0.0 0.0)))
(defun get-out1-offset (bn / r) (if (setq r (assoc bn *OUT1-CACHE*)) (cdr r) '(0.0 0.0)))

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
      (setq *ENAME-CACHE* (cons rec *ENAME-CACHE*))
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

(princ "\npid_utils 로드 완료\n")
(princ)
