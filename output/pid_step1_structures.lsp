;;; ============================================================
;;; PID-ENGINE  Step 1 — 구조물 배치
;;; 단위    : mm
;;; 삽입점  : 블록 좌하단 기준 (S_COND01 기준)
;;; 실행    : (load "전체경로/pid_step1_structures.lsp") 후 PID-STEP1 실행
;;; ============================================================

;; ── 레이아웃 상수 ────────────────────────────────────────────
(setq *STR-W*    200)   ; 구조물 블록 가로 (mm)
(setq *STR-H*    100)   ; 구조물 블록 세로 (mm)
(setq *STR-GAP*  300)   ; 같은 그룹 내 구조물 세로 간격 (mm)
(setq *PROC-GAP* 3000)  ; 공정 간 가로 간격 (Step2 이후 조정 예정)
(setq *ORIG-X*      0)  ; 시작 X
(setq *ORIG-Y*      0)  ; 시작 Y (아래로 갈수록 음수)

;; ── 공정 순서 ────────────────────────────────────────────────
;; 순서 = X축 배치 순서 (왼쪽 → 오른쪽)
(setq *PROCESSES* '("PROC-A" "PROC-B"))

;; ── 구조물 데이터 ─────────────────────────────────────────────
;; 형식: (str-id  code_key  proc-id  group-no)
;; group-no 동일 → 같은 그룹 → 세로로 쌓기
(setq *STRUCTURES*
  '(("STR-A01" "S_COND01" "PROC-A" 1)
    ("STR-A02" "S_COND01" "PROC-A" 1)
    ("STR-B01" "S_COND01" "PROC-B" 1)))

;; ── 유틸리티 ─────────────────────────────────────────────────

;; 공정 인덱스 반환 (0-based)
(defun proc-idx (pid / i result)
  (setq i 0  result 0)
  (foreach p *PROCESSES*
    (if (equal p pid) (setq result i))
    (setq i (1+ i)))
  result)

;; 카운터 조회 (없으면 0 반환)
(defun get-cnt (tbl key / rec)
  (setq rec (assoc key tbl))
  (if rec (cdr rec) 0))

;; 카운터 업데이트
(defun set-cnt (tbl key val)
  (if (assoc key tbl)
    (subst (cons key val) (assoc key tbl) tbl)
    (cons (cons key val) tbl)))

;; ── 구조물 배치 ───────────────────────────────────────────────
(defun place-structures (/ tbl str-id ckey pid grp key cnt x y)
  (setq tbl '())
  (setvar "ATTREQ" 0)   ; 속성 입력 프롬프트 억제

  (foreach str *STRUCTURES*
    (setq str-id (nth 0 str)
          ckey   (nth 1 str)
          pid    (nth 2 str)
          grp    (nth 3 str)
          key    (strcat pid "_" (itoa grp))
          cnt    (get-cnt tbl key))

    ;; X: 공정 시작 X (구조물은 공정 내 가장 왼쪽)
    (setq x (+ *ORIG-X* (* (proc-idx pid) *PROC-GAP*)))

    ;; Y: 같은 그룹 내 위에서 아래로 쌓기
    (setq y (- *ORIG-Y* (* cnt (+ *STR-H* *STR-GAP*))))

    ;; 블록 삽입
    (command "._INSERT" ckey (list x y) 1 1 0)

    ;; 확인용 ID 레이블 (블록 위쪽)
    (command "._TEXT"
             (list (+ x 5) (+ y *STR-H* 15))
             25 0
             str-id)

    (setq tbl (set-cnt tbl key (1+ cnt)))
    (princ (strcat "\n  배치: " str-id
                   "  위치: (" (rtos x 2 0) ", " (rtos y 2 0) ")")))

  (setvar "ATTREQ" 1)
  (princ "\n[Step1] 구조물 배치 완료.\n"))

;; ── 진입점 ────────────────────────────────────────────────────
(defun c:PID-STEP1 ()
  (command "._UNDO" "BE")
  (setvar "CMDECHO" 0)
  (princ "\n[Step1] 구조물 배치 시작...\n")
  (place-structures)
  (command "._ZOOM" "E")
  (setvar "CMDECHO" 1)
  (command "._UNDO" "E")
  (princ))

(princ "\nPID-STEP1 로드 완료. 커맨드라인에서 'PID-STEP1' 입력 후 실행하세요.\n")
(princ)
