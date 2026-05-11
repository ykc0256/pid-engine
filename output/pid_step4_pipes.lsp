;;; ============================================================
;;; PID-ENGINE  Step 4 — 배관 + 부속품 통합 생성
;;; 전제: pid_step2_machines.lsp 로드 + PID-STEP2 실행 완료
;;; 실행: (load "전체경로/pid_step4_pipes.lsp") 후 PID-STEP4
;;; ============================================================

;; ── media 레이어/색상 ────────────────────────────────────────
(setq *MEDIA-LAYERS*
  '(("sewage"   "PID-SEWAGE"   4)
    ("sludge"   "PID-SLUDGE"   3)
    ("air"      "PID-AIR"      7)
    ("chemical" "PID-CHEMICAL" 6)))

;; ── 포트 variant 치환 (code_key + IN/OUT → 실제 블록명) ─────
(setq *PORT-VARIANTS*
  '(("FIT_CONDC" "IN"  "FIT_CONDC_IN")
    ("FIT_CONDC" "OUT" "FIT_CONDC_OUT")))

;; ── 파이프 데이터 ─────────────────────────────────────────────
;; 형식: (pipe-id  from-spec  to-spec  fa  ta  ia  tees  media)
;; from/to-spec:
;;   ("S" str-id  port-id)
;;   ("M" mch-id  port-id)
;;   ("T" tee-id)           ; 기등록 TEE
;; fa/ta/ia: (code_key ...) 또는 nil
;; tees:     (tee-id ...) 또는 nil

(setq *PIPES*
  '(
    ;; ─ Pass 1 ────────────────────────────────────────────────
    ("PIPE-A01"
     ("S" "STR-A01" "OUT1") ("M" "MCH-A03" "IN1")
     ("P_VAV01" "FIT_FLNG") ("P_VAV07" "P_VAV01" "FIT_FLNG")
     nil ("TEE-A1-1") "sludge")
  ))

;; ▲▲▲ 테스트 통과 후 나머지 파이프 추가 예정 ▲▲▲

;; ── TEE 레지스트리 ───────────────────────────────────────────
(setq *TEE-PTS*  '())
(setq *IN1-CACHE* '())
(setq *ENAME-CACHE* '())

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

;; Attribute DXF code 조회 (code=10→위치, code=1→값)
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

;; 포트 방향 각도 (정수) 반환
(defun port-ang (ent-id port-id / en val)
  (setq en (cdr (assoc ent-id *ENAME-CACHE*)))
  (if en
    (progn
      (setq val (get-attr en (strcat port-id "_ANG") 1))
      (if val (atoi val) 0))
    0))

;; 각도 → (dx dy) 단위벡터
(defun dir-vec (ang / a)
  (setq a (if (numberp ang) ang (atoi ang)))
  (cond ((= a 0)   '( 1.0  0.0))
        ((= a 90)  '( 0.0  1.0))
        ((= a 180) '(-1.0  0.0))
        ((= a 270) '( 0.0 -1.0))
        (T         '( 1.0  0.0))))

;; (ox oy) 벡터를 ang 도 회전
(defun rot-off (ox oy ang / a)
  (setq a (if (numberp ang) ang (atoi ang)))
  (cond ((= a 0)   (list ox        oy))
        ((= a 90)  (list (- oy)    ox))
        ((= a 180) (list (- ox)    (- oy)))
        ((= a 270) (list oy        (- ox)))
        (T         (list ox        oy))))

;; 두 점 사이 거리
(defun pt-dist (a b)
  (sqrt (+ (* (- (car b) (car a)) (- (car b) (car a)))
           (* (- (cadr b) (cadr a)) (- (cadr b) (cadr a))))))

;; fp→tp 의 주 방향 각도
(defun dom-ang (fp tp / dx dy)
  (setq dx (- (car tp) (car fp))
        dy (- (cadr tp) (cadr fp)))
  (cond ((>= (abs dx) (abs dy)) (if (>= dx 0) 0 180))
        (T                      (if (>= dy 0) 90 270))))

;; ============================================================
;; 블록 IN1 오프셋 캐시
;; ============================================================

;; block-name을 (0,0) 에 임시 삽입 → IN1 위치 취득 → UNDO → 캐시
(defun get-in1-offset (block-name / rec en in1-pt)
  (setq rec (assoc block-name *IN1-CACHE*))
  (if rec
    (cdr rec)
    (progn
      (setvar "ATTREQ" 0)
      (command "._INSERT" block-name '(0.0 0.0) 1 1 0)
      (setq en (entlast)
            in1-pt (get-attr en "IN1" 10))
      (command "._U")
      (setvar "ATTREQ" 1)
      (if (null in1-pt) (setq in1-pt '(0.0 0.0)))
      (setq *IN1-CACHE* (cons (cons block-name in1-pt) *IN1-CACHE*))
      in1-pt)))

;; 캐시 사전 워밍 (UNDO BE 전에 호출 — 임시 삽입이 메인 UNDO에 포함 안 되도록)
(defun warm-in1-cache ()
  (foreach bn '("P_VAV01" "P_VAV04" "P_VAV07" "P_VAV03"
                "FIT_FLNG" "FIT_CONDC_IN" "FIT_CONDC_OUT")
    (get-in1-offset bn))
  (princ "\n  IN1 캐시 워밍 완료"))

;; ============================================================
;; 부속품 배치
;; ============================================================

;; code_key + 포트 종류(IN/OUT) → 실제 블록명 반환
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

;; 부속품 블록 1개 배치 → OUT1 위치 반환
;; chain-pt : IN1을 놓을 세계좌표
;; ang      : 파이프 방향 각도 (정수)
(defun place-acc (block-name chain-pt ang / off roff ins en out1)
  (setq off  (get-in1-offset block-name)
        roff (rot-off (car off) (cadr off) ang)
        ins  (list (- (car chain-pt)  (car roff))
                   (- (cadr chain-pt) (cadr roff))))
  (setvar "ATTREQ" 0)
  (command "._INSERT" block-name ins 1 1 ang)
  (setvar "ATTREQ" 1)
  (setq en (entlast))
  ; OUT1 위치 반환 (다음 체인 포인트)
  (setq out1 (get-attr en "OUT1" 10))
  (if out1 out1 chain-pt))

;; 부속품 체인 전체 배치 → 최종 pt 반환
(defun place-chain (chain-pt ang port-id acc-list / pt)
  (setq pt chain-pt)
  (foreach ckey acc-list
    (setq pt (place-acc (resolve-blk ckey port-id) pt ang)))
  pt)

;; ============================================================
;; TEE 관리
;; ============================================================

(defun tee-pt (tee-id / rec)
  (setq rec (assoc tee-id *TEE-PTS*))
  (if rec (cdr rec) nil))

;; TEE 위치 = 직각 라우팅의 elbow (to.x, from.y)
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
;; 엔티티 캐시 (Step 2 함수 재사용)
;; ============================================================

(defun get-slot-pt (blk-en tag / en ed result)
  (setq en (entnext blk-en)  result nil)
  (while (and en (not result))
    (setq ed (entget en))
    (cond
      ((equal (cdr (assoc 0 ed)) "ATTRIB")
       (if (equal (strcase (cdr (assoc 2 ed))) (strcase tag))
         (setq result (cdr (assoc 10 ed))))
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

(defun build-ename-cache (/ all-ss pt en str-en)
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
    (setq str-en (cdr (assoc (nth 2 imch) *ENAME-CACHE*)))
    (if str-en
      (progn
        (setq pt (get-slot-pt str-en (nth 3 imch))
              en (if pt (find-in-ss pt all-ss) nil))
        (if en (setq *ENAME-CACHE* (cons (cons (nth 0 imch) en) *ENAME-CACHE*))
               (princ (strcat "\n  [경고] " (nth 0 imch) " 캐싱 실패"))))
      (princ (strcat "\n  [경고] " (nth 2 imch) " 구조물 미캐시"))))

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

;; from/to 스펙 → 좌표 + 각도 반환 (list pt ang)
;; TEE: (pt nil)  entity: (pt ang)
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

;; 인라인 부속품 포함 배관:
;; fp → [ia chain 중앙 배치] → tp
(defun draw-with-inline (fp tp ia port-id / ang mid acc-end)
  (setq ang (dom-ang fp tp)
        mid (list (/ (+ (car fp) (car tp)) 2.0)
                  (/ (+ (cadr fp) (cadr tp)) 2.0))
        acc-end (place-chain mid ang port-id ia))
  (draw-ortho fp mid)
  (draw-ortho acc-end tp))

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
;; 파이프 1개 처리
;; ============================================================

(defun process-pipe (pipe / pid fspec tspec fa ta ia tees media
                          fres tres fp-base tp-base
                          fp-ang tp-ang pipe-fp pipe-tp)
  (setq pid   (nth 0 pipe)
        fspec (nth 1 pipe)
        tspec (nth 2 pipe)
        fa    (nth 3 pipe)
        ta    (nth 4 pipe)
        ia    (nth 5 pipe)
        tees  (nth 6 pipe)
        media (nth 7 pipe))

  (set-media-layer media)

  ;; FROM 쪽 체인 끝점 계산
  (setq fres    (resolve-spec fspec)
        fp-base (nth 0 fres)
        fp-ang  (nth 1 fres))
  (if (and fp-base fp-ang fa)
    (setq pipe-fp (place-chain fp-base fp-ang (nth 2 fspec) fa))
    (setq pipe-fp fp-base))

  ;; TO 쪽 체인 끝점 계산
  (setq tres    (resolve-spec tspec)
        tp-base (nth 0 tres)
        tp-ang  (nth 1 tres))
  (if (and tp-base tp-ang ta)
    (setq pipe-tp (place-chain tp-base tp-ang (nth 2 tspec) ta))
    (setq pipe-tp tp-base))

  ;; 배관선 + 인라인 부속품
  (if (and pipe-fp pipe-tp)
    (progn
      (if ia
        (draw-with-inline pipe-fp pipe-tp ia "IN1")
        (draw-ortho pipe-fp pipe-tp))

      ;; TEE 등록 + 심볼
      (if tees
        (progn
          (register-tees pipe-fp pipe-tp tees)
          (foreach tid tees
            (draw-tee-sym (tee-pt tid)))))

      (princ (strcat "\n  배관: " pid " [" media "]")))
    (princ (strcat "\n  [건너뜀] " pid))))

;; ============================================================
;; 메인 루프
;; ============================================================

(defun place-pipes ()
  (foreach pipe *PIPES*
    (process-pipe pipe)))

;; ============================================================
;; 진입점
;; ============================================================

(defun c:PID-STEP4 ()
  (setvar "CMDECHO" 0)
  (setq *TEE-PTS* '()  *IN1-CACHE* '())

  (princ "\n[Step4] IN1 캐시 워밍...\n")
  (warm-in1-cache)   ; UNDO BE 전에 호출

  (command "._UNDO" "BE")

  (princ "\n[Step4] 레이어 초기화...\n")
  (init-layers)

  (princ "\n[Step4] 엔티티 캐시 구축...\n")
  (build-ename-cache)

  (princ "\n[Step4] 배관 + 부속품 생성...\n")
  (place-pipes)

  (setvar "CLAYER" "0")
  (command "._ZOOM" "E")
  (command "._UNDO" "E")
  (setvar "CMDECHO" 1)
  (princ "\n[Step4] 완료.\n")
  (princ))

(princ "\nPID-STEP4 로드 완료. 'PID-STEP4' 실행하세요.\n")
(princ)
