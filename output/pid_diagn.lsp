;;; ============================================================
;;; PID-ENGINE  진단 커맨드 — PID-DIAGN
;;; PID-STEP4 실행 후 노즐 위치 vs 실제 부속품 위치 비교
;;; ============================================================

(defun c:PID-DIAGN (/ pt ang exp ss i en ed ins-pt i1 o1 cnt)
  (setvar "CMDECHO" 0)
  (setq *PROC-X* '()  *ENAME-CACHE* '()  *INT-ENAMES* '())
  (compute-proc-x)
  (build-ename-cache)
  (princ "\n========== PID-DIAGN ==========")

  ;; ── [1] 노즐 좌표 & 첫 부속품 기대 IN1 ──────────────────────
  (princ "\n\n[1] 노즐 위치 & 첫 부속품 기대 IN1  (노즐 + ACC-GAP 방향)")
  (foreach spec '(("STR-A01" "OUT1") ("STR-A02" "OUT1")
                  ("MCH-A03" "IN1")  ("MCH-A05" "IN1"))
    (setq pt  (port-pt  (nth 0 spec) (nth 1 spec))
          ang (port-ang (nth 0 spec) (nth 1 spec)))
    (if pt
      (progn
        (setq exp (lead-pt pt ang *ACC-GAP*))
        (princ (strcat
          "\n  " (nth 0 spec) "." (nth 1 spec)
          "  노즐=(" (rtos (car pt)  2 2) "," (rtos (cadr pt)  2 2) ")"
          "  ang=" (itoa ang) "°"
          "  → 기대IN1=(" (rtos (car exp) 2 2) "," (rtos (cadr exp) 2 2) ")")))
      (princ (strcat "\n  " (nth 0 spec) "." (nth 1 spec) "  → 캐시없음"))))

  ;; ── [2] 도면 내 부속품 실제 위치 ────────────────────────────
  (princ "\n\n[2] 도면 내 부속품  삽입점 / IN1 / OUT1  (세계좌표)")
  (foreach bn '("P_VAV01" "P_VAV07" "FIT_FLNG")
    (setq ss  (ssget "X" (list (cons 0 "INSERT") (cons 2 bn)))
          cnt (if ss (sslength ss) 0))
    (princ (strcat "\n  [" bn "]  " (itoa cnt) "개"))
    (setq i 0)
    (while (and ss (< i cnt))
      (setq en     (ssname ss i)
            ed     (entget en)
            ins-pt (cdr (assoc 10 ed))
            i1     (get-attr en "IN1"  10)
            o1     (get-attr en "OUT1" 10))
      (if ins-pt (setq ins-pt (list (car ins-pt) (cadr ins-pt))))
      (if i1     (setq i1     (list (car i1)     (cadr i1))))
      (if o1     (setq o1     (list (car o1)     (cadr o1))))
      (princ (strcat
        "\n    #" (itoa (1+ i))
        "  삽입점=(" (rtos (car ins-pt) 2 2) "," (rtos (cadr ins-pt) 2 2) ")"
        "  IN1=("  (if i1 (strcat (rtos (car i1)  2 2) "," (rtos (cadr i1)  2 2)) "없음") ")"
        "  OUT1=(" (if o1 (strcat (rtos (car o1)  2 2) "," (rtos (cadr o1)  2 2)) "없음") ")"))
      (setq i (1+ i))))

  (princ "\n\n========== 완료 ==========\n")
  (setvar "CMDECHO" 1)
  (princ))

(princ "\npid_diagn 로드 완료\n")
(princ)
