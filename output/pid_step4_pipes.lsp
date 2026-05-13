;;; ============================================================
;;; PID-ENGINE  Step 4 — 로더 + 진입점
;;; 실행: (load "전체경로/pid_step4_pipes.lsp") → PID-STEP4
;;;
;;; [경로 설정] output/ 폴더를 AutoCAD 지원 파일 검색 경로에 추가:
;;;   OPTIONS → Files → Support File Search Path → output/ 폴더 추가
;;; ============================================================

(defun pid-load (f / p)
  (setq p (findfile f))
  (if (null p) (setq p f))
  (load p))

(pid-load "pid_data.lsp")
(pid-load "pid_utils.lsp")
(pid-load "pid_place.lsp")
(pid-load "pid_pipes.lsp")
(pid-load "pid_diagn.lsp")

;; ============================================================
;; 진입점
;; ============================================================

(defun c:PID-STEP4 (/ *saved-osmode*)
  (setvar "CMDECHO" 0)
  (setq *saved-osmode* (getvar "OSMODE"))
  (setvar "OSMODE" 0)
  (setq *TEE-PTS* '()  *IN1-CACHE* '()  *OUT1-CACHE* '()
        *ENAME-CACHE* '()  *PIPE-IDX* 0  *INT-ENAMES* '())

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
