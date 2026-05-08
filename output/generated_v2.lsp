;;; ============================================================
;;; PID INSTANCE CONNECTION TEST 019
;;; Purpose : Instance placement test only. No pipe routing.
;;; Command : PID_LAYOUT_TEST
;;;
;;; Fix points from test_007:
;;; - Outside machines are no longer placed by manually supplied indices.
;;; - Each media + series_id has its own automatic column and item counter.
;;; - Same series_id: TOP -> BOTTOM, 80mm spacing.
;;; - Different series_id groups in same media lane: LEFT -> RIGHT, wider column spacing.
;;; - Insertion point marker is drawn to check block base-point issues.
;;; - All coordinate inputs use _NON and OSMODE is temporarily disabled to prevent snap drift.
;;; ============================================================

(vl-load-com)

;;; -----------------------------
;;; Constants
;;; -----------------------------
(setq *PID-STRUCTURE-X*             0.0)
(setq *PID-STRUCTURE-START-Y*       0.0)
(setq *PID-STRUCTURE-GAP-Y*         260.0)

(setq *PID-MACHINE-START-X*         430.0)
(setq *PID-MACHINE-SERIES-GAP-X*    280.0)
(setq *PID-MACHINE-GAP-Y*           80.0)
(setq *PID-MACHINE-LANE-OFFSET-Y*   35.0)

(setq *PID-LABEL-OFFSET*            (list 0.0 -14.0 0.0))

(setq *PID-LANE-Y-MAP*
  (list
    (cons "CHEMICAL"   500.0)
    (cons "AIR"        250.0)
    (cons "RAW_WATER"    0.0)
    (cons "SLUDGE"    -250.0)
  )
)

(setq *PID-INSTANCE-MAP* nil)
(setq *PID-SERIES-STATE* nil)

;;; -----------------------------
;;; Utilities
;;; -----------------------------
(defun pid-pt (x y /)
  (list (float x) (float y) 0.0)
)

(defun pid-add-pt (a b /)
  (list (+ (car a) (car b)) (+ (cadr a) (cadr b)) (+ (caddr a) (caddr b)))
)

(defun pid-layer (name color /)
  (if (not (tblsearch "LAYER" name))
    (command "_.-LAYER" "_M" name "_C" color name "")
  )
  name
)

(defun pid-set-layer (name color /)
  (pid-layer name color)
  (setvar "CLAYER" name)
)

(defun pid-insert-block (blk pt rot / en)
  (if (tblsearch "BLOCK" blk)
    (progn
      (command "_.-INSERT" blk "_NON" pt 1.0 1.0 rot)
      (setq en (entlast))
      en
    )
    (progn
      (prompt (strcat "\n[PID WARN] Block not found: " blk))
      nil
    )
  )
)

(defun pid-label (pt txt / p)
  (pid-set-layer "PID_LABEL" 7)
  (setq p (pid-add-pt pt *PID-LABEL-OFFSET*))
  (command "_.TEXT" "_J" "MC" "_NON" p 5.0 0.0 txt)
)

(defun pid-draw-line (p1 p2 layer color /)
  (pid-set-layer layer color)
  (command "_.LINE" "_NON" p1 "_NON" p2 "")
)

(defun pid-draw-rect (p1 p2 layer color / x1 y1 x2 y2)
  (pid-set-layer layer color)
  (setq x1 (car p1))
  (setq y1 (cadr p1))
  (setq x2 (car p2))
  (setq y2 (cadr p2))
  (command "_.PLINE"
           "_NON" (list x1 y1 0.0)
           "_NON" (list x2 y1 0.0)
           "_NON" (list x2 y2 0.0)
           "_NON" (list x1 y2 0.0)
           "_C")
)

(defun pid-mark-point (pt id / x y s)
  ;; Cross marker for insertion base-point verification.
  (setq x (car pt))
  (setq y (cadr pt))
  (setq s 7.0)
  (pid-set-layer "PID_INSERT_MARK" 1)
  (command "_.LINE" "_NON" (pid-pt (- x s) y) "_NON" (pid-pt (+ x s) y) "")
  (command "_.LINE" "_NON" (pid-pt x (- y s)) "_NON" (pid-pt x (+ y s)) "")
)

;;; -----------------------------
;;; Attribute readers
;;; -----------------------------
(defun pid-get-attr (ename tag / obj attrs a res)
  (setq res nil)
  (if ename
    (progn
      (setq obj (vlax-ename->vla-object ename))
      (if (= :vlax-true (vla-get-HasAttributes obj))
        (progn
          (setq attrs (vlax-invoke obj 'GetAttributes))
          (foreach a attrs
            (if (= (strcase (vla-get-TagString a)) (strcase tag))
              (setq res (vla-get-TextString a))
            )
          )
        )
      )
    )
  )
  res
)

(defun pid-parse-offset (s / txt vals)
  ;; Accepts: "10,20", "10 20", "(10 20)", "10,20,0"
  (if (and s (/= s ""))
    (progn
      (setq txt (vl-string-translate ",()[]" "     " s))
      (setq vals (read (strcat "(" txt ")")))
      (if (and vals (numberp (car vals)) (numberp (cadr vals)))
        (list (float (car vals)) (float (cadr vals)) 0.0)
        (list 0.0 0.0 0.0)
      )
    )
    (list 0.0 0.0 0.0)
  )
)

(defun pid-slot-code (parent-ename slot /)
  (pid-get-attr parent-ename (strcat slot "_CODE"))
)

(defun pid-slot-offset (parent-ename slot / val)
  (setq val (pid-get-attr parent-ename (strcat slot "_OFFSET")))
  (if (not val)
    (prompt (strcat "\n[PID WARN] Missing " slot "_OFFSET. Offset set to 0,0."))
  )
  (pid-parse-offset val)
)

(defun pid-code-matches-slot-p (slot-code child-code / a b)
  ;; Allows exact match or prefix match.
  ;; Example: M_TDIF accepts M_TDIF04.
  (if (and slot-code child-code (/= slot-code ""))
    (progn
      (setq a (strcase slot-code))
      (setq b (strcase child-code))
      (or (= a b) (= a (substr b 1 (strlen a))))
    )
    T
  )
)

;;; -----------------------------
;;; Instance map
;;; -----------------------------
(defun pid-map-put (id ename pt code /)
  (setq *PID-INSTANCE-MAP*
    (cons (list id ename pt code)
          (vl-remove-if '(lambda (x) (= (car x) id)) *PID-INSTANCE-MAP*)))
)

(defun pid-map-get (id /)
  (assoc id *PID-INSTANCE-MAP*)
)

(defun pid-map-ename (id / row)
  (setq row (pid-map-get id))
  (if row (cadr row) nil)
)

(defun pid-map-pt (id / row)
  (setq row (pid-map-get id))
  (if row (caddr row) nil)
)

(defun pid-map-code-safe (id / row)
  (setq row (pid-map-get id))
  (if row
    (cadddr row)
    (progn
      (prompt (strcat "\n[PID WARN] Missing instance code for: " id ". Use UNKNOWN."))
      "UNKNOWN"
    )
  )
)


;;; -----------------------------
;;; Series auto-counter
;;; -----------------------------
(defun pid-lane-y (media / row)
  (setq row (assoc media *PID-LANE-Y-MAP*))
  (if row (cdr row) 0.0)
)

(defun pid-series-key (media series /)
  (strcat (strcase media) "|" (strcase series))
)

(defun pid-lane-series-count (media / prefix cnt)
  ;; Count series already registered in this media lane.
  (setq prefix (strcat (strcase media) "|"))
  (setq cnt 0)
  (foreach row *PID-SERIES-STATE*
    (if (= prefix (substr (car row) 1 (strlen prefix)))
      (setq cnt (1+ cnt))
    )
  )
  cnt
)

(defun pid-get-series-state (media series / key row col count)
  ;; Return and update state.
  ;; Row format: (key col next_item_index)
  (setq key (pid-series-key media series))
  (setq row (assoc key *PID-SERIES-STATE*))
  (if row
    row
    (progn
      (setq col (pid-lane-series-count media))
      (setq row (list key col 0))
      (setq *PID-SERIES-STATE* (append *PID-SERIES-STATE* (list row)))
      row
    )
  )
)

(defun pid-update-series-state (key col next-idx /)
  (setq *PID-SERIES-STATE*
    (cons (list key col next-idx)
          (vl-remove-if '(lambda (x) (= (car x) key)) *PID-SERIES-STATE*)))
)

;;; -----------------------------
;;; Placement functions
;;; -----------------------------
(defun pid-place-structure (id code idx / x y pt en)
  (setq x *PID-STRUCTURE-X*)
  (setq y (- *PID-STRUCTURE-START-Y* (* idx *PID-STRUCTURE-GAP-Y*)))
  (setq pt (pid-pt x y))
  (pid-set-layer "PID_STRUCTURE" 2)
  (setq en (pid-insert-block code pt 0.0))
  (if en
    (progn
      (pid-map-put id en pt code)
      (pid-mark-point pt id)
      (pid-label pt id)
      (prompt (strcat "\n[PID PLACE] " id " " code " @ (" (rtos x 2 2) "," (rtos y 2 2) ")"))
    )
  )
  en
)

(defun pid-place-structure-at (id code x y / pt en)
  (setq pt (pid-pt x y))
  (pid-set-layer "PID_STRUCTURE" 2)
  (setq en (pid-insert-block code pt 0.0))
  (if en
    (progn
      (pid-map-put id en pt code)
      (pid-mark-point pt id)
      (pid-label pt id)
      (prompt (strcat "\n[PID PLACE] " id " " code " @ (" (rtos x 2 2) "," (rtos y 2 2) ")"))
    )
  )
  en
)

(defun pid-place-inside-machine (id code parent-id slot / parent-en parent-pt slot-code off pt en x y)
  (setq parent-en (pid-map-ename parent-id))
  (setq parent-pt (pid-map-pt parent-id))
  (if (and parent-en parent-pt)
    (progn
      (setq slot-code (pid-slot-code parent-en slot))
      (if (not (pid-code-matches-slot-p slot-code code))
        (prompt (strcat "\n[PID WARN] " id " / slot " slot " code mismatch. Slot=" slot-code ", Child=" code))
      )
      (setq off (pid-slot-offset parent-en slot))
      (setq pt (pid-add-pt parent-pt off))
      (setq x (car pt))
      (setq y (cadr pt))
      (pid-set-layer "PID_INSIDE_MACHINE" 4)
      (setq en (pid-insert-block code pt 0.0))
      (if en
        (progn
          (pid-map-put id en pt code)
          (pid-mark-point pt id)
          (pid-label pt id)
          (prompt (strcat "\n[PID PLACE] " id " " code " @ (" (rtos x 2 2) "," (rtos y 2 2) ") INSIDE " parent-id "/" slot))
        )
      )
      en
    )
    (progn
      (prompt (strcat "\n[PID WARN] Parent not found for inside machine: " id))
      nil
    )
  )
)

(defun pid-place-lane-machine-auto (id code media series / state key col idx lane-y x y pt en)
  (setq state (pid-get-series-state media series))
  (setq key (car state))
  (setq col (cadr state))
  (setq idx (caddr state))

  (setq x (+ *PID-MACHINE-START-X* (* col *PID-MACHINE-SERIES-GAP-X*)))
  (setq lane-y (pid-lane-y media))
  (setq y (- lane-y *PID-MACHINE-LANE-OFFSET-Y* (* idx *PID-MACHINE-GAP-Y*)))
  (setq pt (pid-pt x y))

  (pid-set-layer "PID_OUTSIDE_MACHINE" 3)
  (setq en (pid-insert-block code pt 0.0))
  (if en
    (progn
      (pid-map-put id en pt code)
      (pid-mark-point pt id)
      (pid-label pt id)
      (pid-update-series-state key col (1+ idx))
      (prompt (strcat "\n[PID PLACE] " id " " code " @ (" (rtos x 2 2) "," (rtos y 2 2)
                      ") MEDIA=" media " SERIES=" series
                      " COL=" (itoa col) " IDX=" (itoa idx)))
    )
  )
  en
)

(defun pid-draw-layout-guide (/)
  ;; PROC_001 area
  (pid-draw-rect (pid-pt -100.0 570.0) (pid-pt 1300.0 -570.0) "PID_PROCESS_AREA" 8)
  (pid-label (pid-pt 0.0 545.0) "PROC_001")

  (pid-draw-line (pid-pt 250.0 550.0) (pid-pt 250.0 -550.0) "PID_PROCESS_AREA" 8)
  (pid-label (pid-pt 100.0 525.0) "STRUCTURES")
  (pid-label (pid-pt 700.0 525.0) "MACHINES / MEDIA LANES")

  (pid-draw-line (pid-pt 270.0 500.0) (pid-pt 1270.0 500.0) "PID_LANE" 8)
  (pid-label (pid-pt 315.0 500.0) "CHEMICAL")

  (pid-draw-line (pid-pt 270.0 250.0) (pid-pt 1270.0 250.0) "PID_LANE" 8)
  (pid-label (pid-pt 300.0 250.0) "AIR")

  (pid-draw-line (pid-pt 270.0 0.0) (pid-pt 1270.0 0.0) "PID_LANE_RAW_WATER" 1)
  (pid-label (pid-pt 345.0 0.0) "RAW_WATER BASELINE")

  (pid-draw-line (pid-pt 270.0 -250.0) (pid-pt 1270.0 -250.0) "PID_LANE" 8)
  (pid-label (pid-pt 310.0 -250.0) "SLUDGE")

  ;; PROC_002 area
  (pid-draw-rect (pid-pt 1450.0 570.0) (pid-pt 2300.0 -570.0) "PID_PROCESS_AREA" 8)
  (pid-label (pid-pt 1550.0 545.0) "PROC_002")
  (pid-draw-line (pid-pt 1780.0 550.0) (pid-pt 1780.0 -550.0) "PID_PROCESS_AREA" 8)
  (pid-label (pid-pt 1630.0 525.0) "STRUCTURES")
  (pid-label (pid-pt 2050.0 525.0) "MACHINES / MEDIA LANES")

  (pid-draw-line (pid-pt 1800.0 500.0) (pid-pt 2280.0 500.0) "PID_LANE" 8)
  (pid-label (pid-pt 1845.0 500.0) "CHEMICAL")

  (pid-draw-line (pid-pt 1800.0 250.0) (pid-pt 2280.0 250.0) "PID_LANE" 8)
  (pid-label (pid-pt 1830.0 250.0) "AIR")

  (pid-draw-line (pid-pt 1800.0 0.0) (pid-pt 2280.0 0.0) "PID_LANE_RAW_WATER" 1)
  (pid-label (pid-pt 1875.0 0.0) "RAW_WATER BASELINE")

  (pid-draw-line (pid-pt 1800.0 -250.0) (pid-pt 2280.0 -250.0) "PID_LANE" 8)
  (pid-label (pid-pt 1840.0 -250.0) "SLUDGE")
)


;;; -----------------------------
;;; Connection functions - rule-based test version 004
;;; -----------------------------
(setq *PID-CHAIN-GAP* 0.9375)
(setq *PID-PIPE-LEAD* 10.0)
(setq *PID-TEE-SOURCE-DIST* 50.0)
(setq *PID-TEE-AFTER-LEAD* 50.0)
(setq *PID-PIPE-OVERLAP-OFFSETS* (list 25.0 -25.0 50.0 -50.0 75.0 -75.0 120.0 -120.0 180.0 -180.0))
(setq *PID-OBSTACLE-CLEARANCE* 10.0)
(setq *PID-ROUTE-EXCLUDES* nil)
(setq *PID-PIPE-SEGMENTS* nil)
(setq *PID-ROUTE-PREF* nil)

(defun pid-deg-rad (a /)
  (* pi (/ a 180.0))
)

(defun pid-angle-vec (a / r)
  (setq r (pid-deg-rad a))
  (list (cos r) (sin r) 0.0)
)

(defun pid-scale-vec (v s /)
  (list (* (car v) s) (* (cadr v) s) 0.0)
)

(defun pid-sub-pt (a b /)
  (list (- (car a) (car b)) (- (cadr a) (cadr b)) 0.0)
)

(defun pid-rot-vec (v ang / r x y)
  (setq r (pid-deg-rad ang))
  (setq x (car v))
  (setq y (cadr v))
  (list
    (- (* x (cos r)) (* y (sin r)))
    (+ (* x (sin r)) (* y (cos r)))
    0.0
  )
)

(defun pid-normalize-angle (a /)
  (while (< a 0.0) (setq a (+ a 360.0)))
  (while (>= a 360.0) (setq a (- a 360.0)))
  a
)

(defun pid-angle-horizontal-p (ang / a)
  (setq a (pid-normalize-angle ang))
  (or (< (abs (- a 0.0)) 1.0) (< (abs (- a 180.0)) 1.0) (> a 359.0))
)

(defun pid-port-tag (port suffix /)
  (strcat "PORT" (itoa port) "_" suffix)
)

(defun pid-port-type-by-ename (ename port / val)
  (setq val (pid-get-attr ename (pid-port-tag port "TYPE")))
  (if val (strcase val) nil)
)

(defun pid-port-offset-by-ename (ename port / val)
  (setq val (pid-get-attr ename (pid-port-tag port "OFFSET")))
  (pid-parse-offset val)
)

(defun pid-port-angle-by-ename (ename port / val)
  (setq val (pid-get-attr ename (pid-port-tag port "ANGLE")))
  (if val (atof val) 0.0)
)

(defun pid-port-type (id port / en val)
  (setq en (pid-map-ename id))
  (setq val (if en (pid-port-type-by-ename en port) nil))
  (if val val "OUT")
)

(defun pid-port-angle (id port / en)
  (setq en (pid-map-ename id))
  (if en (pid-port-angle-by-ename en port) 0.0)
)

(defun pid-port-point (id port / en base off)
  (setq en (pid-map-ename id))
  (setq base (pid-map-pt id))
  (if (and en base)
    (progn
      (setq off (pid-port-offset-by-ename en port))
      ;; Current test inserts all instances at rotation 0.
      (pid-add-pt base off)
    )
    (progn
      (prompt (strcat "\n[PID WARN] Missing instance/port: " id ".PORT" (itoa port)))
      (if base base (pid-pt 0.0 0.0))
    )
  )
)

(defun pid-find-port-by-type (ename target-type / idx found val)
  (setq idx 1)
  (setq found nil)
  (while (and (<= idx 20) (not found))
    (setq val (pid-port-type-by-ename ename idx))
    (if (and val (= (strcase val) (strcase target-type)))
      (setq found idx)
      (setq idx (1+ idx))
    )
  )
  found
)

(defun pid-seg-horizontal-p (a b /)
  (< (abs (- (cadr a) (cadr b))) 0.001)
)

(defun pid-seg-vertical-p (a b /)
  (< (abs (- (car a) (car b))) 0.001)
)

(defun pid-range-overlap-len (a1 a2 b1 b2 / amin amax bmin bmax lo hi)
  (setq amin (min a1 a2))
  (setq amax (max a1 a2))
  (setq bmin (min b1 b2))
  (setq bmax (max b1 b2))
  (setq lo (max amin bmin))
  (setq hi (min amax bmax))
  (max 0.0 (- hi lo))
)

(defun pid-collinear-overlap-p (a b c d / len)
  ;; Crossing at one point is allowed.
  ;; Same-axis overlap with positive length is not allowed.
  (cond
    ((and (pid-seg-horizontal-p a b) (pid-seg-horizontal-p c d)
          (< (abs (- (cadr a) (cadr c))) 0.001))
      (setq len (pid-range-overlap-len (car a) (car b) (car c) (car d)))
      (> len 0.001)
    )
    ((and (pid-seg-vertical-p a b) (pid-seg-vertical-p c d)
          (< (abs (- (car a) (car c))) 0.001))
      (setq len (pid-range-overlap-len (cadr a) (cadr b) (cadr c) (cadr d)))
      (> len 0.001)
    )
    (T nil)
  )
)

(defun pid-path-segments (pts / res rest a b)
  (setq res nil)
  (setq rest pts)
  (while (> (length rest) 1)
    (setq a (car rest))
    (setq b (cadr rest))
    (if (> (distance a b) 0.0001)
      (setq res (append res (list (list a b))))
    )
    (setq rest (cdr rest))
  )
  res
)

(defun pid-path-overlaps-existing-p (pts / segs s e hit)
  (setq segs (pid-path-segments pts))
  (setq hit nil)
  (foreach s segs
    (foreach e *PID-PIPE-SEGMENTS*
      (if (pid-collinear-overlap-p (car s) (cadr s) (car e) (cadr e))
        (setq hit T)
      )
    )
  )
  hit
)

;;; -----------------------------
;;; Obstacle / bbox avoidance functions - added in 008
;;; -----------------------------
(defun pid-member-str (x lst / hit)
  (setq hit nil)
  (foreach a lst
    (if (= (strcase x) (strcase a))
      (setq hit T)
    )
  )
  hit
)

(defun pid-inside-parent-id (id / u)
  ;; Generated from JSON: parent_structure field.
  (setq u (strcase id))
  (cond
    ((or (= u "TDIF1") (= u "FDC1")) "COND1")
    ((or (= u "TDIF2") (= u "FDC2")) "COND2")
    (T nil)
  )
)

(defun pid-route-exclude-ids (a-id b-id / res pa pb)
  ;; Exclude endpoint instances and parent structures for inside machines.
  ;; This allows a pipe to enter the target parent structure normally,
  ;; while still blocking unrelated structure penetration.
  (setq res nil)
  (if a-id (setq res (append res (list a-id))))
  (if b-id (setq res (append res (list b-id))))
  (setq pa (if a-id (pid-inside-parent-id a-id) nil))
  (setq pb (if b-id (pid-inside-parent-id b-id) nil))
  (if pa (setq res (append res (list pa))))
  (if pb (setq res (append res (list pb))))
  res
)

(defun pid-get-entity-bbox (ename / obj mn mx mnlist mxlist)
  (if ename
    (progn
      (setq obj (vlax-ename->vla-object ename))
      (if obj
        (progn
          (vla-getboundingbox obj 'mn 'mx)
          (setq mnlist (vlax-safearray->list mn))
          (setq mxlist (vlax-safearray->list mx))
          (list
            (list (- (car mnlist) *PID-OBSTACLE-CLEARANCE*)
                  (- (cadr mnlist) *PID-OBSTACLE-CLEARANCE*)
                  0.0)
            (list (+ (car mxlist) *PID-OBSTACLE-CLEARANCE*)
                  (+ (cadr mxlist) *PID-OBSTACLE-CLEARANCE*)
                  0.0)
          )
        )
        nil
      )
    )
    nil
  )
)

(defun pid-obstacle-candidate-p (id code /)
  ;; Structures and machines are hard obstacles.
  ;; Accessories/refs are not checked here.
  (or (and code (>= (strlen code) 2) (= (substr (strcase code) 1 2) "S_"))
      (and code (>= (strlen code) 2) (= (substr (strcase code) 1 2) "M_")))
)

(defun pid-obstacle-boxes (/ boxes row id en pt code bb)
  (setq boxes nil)
  (foreach row *PID-INSTANCE-MAP*
    (setq id (car row))
    (setq en (cadr row))
    (setq code (cadddr row))
    (if (and (pid-obstacle-candidate-p id code)
             (not (pid-member-str id *PID-ROUTE-EXCLUDES*)))
      (progn
        (setq bb (pid-get-entity-bbox en))
        (if bb
          (setq boxes (append boxes (list (list id (car bb) (cadr bb)))))
        )
      )
    )
  )
  boxes
)

(defun pid-seg-intersects-bbox-p (a b mn mx / overlap)
  ;; Horizontal/vertical segment vs bbox with positive overlap.
  ;; Touching at a single point is allowed.
  (cond
    ((pid-seg-horizontal-p a b)
      (and
        (> (cadr a) (cadr mn))
        (< (cadr a) (cadr mx))
        (> (pid-range-overlap-len (car a) (car b) (car mn) (car mx)) 0.001)
      )
    )
    ((pid-seg-vertical-p a b)
      (and
        (> (car a) (car mn))
        (< (car a) (car mx))
        (> (pid-range-overlap-len (cadr a) (cadr b) (cadr mn) (cadr mx)) 0.001)
      )
    )
    (T nil)
  )
)

(defun pid-path-intersects-obstacle-p (pts / segs boxes s b hit)
  (setq hit nil)
  (setq segs (pid-path-segments pts))
  (setq boxes (pid-obstacle-boxes))
  (foreach s segs
    (foreach b boxes
      (if (pid-seg-intersects-bbox-p (car s) (cadr s) (cadr b) (caddr b))
        (progn
          (setq hit T)
          (prompt (strcat "\n[PID ROUTE] Candidate rejected by obstacle: " (car b)))
        )
      )
    )
  )
  hit
)

(defun pid-path-invalid-p (pts /)
  (or
    (pid-path-overlaps-existing-p pts)
    (pid-path-intersects-obstacle-p pts)
  )
)

(defun pid-candidate-around-bbox-x (sl el mn mx side / x p1 p2)
  ;; Vertical corridor around bbox left/right side.
  (if (= side "LEFT")
    (setq x (- (car mn) *PID-OBSTACLE-CLEARANCE*))
    (setq x (+ (car mx) *PID-OBSTACLE-CLEARANCE*))
  )
  (setq p1 (pid-pt x (cadr sl)))
  (setq p2 (pid-pt x (cadr el)))
  (pid-remove-dup-pts (list sl p1 p2 el))
)

(defun pid-candidate-around-bbox-y (sl el mn mx side / y p1 p2)
  ;; Horizontal corridor around bbox top/bottom side.
  (if (= side "TOP")
    (setq y (+ (cadr mx) *PID-OBSTACLE-CLEARANCE*))
    (setq y (- (cadr mn) *PID-OBSTACLE-CLEARANCE*))
  )
  (setq p1 (pid-pt (car sl) y))
  (setq p2 (pid-pt (car el) y))
  (pid-remove-dup-pts (list sl p1 p2 el))
)

(defun pid-obstacle-detour-candidates (sl el / boxes b mn mx res)
  ;; Add detour candidates around all currently relevant S_/M_ bboxes.
  (setq res nil)
  (setq boxes (pid-obstacle-boxes))
  (foreach b boxes
    (setq mn (cadr b))
    (setq mx (caddr b))
    (setq res (append res (list (pid-candidate-around-bbox-x sl el mn mx "LEFT"))))
    (setq res (append res (list (pid-candidate-around-bbox-x sl el mn mx "RIGHT"))))
    (setq res (append res (list (pid-candidate-around-bbox-y sl el mn mx "TOP"))))
    (setq res (append res (list (pid-candidate-around-bbox-y sl el mn mx "BOTTOM"))))
  )
  res
)



(defun pid-register-path-segments (pts / s)
  (foreach s (pid-path-segments pts)
    (setq *PID-PIPE-SEGMENTS* (append *PID-PIPE-SEGMENTS* (list s)))
  )
)

(defun pid-make-line-segment (p1 p2 layer color /)
  (if (and p1 p2 (> (distance p1 p2) 0.0001))
    (progn
      (pid-layer layer color)
      (entmakex
        (list
          (cons 0 "LINE")
          (cons 8 layer)
          (cons 62 color)
          (cons 10 p1)
          (cons 11 p2)
        )
      )
      (setq *PID-PIPE-SEGMENTS* (append *PID-PIPE-SEGMENTS* (list (list p1 p2))))
    )
  )
)

(defun pid-draw-path-segments (pts layer color / a b rest)
  (if (> (length pts) 1)
    (progn
      (setq rest pts)
      (while (> (length rest) 1)
        (setq a (car rest))
        (setq b (cadr rest))
        (pid-make-line-segment a b layer color)
        (setq rest (cdr rest))
      )
    )
  )
)

(defun pid-insert-accessory-align (code align-type target rot / en pidx off inspt)
  ;; Insert accessory so align-type port is exactly at target.
  ;; No pipe line is drawn inside accessory gap.
  (pid-set-layer "PID_CHAIN" 5)
  (setq en (pid-insert-block code (pid-pt 0.0 0.0) rot))
  (if en
    (progn
      (setq pidx (pid-find-port-by-type en align-type))
      (if pidx
        (setq off (pid-port-offset-by-ename en pidx))
        (progn
          (prompt (strcat "\n[PID WARN] " code " has no " align-type " port. Use insertion point."))
          (setq off (list 0.0 0.0 0.0))
        )
      )
      (setq inspt (pid-sub-pt target (pid-rot-vec off rot)))
      (command "_.MOVE" en "" "_NON" (pid-pt 0.0 0.0) "_NON" inspt)
      (pid-mark-point inspt code)
      (list en inspt)
    )
    nil
  )
)

(defun pid-accessory-port-point (ename inspt rot port-type / pidx off)
  (setq pidx (pid-find-port-by-type ename port-type))
  (if pidx
    (progn
      (setq off (pid-port-offset-by-ename ename pidx))
      (pid-add-pt inspt (pid-rot-vec off rot))
    )
    inspt
  )
)

(defun pid-endpoint-info (id port chain-list / port-pt port-ang port-type dir align-type outer-type rot target pair en inspt outer-pt item)
  ;; Unified from/to endpoint chain rule.
  ;; - from/to does not decide chain direction.
  ;; - PORT_TYPE decides which accessory side is adjacent to the endpoint.
  ;; - PORT_ANGLE gives the outward direction from the endpoint.
  ;; - Normal accessories keep 0.9375 gap; no pipe is drawn inside those gaps.
  ;; Return: (actual_pipe_port lead_point dir angle code id)
  (setq port-pt (pid-port-point id port))
  (setq port-ang (pid-port-angle id port))
  (setq port-type (pid-port-type id port))
  (setq dir (pid-angle-vec port-ang))

  (if (= port-type "IN")
    (progn
      ;; Chain is outside of an IN port. Accessory OUT faces the equipment port.
      (setq align-type "OUT")
      (setq outer-type "IN")
      (setq rot (pid-normalize-angle (+ port-ang 180.0)))
    )
    (progn
      ;; Chain is outside of an OUT port. Accessory IN faces the equipment port.
      (setq align-type "IN")
      (setq outer-type "OUT")
      (setq rot (pid-normalize-angle port-ang))
    )
  )

  (setq outer-pt port-pt)
  (if chain-list
    (progn
      ;; First accessory side is separated from equipment port by gap.
      (setq target (pid-add-pt port-pt (pid-scale-vec dir *PID-CHAIN-GAP*)))
      (foreach item chain-list
        (setq pair (pid-insert-accessory-align item align-type target rot))
        (if pair
          (progn
            (setq en (car pair))
            (setq inspt (cadr pair))
            (setq outer-pt (pid-accessory-port-point en inspt rot outer-type))
            ;; Next accessory gap only; no line is drawn here.
            (setq target (pid-add-pt outer-pt (pid-scale-vec dir *PID-CHAIN-GAP*)))
          )
        )
      )
      ;; After final accessory, pipe starts after 10mm lead from outer port.
      (list outer-pt (pid-add-pt outer-pt (pid-scale-vec dir *PID-PIPE-LEAD*)) dir port-ang (pid-map-code-safe id) id)
    )
    (progn
      ;; No chain: pipe starts with 10mm lead from actual equipment port.
      (list port-pt (pid-add-pt port-pt (pid-scale-vec dir *PID-PIPE-LEAD*)) dir port-ang (pid-map-code-safe id) id)
    )
  )
)

(defun pid-endpoint-info-safe (id port chain-list / res pt ang dir code)
  ;; Safe wrapper for endpoint + chain generation.
  ;; If target chain/port processing fails, use the port point with 10mm lead fallback,
  ;; so the connection does not stop after the source chain is inserted.
  (setq res (vl-catch-all-apply 'pid-endpoint-info (list id port chain-list)))
  (if (vl-catch-all-error-p res)
    (progn
      (prompt (strcat "\n[PID WARN] endpoint-info failed: " id ".PORT" (itoa port) ". Use fallback without chain."))
      (setq pt (pid-port-point id port))
      (setq ang (pid-port-angle id port))
      (setq dir (pid-angle-vec ang))
      (setq code (pid-map-code-safe id))
      (list pt (pid-add-pt pt (pid-scale-vec dir *PID-PIPE-LEAD*)) dir ang code id)
    )
    res
  )
)


(defun pid-structure-code-p (code /)
  (and code (>= (strlen code) 2) (= (substr (strcase code) 1 2) "S_"))
)

(defun pid-remove-dup-pts (pts / res p lastp)
  (setq res nil)
  (foreach p pts
    (if (or (not lastp) (> (distance p lastp) 0.0001))
      (progn
        (setq res (append res (list p)))
        (setq lastp p)
      )
    )
  )
  res
)

(defun pid-candidate-source-near (sl el / mid)
  ;; Bend near source/structure side: vertical first, then horizontal.
  (setq mid (pid-pt (car sl) (cadr el)))
  (pid-remove-dup-pts (list sl mid el))
)

(defun pid-candidate-target-near (sl el / mid)
  ;; Bend near target/structure side: horizontal first, then vertical near target.
  (setq mid (pid-pt (car el) (cadr sl)))
  (pid-remove-dup-pts (list sl mid el))
)

(defun pid-candidate-offset-x (sl el off / x1 p1 p2)
  ;; Dogleg with a separate vertical riser to avoid collinear overlap.
  (setq x1 (+ (car el) off))
  (setq p1 (pid-pt x1 (cadr sl)))
  (setq p2 (pid-pt x1 (cadr el)))
  (pid-remove-dup-pts (list sl p1 p2 el))
)

(defun pid-candidate-offset-y (sl el off / y1 p1 p2)
  ;; Dogleg with a separate horizontal runner to avoid collinear overlap.
  (setq y1 (+ (cadr el) off))
  (setq p1 (pid-pt (car sl) y1))
  (setq p2 (pid-pt (car el) y1))
  (pid-remove-dup-pts (list sl p1 p2 el))
)

(defun pid-select-non-overlap-path (candidates / c selected)
  ;; Hard rules:
  ;; 1. Do not overlap existing pipe segments except point-crossing.
  ;; 2. Do not penetrate S_/M_ bboxes except endpoint/parent exclusions.
  (setq selected nil)
  (foreach c candidates
    (if (and (not selected) (not (pid-path-invalid-p c)))
      (setq selected c)
    )
  )
  (if selected
    selected
    (progn
      (prompt "\n[PID WARN] All route candidates failed overlap/obstacle checks. Use first candidate as fallback.")
      (car candidates)
    )
  )
)

(defun pid-build-ortho-route (start-info end-info / sp sl ep el sdir edir sang eang scode ecode candidates off path)
  ;; Draw endpoint lead segments and choose orthogonal center route.
  ;; The center route never uses diagonal segment.
  ;; Rule 004:
  ;; - SOURCE_NEAR forces the first bend near the source side.
  ;;   This is used for COND/FDC -> VAV type lines.
  ;; - Structure target still prefers target-side bend.
  ;; - Existing collinear pipe overlap is forbidden if another candidate exists.
  ;; - Crossing at a point is allowed.
  (setq sp (car start-info))
  (setq sl (cadr start-info))
  (setq sdir (caddr start-info))
  (setq sang (cadddr start-info))
  (setq scode (nth 4 start-info))

  (setq ep (car end-info))
  (setq el (cadr end-info))
  (setq edir (caddr end-info))
  (setq eang (cadddr end-info))
  (setq ecode (nth 4 end-info))

  ;; Set route exclusion list before bbox checks.
  ;; Endpoint blocks and parent structures of inside machines are allowed.
  (setq *PID-ROUTE-EXCLUDES* (pid-route-exclude-ids (nth 5 start-info) (nth 5 end-info)))

  ;; Lead lines from actual port/chain outer point to lead point.
  ;; These are normal connection lead segments, not accessory gap lines.
  (pid-make-line-segment sp sl "PID_PIPE" 1)
  (pid-make-line-segment el ep "PID_PIPE" 1)

  (setq candidates nil)

  (cond
    ((= *PID-ROUTE-PREF* "SOURCE_NEAR")
      ;; COND/FDC -> VAV: bend near COND/source side.
      (setq candidates (append candidates (list (pid-candidate-source-near sl el))))
      (foreach off *PID-PIPE-OVERLAP-OFFSETS*
        (setq candidates (append candidates (list (pid-candidate-offset-y sl el off))))
      )
      (setq candidates (append candidates (list (pid-candidate-target-near sl el))))
    )

    ((= *PID-ROUTE-PREF* "TARGET_NEAR")
      (setq candidates (append candidates (list (pid-candidate-target-near sl el))))
      (foreach off *PID-PIPE-OVERLAP-OFFSETS*
        (setq candidates (append candidates (list (pid-candidate-offset-x sl el off))))
      )
      (setq candidates (append candidates (list (pid-candidate-source-near sl el))))
    )

    ((pid-structure-code-p ecode)
      ;; Structure target: place last bend near target side.
      (setq candidates (append candidates (list (pid-candidate-target-near sl el))))
      (foreach off *PID-PIPE-OVERLAP-OFFSETS*
        (setq candidates (append candidates (list (pid-candidate-offset-x sl el off))))
      )
      (setq candidates (append candidates (list (pid-candidate-source-near sl el))))
    )

    ((pid-structure-code-p scode)
      ;; Structure source: place first bend near source side.
      (setq candidates (append candidates (list (pid-candidate-source-near sl el))))
      (foreach off *PID-PIPE-OVERLAP-OFFSETS*
        (setq candidates (append candidates (list (pid-candidate-offset-y sl el off))))
      )
      (setq candidates (append candidates (list (pid-candidate-target-near sl el))))
    )

    (T
      ;; General default: target-near first, then source-near, then offset candidates.
      (setq candidates (append candidates (list (pid-candidate-target-near sl el))))
      (setq candidates (append candidates (list (pid-candidate-source-near sl el))))
      (foreach off *PID-PIPE-OVERLAP-OFFSETS*
        (setq candidates (append candidates (list (pid-candidate-offset-x sl el off))))
      )
    )
  )

  ;; Add bbox detour candidates after normal priority candidates.
  ;; These are used only when normal candidates penetrate S_/M_ blocks.
  (setq candidates (append candidates (pid-obstacle-detour-candidates sl el)))

  (setq path (pid-select-non-overlap-path candidates))
  path
)

(defun pid-connect-endpoints (line-id from-id from-port from-chain to-id to-port to-chain / a b path oldpref)
  (prompt (strcat "\n[PID CONNECT] " line-id ": " from-id ".PORT" (itoa from-port) " -> " to-id ".PORT" (itoa to-port)))
  (setq a (pid-endpoint-info-safe from-id from-port from-chain))
  (setq b (pid-endpoint-info-safe to-id to-port to-chain))
  (setq path (pid-build-ortho-route a b))
  (pid-draw-path-segments path "PID_PIPE" 1)
  (pid-label (pid-add-pt (car path) (list 15.0 15.0 0.0)) line-id)
)

(defun pid-connect-endpoints-pref (pref line-id from-id from-port from-chain to-id to-port to-chain / oldpref)
  (setq oldpref *PID-ROUTE-PREF*)
  (setq *PID-ROUTE-PREF* pref)
  (pid-connect-endpoints line-id from-id from-port from-chain to-id to-port to-chain)
  (setq *PID-ROUTE-PREF* oldpref)
)


;;; -----------------------------
;;; REF / TEE / trunk helper functions - added in 005
;;; -----------------------------
(setq *PID-REF-MAP* nil)

(defun pid-ref-put (id pt /)
  (setq *PID-REF-MAP*
    (cons (list id pt)
          (vl-remove-if '(lambda (x) (= (car x) id)) *PID-REF-MAP*)))
)

(defun pid-ref-point (id / row)
  (setq row (assoc id *PID-REF-MAP*))
  (if row
    (cadr row)
    (progn
      (prompt (strcat "\n[PID WARN] Missing ref: " id))
      (pid-pt 0.0 0.0)
    )
  )
)

(defun pid-draw-ref-marker (id pt / x y r)
  (setq x (car pt))
  (setq y (cadr pt))
  (setq r 5.0)
  (pid-set-layer "PID_REF" 6)
  (command "_.CIRCLE" "_NON" pt r)
  (pid-label (pid-add-pt pt (list 0.0 12.0 0.0)) id)
)

(defun pid-path-length (pts / total rest a b)
  (setq total 0.0)
  (setq rest pts)
  (while (> (length rest) 1)
    (setq a (car rest))
    (setq b (cadr rest))
    (setq total (+ total (distance a b)))
    (setq rest (cdr rest))
  )
  total
)

(defun pid-point-at-path-distance (pts dist / rest a b seg remain ratio result)
  ;; Robust point-at-distance along orthogonal path.
  ;; Returns last point if distance exceeds path length.
  (setq result nil)
  (if (and pts (> (length pts) 0))
    (progn
      (setq rest pts)
      (setq remain dist)

      (while (and (> (length rest) 1) (not result))
        (setq a (car rest))
        (setq b (cadr rest))
        (setq seg (distance a b))

        (if (<= remain seg)
          (progn
            (setq ratio (if (> seg 0.0001) (/ remain seg) 0.0))
            (setq result
              (list
                (+ (car a) (* (- (car b) (car a)) ratio))
                (+ (cadr a) (* (- (cadr b) (cadr a)) ratio))
                0.0
              )
            )
          )
          (progn
            (setq remain (- remain seg))
            (setq rest (cdr rest))
          )
        )
      )

      (if (not result)
        (setq result (car (last pts)))
      )
    )
    (setq result (list 0.0 0.0 0.0))
  )
  result
)

(defun pid-path-midpoint-by-length (pts / len)
  (setq len (pid-path-length pts))
  (pid-point-at-path-distance pts (/ len 2.0))
)

(defun pid-between-p (v a b / mn mx)
  (setq mn (min a b))
  (setq mx (max a b))
  (and (>= v (- mn 0.001)) (<= v (+ mx 0.001)))
)

(defun pid-align-target-to-path (pts target / rest a b hit)
  ;; Returns a point on path aligned to target by X/Y if possible.
  ;; For horizontal segment: use target.X if it lies on segment.
  ;; For vertical segment: use target.Y if it lies on segment.
  (setq hit nil)
  (setq rest pts)
  (while (and (> (length rest) 1) (not hit))
    (setq a (car rest))
    (setq b (cadr rest))
    (cond
      ((and (pid-seg-horizontal-p a b) (pid-between-p (car target) (car a) (car b)))
        (setq hit (pid-pt (car target) (cadr a)))
      )
      ((and (pid-seg-vertical-p a b) (pid-between-p (cadr target) (cadr a) (cadr b)))
        (setq hit (pid-pt (car a) (cadr target)))
      )
    )
    (setq rest (cdr rest))
  )
  hit
)

(defun pid-create-tee-on-path (tee-id path target / pt)
  ;; Priority:
  ;; 1. branch target projection/intersection on parent path
  ;; 2. path-length midpoint fallback
  (setq pt nil)
  (if target
    (setq pt (pid-align-target-to-path path target))
  )
  (if (not pt)
    (setq pt (pid-path-midpoint-by-length path))
  )
  (if (not pt)
    (progn
      (prompt (strcat "\n[PID WARN] TEE fallback failed: " tee-id ". Use 0,0."))
      (setq pt (pid-pt 0.0 0.0))
    )
  )
  (pid-ref-put tee-id pt)
  (pid-draw-ref-marker tee-id pt)
  pt
)

(defun pid-ref-info (ref-id / p)
  (setq p (pid-ref-point ref-id))
  ;; Same list format as endpoint-info:
  ;; (actual_pipe_port lead_point dir angle code id)
  ;; Ref is neutral, so actual and lead are the same.
  (list p p nil 0.0 "REF" ref-id)
)


(defun pid-point-on-path-distance-from-start (pts dist / result)
  ;; Wrapper for source-side TEE placement.
  ;; Returns a point located dist from the first path point along the routed path.
  (setq result (pid-point-at-path-distance pts dist))
  (if result
    result
    (if pts (car pts) (pid-pt 0.0 0.0))
  )
)

(defun pid-create-tee-source-near-on-path (tee-id path dist / pt)
  ;; For bypass/source-side branch TEE.
  ;; TEE is placed near the source equipment side, measured by path length.
  ;; This prevents TEE1/TEE2 from being created at the path midpoint.
  (setq pt (pid-point-on-path-distance-from-start path dist))
  (pid-ref-put tee-id pt)
  (pid-draw-ref-marker tee-id pt)
  pt
)


(defun pid-machine-code-p (code /)
  (and code (>= (strlen code) 2) (= (substr (strcase code) 1 2) "M_"))
)

(defun pid-point-on-path-distance-from-end (pts dist / len target)
  ;; Returns a point located dist from the end of the path, measured by path length.
  (setq len (pid-path-length pts))
  (setq target (- len dist))
  (if (< target 0.0)
    (setq target 0.0)
  )
  (pid-point-at-path-distance pts target)
)

(defun pid-create-tee-near-side-on-path (tee-id path side dist / pt)
  ;; side = "SOURCE" / "TARGET" / "MID"
  ;; SOURCE: dist from path start
  ;; TARGET: dist from path end
  ;; MID: path-length midpoint
  (cond
    ((= side "SOURCE")
      (setq pt (pid-point-on-path-distance-from-start path dist))
    )
    ((= side "TARGET")
      (setq pt (pid-point-on-path-distance-from-end path dist))
    )
    (T
      (setq pt (pid-path-midpoint-by-length path))
    )
  )
  (if (not pt)
    (setq pt (pid-path-midpoint-by-length path))
  )
  (if (not pt)
    (setq pt (if path (car path) (pid-pt 0.0 0.0)))
  )
  (pid-ref-put tee-id pt)
  (pid-draw-ref-marker tee-id pt)
  pt
)

(defun pid-tee-side-by-endpoint-type (scode ecode /)
  ;; TEE placement rule:
  ;; 1. Structure-Machine connection: TEE near the machine side.
  ;; 2. Machine-Machine connection: TEE near the TO side.
  ;; 3. Structure-Structure/unknown: midpoint fallback.
  ;; This is intentionally separated from bend priority.
  (cond
    ((and (pid-structure-code-p scode) (pid-machine-code-p ecode)) "TARGET")
    ((and (pid-machine-code-p scode) (pid-structure-code-p ecode)) "SOURCE")
    ((and (pid-machine-code-p scode) (pid-machine-code-p ecode)) "TARGET")
    (T "MID")
  )
)

(defun pid-bend-pref-by-endpoint-type (scode ecode /)
  ;; Bend placement rule:
  ;; Structure-Machine connection bends near the structure side.
  ;; Machine-Machine keeps target-side priority as a general clean default.
  (cond
    ((and (pid-structure-code-p scode) (pid-machine-code-p ecode)) "SOURCE_NEAR")
    ((and (pid-machine-code-p scode) (pid-structure-code-p ecode)) "TARGET_NEAR")
    ((and (pid-machine-code-p scode) (pid-machine-code-p ecode)) "TARGET_NEAR")
    (T nil)
  )
)


(defun pid-connect-endpoints-with-tee (line-id from-id from-port from-chain tee-id to-id to-port to-chain / a b path teept scode ecode tee-side bend-pref oldpref)
  (prompt (strcat "
[PID CONNECT] " line-id " with " tee-id " TYPE_BASED_TEE"))

  ;; Endpoint info format:
  ;; (actual_pipe_port lead_point dir angle code id)
  (setq a (pid-endpoint-info-safe from-id from-port from-chain))
  (setq b (pid-endpoint-info-safe to-id to-port to-chain))

  (setq scode (nth 4 a))
  (setq ecode (nth 4 b))

  ;; TEE placement and bend placement are separate rules.
  ;; Example S_ -> M_:
  ;; - TEE near M_ side
  ;; - bend near S_ side
  (setq tee-side (pid-tee-side-by-endpoint-type scode ecode))
  (setq bend-pref (pid-bend-pref-by-endpoint-type scode ecode))

  (setq oldpref *PID-ROUTE-PREF*)
  (setq *PID-ROUTE-PREF* bend-pref)

  ;; pid-build-ortho-route draws endpoint lead segments and selects
  ;; an overlap/obstacle-aware route candidate.
  (setq path (pid-build-ortho-route a b))

  (setq *PID-ROUTE-PREF* oldpref)

  (if path
    (progn
      ;; Revised TEE placement:
      ;; - S-M: machine side
      ;; - M-M: to side
      ;; - fallback: midpoint
      (setq teept (pid-create-tee-near-side-on-path tee-id path tee-side *PID-TEE-SOURCE-DIST*))
      (pid-draw-path-segments path "PID_PIPE" 1)
      (pid-label (pid-add-pt (car path) (list 15.0 15.0 0.0)) line-id)
    )
    (progn
      (prompt (strcat "
[PID WARN] route failed for " line-id "."))
    )
  )
)

(defun pid-build-route-between-infos-no-draw (a b / sp sl ep el candidates off path)
  (setq sp (car a))
  (setq sl (cadr a))
  (setq ep (car b))
  (setq el (cadr b))
  (setq candidates nil)
  (setq *PID-ROUTE-EXCLUDES* (pid-route-exclude-ids (nth 5 a) (nth 5 b)))

  ;; Candidate set without route_hint. Score is approximated by candidate order
  ;; plus overlap rejection:
  ;; 1. target-near
  ;; 2. source-near
  ;; 3. offset doglegs
  (setq candidates (append candidates (list (pid-candidate-target-near sl el))))
  (setq candidates (append candidates (list (pid-candidate-source-near sl el))))
  (foreach off *PID-PIPE-OVERLAP-OFFSETS*
    (setq candidates (append candidates (list (pid-candidate-offset-x sl el off))))
    (setq candidates (append candidates (list (pid-candidate-offset-y sl el off))))
  )
  (setq candidates (append candidates (pid-obstacle-detour-candidates sl el)))
  (pid-select-non-overlap-path candidates)
)

(defun pid-connect-ref-to-endinfo (line-id ref-id end-info / a path ep el)
  (prompt (strcat "\n[PID CONNECT] " line-id ": " ref-id " -> endpoint"))
  (setq a (pid-ref-info ref-id))

  ;; endpoint lead
  (setq ep (car end-info))
  (setq el (cadr end-info))
  (pid-make-line-segment el ep "PID_PIPE" 1)

  (setq path (pid-build-route-between-infos-no-draw a end-info))
  (pid-draw-path-segments path "PID_PIPE" 1)
  (pid-label (pid-add-pt (car path) (list 15.0 15.0 0.0)) line-id)
)

(defun pid-connect-ref-to-ref-virtual-path (from-ref to-ref / a b)
  ;; Used for trunk coordinate calculation only.
  ;; Does not draw pipe.
  (setq a (pid-ref-info from-ref))
  (setq b (pid-ref-info to-ref))
  (pid-build-route-between-infos-no-draw a b)
)

(defun pid-angle-between-points-orthogonal (a b / dx dy)
  ;; Choose main direction for inline accessory placement.
  ;; Prefer vertical if abs(dy) >= abs(dx), otherwise horizontal.
  (setq dx (- (car b) (car a)))
  (setq dy (- (cadr b) (cadr a)))
  (cond
    ((>= (abs dy) (abs dx))
      (if (>= dy 0.0) 90.0 270.0)
    )
    (T
      (if (>= dx 0.0) 0.0 180.0)
    )
  )
)

(defun pid-accessory-axis-length (code / en inidx outidx inoff outoff len)
  ;; Temporary insert only for measurement. Deleted immediately.
  (setq en (pid-insert-block code (pid-pt 0.0 0.0) 0.0))
  (if en
    (progn
      (setq inidx (pid-find-port-by-type en "IN"))
      (setq outidx (pid-find-port-by-type en "OUT"))
      (if (and inidx outidx)
        (progn
          (setq inoff (pid-port-offset-by-ename en inidx))
          (setq outoff (pid-port-offset-by-ename en outidx))
          (setq len (distance inoff outoff))
        )
        (setq len 20.0)
      )
      (entdel en)
      len
    )
    20.0
  )
)

(defun pid-chain-total-length (chain-list / total first item)
  (setq total 0.0)
  (setq first T)
  (foreach item chain-list
    (if (not first)
      (setq total (+ total *PID-CHAIN-GAP*))
    )
    (setq total (+ total (pid-accessory-axis-length item)))
    (setq first nil)
  )
  total
)

(defun pid-insert-inline-chain-centered (from-pt to-pt chain-list / ang dir total center start target pair en inspt outpt first-in last-out item)
  ;; Places normal accessory chain centered between two refs.
  ;; Internal accessory gaps are respected and no pipe is drawn inside those gaps.
  ;; Returns (first-in last-out).
  (setq ang (pid-angle-between-points-orthogonal from-pt to-pt))
  (setq dir (pid-angle-vec ang))
  (setq total (pid-chain-total-length chain-list))
  (setq center (list (/ (+ (car from-pt) (car to-pt)) 2.0)
                     (/ (+ (cadr from-pt) (cadr to-pt)) 2.0)
                     0.0))
  (setq start (pid-add-pt center (pid-scale-vec dir (- (/ total 2.0)))))
  (setq target start)
  (setq first-in nil)
  (setq last-out nil)

  (foreach item chain-list
    (setq pair (pid-insert-accessory-align item "IN" target ang))
    (if pair
      (progn
        (setq en (car pair))
        (setq inspt (cadr pair))
        (if (not first-in)
          (setq first-in target)
        )
        (setq outpt (pid-accessory-port-point en inspt ang "OUT"))
        (setq last-out outpt)
        ;; gap only; no line is drawn between accessories
        (setq target (pid-add-pt outpt (pid-scale-vec dir *PID-CHAIN-GAP*)))
      )
    )
  )
  (list first-in last-out)
)

(defun pid-connect-ref-to-ref-with-centered-chain (line-id from-ref to-ref chain-list / p1 p2 ends first-in last-out)
  (prompt (strcat "\n[PID CONNECT] " line-id ": " from-ref " -> chain -> " to-ref))
  (setq p1 (pid-ref-point from-ref))
  (setq p2 (pid-ref-point to-ref))
  (setq ends (pid-insert-inline-chain-centered p1 p2 chain-list))
  (setq first-in (car ends))
  (setq last-out (cadr ends))

  ;; Draw only both outer pipe sections.
  ;; No internal pipe is drawn inside accessory gaps.
  (if first-in
    (pid-draw-path-segments (pid-build-route-between-infos-no-draw (list p1 p1 nil 0.0 "REF" from-ref)
                                                                  (list first-in first-in nil 0.0 "REF" "CHAIN_IN"))
                            "PID_PIPE" 1)
  )
  (if last-out
    (pid-draw-path-segments (pid-build-route-between-infos-no-draw (list last-out last-out nil 0.0 "REF" "CHAIN_OUT")
                                                                  (list p2 p2 nil 0.0 "REF" to-ref))
                            "PID_PIPE" 1)
  )
  (pid-label (pid-add-pt p1 (list 15.0 15.0 0.0)) line-id)
)



;;; ============================================================
;;; Rule override 012
;;; - Pipe color by media
;;; - M-M TEE near endpoint whose PORT_TYPE is OUT
;;; - S-M TEE near machine side
;;; - Bend priority remains structure-side for S-M
;;; - Chain output minimum straight length before first bend
;;; ============================================================

(setq *PID-CURRENT-MEDIA* "RAW_WATER")
(setq *PID-CHAIN-AFTER-LEAD* 50.0)

(defun pid-media-color (media / m)
  (setq m (strcase media))
  (cond
    ((= m "RAW_WATER") 4)
    ((= m "SLUDGE") 3)
    ((= m "AIR") 7)
    ((= m "CHEMICAL") 6)
    (T 1)
  )
)

(defun pid-pipe-layer-by-media (media / m)
  (setq m (strcase media))
  (cond
    ((= m "RAW_WATER") "PID_PIPE_RAW_WATER")
    ((= m "SLUDGE") "PID_PIPE_SLUDGE")
    ((= m "AIR") "PID_PIPE_AIR")
    ((= m "CHEMICAL") "PID_PIPE_CHEMICAL")
    (T "PID_PIPE")
  )
)

(defun pid-set-current-media (media / layer color)
  (setq *PID-CURRENT-MEDIA* media)
  (setq layer (pid-pipe-layer-by-media media))
  (setq color (pid-media-color media))
  (pid-layer layer color)
)

(defun pid-make-line-segment (p1 p2 layer color / actual-layer actual-color)
  ;; 012 override:
  ;; Pipe segments use media-based layer/color.
  ;; RAW_WATER=4, SLUDGE=3, AIR=7, CHEMICAL=6.
  (if (and p1 p2 (> (distance p1 p2) 0.0001))
    (progn
      (if (= (strcase layer) "PID_PIPE")
        (progn
          (setq actual-layer (pid-pipe-layer-by-media *PID-CURRENT-MEDIA*))
          (setq actual-color (pid-media-color *PID-CURRENT-MEDIA*))
        )
        (progn
          (setq actual-layer layer)
          (setq actual-color color)
        )
      )
      (pid-layer actual-layer actual-color)
      (entmakex
        (list
          (cons 0 "LINE")
          (cons 8 actual-layer)
          (cons 62 actual-color)
          (cons 10 p1)
          (cons 11 p2)
        )
      )
      (if (= (strcase layer) "PID_PIPE")
        (setq *PID-PIPE-SEGMENTS* (append *PID-PIPE-SEGMENTS* (list (list p1 p2))))
      )
    )
  )
)

(defun pid-endpoint-info (id port chain-list / port-pt port-ang port-type dir align-type outer-type rot target pair en inspt outer-pt item lead-len)
  ;; 012 override:
  ;; Chain placement still depends on actual PORT_TYPE and PORT_ANGLE,
  ;; not from/to role.
  ;; If an endpoint has a chain, reserve an additional 50mm straight
  ;; after the chain before route bending is allowed.
  (setq port-pt (pid-port-point id port))
  (setq port-ang (pid-port-angle id port))
  (setq port-type (pid-port-type id port))
  (setq dir (pid-angle-vec port-ang))

  (if (= port-type "IN")
    (progn
      ;; Chain is outside of an IN port. Accessory OUT faces the equipment port.
      (setq align-type "OUT")
      (setq outer-type "IN")
      (setq rot (pid-normalize-angle (+ port-ang 180.0)))
    )
    (progn
      ;; Chain is outside of an OUT port. Accessory IN faces the equipment port.
      (setq align-type "IN")
      (setq outer-type "OUT")
      (setq rot (pid-normalize-angle port-ang))
    )
  )

  (setq outer-pt port-pt)

  (if chain-list
    (progn
      ;; First accessory side is separated from equipment port by 0.9375 gap.
      ;; No pipe is drawn in the gap.
      (setq target (pid-add-pt port-pt (pid-scale-vec dir *PID-CHAIN-GAP*)))

      (foreach item chain-list
        (setq pair (pid-insert-accessory-align item align-type target rot))
        (if pair
          (progn
            (setq en (car pair))
            (setq inspt (cadr pair))
            (setq outer-pt (pid-accessory-port-point en inspt rot outer-type))
            ;; Normal accessory gap only. No pipe in this internal gap.
            (setq target (pid-add-pt outer-pt (pid-scale-vec dir *PID-CHAIN-GAP*)))
          )
        )
      )

      ;; Chain endpoint straight rule:
      ;; After final accessory outer port, keep 10mm port lead + 50mm straight
      ;; before the route is allowed to bend.
      (setq lead-len (+ *PID-PIPE-LEAD* *PID-CHAIN-AFTER-LEAD*))
      (list outer-pt (pid-add-pt outer-pt (pid-scale-vec dir lead-len)) dir port-ang (pid-map-code-safe id) id)
    )
    (progn
      ;; No chain: keep normal 10mm port lead.
      (list port-pt (pid-add-pt port-pt (pid-scale-vec dir *PID-PIPE-LEAD*)) dir port-ang (pid-map-code-safe id) id)
    )
  )
)

(defun pid-tee-side-by-connection (from-id from-port scode to-id to-port ecode / ftype ttype)
  ;; 012 TEE placement rule:
  ;; 1. Structure-Machine: TEE near machine side.
  ;; 2. Machine-Machine: TEE near endpoint whose PORT_TYPE is OUT.
  ;;    If both/none are OUT, fallback to TARGET.
  ;; 3. Structure-Structure/unknown: midpoint fallback.
  (cond
    ((and (pid-structure-code-p scode) (pid-machine-code-p ecode)) "TARGET")
    ((and (pid-machine-code-p scode) (pid-structure-code-p ecode)) "SOURCE")
    ((and (pid-machine-code-p scode) (pid-machine-code-p ecode))
      (setq ftype (pid-port-type from-id from-port))
      (setq ttype (pid-port-type to-id to-port))
      (cond
        ((= ftype "OUT") "SOURCE")
        ((= ttype "OUT") "TARGET")
        (T "TARGET")
      )
    )
    (T "MID")
  )
)

(defun pid-bend-pref-by-endpoint-type (scode ecode /)
  ;; Bend placement rule stays independent from TEE position:
  ;; S-M bends near the structure side.
  (cond
    ((and (pid-structure-code-p scode) (pid-machine-code-p ecode)) "SOURCE_NEAR")
    ((and (pid-machine-code-p scode) (pid-structure-code-p ecode)) "TARGET_NEAR")
    ((and (pid-machine-code-p scode) (pid-machine-code-p ecode)) "TARGET_NEAR")
    (T nil)
  )
)

(defun pid-connect-endpoints-with-tee (line-id from-id from-port from-chain tee-id to-id to-port to-chain / a b path teept scode ecode tee-side bend-pref oldpref)
  (prompt (strcat "\n[PID CONNECT] " line-id " with " tee-id " RULE_012"))

  ;; Endpoint info format:
  ;; (actual_pipe_port lead_point dir angle code id)
  (setq a (pid-endpoint-info-safe from-id from-port from-chain))
  (setq b (pid-endpoint-info-safe to-id to-port to-chain))

  (setq scode (nth 4 a))
  (setq ecode (nth 4 b))

  ;; TEE placement and bend placement are intentionally separated.
  (setq tee-side (pid-tee-side-by-connection from-id from-port scode to-id to-port ecode))
  (setq bend-pref (pid-bend-pref-by-endpoint-type scode ecode))

  (setq oldpref *PID-ROUTE-PREF*)
  (setq *PID-ROUTE-PREF* bend-pref)

  (setq path (pid-build-ortho-route a b))

  (setq *PID-ROUTE-PREF* oldpref)

  (if path
    (progn
      ;; TEE placement:
      ;; - S-M: machine side
      ;; - M-M: OUT-port side
      ;; - fallback: midpoint
      (setq teept (pid-create-tee-near-side-on-path tee-id path tee-side *PID-TEE-SOURCE-DIST*))
      (pid-draw-path-segments path "PID_PIPE" 1)
      (pid-label (pid-add-pt (car path) (list 15.0 15.0 0.0)) line-id)
    )
    (prompt (strcat "\n[PID WARN] route failed for " line-id "."))
  )
)



;;; ============================================================
;;; Rule override 013
;;; - TEE position must be 50mm from the OUT-side pipe-start point.
;;; - For M-M: choose endpoint whose PORT_TYPE is OUT.
;;; - For S-M: choose machine side.
;;; - No bend before TEE.
;;; - After TEE, keep 50mm straight segment before routing can bend.
;;; ============================================================

(defun pid-tee-side-by-connection (from-id from-port scode to-id to-port ecode / ftype ttype)
  ;; 013 TEE placement rule:
  ;; 1. Structure-Machine: TEE near machine side.
  ;; 2. Machine-Machine: TEE near endpoint whose block PORT_TYPE is OUT.
  ;; 3. If OUT side is ambiguous, fallback to TARGET.
  (cond
    ((and (pid-structure-code-p scode) (pid-machine-code-p ecode)) "TARGET")
    ((and (pid-machine-code-p scode) (pid-structure-code-p ecode)) "SOURCE")
    ((and (pid-machine-code-p scode) (pid-machine-code-p ecode))
      (setq ftype (pid-port-type from-id from-port))
      (setq ttype (pid-port-type to-id to-port))
      (cond
        ((= ftype "OUT") "SOURCE")
        ((= ttype "OUT") "TARGET")
        (T "TARGET")
      )
    )
    (T "MID")
  )
)

(defun pid-connect-endpoints-with-tee (line-id from-id from-port from-chain tee-id to-id to-port to-chain / a b scode ecode tee-side bend-pref oldpref anchor dir teept postpt prept path start-info target-info)
  (prompt (strcat "\n[PID CONNECT] " line-id " with " tee-id " RULE_013"))

  ;; Endpoint info format:
  ;; (actual_pipe_port lead_point dir angle code id)
  ;; For chained endpoints, actual_pipe_port is the final outer accessory port.
  ;; This prevents TEE distance from becoming 10+50+50 = 110mm.
  (setq a (pid-endpoint-info-safe from-id from-port from-chain))
  (setq b (pid-endpoint-info-safe to-id to-port to-chain))

  (setq scode (nth 4 a))
  (setq ecode (nth 4 b))

  (setq tee-side (pid-tee-side-by-connection from-id from-port scode to-id to-port ecode))
  (setq bend-pref (pid-bend-pref-by-endpoint-type scode ecode))

  (cond
    ;; ----------------------------------------------------------
    ;; TEE near SOURCE side
    ;; Rule:
    ;;   source pipe-start -> 50mm straight -> TEE
    ;;   TEE -> 50mm straight -> route may bend
    ;; ----------------------------------------------------------
    ((= tee-side "SOURCE")
      (setq anchor (car a))
      (setq dir (caddr a))
      (if (not dir) (setq dir (pid-angle-vec 0.0)))

      (setq teept  (pid-add-pt anchor (pid-scale-vec dir *PID-TEE-SOURCE-DIST*)))
      (setq postpt (pid-add-pt teept  (pid-scale-vec dir *PID-TEE-AFTER-LEAD*)))

      ;; Draw source-side straight only. No bend is allowed before TEE.
      (pid-make-line-segment anchor teept "PID_PIPE" 1)
      (pid-ref-put tee-id teept)
      (pid-draw-ref-marker tee-id teept)
      (pid-make-line-segment teept postpt "PID_PIPE" 1)

      ;; Route from post-TEE straight point to the target endpoint.
      (setq start-info (list postpt postpt dir 0.0 "REF" tee-id))

      (setq oldpref *PID-ROUTE-PREF*)
      (setq *PID-ROUTE-PREF* bend-pref)
      (setq path (pid-build-ortho-route start-info b))
      (setq *PID-ROUTE-PREF* oldpref)

      (if path
        (pid-draw-path-segments path "PID_PIPE" 1)
      )
      (pid-label (pid-add-pt anchor (list 15.0 15.0 0.0)) line-id)
    )

    ;; ----------------------------------------------------------
    ;; TEE near TARGET side
    ;; Rule:
    ;;   target pipe-start -> 50mm straight -> TEE
    ;;   TEE -> 50mm straight outward -> route may bend
    ;; ----------------------------------------------------------
    ((= tee-side "TARGET")
      (setq anchor (car b))
      (setq dir (caddr b))
      (if (not dir) (setq dir (pid-angle-vec 180.0)))

      (setq teept (pid-add-pt anchor (pid-scale-vec dir *PID-TEE-SOURCE-DIST*)))
      (setq prept (pid-add-pt teept (pid-scale-vec dir *PID-TEE-AFTER-LEAD*)))

      ;; Draw target-side straight. No bend is allowed between target and TEE.
      (pid-make-line-segment anchor teept "PID_PIPE" 1)
      (pid-ref-put tee-id teept)
      (pid-draw-ref-marker tee-id teept)
      (pid-make-line-segment teept prept "PID_PIPE" 1)

      ;; Route from source endpoint to pre-TEE straight point.
      (setq target-info (list prept prept dir 0.0 "REF" tee-id))

      (setq oldpref *PID-ROUTE-PREF*)
      (setq *PID-ROUTE-PREF* bend-pref)
      (setq path (pid-build-ortho-route a target-info))
      (setq *PID-ROUTE-PREF* oldpref)

      (if path
        (pid-draw-path-segments path "PID_PIPE" 1)
      )
      (pid-label (pid-add-pt (car a) (list 15.0 15.0 0.0)) line-id)
    )

    ;; ----------------------------------------------------------
    ;; MID fallback
    ;; ----------------------------------------------------------
    (T
      (setq oldpref *PID-ROUTE-PREF*)
      (setq *PID-ROUTE-PREF* bend-pref)
      (setq path (pid-build-ortho-route a b))
      (setq *PID-ROUTE-PREF* oldpref)

      (if path
        (progn
          (pid-create-tee-near-side-on-path tee-id path "MID" *PID-TEE-SOURCE-DIST*)
          (pid-draw-path-segments path "PID_PIPE" 1)
          (pid-label (pid-add-pt (car path) (list 15.0 15.0 0.0)) line-id)
        )
      )
    )
  )
)



(defun pid-connect-endinfo-to-ref (line-id start-info ref-id / b path sp sl)
  ;; Endpoint -> REF connector.
  ;; Used for lines like: PMP2 port2 + from.chain -> TEE9
  (prompt (strcat "\n[PID CONNECT] " line-id ": endpoint -> " ref-id))
  (setq b (pid-ref-info ref-id))

  ;; Source endpoint lead / post-chain straight section.
  (setq sp (car start-info))
  (setq sl (cadr start-info))
  (pid-make-line-segment sp sl "PID_PIPE" 1)

  (setq path (pid-build-route-between-infos-no-draw start-info b))
  (pid-draw-path-segments path "PID_PIPE" 1)

  (if path
    (pid-label (pid-add-pt (car path) (list 15.0 15.0 0.0)) line-id)
  )
)



;;; ============================================================
;;; Rule override 015
;;; - from/to direction is not hardcoded for global routing.
;;; - PORT_ANGLE is used for local lead/chain/TEE straight sections only.
;;; - After local lead/chain/TEE straight sections, choose shortest clean
;;;   orthogonal route by scoring candidates.
;;; - Hard constraints remain:
;;;   no diagonal, no S_/M_ bbox penetration, no same-axis pipe overlap.
;;; ============================================================

(defun pid-path-bend-count (pts / cnt rest a b c dx1 dy1 dx2 dy2)
  (setq cnt 0)
  (setq rest pts)
  (while (> (length rest) 2)
    (setq a (car rest))
    (setq b (cadr rest))
    (setq c (caddr rest))
    (setq dx1 (- (car b) (car a)))
    (setq dy1 (- (cadr b) (cadr a)))
    (setq dx2 (- (car c) (car b)))
    (setq dy2 (- (cadr c) (cadr b)))
    (if (or
          (and (> (abs dx1) 0.001) (> (abs dy2) 0.001))
          (and (> (abs dy1) 0.001) (> (abs dx2) 0.001))
        )
      (setq cnt (1+ cnt))
    )
    (setq rest (cdr rest))
  )
  cnt
)

(defun pid-path-score (pts / len bends)
  ;; Lower is better.
  ;; Length is the main criterion.
  ;; Bend count is a small readability penalty.
  (setq len (pid-path-length pts))
  (setq bends (pid-path-bend-count pts))
  (+ len (* 15.0 bends))
)

(defun pid-append-candidate-unique (lst cand / exists c)
  (setq exists nil)
  (foreach c lst
    (if (= (vl-princ-to-string c) (vl-princ-to-string cand))
      (setq exists T)
    )
  )
  (if exists lst (append lst (list cand)))
)

(defun pid-build-general-candidates (sl el / candidates off)
  ;; Generate broad orthogonal candidates.
  ;; Do not prefer from/to role here.
  ;; Scoring will choose the shortest valid route.
  (setq candidates nil)

  ;; Simple 1-bend candidates
  (setq candidates (pid-append-candidate-unique candidates (pid-candidate-target-near sl el))) ; H then V
  (setq candidates (pid-append-candidate-unique candidates (pid-candidate-source-near sl el))) ; V then H

  ;; Offset doglegs for pipe overlap avoidance and visual cleanup.
  (foreach off *PID-PIPE-OVERLAP-OFFSETS*
    (setq candidates (pid-append-candidate-unique candidates (pid-candidate-offset-x sl el off)))
    (setq candidates (pid-append-candidate-unique candidates (pid-candidate-offset-y sl el off)))
  )

  ;; Obstacle/bbox detours.
  (foreach off (pid-obstacle-detour-candidates sl el)
    (setq candidates (pid-append-candidate-unique candidates off))
  )

  candidates
)

(defun pid-select-best-scored-path (candidates / c best best-score score fallback fallback-score)
  ;; Hard invalid candidates are rejected first.
  ;; Among valid candidates, choose shortest + fewer bends.
  ;; If all candidates are invalid, choose the least-scored fallback and warn.
  (setq best nil)
  (setq best-score nil)
  (setq fallback nil)
  (setq fallback-score nil)

  (foreach c candidates
    (setq score (pid-path-score c))

    ;; Keep a fallback by score in case all candidates fail hard checks.
    (if (or (not fallback-score) (< score fallback-score))
      (progn
        (setq fallback c)
        (setq fallback-score score)
      )
    )

    ;; Hard constraints: no pipe overlap / no bbox penetration.
    (if (not (pid-path-invalid-p c))
      (if (or (not best-score) (< score best-score))
        (progn
          (setq best c)
          (setq best-score score)
        )
      )
    )
  )

  (if best
    best
    (progn
      (prompt "\n[PID WARN] All route candidates failed hard checks. Use shortest fallback.")
      fallback
    )
  )
)

(defun pid-select-non-overlap-path (candidates /)
  ;; 015 override name kept for compatibility with old functions.
  (pid-select-best-scored-path candidates)
)

(defun pid-build-route-between-infos-no-draw (a b / sl el candidates)
  ;; 015 override:
  ;; After local endpoint straight sections, choose the shortest clean route.
  (setq sl (cadr a))
  (setq el (cadr b))
  (setq *PID-ROUTE-EXCLUDES* (pid-route-exclude-ids (nth 5 a) (nth 5 b)))
  (setq candidates (pid-build-general-candidates sl el))
  (pid-select-best-scored-path candidates)
)

(defun pid-build-ortho-route (start-info end-info / sp sl ep el candidates path)
  ;; 015 override:
  ;; Keep local endpoint lead/chain straight sections,
  ;; then score all center-route candidates by length and bends.
  (setq sp (car start-info))
  (setq sl (cadr start-info))
  (setq ep (car end-info))
  (setq el (cadr end-info))

  ;; Endpoint exclusions for bbox checks.
  (setq *PID-ROUTE-EXCLUDES* (pid-route-exclude-ids (nth 5 start-info) (nth 5 end-info)))

  ;; Local straight segments.
  ;; These are not candidate-scored route segments; they are mandatory local leads.
  (pid-make-line-segment sp sl "PID_PIPE" 1)
  (pid-make-line-segment el ep "PID_PIPE" 1)

  (setq candidates (pid-build-general-candidates sl el))
  (setq path (pid-select-best-scored-path candidates))
  path
)

(defun pid-tee-side-by-connection (from-id from-port scode to-id to-port ecode / ftype ttype)
  ;; 015 keeps TEE placement rules independent of routing.
  ;; S-M: TEE near machine side.
  ;; M-M: TEE near endpoint whose PORT_TYPE is OUT.
  ;; Unknown: midpoint.
  (cond
    ((and (pid-structure-code-p scode) (pid-machine-code-p ecode)) "TARGET")
    ((and (pid-machine-code-p scode) (pid-structure-code-p ecode)) "SOURCE")
    ((and (pid-machine-code-p scode) (pid-machine-code-p ecode))
      (setq ftype (pid-port-type from-id from-port))
      (setq ttype (pid-port-type to-id to-port))
      (cond
        ((= ftype "OUT") "SOURCE")
        ((= ttype "OUT") "TARGET")
        (T "TARGET")
      )
    )
    (T "MID")
  )
)

(defun pid-connect-endpoints-with-tee (line-id from-id from-port from-chain tee-id to-id to-port to-chain / a b scode ecode tee-side anchor dir teept postpt prept path start-info target-info)
  ;; 015 override:
  ;; TEE still follows type rules, but post-TEE routing is scored by shortest clean route.
  (prompt (strcat "\n[PID CONNECT] " line-id " with " tee-id " RULE_015"))

  (setq a (pid-endpoint-info-safe from-id from-port from-chain))
  (setq b (pid-endpoint-info-safe to-id to-port to-chain))

  (setq scode (nth 4 a))
  (setq ecode (nth 4 b))
  (setq tee-side (pid-tee-side-by-connection from-id from-port scode to-id to-port ecode))

  (cond
    ;; TEE near source side
    ((= tee-side "SOURCE")
      (setq anchor (car a))
      (setq dir (caddr a))
      (if (not dir) (setq dir (pid-angle-vec 0.0)))

      ;; TEE is 50mm from source-side pipe-start.
      ;; No bend before TEE.
      (setq teept  (pid-add-pt anchor (pid-scale-vec dir *PID-TEE-SOURCE-DIST*)))
      (setq postpt (pid-add-pt teept  (pid-scale-vec dir *PID-TEE-AFTER-LEAD*)))

      (pid-make-line-segment anchor teept "PID_PIPE" 1)
      (pid-ref-put tee-id teept)
      (pid-draw-ref-marker tee-id teept)
      (pid-make-line-segment teept postpt "PID_PIPE" 1)

      ;; After TEE straight section, shortest valid route.
      (setq start-info (list postpt postpt dir 0.0 "REF" tee-id))
      (setq path (pid-build-route-between-infos-no-draw start-info b))
      (pid-draw-path-segments path "PID_PIPE" 1)

      (pid-label (pid-add-pt anchor (list 15.0 15.0 0.0)) line-id)
    )

    ;; TEE near target side
    ((= tee-side "TARGET")
      (setq anchor (car b))
      (setq dir (caddr b))
      (if (not dir) (setq dir (pid-angle-vec 180.0)))

      ;; TEE is 50mm from target-side pipe-start.
      ;; No bend between target pipe-start and TEE.
      (setq teept (pid-add-pt anchor (pid-scale-vec dir *PID-TEE-SOURCE-DIST*)))
      (setq prept (pid-add-pt teept (pid-scale-vec dir *PID-TEE-AFTER-LEAD*)))

      (pid-make-line-segment anchor teept "PID_PIPE" 1)
      (pid-ref-put tee-id teept)
      (pid-draw-ref-marker tee-id teept)
      (pid-make-line-segment teept prept "PID_PIPE" 1)

      ;; Route source endpoint to pre-TEE point by shortest valid route.
      (setq target-info (list prept prept dir 0.0 "REF" tee-id))
      (setq path (pid-build-route-between-infos-no-draw a target-info))
      (pid-draw-path-segments path "PID_PIPE" 1)

      (pid-label (pid-add-pt (car a) (list 15.0 15.0 0.0)) line-id)
    )

    ;; Mid fallback
    (T
      (setq path (pid-build-route-between-infos-no-draw a b))
      (if path
        (progn
          (pid-create-tee-near-side-on-path tee-id path "MID" *PID-TEE-SOURCE-DIST*)
          (pid-draw-path-segments path "PID_PIPE" 1)
          (pid-label (pid-add-pt (car path) (list 15.0 15.0 0.0)) line-id)
        )
      )
    )
  )
)



;;; ============================================================
;;; Rule override 016
;;; Fixes after test_015:
;;; 1. Inside machines such as FDC1/FDC2/TDIF1/TDIF2 are treated as
;;;    structure-side endpoints for bend-priority because they are installed
;;;    inside their parent structure.
;;; 2. S_/inside-structure ↔ M_ route keeps structure-side bend priority
;;;    above shortest-path scoring.
;;; 3. TEE-side route generation draws mandatory local lead/chain straight
;;;    segments on both sides so FIT_FLNG is not left disconnected.
;;; 4. Bbox/obstacle avoidance is kept as a hard candidate rejection; wider
;;;    global detour candidates are added before fallback.
;;; ============================================================

(defun pid-endpoint-structure-side-p (id code /)
  ;; True when endpoint itself is S_ or a machine placed inside a structure.
  ;; This fixes FDC1/FDC2 -> VAV routing: they are M_ blocks but belong to COND.
  (or (pid-structure-code-p code)
      (pid-inside-parent-id id))
)

(defun pid-endpoint-machine-side-p (id code /)
  ;; External M_ machine only. Inside machines are treated as structure-side
  ;; for bend-priority purposes.
  (and (pid-machine-code-p code)
       (not (pid-inside-parent-id id)))
)

(defun pid-route-pref-by-infos (a b / aid bid acode bcode astruct bstruct)
  ;; Returns SOURCE_NEAR / TARGET_NEAR / nil.
  ;; This is the bend-priority rule, independent from TEE placement.
  (setq aid (nth 5 a))
  (setq bid (nth 5 b))
  (setq acode (nth 4 a))
  (setq bcode (nth 4 b))
  (setq astruct (pid-endpoint-structure-side-p aid acode))
  (setq bstruct (pid-endpoint-structure-side-p bid bcode))

  (cond
    ((and astruct (not bstruct)) "SOURCE_NEAR")
    ((and bstruct (not astruct)) "TARGET_NEAR")
    (*PID-ROUTE-PREF* *PID-ROUTE-PREF*)
    (T nil)
  )
)

(defun pid-global-detour-candidates (sl el / boxes b mn mx minx maxx miny maxy sx1 sx2 sy1 sy2 res)
  ;; Wider detours around all current obstacles.
  ;; Used before invalid fallback so pipes do not penetrate structures/machines.
  (setq boxes (pid-obstacle-boxes))
  (setq res nil)

  (if boxes
    (progn
      (setq minx nil maxx nil miny nil maxy nil)
      (foreach b boxes
        (setq mn (cadr b))
        (setq mx (caddr b))
        (setq minx (if minx (min minx (car mn)) (car mn)))
        (setq maxx (if maxx (max maxx (car mx)) (car mx)))
        (setq miny (if miny (min miny (cadr mn)) (cadr mn)))
        (setq maxy (if maxy (max maxy (cadr mx)) (cadr mx)))
      )

      (setq sx1 (- minx 80.0))
      (setq sx2 (+ maxx 80.0))
      (setq sy1 (- miny 80.0))
      (setq sy2 (+ maxy 80.0))

      ;; Route via safe vertical riser at global left/right.
      (setq res
        (append res
          (list
            (pid-remove-dup-pts (list sl (pid-pt sx1 (cadr sl)) (pid-pt sx1 (cadr el)) el))
            (pid-remove-dup-pts (list sl (pid-pt sx2 (cadr sl)) (pid-pt sx2 (cadr el)) el))
            (pid-remove-dup-pts (list sl (pid-pt (car sl) sy1) (pid-pt (car el) sy1) el))
            (pid-remove-dup-pts (list sl (pid-pt (car sl) sy2) (pid-pt (car el) sy2) el))
          )
        )
      )
    )
  )
  res
)

(defun pid-build-general-candidates-016 (sl el pref / candidates off c)
  (setq candidates nil)

  (cond
    ((= pref "SOURCE_NEAR")
      (setq candidates (pid-append-candidate-unique candidates (pid-candidate-source-near sl el)))
      (setq candidates (pid-append-candidate-unique candidates (pid-candidate-target-near sl el)))
    )
    ((= pref "TARGET_NEAR")
      (setq candidates (pid-append-candidate-unique candidates (pid-candidate-target-near sl el)))
      (setq candidates (pid-append-candidate-unique candidates (pid-candidate-source-near sl el)))
    )
    (T
      (setq candidates (pid-append-candidate-unique candidates (pid-candidate-target-near sl el)))
      (setq candidates (pid-append-candidate-unique candidates (pid-candidate-source-near sl el)))
    )
  )

  ;; Normal offset doglegs.
  (foreach off *PID-PIPE-OVERLAP-OFFSETS*
    (setq candidates (pid-append-candidate-unique candidates (pid-candidate-offset-x sl el off)))
    (setq candidates (pid-append-candidate-unique candidates (pid-candidate-offset-y sl el off)))
  )

  ;; Existing bbox local detours.
  (foreach c (pid-obstacle-detour-candidates sl el)
    (setq candidates (pid-append-candidate-unique candidates c))
  )

  ;; Wider global detours to prevent invalid fallback through obstacles.
  (foreach c (pid-global-detour-candidates sl el)
    (setq candidates (pid-append-candidate-unique candidates c))
  )

  candidates
)

(defun pid-select-best-scored-path (candidates / c best best-score score fallback fallback-score)
  ;; Hard constraints first: bbox/overlap invalid candidates are rejected.
  ;; If all fail, use the shortest fallback but explicitly warn.
  (setq best nil)
  (setq best-score nil)
  (setq fallback nil)
  (setq fallback-score nil)

  (foreach c candidates
    (setq score (pid-path-score c))
    (if (or (not fallback-score) (< score fallback-score))
      (progn
        (setq fallback c)
        (setq fallback-score score)
      )
    )

    (if (not (pid-path-invalid-p c))
      (if (or (not best-score) (< score best-score))
        (progn
          (setq best c)
          (setq best-score score)
        )
      )
    )
  )

  (if best
    best
    (progn
      (prompt "\n[PID WARN] All route candidates failed hard checks even after detours. Use shortest fallback.")
      fallback
    )
  )
)

(defun pid-build-route-between-infos-no-draw (a b / sl el pref candidates)
  ;; 017 override:
  ;; Structure-side bend priority is applied before shortest scoring.
  ;; Used where local lead segments are already drawn by caller.
  (setq sl (cadr a))
  (setq el (cadr b))
  (setq *PID-ROUTE-EXCLUDES* (pid-route-exclude-ids (nth 5 a) (nth 5 b)))
  (setq pref (pid-route-pref-by-infos a b))
  (setq candidates (pid-build-general-candidates-016 sl el pref))
  (pid-select-best-scored-path candidates)
)

(defun pid-build-ortho-route (start-info end-info / sp sl ep el pref candidates path)
  ;; 017 override:
  ;; Draw local mandatory lead/chain straight sections first.
  ;; Then choose center route with structure-side bend priority and obstacle checks.
  (setq sp (car start-info))
  (setq sl (cadr start-info))
  (setq ep (car end-info))
  (setq el (cadr end-info))

  (setq *PID-ROUTE-EXCLUDES* (pid-route-exclude-ids (nth 5 start-info) (nth 5 end-info)))

  ;; Mandatory local straight sections.
  ;; These ensure chain outer ports and equipment ports are not disconnected.
  (pid-make-line-segment sp sl "PID_PIPE" 1)
  (pid-make-line-segment el ep "PID_PIPE" 1)

  (setq pref (pid-route-pref-by-infos start-info end-info))
  (setq candidates (pid-build-general-candidates-016 sl el pref))
  (setq path (pid-select-best-scored-path candidates))
  path
)

(defun pid-connect-endpoints-with-tee (line-id from-id from-port from-chain tee-id to-id to-port to-chain / a b scode ecode tee-side anchor dir teept postpt prept path start-info target-info)
  ;; 017 override:
  ;; Keeps 013/015 TEE placement rules, but fixes disconnected local lead
  ;; and applies corrected routing priority.
  (prompt (strcat "\n[PID CONNECT] " line-id " with " tee-id " RULE_017"))

  (setq a (pid-endpoint-info-safe from-id from-port from-chain))
  (setq b (pid-endpoint-info-safe to-id to-port to-chain))

  (setq scode (nth 4 a))
  (setq ecode (nth 4 b))
  (setq tee-side (pid-tee-side-by-connection from-id from-port scode to-id to-port ecode))

  (cond
    ;; ----------------------------------------------------------
    ;; TEE near SOURCE side.
    ;; ----------------------------------------------------------
    ((= tee-side "SOURCE")
      (setq anchor (car a))
      (setq dir (caddr a))
      (if (not dir) (setq dir (pid-angle-vec 0.0)))

      ;; No bend before TEE.
      (setq teept  (pid-add-pt anchor (pid-scale-vec dir *PID-TEE-SOURCE-DIST*)))
      (setq postpt (pid-add-pt teept  (pid-scale-vec dir *PID-TEE-AFTER-LEAD*)))

      (pid-make-line-segment anchor teept "PID_PIPE" 1)
      (pid-ref-put tee-id teept)
      (pid-draw-ref-marker tee-id teept)
      (pid-make-line-segment teept postpt "PID_PIPE" 1)

      ;; Target local straight section must still be drawn.
      (pid-make-line-segment (cadr b) (car b) "PID_PIPE" 1)

      ;; Route post-TEE to target lead.
      (setq start-info (list postpt postpt dir 0.0 "REF" tee-id))
      (setq path (pid-build-route-between-infos-no-draw start-info b))
      (if path (pid-draw-path-segments path "PID_PIPE" 1))

      (pid-label (pid-add-pt anchor (list 15.0 15.0 0.0)) line-id)
    )

    ;; ----------------------------------------------------------
    ;; TEE near TARGET side.
    ;; ----------------------------------------------------------
    ((= tee-side "TARGET")
      (setq anchor (car b))
      (setq dir (caddr b))
      (if (not dir) (setq dir (pid-angle-vec 180.0)))

      ;; No bend between target pipe-start and TEE.
      (setq teept (pid-add-pt anchor (pid-scale-vec dir *PID-TEE-SOURCE-DIST*)))
      (setq prept (pid-add-pt teept (pid-scale-vec dir *PID-TEE-AFTER-LEAD*)))

      (pid-make-line-segment anchor teept "PID_PIPE" 1)
      (pid-ref-put tee-id teept)
      (pid-draw-ref-marker tee-id teept)
      (pid-make-line-segment teept prept "PID_PIPE" 1)

      ;; Source local straight section must still be drawn.
      (pid-make-line-segment (car a) (cadr a) "PID_PIPE" 1)

      ;; Route source lead to pre-TEE.
      (setq target-info (list prept prept dir 0.0 "REF" tee-id))
      (setq path (pid-build-route-between-infos-no-draw a target-info))
      (if path (pid-draw-path-segments path "PID_PIPE" 1))

      (pid-label (pid-add-pt (car a) (list 15.0 15.0 0.0)) line-id)
    )

    ;; ----------------------------------------------------------
    ;; MID fallback.
    ;; ----------------------------------------------------------
    (T
      (setq path (pid-build-ortho-route a b))
      (if path
        (progn
          (pid-create-tee-near-side-on-path tee-id path "MID" *PID-TEE-SOURCE-DIST*)
          (pid-draw-path-segments path "PID_PIPE" 1)
          (pid-label (pid-add-pt (car path) (list 15.0 15.0 0.0)) line-id)
        )
      )
    )
  )
)




;;; ============================================================
;;; Rule override 018
;;; Fix line_21/22 BRX->PMP_B TEE placement.
;;; - BRX port angle 270 is treated as local lead only.
;;; - TEE13/TEE14 are placed on the selected orthogonal route, not by
;;;   extending 50+50mm in the BRX port direction.
;;; - This prevents the branch from dropping below BRX before turning
;;;   toward PMP4/PMP6.
;;; ============================================================

(defun pid-connect-endpoints-with-tee-on-selected-route
  (line-id from-id from-port from-chain tee-id to-id to-port to-chain tee-side
   / a b path teept)
  (prompt (strcat "\n[PID CONNECT] " line-id " with " tee-id " RULE_018_SELECTED_ROUTE"))

  ;; Create endpoint chains first. Endpoint PORT_ANGLE is used only to make
  ;; the local lead/chain straight section.
  (setq a (pid-endpoint-info-safe from-id from-port from-chain))
  (setq b (pid-endpoint-info-safe to-id to-port to-chain))

  ;; Draw mandatory local straight sections only.
  ;; These are short local leads and must not decide the global route.
  (pid-make-line-segment (car a) (cadr a) "PID_PIPE" 1)
  (pid-make-line-segment (cadr b) (car b) "PID_PIPE" 1)

  ;; Build the global orthogonal route between lead points by candidate scoring.
  ;; The TEE is then placed on that selected path.
  (setq path (pid-build-route-between-infos-no-draw a b))
  (if path
    (progn
      (setq teept (pid-create-tee-near-side-on-path tee-id path tee-side *PID-TEE-SOURCE-DIST*))
      (pid-draw-path-segments path "PID_PIPE" 1)
      (pid-label (pid-add-pt (car a) (list 15.0 15.0 0.0)) line-id)
      teept
    )
    (progn
      (prompt (strcat "\n[PID WARN] " line-id " route failed. TEE not created."))
      nil
    )
  )
)



;;; ============================================================
;;; Rule override 019
;;; M_BRX routing/type definition override
;;; - M_BRX01 is treated as STRUCTURE for routing, TEE-side, and bend rules.
;;; - Block name remains M_BRX01 and layout position remains SLUDGE lane.
;;; - This fixes line_21/22: BRX port 270deg is only local lead,
;;;   while S-M rules place TEE near PMP side and bend near BRX side.
;;; ============================================================

(defun pid-brx-code-p (code / u)
  (setq u (if code (strcase code) ""))
  (or (= u "M_BRX01") (= u "M_BRX") (= "M_BRX" (substr u 1 (min 5 (strlen u)))))
)

(defun pid-structure-code-p (code / u)
  ;; Treat normal S_ blocks and M_BRX* blocks as structure-like endpoints.
  (setq u (if code (strcase code) ""))
  (or
    (and (>= (strlen u) 2) (= (substr u 1 2) "S_"))
    (pid-brx-code-p u)
  )
)

(defun pid-machine-code-p (code / u)
  ;; M_BRX* is no longer treated as a machine for routing/TEE rules.
  (setq u (if code (strcase code) ""))
  (and
    (>= (strlen u) 2)
    (= (substr u 1 2) "M_")
    (not (pid-brx-code-p u))
  )
)

(defun pid-instance-structure-like-p (id / code)
  (setq code (pid-map-code-safe id))
  (pid-structure-code-p code)
)

(defun pid-create-test-connections (/ tee3-trunk-path tee3-info tee3-target tee6-trunk-path tee6-info tee6-target tee9-trunk-path tee9-info tee9-target tee12-trunk-path tee12-info tee12-target tee15-trunk-path tee15-info tee15-target tee18-trunk-path tee18-info tee18-target)
  (pid-layer "PID_PIPE" 1)
  (pid-layer "PID_CHAIN" 5)
  (pid-layer "PID_REF" 6)
  (setq *PID-PIPE-SEGMENTS* nil)
  (setq *PID-REF-MAP* nil)


  ;; ============================================================
  ;; RAW_WATER
  ;; ============================================================
  (pid-set-current-media "RAW_WATER")

  ;; line_1
  ;; RAW_WATER
  ;; FDC1 port1 -> VAV1 port1
  (pid-connect-endpoints-pref
    "SOURCE_NEAR"
    "line_1"
    "FDC1" 1 (list "P_VAV01" "FIT_FLNG")
    "VAV1" 1 nil
  )

  ;; line_2
  ;; RAW_WATER
  ;; FDC2 port1 -> VAV2 port1
  (pid-connect-endpoints-pref
    "SOURCE_NEAR"
    "line_2"
    "FDC2" 1 (list "P_VAV01" "FIT_FLNG")
    "VAV2" 1 nil
  )

  ;; line_3
  ;; RAW_WATER
  ;; VAV1 port2 -> COND3 port1
  (pid-connect-endpoints
    "line_3"
    "VAV1" 2 nil
    "COND3" 1 nil
  )

  ;; line_4
  ;; RAW_WATER
  ;; VAV2 port2 -> COND3 port3
  (pid-connect-endpoints
    "line_4"
    "VAV2" 2 nil
    "COND3" 3 nil
  )

  ;; ============================================================
  ;; AIR
  ;; ============================================================
  (pid-set-current-media "AIR")

  ;; line_5
  ;; AIR
  ;; AEB1 port1 [TEE:TEE1] TDIF1 port1
  (pid-connect-endpoints-with-tee
    "line_5"
    "AEB1" 1 (list "P_VAV07" "P_VAV01" "FIT_FLNG")
    "TEE1"
    "TDIF1" 1 nil
  )

  ;; line_6
  ;; AIR
  ;; AEB3 port1 [TEE:TEE2] TDIF2 port1
  (pid-connect-endpoints-with-tee
    "line_6"
    "AEB3" 1 (list "P_VAV07" "P_VAV01" "FIT_FLNG")
    "TEE2"
    "TDIF2" 1 nil
  )

  ;; line_7
  ;; AIR
  ;; TEE1 -> TEE3 -> TEE2
  ;; Pre-compute sibling endpoint for TEE alignment
  (setq tee3-info
    (pid-endpoint-info-safe "AEB2" 1
      (list "P_VAV07" "P_VAV01" "FIT_FLNG")
    )
  )
  (setq tee3-target (cadr tee3-info))

  ;; trunk calculation only, no trunk pipe output
  (setq tee3-trunk-path (pid-connect-ref-to-ref-virtual-path "TEE1" "TEE2"))
  (pid-create-tee-on-path "TEE3" tee3-trunk-path tee3-target)

  ;; line_7A
  ;; AIR
  ;; TEE1 -> chain -> TEE3
  (pid-connect-ref-to-ref-with-centered-chain
    "line_7A"
    "TEE1"
    "TEE3"
    (list "FIT_FLNG" "P_VAV01" "FIT_FLNG")
  )

  ;; line_7B
  ;; AIR
  ;; TEE2 -> chain -> TEE3
  (pid-connect-ref-to-ref-with-centered-chain
    "line_7B"
    "TEE2"
    "TEE3"
    (list "FIT_FLNG" "P_VAV01" "FIT_FLNG")
  )

  ;; line_8
  ;; AIR
  ;; TEE3 -> AEB2 port1 (pre-computed)
  (pid-connect-ref-to-endinfo
    "line_8"
    "TEE3"
    tee3-info
  )

  ;; ============================================================
  ;; SLUDGE
  ;; ============================================================
  (pid-set-current-media "SLUDGE")

  ;; line_9
  ;; SLUDGE
  ;; COND1 port2 [TEE:TEE4] PMP1 port1
  (pid-connect-endpoints-with-tee
    "line_9"
    "COND1" 2 (list "P_VAV01" "FIT_FLNG")
    "TEE4"
    "PMP1" 1 (list "P_VAV07" "P_VAV01" "FIT_FLNG")
  )

  ;; line_10
  ;; SLUDGE
  ;; COND2 port2 [TEE:TEE5] PMP3 port1
  (pid-connect-endpoints-with-tee
    "line_10"
    "COND2" 2 (list "P_VAV01" "FIT_FLNG")
    "TEE5"
    "PMP3" 1 (list "P_VAV07" "P_VAV01" "FIT_FLNG")
  )

  ;; line_11
  ;; SLUDGE
  ;; TEE4 -> TEE6 -> TEE5
  ;; Pre-compute sibling endpoint for TEE alignment
  (setq tee6-info
    (pid-endpoint-info-safe "PMP2" 1
      (list "P_VAV07" "FIT_FLNG")
    )
  )
  (setq tee6-target (cadr tee6-info))

  ;; trunk calculation only, no trunk pipe output
  (setq tee6-trunk-path (pid-connect-ref-to-ref-virtual-path "TEE4" "TEE5"))
  (pid-create-tee-on-path "TEE6" tee6-trunk-path tee6-target)

  ;; line_11A
  ;; SLUDGE
  ;; TEE4 -> chain -> TEE6
  (pid-connect-ref-to-ref-with-centered-chain
    "line_11A"
    "TEE4"
    "TEE6"
    (list "FIT_FLNG" "P_VAV01" "FIT_FLNG")
  )

  ;; line_11B
  ;; SLUDGE
  ;; TEE5 -> chain -> TEE6
  (pid-connect-ref-to-ref-with-centered-chain
    "line_11B"
    "TEE5"
    "TEE6"
    (list "FIT_FLNG" "P_VAV01" "FIT_FLNG")
  )

  ;; line_12
  ;; SLUDGE
  ;; TEE6 -> PMP2 port1 (pre-computed)
  (pid-connect-ref-to-endinfo
    "line_12"
    "TEE6"
    tee6-info
  )

  ;; line_13
  ;; SLUDGE
  ;; PMP1 port2 [TEE:TEE7] BRX1 port1
  (pid-connect-endpoints-with-tee
    "line_13"
    "PMP1" 2 (list "P_VAV07" "P_VAV01" "FIT_FLNG")
    "TEE7"
    "BRX1" 1 nil
  )

  ;; line_14
  ;; SLUDGE
  ;; PMP3 port2 [TEE:TEE8] BRX2 port1
  (pid-connect-endpoints-with-tee
    "line_14"
    "PMP3" 2 (list "P_VAV07" "P_VAV01" "FIT_FLNG")
    "TEE8"
    "BRX2" 1 nil
  )

  ;; line_15
  ;; SLUDGE
  ;; TEE7 -> TEE9 -> TEE8
  ;; Pre-compute sibling endpoint for TEE alignment
  (setq tee9-info
    (pid-endpoint-info-safe "PMP2" 2
      (list "P_VAV07" "FIT_FLNG")
    )
  )
  (setq tee9-target (cadr tee9-info))

  ;; trunk calculation only, no trunk pipe output
  (setq tee9-trunk-path (pid-connect-ref-to-ref-virtual-path "TEE7" "TEE8"))
  (pid-create-tee-on-path "TEE9" tee9-trunk-path tee9-target)

  ;; line_15A
  ;; SLUDGE
  ;; TEE7 -> chain -> TEE9
  (pid-connect-ref-to-ref-with-centered-chain
    "line_15A"
    "TEE7"
    "TEE9"
    (list "FIT_FLNG" "P_VAV01" "FIT_FLNG")
  )

  ;; line_15B
  ;; SLUDGE
  ;; TEE8 -> chain -> TEE9
  (pid-connect-ref-to-ref-with-centered-chain
    "line_15B"
    "TEE8"
    "TEE9"
    (list "FIT_FLNG" "P_VAV01" "FIT_FLNG")
  )

  ;; line_16
  ;; SLUDGE
  ;; PMP2 port2 (pre-computed) -> TEE9
  (pid-connect-endinfo-to-ref
    "line_16"
    tee9-info
    "TEE9"
  )

  ;; ============================================================
  ;; AIR
  ;; ============================================================
  (pid-set-current-media "AIR")

  ;; line_17
  ;; AIR
  ;; BRX1 port3 [TEE:TEE10] PKA1 port1
  (pid-connect-endpoints-with-tee
    "line_17"
    "BRX1" 3 nil
    "TEE10"
    "PKA1" 1 (list "P_VAV07" "P_VAV01" "FIT_FLNG")
  )

  ;; line_18
  ;; AIR
  ;; BRX2 port3 [TEE:TEE11] PKA3 port1
  (pid-connect-endpoints-with-tee
    "line_18"
    "BRX2" 3 nil
    "TEE11"
    "PKA3" 1 (list "P_VAV07" "P_VAV01" "FIT_FLNG")
  )

  ;; line_19
  ;; AIR
  ;; TEE11 -> TEE12 -> TEE10
  ;; Pre-compute sibling endpoint for TEE alignment
  (setq tee12-info
    (pid-endpoint-info-safe "PKA2" 1
      (list "P_VAV07" "FIT_FLNG")
    )
  )
  (setq tee12-target (cadr tee12-info))

  ;; trunk calculation only, no trunk pipe output
  (setq tee12-trunk-path (pid-connect-ref-to-ref-virtual-path "TEE11" "TEE10"))
  (pid-create-tee-on-path "TEE12" tee12-trunk-path tee12-target)

  ;; line_19A
  ;; AIR
  ;; TEE12 -> chain -> TEE10
  (pid-connect-ref-to-ref-with-centered-chain
    "line_19A"
    "TEE12"
    "TEE10"
    (list "FIT_FLNG" "P_VAV01" "FIT_FLNG")
  )

  ;; line_19B
  ;; AIR
  ;; TEE12 -> chain -> TEE11
  (pid-connect-ref-to-ref-with-centered-chain
    "line_19B"
    "TEE12"
    "TEE11"
    (list "FIT_FLNG" "P_VAV01" "FIT_FLNG")
  )

  ;; line_20
  ;; AIR
  ;; TEE12 -> PKA2 port1 (pre-computed)
  (pid-connect-ref-to-endinfo
    "line_20"
    "TEE12"
    tee12-info
  )

  ;; ============================================================
  ;; SLUDGE
  ;; ============================================================
  (pid-set-current-media "SLUDGE")

  ;; line_21
  ;; SLUDGE
  ;; PMP4 port1 [TEE:TEE13] BRX1 port2
  (pid-connect-endpoints-with-tee
    "line_21"
    "PMP4" 1 (list "P_VAV07" "P_VAV01" "FIT_FLNG")
    "TEE13"
    "BRX1" 2 nil
  )

  ;; line_22
  ;; SLUDGE
  ;; PMP6 port1 [TEE:TEE14] BRX2 port2
  (pid-connect-endpoints-with-tee
    "line_22"
    "PMP6" 1 (list "P_VAV07" "P_VAV01" "FIT_FLNG")
    "TEE14"
    "BRX2" 2 nil
  )

  ;; line_23
  ;; SLUDGE
  ;; TEE14 -> TEE15 -> TEE13
  ;; Pre-compute sibling endpoint for TEE alignment
  (setq tee15-info
    (pid-endpoint-info-safe "PMP5" 1
      (list "P_VAV07" "FIT_FLNG")
    )
  )
  (setq tee15-target (cadr tee15-info))

  ;; trunk calculation only, no trunk pipe output
  (setq tee15-trunk-path (pid-connect-ref-to-ref-virtual-path "TEE14" "TEE13"))
  (pid-create-tee-on-path "TEE15" tee15-trunk-path tee15-target)

  ;; line_23A
  ;; SLUDGE
  ;; TEE15 -> chain -> TEE13
  (pid-connect-ref-to-ref-with-centered-chain
    "line_23A"
    "TEE15"
    "TEE13"
    (list "FIT_FLNG" "P_VAV01" "FIT_FLNG")
  )

  ;; line_23B
  ;; SLUDGE
  ;; TEE15 -> chain -> TEE14
  (pid-connect-ref-to-ref-with-centered-chain
    "line_23B"
    "TEE15"
    "TEE14"
    (list "FIT_FLNG" "P_VAV01" "FIT_FLNG")
  )

  ;; line_24
  ;; SLUDGE
  ;; PMP5 port1 (pre-computed) -> TEE15
  (pid-connect-endinfo-to-ref
    "line_24"
    tee15-info
    "TEE15"
  )

  ;; line_25
  ;; SLUDGE
  ;; COND1 port3 [TEE:TEE16] PMP4 port2
  (pid-connect-endpoints-with-tee
    "line_25"
    "COND1" 3 nil
    "TEE16"
    "PMP4" 2 (list "P_VAV07" "P_VAV01" "FIT_FLNG")
  )

  ;; line_26
  ;; SLUDGE
  ;; COND2 port3 [TEE:TEE17] PMP6 port2
  (pid-connect-endpoints-with-tee
    "line_26"
    "COND2" 3 nil
    "TEE17"
    "PMP6" 2 (list "P_VAV07" "P_VAV01" "FIT_FLNG")
  )

  ;; line_27
  ;; SLUDGE
  ;; TEE17 -> TEE18 -> TEE16
  ;; Pre-compute sibling endpoint for TEE alignment
  (setq tee18-info
    (pid-endpoint-info-safe "PMP5" 2
      (list "P_VAV07" "FIT_FLNG")
    )
  )
  (setq tee18-target (cadr tee18-info))

  ;; trunk calculation only, no trunk pipe output
  (setq tee18-trunk-path (pid-connect-ref-to-ref-virtual-path "TEE17" "TEE16"))
  (pid-create-tee-on-path "TEE18" tee18-trunk-path tee18-target)

  ;; line_27A
  ;; SLUDGE
  ;; TEE18 -> chain -> TEE16
  (pid-connect-ref-to-ref-with-centered-chain
    "line_27A"
    "TEE18"
    "TEE16"
    (list "FIT_FLNG" "P_VAV01" "FIT_FLNG")
  )

  ;; line_27B
  ;; SLUDGE
  ;; TEE18 -> chain -> TEE17
  (pid-connect-ref-to-ref-with-centered-chain
    "line_27B"
    "TEE18"
    "TEE17"
    (list "FIT_FLNG" "P_VAV01" "FIT_FLNG")
  )

  ;; line_28
  ;; SLUDGE
  ;; TEE18 -> PMP5 port2 (pre-computed)
  (pid-connect-ref-to-endinfo
    "line_28"
    "TEE18"
    tee18-info
  )

)

;;; -----------------------------
;;; Main command
;;; -----------------------------


;;; ============================================================
;;; Pipe crossing jump mark override - added in 021
;;; Rule:
;;; - If a newly drawn pipe segment crosses an existing pipe segment at
;;;   a perpendicular point, and the point is not an endpoint/TEE/ref
;;;   connection point, draw a semicircle jump mark on the new segment.
;;; - Collinear overlap is still prohibited by the route selector.
;;; - Simple point crossing is allowed and visualized as "passing over".
;;; ============================================================
(setq *PID-JUMP-RADIUS* 6.0)
(setq *PID-JUMP-END-TOL* 0.75)

(defun pid-pt-equal-p (a b tol /)
  (and a b
       (<= (abs (- (car a) (car b))) tol)
       (<= (abs (- (cadr a) (cadr b))) tol))
)

(defun pid-between-open-p (v a b tol / mn mx)
  ;; Strictly inside segment range, not at either endpoint.
  (setq mn (min a b))
  (setq mx (max a b))
  (and (> v (+ mn tol)) (< v (- mx tol)))
)

(defun pid-perp-cross-point (a b c d / x y)
  ;; Returns intersection point for horizontal/vertical perpendicular crossing.
  ;; Returns nil if not a strict interior crossing.
  (cond
    ((and (pid-seg-horizontal-p a b) (pid-seg-vertical-p c d))
      (setq x (car c))
      (setq y (cadr a))
      (if (and (pid-between-open-p x (car a) (car b) *PID-JUMP-END-TOL*)
               (pid-between-open-p y (cadr c) (cadr d) *PID-JUMP-END-TOL*))
        (pid-pt x y)
        nil
      )
    )
    ((and (pid-seg-vertical-p a b) (pid-seg-horizontal-p c d))
      (setq x (car a))
      (setq y (cadr c))
      (if (and (pid-between-open-p y (cadr a) (cadr b) *PID-JUMP-END-TOL*)
               (pid-between-open-p x (car c) (car d) *PID-JUMP-END-TOL*))
        (pid-pt x y)
        nil
      )
    )
    (T nil)
  )
)

(defun pid-segment-param (p1 p2 p / len)
  ;; Sort value along segment.
  (if (pid-seg-horizontal-p p1 p2)
    (if (>= (car p2) (car p1)) (car p) (- (car p)))
    (if (>= (cadr p2) (cadr p1)) (cadr p) (- (cadr p)))
  )
)

(defun pid-insert-crossing-sorted (pt lst p1 p2 / res inserted e)
  (setq res nil)
  (setq inserted nil)
  (foreach e lst
    (if (and (not inserted)
             (< (pid-segment-param p1 p2 pt) (pid-segment-param p1 p2 e)))
      (progn
        (setq res (append res (list pt)))
        (setq inserted T)
      )
    )
    (setq res (append res (list e)))
  )
  (if (not inserted)
    (setq res (append res (list pt)))
  )
  res
)

(defun pid-find-jump-crossings (p1 p2 / hits e cp duplicate)
  ;; Detect where the new segment crosses already drawn pipe segments.
  (setq hits nil)
  (foreach e *PID-PIPE-SEGMENTS*
    (setq cp (pid-perp-cross-point p1 p2 (car e) (cadr e)))
    (if cp
      (progn
        (setq duplicate nil)
        (foreach h hits
          (if (pid-pt-equal-p h cp 0.5) (setq duplicate T))
        )
        (if (not duplicate)
          (setq hits (pid-insert-crossing-sorted cp hits p1 p2))
        )
      )
    )
  )
  hits
)

(defun pid-draw-raw-line-segment (p1 p2 actual-layer actual-color register-p /)
  (if (and p1 p2 (> (distance p1 p2) 0.0001))
    (progn
      (pid-layer actual-layer actual-color)
      (entmakex
        (list
          (cons 0 "LINE")
          (cons 8 actual-layer)
          (cons 62 actual-color)
          (cons 10 p1)
          (cons 11 p2)
        )
      )
      (if register-p
        (setq *PID-PIPE-SEGMENTS* (append *PID-PIPE-SEGMENTS* (list (list p1 p2))))
      )
    )
  )
)

(defun pid-draw-jump-arc (center horizontal-p actual-layer actual-color / r sa ea)
  ;; Horizontal segment: upper semicircle. Vertical segment: right semicircle.
  (setq r *PID-JUMP-RADIUS*)
  (if horizontal-p
    (progn
      (setq sa (pid-deg-rad 0.0))
      (setq ea (pid-deg-rad 180.0))
    )
    (progn
      (setq sa (pid-deg-rad 270.0))
      (setq ea (pid-deg-rad 90.0))
    )
  )
  (pid-layer actual-layer actual-color)
  (entmakex
    (list
      (cons 0 "ARC")
      (cons 8 actual-layer)
      (cons 62 actual-color)
      (cons 10 center)
      (cons 40 r)
      (cons 50 sa)
      (cons 51 ea)
    )
  )
)

(defun pid-jump-segment-start (p1 p2 cp / r)
  (setq r *PID-JUMP-RADIUS*)
  (if (pid-seg-horizontal-p p1 p2)
    (if (>= (car p2) (car p1))
      (pid-pt (- (car cp) r) (cadr cp))
      (pid-pt (+ (car cp) r) (cadr cp))
    )
    (if (>= (cadr p2) (cadr p1))
      (pid-pt (car cp) (- (cadr cp) r))
      (pid-pt (car cp) (+ (cadr cp) r))
    )
  )
)

(defun pid-jump-segment-end (p1 p2 cp / r)
  (setq r *PID-JUMP-RADIUS*)
  (if (pid-seg-horizontal-p p1 p2)
    (if (>= (car p2) (car p1))
      (pid-pt (+ (car cp) r) (cadr cp))
      (pid-pt (- (car cp) r) (cadr cp))
    )
    (if (>= (cadr p2) (cadr p1))
      (pid-pt (car cp) (+ (cadr cp) r))
      (pid-pt (car cp) (- (cadr cp) r))
    )
  )
)

(defun pid-crossings-too-close-p (hits p1 p2 / prev bad gap)
  ;; Avoid broken segments when crossings are too close to each other.
  (setq bad nil)
  (setq prev nil)
  (foreach h hits
    (if prev
      (progn
        (setq gap (distance prev h))
        (if (< gap (* 2.5 *PID-JUMP-RADIUS*))
          (setq bad T)
        )
      )
    )
    (setq prev h)
  )
  bad
)

(defun pid-draw-line-with-jumps (p1 p2 actual-layer actual-color / hits cur cp js je horizontal-p)
  (setq hits (pid-find-jump-crossings p1 p2))
  (if (or (not hits) (pid-crossings-too-close-p hits p1 p2))
    (pid-draw-raw-line-segment p1 p2 actual-layer actual-color T)
    (progn
      (setq cur p1)
      (setq horizontal-p (pid-seg-horizontal-p p1 p2))
      (foreach cp hits
        (setq js (pid-jump-segment-start p1 p2 cp))
        (setq je (pid-jump-segment-end p1 p2 cp))
        (pid-draw-raw-line-segment cur js actual-layer actual-color T)
        (pid-draw-jump-arc cp horizontal-p actual-layer actual-color)
        (setq cur je)
      )
      (pid-draw-raw-line-segment cur p2 actual-layer actual-color T)
    )
  )
)

(defun pid-make-line-segment (p1 p2 layer color / actual-layer actual-color)
  ;; 021 override:
  ;; Pipe segments use media-based layer/color and get a jump arc when the
  ;; newly drawn segment crosses an existing perpendicular pipe segment.
  (if (and p1 p2 (> (distance p1 p2) 0.0001))
    (progn
      (if (= (strcase layer) "PID_PIPE")
        (progn
          (setq actual-layer (pid-pipe-layer-by-media *PID-CURRENT-MEDIA*))
          (setq actual-color (pid-media-color *PID-CURRENT-MEDIA*))
          (pid-draw-line-with-jumps p1 p2 actual-layer actual-color)
        )
        (progn
          (setq actual-layer layer)
          (setq actual-color color)
          (pid-draw-raw-line-segment p1 p2 actual-layer actual-color nil)
        )
      )
    )
  )
)
(defun c:PID_LAYOUT_TEST (/ oldattdia oldattreq oldcmdecho oldosmode)
  (setq oldattdia (getvar "ATTDIA"))
  (setq oldattreq (getvar "ATTREQ"))
  (setq oldcmdecho (getvar "CMDECHO"))
  (setq oldosmode (getvar "OSMODE"))

  (setvar "CMDECHO" 0)
  (setvar "ATTDIA" 0)
  (setvar "ATTREQ" 0)
  (setvar "OSMODE" 0)

  (setq *PID-INSTANCE-MAP* nil)
  (setq *PID-SERIES-STATE* nil)

  (pid-layer "PID_PROCESS_AREA" 8)
  (pid-layer "PID_LANE" 8)
  (pid-layer "PID_LANE_RAW_WATER" 1)
  (pid-layer "PID_STRUCTURE" 2)
  (pid-layer "PID_INSIDE_MACHINE" 4)
  (pid-layer "PID_OUTSIDE_MACHINE" 3)
  (pid-layer "PID_INSERT_MARK" 1)
  (pid-layer "PID_LABEL" 7)
  (pid-layer "PID_PIPE" 1)
  (pid-layer "PID_CHAIN" 5)

  (pid-draw-layout-guide)

  ;; 1) Structures
  ;; PROC_001 structures
  (pid-place-structure "COND1" "S_COND01" 0)
  (pid-place-structure "COND2" "S_COND01" 1)
  ;; PROC_002 structures
  (pid-place-structure-at "COND3" "S_COND01" 1530.0 0.0)

  ;; 2) Inside machines
  ;; COND1
  (pid-place-inside-machine "TDIF1" "M_TDIF04" "COND1" "INSIDE1")
  (pid-place-inside-machine "FDC1" "M_FDC01" "COND1" "INSIDE2")
  ;; COND2
  (pid-place-inside-machine "TDIF2" "M_TDIF04" "COND2" "INSIDE1")
  (pid-place-inside-machine "FDC2" "M_FDC01" "COND2" "INSIDE2")

  ;; 3) Outside machines
  (pid-place-lane-machine-auto "AEB1" "M_AEB0101" "AIR" "AEB")
  (pid-place-lane-machine-auto "AEB2" "M_AEB0101" "AIR" "AEB")
  (pid-place-lane-machine-auto "AEB3" "M_AEB0101" "AIR" "AEB")
  (pid-place-lane-machine-auto "PKA1" "M_PKA0103" "AIR" "PKA")
  (pid-place-lane-machine-auto "PKA2" "M_PKA0103" "AIR" "PKA")
  (pid-place-lane-machine-auto "PKA3" "M_PKA0103" "AIR" "PKA")
  (pid-place-lane-machine-auto "VAV1" "M_VAV0201" "RAW_WATER" "VAV")
  (pid-place-lane-machine-auto "VAV2" "M_VAV0201" "RAW_WATER" "VAV")
  (pid-place-lane-machine-auto "PMP1" "M_PMP01" "SLUDGE" "PMP_A")
  (pid-place-lane-machine-auto "PMP2" "M_PMP01" "SLUDGE" "PMP_A")
  (pid-place-lane-machine-auto "PMP3" "M_PMP01" "SLUDGE" "PMP_A")
  (pid-place-lane-machine-auto "BRX1" "M_BRX01" "SLUDGE" "BRX")
  (pid-place-lane-machine-auto "BRX2" "M_BRX01" "SLUDGE" "BRX")
  (pid-place-lane-machine-auto "PMP4" "M_PMP01" "SLUDGE" "PMP_B")
  (pid-place-lane-machine-auto "PMP5" "M_PMP01" "SLUDGE" "PMP_B")
  (pid-place-lane-machine-auto "PMP6" "M_PMP01" "SLUDGE" "PMP_B")

  ;; 4) Rule-based connections
  (pid-create-test-connections)

  (setvar "ATTDIA" oldattdia)
  (setvar "ATTREQ" oldattreq)
  (setvar "OSMODE" oldosmode)
  (setvar "CMDECHO" oldcmdecho)

  (prompt "\n[PID] PID V2 generated layout completed. Command: PID_LAYOUT_TEST")
  (princ)
)

(prompt "\n[PID] Loaded: PID instance connection test 020. Run command: PID_LAYOUT_TEST")
(princ)

;;; ============================================================
;;; Jump mark override 022 - radius 3mm + vertical-cross priority
;;; - Jump radius changed from 6mm to 3mm.
;;; - For a simple perpendicular pipe crossing, the vertical segment receives
;;;   the jump arc, matching the standard symbol shown by the user.
;;; - If the vertical segment was drawn earlier, it is replaced by two split
;;;   line pieces and an arc when a later horizontal segment crosses it.
;;; - REF/TEE points are excluded from jump creation.
;;; ============================================================
(setq *PID-JUMP-RADIUS* 3.0)
(setq *PID-JUMP-END-TOL* 0.75)

(defun pid-jump-ref-point-p (pt / row hit)
  (setq hit nil)
  (foreach row *PID-REF-MAP*
    (if (pid-pt-equal-p pt (cadr row) 0.75)
      (setq hit T)
    )
  )
  hit
)

(defun pid-pipe-seg-ent (e /)
  (if (>= (length e) 3) (nth 2 e) nil)
)

(defun pid-pipe-seg-layer (e /)
  (if (>= (length e) 4) (nth 3 e) (pid-pipe-layer-by-media *PID-CURRENT-MEDIA*))
)

(defun pid-pipe-seg-color (e /)
  (if (>= (length e) 5) (nth 4 e) (pid-media-color *PID-CURRENT-MEDIA*))
)

(defun pid-remove-pipe-entry-by-ent (ent / res e)
  (setq res nil)
  (foreach e *PID-PIPE-SEGMENTS*
    (if (not (= (pid-pipe-seg-ent e) ent))
      (setq res (append res (list e)))
    )
  )
  (setq *PID-PIPE-SEGMENTS* res)
)

(defun pid-find-active-vertical-entry-at (cp / found e)
  (setq found nil)
  (foreach e *PID-PIPE-SEGMENTS*
    (if (and (not found)
             (pid-seg-vertical-p (car e) (cadr e))
             (pid-between-open-p (cadr cp) (cadr (car e)) (cadr (cadr e)) *PID-JUMP-END-TOL*)
             (<= (abs (- (car cp) (car (car e)))) 0.5))
      (setq found e)
    )
  )
  found
)

(defun pid-draw-raw-line-segment (p1 p2 actual-layer actual-color register-p / ent)
  ;; 022 override: store entity/layer/color so an already-drawn vertical pipe
  ;; can be split later if a horizontal pipe crosses it.
  (if (and p1 p2 (> (distance p1 p2) 0.0001))
    (progn
      (pid-layer actual-layer actual-color)
      (setq ent
        (entmakex
          (list
            (cons 0 "LINE")
            (cons 8 actual-layer)
            (cons 62 actual-color)
            (cons 10 p1)
            (cons 11 p2)
          )
        )
      )
      (if register-p
        (setq *PID-PIPE-SEGMENTS*
          (append *PID-PIPE-SEGMENTS* (list (list p1 p2 ent actual-layer actual-color)))
        )
      )
    )
  )
)

(defun pid-find-jump-crossings (p1 p2 / hits e cp duplicate)
  ;; 022 override: skip actual REF/TEE connection points.
  (setq hits nil)
  (foreach e *PID-PIPE-SEGMENTS*
    (setq cp (pid-perp-cross-point p1 p2 (car e) (cadr e)))
    (if (and cp (not (pid-jump-ref-point-p cp)))
      (progn
        (setq duplicate nil)
        (foreach h hits
          (if (pid-pt-equal-p h cp 0.5) (setq duplicate T))
        )
        (if (not duplicate)
          (setq hits (pid-insert-crossing-sorted cp hits p1 p2))
        )
      )
    )
  )
  hits
)

(defun pid-break-existing-vertical-with-jump (cp / e p1 p2 ent lyr col js je)
  ;; Split the existing vertical segment at cp and add the jump arc there.
  (if (not (pid-jump-ref-point-p cp))
    (progn
      (setq e (pid-find-active-vertical-entry-at cp))
      (if e
        (progn
          (setq p1 (car e))
          (setq p2 (cadr e))
          (setq ent (pid-pipe-seg-ent e))
          (setq lyr (pid-pipe-seg-layer e))
          (setq col (pid-pipe-seg-color e))

          (if ent
            (progn
              (entdel ent)
              (pid-remove-pipe-entry-by-ent ent)
            )
            (setq *PID-PIPE-SEGMENTS* (vl-remove e *PID-PIPE-SEGMENTS*))
          )

          (setq js (pid-jump-segment-start p1 p2 cp))
          (setq je (pid-jump-segment-end p1 p2 cp))

          (pid-draw-raw-line-segment p1 js lyr col T)
          (pid-draw-jump-arc cp nil lyr col)
          (pid-draw-raw-line-segment je p2 lyr col T)
        )
      )
    )
  )
)

(defun pid-draw-line-with-jumps (p1 p2 actual-layer actual-color / hits cur cp js je horizontal-p)
  ;; 022 override:
  ;; - If the new pipe is vertical, draw the jump on the new vertical pipe.
  ;; - If the new pipe is horizontal, split the existing vertical pipe and keep
  ;;   the horizontal pipe continuous.
  (setq horizontal-p (pid-seg-horizontal-p p1 p2))
  (setq hits (pid-find-jump-crossings p1 p2))
  (cond
    ((not hits)
      (pid-draw-raw-line-segment p1 p2 actual-layer actual-color T)
    )
    (horizontal-p
      (foreach cp hits
        (pid-break-existing-vertical-with-jump cp)
      )
      (pid-draw-raw-line-segment p1 p2 actual-layer actual-color T)
    )
    ((pid-crossings-too-close-p hits p1 p2)
      (pid-draw-raw-line-segment p1 p2 actual-layer actual-color T)
    )
    (T
      (setq cur p1)
      (foreach cp hits
        (setq js (pid-jump-segment-start p1 p2 cp))
        (setq je (pid-jump-segment-end p1 p2 cp))
        (pid-draw-raw-line-segment cur js actual-layer actual-color T)
        (pid-draw-jump-arc cp nil actual-layer actual-color)
        (setq cur je)
      )
      (pid-draw-raw-line-segment cur p2 actual-layer actual-color T)
    )
  )
)

(prompt "\n[PID] Jump override 022 loaded: radius 3mm, vertical crossing priority.")
(princ)
