;;; ============================================================
;;; PID-ENGINE  배관 드로잉 — 선분 / 부속품 인라인 / 파이프 처리
;;; ============================================================

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
       (command "._PLINE" fp (list (car fp) (cadr tp)) tp "")
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

  (setq fres    (resolve-spec fspec)
        fp-base (nth 0 fres)
        fp-ang  (nth 1 fres))
  (if (and fp-base fp-ang fa)
    (setq pipe-fp (place-chain fp-base fp-ang (nth 2 fspec) fa))
    (setq pipe-fp fp-base))

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

      (if (not (equal fp-outer pipe-fp))
        (command "._LINE" pipe-fp fp-outer ""))

      (if (not (equal tp-outer pipe-tp))
        (command "._LINE" pipe-tp tp-outer ""))

      (if ia
        (draw-with-inline fp-outer tp-outer ia "IN1")
        (if str-to-mch
          (draw-ortho-str-mch fp-outer tp-outer)
          (draw-ortho fp-outer tp-outer)))

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

(princ "\npid_pipes 로드 완료\n")
(princ)
