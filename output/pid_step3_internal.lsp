;;; ============================================================
;;; PID-ENGINE  Step 3 — 내부 기계 배치
;;; 구조물 블록의 슬롯 attribute (invisible, TAG = parent_key) 위치에
;;; 기계 블록 삽입
;;; 전제: pid_step2_machines.lsp 로드 + PID-STEP2 실행 완료
;;;       (*PROC-X*, *STRUCTURES*, *ORIG-Y*, *STR-H*, *STR-GAP*,
;;;        get-proc-x, get-cnt 함수 사용)
;;; 실행: (load "전체경로/pid_step3_internal.lsp") 후 PID-STEP3
;;; ============================================================

;; ── 내부 기계 데이터 ─────────────────────────────────────────
;; (mch-id  code_key  str-id  slot-tag)
;; slot-tag = 해당 code_key 의 DB parent_key
(setq *INT-MACHINES*
  '(("MCH-A17" "M_FDC01"  "STR-A01" "M_FDCT")
    ("MCH-A18" "M_TDIF04" "STR-A01" "M_TDIF")
    ("MCH-A19" "M_FDC01"  "STR-A02" "M_FDCT")
    ("MCH-A20" "M_TDIF04" "STR-A02" "M_TDIF")))

;; ── 구조물 삽입점 계산 ───────────────────────────────────────
;; Step 2 globals: *STRUCTURES*, *PROC-X*, *ORIG-Y*, *STR-H*, *STR-GAP*
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

;; ── 구조물 블록 엔티티 탐색 ──────────────────────────────────
;; 계산된 삽입점과 일치하는 INSERT 엔티티 반환 (허용 오차 ±1mm)
(defun find-str-ename (str-id / pt ss i en ed ins found)
  (setq pt (str-insert-pt str-id)
        found nil)
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

;; ── 슬롯 attribute 삽입점 추출 ───────────────────────────────
;; 블록 내 ATTRIB 중 TAG = slot-tag 인 것의 삽입점(10) 반환
(defun get-slot-pt (blk-en slot-tag / en ed result)
  (setq en (entnext blk-en)  result nil)
  (while (and en (not result))
    (setq ed (entget en))
    (cond
      ((equal (cdr (assoc 0 ed)) "ATTRIB")
       (if (equal (strcase (cdr (assoc 2 ed))) (strcase slot-tag))
         (setq result (cdr (assoc 10 ed))))
       (setq en (entnext en)))
      ((equal (cdr (assoc 0 ed)) "SEQEND")
       (setq en nil))
      (T (setq en (entnext en)))))
  result)

;; ── 내부 기계 배치 ───────────────────────────────────────────
(defun place-internal-machines (/ mch-id ckey str-id slot-tag blk-en pt)
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
          (princ (strcat "\n  [경고] " str-id
                         " 슬롯 '" slot-tag "' 없음 — " mch-id " 건너뜀"))
          (progn
            (command "._INSERT" ckey (list (car pt) (cadr pt)) 1 1 0)
            (command "._TEXT"
                     (list (+ (car pt) 2) (+ (cadr pt) 35))
                     18 0 mch-id)
            (princ (strcat "\n  내부기계 배치: " mch-id
                           "  슬롯=" slot-tag
                           "  (" (rtos (car pt) 2 0)
                           ", " (rtos (cadr pt) 2 0) ")")))))))
  (setvar "ATTREQ" 1))

;; ── 진입점 ────────────────────────────────────────────────────
(defun c:PID-STEP3 ()
  (command "._UNDO" "BE")
  (setvar "CMDECHO" 0)
  (princ "\n[Step3] 내부 기계 배치...\n")
  (place-internal-machines)
  (command "._ZOOM" "E")
  (setvar "CMDECHO" 1)
  (command "._UNDO" "E")
  (princ "\n[Step3] 완료.\n")
  (princ))

(princ "\nPID-STEP3 로드 완료. 커맨드라인에서 'PID-STEP3' 입력 후 실행하세요.\n")
(princ)
