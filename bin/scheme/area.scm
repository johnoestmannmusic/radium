;;
;; A very lightweight and super simple widget manager.
;;
;; This code is originally taken from hurtigmixer (https://github.com/kmatheussen/hurtigmixer/blob/master/src/area.scm),
;; but slightly simplified and modified. Blitting has, for instance, been removed since we don't
;; need it. It might be put back later if needed.

;; All x and y values are according to the underlying Qt widget, and not according to the area.
;; (makes everything much simpler, and straight forward)

;; All x and y values can be floating points (QWidget's x and y values must be integers).

;; Subclasses of def-area must define x1, y1, x2, y2, and gui. All of these would usually be provided as class parameters.

;; Subclasses can implement the following virtual methods: has-been-moved-callback, about-to-be-removed-callback, key-pressed, paint, post-paint, etc.
;; Areas only holding sub areas will often not implement any of these, and for those areas, we can simply
;; use the ready-made (and ultimately simple) <area> class instead (see below).

;; How to implement a custom method in an area subclass:
;;  (def-area-subclass (<area-with-custom-method> :gui :x1 :y1 :x2 :y2)  
;;    :custom-method ()
;;    (c-display "this text was printed from a custom method!"))
;; i.e. just like you normally would; methods go at the end of the class.
;; EDIT: That doesn't work anymore. The body of the subclasses was later put into their own scope to avoid accidentally
;; overriding symbols in the superclass. Instead you need to use :add-method! manually, after an instance has been created.
;; That's very inconvenient though, so maybe this should be improved.


(provide 'area.scm)

(my-require 'mouse-primitives.scm)
(my-require 'gui.scm)


#!!
(gc #t)
(set! (*s7* 'gc-stats) #f)
!!#

(define (myfloor a)
  ;;a
  (floor a)
  )

(define-expansion (define-override def . body)
  (let* ((funcname (car def))
         (org (<_> "super:" funcname)))
    `(let ((,org ,funcname))
       (set! ,funcname (lambda ,(cdr def)
                         ,@body)))))


(define-struct raw-mouse-cycle
  :enter-func
  :move-func
  :leave-func  
  :inside?
  :id
  :is-active #f
  :data #f)

(define *raw-mouse-cycle-counter* 0)

(define *area-id-counter* 0)

(c-define-expansion (*def-area-subclass* def . body)
                    
  (define body-methods '())
  (let ((temp (split-list body keyword?)))
    (set! body (car temp))
    (set! body-methods (cadr temp)))
  
  `(define-class ,def

     ;; To avoid overlapping paint updates, we convert all coordinates to integers.
     ;; (Qt uses integers in the widget update system, so if we use floats here, widgets on all sides of the area will be repainted unnecessarily.)
     (set! x1 (myfloor x1))
     (set! y1 (myfloor y1))
     (set! x2 (myfloor x2))
     (set! y2 (myfloor y2))
     
     (define width (- x2 x1))
     (define height (- y2 y1))

     (define font #f)
     
     (define (paint?)
       #t)

     (define id_ (inc! *area-id-counter* 1))

     (define is-alive #t)

     ;; Position
     
     (define (get-position callback)
       (callback x1 y1 x2 y2 width height))
     
     (define i-x1 #f)
     (define i-y1 #f)
     (define i-x2 #f)
     (define i-y2 #f)
     
     ;; optimization to avoid inside? to call parent-area::inside?
     (define (set-i-variables!)
       (when (not i-x1)
         (if parent-area
             (parent-area :get-i-position
                          (lambda (px1 py1 px2 py2)
                            (set! i-x1 (max x1 px1))
                            (set! i-y1 (max y1 py1))
                            (set! i-x2 (min x2 px2))
                            (set! i-y2 (min y2 py2))))
             (begin
               (set! i-x1 x1)
               (set! i-y1 y1)
               (set! i-x2 x2)
               (set! i-y2 y2)))))
       
     (define (get-i-position callback)
       (set-i-variables!)
       (callback i-x1 i-y1 i-x2 i-y2))
     
     ;; We return false if x* and y* aren't inside the parent either.
     (define (inside? x* y*)
       (set-i-variables!)
       (and (>= x* i-x1)
            (< x* i-x2)
            (>= y* i-y1)
            (< y* i-y2)))

     (define (overlaps? x1* y1* x2* y2*)
       (and (> x2* x1)
	    (< x1* x2)
	    (> y2* y1)
	    (< y1* y2)))

     (define-optional-func has-been-moved ()) ;; Called after being moved.

     (define (move-internal! dx dy)
       (set! i-x1 #f)
       (inc! x1 dx)
       (inc! y1 dy)
       (inc! x2 dx)
       (inc! y2 dy)
       (for-each (lambda (sub-area)
		   (sub-area :move-internal! dx dy))
		 sub-areas)
       (if has-been-moved
	   (has-been-moved)))
     
     (define (move! dx dy)
       (let ((old-x1 x1)
             (old-x2 x2)
             (old-y1 y1)
             (old-y2 y2))
         ;;(update-me!)
         (move-internal! dx dy)
         (update (min old-x1 x1)
                 (min old-y1 y1)
                 (max old-x2 x2)
                 (max old-y2 y2))))

     (define (update x1* y1* x2* y2*)
       (let ((x1 (max x1 x1*))
             (y1 (max y1 y1*))
             (x2 (min x2 x2*))
             (y2 (min y2 y2*)))
         ;;(c-display "     UPDATE" x1 y1 x2 y2)
         (if (and (> x2 x1)
                  (> y2 y1))
             (begin
               (<gui> :update gui x1 y1 x2 y2)
               ;;#f
               )
             (c-display "Warning, illegal parameters for update: " x1 y1 x2 y2))))

     (define (update-me!)
       ;;(c-display "     UPDATE-ME!" x1 y1 x2 y2)
       (<gui> :update gui x1 y1 x2 y2)
       ;;#f
       )

     (define (update-me-and-all-parents-and-siblings!)
       (if parent-area
           (parent-area :update-me-and-all-parents-and-siblings!)
           (update-me!)))
     
     (define (set-position! x* y*)
       (let ((dx (- x* x1))
	     (dy (- y* y1)))
	 (move! dx dy)))     

     (define (set-position-and-size! x1* y1* x2* y2*)
       (set! width (- x2* x1*))
       (set! height (- y2* y1*))
       (set! x2 (+ x1 width))
       (set! y2 (+ y1 height))
       (set-position! x1* y1*))

     (define (resize! width height)
       (set-position-and-size! x1 y1 (+ x1 width) (+ y1 height)))

     (define effect-monitors '())

     (define (add-area-effect-monitor! instrument-id effect-name monitor-stored monitor-automation callback)
       (define effect-monitor #f)
       (set! effect-monitor (<ra> :add-effect-monitor effect-name instrument-id monitor-stored monitor-automation
                                  (lambda (radium-normalized automation)
                                    (if (<gui> :is-open gui)
                                        (callback radium-normalized automation)
                                        (begin                                                 
                                          (c-display (<-> "Warning! In " ',(car def) "::add-area-effect-monitor!: Warning! gui #" gui " has been closed. (removing the effect monitor)"))
                                          (<ra> :remove-effect-monitor effect-monitor #t))))))
       (push-back! effect-monitors effect-monitor))

     (define (shallow-remove-sub-areas!)
       ;;(assert #f)
       (set! sub-areas '())
       (set! top-area #f))
     
     (define (remove-sub-areas!)
       (for-each (lambda (effect-monitor)
                   ;;(c-display "Note: In" ',(car def) ", the effect monitor" effect-monitor "was automatically removed")
                   (<ra> :remove-effect-monitor effect-monitor #f))
                 effect-monitors)
       (set! effect-monitors '())

       (for-each (lambda (sub-area)
                   (sub-area :about-to-be-removed-internal!))
                 sub-areas)
       
       (set! sub-areas '())
       (set! top-area #f))

     (define-optional-func about-to-be-removed-callback ())

     (define (about-to-be-removed-internal!)
       (if about-to-be-removed-callback
           (about-to-be-removed-callback))
       (remove-sub-areas!)
       (set! is-alive #f))

     (define (reset! x1* y1* x2* y2*)
       (set-position-and-size! x1* y1* x2* y2*)
       (remove-sub-areas!)
       (set! parent-area #f)
       (update-me!))

     (define-optional-func parent-area (key . rest))

     ;; Sub areas
     (define sub-areas '())
     (define top-area #f)

     (define (add-sub-area-plain! sub-area)
       (push-back! sub-areas sub-area)
       (set! top-area sub-area)
       (sub-area :set-parent-area! this)
       (sub-area :update-me!)
       ;;(if (eq? ',(car def) '<seqtrack-config-entry>)
       ;;    (c-display "add-sub-area-pain!" ',(car def) ": " (length sub-areas)))
       )


     (define (add-sub-area! sub-area x y)       
       ;;(c-display " THIS10:" this x y ". sub-area:" sub-area)
       (sub-area :set-position! x y)

       (add-sub-area-plain! sub-area)
       ;;(c-display " THIS:" this)

       (sub-area :get-position
                 (lambda (x* y* x2* y2* with* height*)
                   (if (inside? x* y*)
                       (update x* y* x2* y2*))))
       ;;(c-display "sub-area added to" ',(car def) ". New sub-area length:" (length sub-areas))
       )

     (define (add-sub-area-above! sub-area-below sub-area)
       (sub-area-below :get-position
                       (lambda (x1 y1 x2 y2 width height)
                         (add-sub-area! sub-area x2 y1))))
     
     (define (add-sub-area-below! sub-area-above sub-area)
       (sub-area-above :get-position
                       (lambda (x1 y1 x2 y2 width height)
                         (add-sub-area! sub-area x1 y2))))
     
     (define (remove-sub-area! sub-area)
       (sub-area :about-to-be-removed-internal!)
       (set! sub-areas (delete sub-area sub-areas eq?))
       (set! top-area
	     (if (null? sub-areas)
		 #f
		 (last sub-areas)))
       )

     (define (lift-sub-area! sub-area)
       (when (not (eq? sub-area top-area))
	 (set! sub-areas (append (delete sub-area sub-areas eq?)
                                 (list sub-area)))
	 (set! top-area sub-area)
         (sub-area :get-position
                   (lambda (x* y* x2* y2* with* height*)
                     (update x* y* x2* y2*)))))

     (define (lift-me!)
       (if parent-area
           (parent-area :lift-sub-area! this)))

     ;; State
     (define (get-state)
       #f)

     (define (apply-state! a-hash-table)
       #t)

     ;; Keyboard listener
     ;;;;;;;;;;;;;;;;;;;;;;;;
     (define-optional-func key-pressed (key-event))
     (define (key-pressed-internal key-event)
       (call-with-exit
	(lambda (return)
	  (if key-pressed
	      (let ((ret (key-pressed key-event)))
		(if ret
		    (return #t)))
	      (for-each (lambda (sub-area)
			  (if (sub-area :key-pressed-internal key-event)
			      (return #t)))
			sub-areas))
	  #f)))

     (define (key-released-internal key-event)
       ;;(c-display "released something")
       #t
       )

     
     ;; Mouse wheel
     ;;;;;;;;;;;;;;;;;;;;;;;;
     (define-optional-func mouse-wheel-moved (is-up x y))
     (define-optional-func mouse-wheel-moved-last (is-up x y))
     (define (mouse-wheel-moved-internal! is-up x* y*)
       (and (inside? x* y*)
            (call-with-exit
             (lambda (return)
               (if mouse-wheel-moved
                   (let ((ret (mouse-wheel-moved is-up x* y*)))
                     (if ret
                         (return #t))))
               (for-each (lambda (sub-area)
                           (if (sub-area :mouse-wheel-moved-internal! is-up x* y*)
                               (return #t)))
                         sub-areas)
               (if mouse-wheel-moved-last
                   (let ((ret (mouse-wheel-moved-last is-up x* y*)))
                     (if ret
                         (return #t))))
               #f))))
     

     ;; Raw mouse cycles (both when button is pressed, and when button is not pressed)
     ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

     (define raw-mouse-cycles '())
     
     (delafina (add-raw-mouse-cycle! :enter-func (lambda x #t)
                                     :move-func (lambda x #t)
                                     :leave-func (lambda x #f) ;; Leave area, or button was pressed.
                                     :data #f)
       
       (set! *raw-mouse-cycle-counter* (+ 1 *raw-mouse-cycle-counter*))
       
       (push-back! raw-mouse-cycles
                   (make-raw-mouse-cycle enter-func
                                         move-func
                                         leave-func
                                         inside?
                                         *raw-mouse-cycle-counter*
                                         data))
       )

     ;; This function handles all raw mouse cycles, and it is only called from mouse-callback-internal in the gui that is placed directly on the underlying qt widget,
     ;; or from the parent widget's handle-raw-mouse-cycles function.
     (define (handle-raw-mouse-cycles check-leave button state x y)
       (for-each (lambda (sub-area)
                   (sub-area :handle-raw-mouse-cycles check-leave button state x y))
                 sub-areas) ;; (reverse sub-areas))
       
       (define (is-inside?)
         (and (not (eq? state *is-leaving*))
              (inside? x y)))

       (if check-leave
           (for-each (lambda (raw-mouse-cycle)
                       (when (and (raw-mouse-cycle :is-active)
                                  (not (is-inside?)))
                         ;;(c-display "     RAW Leave func for called for" class-name "." x y)
                         (raw-mouse-cycle :leave-func button x y)
                         (set! (raw-mouse-cycle :is-active) #f)))
                     raw-mouse-cycles)
           (for-each (lambda (raw-mouse-cycle)
                       (define was-active (raw-mouse-cycle :is-active))
                       (define is-active was-active)
                       ;;(if (or is-inside was-active is-active)
                       ;;    (c-display "inside?:" is-inside ". is-active:" is-active ". was-active: " was-active ". class-name:" class-name ". state:" state))
                       (when (is-inside?)
                         (if is-active
                             (set! is-active (raw-mouse-cycle :move-func button x y))
                             (begin
                               ;;(c-display "    RAW enter func for called for" class-name "." x y)
                               (set! is-active (raw-mouse-cycle :enter-func button x y)))))
                       (if (not (eq? was-active is-active))
                           (set! (raw-mouse-cycle :is-active) is-active)))
                     raw-mouse-cycles)))
     
     (define is-hovering #f)
     (define has-detected-hovering #f)
  
     (define-optional-func hovering-callback (callback))
     
     (define (detect-hovering!)
       (when (not has-detected-hovering)
         (set! has-detected-hovering #t)
         (add-raw-mouse-cycle!
          :enter-func (lambda (button x y)
                        (set! is-hovering #t)
                        (if hovering-callback
                            (hovering-callback #t))
                        (update-me!)
                        #t)
          :leave-func (lambda (button x y)
                        (set! is-hovering #f)
                        (if hovering-callback
                            (hovering-callback #f))
                        (update-me!)
                        #f))))
     
     (define (add-hover-callback! callback)
       (assert (not hovering-callback))
       (set! hovering-callback callback)
       (detect-hovering!))
     
     ;; Mouse cycles (only when button is pressed)
     ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

     (define-optional-hash-table curr-mouse-cycle)
     (define mouse-cycles '())

     (delafina (add-mouse-cycle-prepend! :press-func (lambda x #t)
                                         :drag-func (lambda x #f)
                                         :release-func (lambda x #f))
       (push! mouse-cycles
              (make-mouse-cycle press-func drag-func release-func))
       )
     
     (delafina (add-mouse-cycle! :press-func (lambda x #t)
                                 :drag-func (lambda x #f)
                                 :release-func (lambda x #f))
       (push-back! mouse-cycles
                   (make-mouse-cycle press-func drag-func release-func))
       )
     
     (delafina (add-delta-mouse-cycle! :press-func (lambda x #t)
                                       :drag-func (lambda x #f)
                                       :release-func (lambda x #f))
       (define prev-x #f)
       (define prev-y #f)
       (define inc-x 0)
       (define inc-y 0)
       (define (call-delta-func func button x* y* force-call)
         (define dx (cond ((only-y-direction)
                           0)
                          ((<ra> :control-pressed)
                           (/ (- x* prev-x)
                              10))
                          (else
                           (- x* prev-x))))
         (define dy (cond ((only-x-direction)
                           0)
                          ((<ra> :control-pressed)
                           (/ (- y* prev-y)
                              10))
                          (else
                           (- y* prev-y))))
         (when (or force-call
                   (not (= 0 dx))
                   (not (= 0 dy)))
           (inc! inc-x dx)
           (inc! inc-y dy)
           (func button x* y* inc-x inc-y)
           )
         (set! prev-x x*)
         (set! prev-y y*))

       (push-back! mouse-cycles
                   (make-mouse-cycle (lambda (button x* y*)
                                       ;;(c-display "delta press")
                                       (set! prev-x x*)
                                       (set! prev-y y*)
                                       (set! inc-x 0)
                                       (set! inc-y 0)
                                       (press-func button x* y*))
                                     (lambda (button x* y*)
                                       ;;(c-display "delta press move: " curr-mouse-cycle)
                                       (call-delta-func drag-func button x* y* #f))
                                     (lambda (button x* y*)
                                       (call-delta-func drag-func button x* y* #f)
                                       (call-delta-func release-func button x* y* #t)))))
     
     (define (get-raw-mouse-cycles x* y*)
       (define ret '())
       (and (paint?)
            (inside? x* y*)
            (call-with-exit (lambda (return)
                              (for-each (lambda (sub-area)
                                          (let ((maybe (sub-area :get-raw-mouse-cycle x* y*)))
                                            (if (not (null? maybe))
                                                (return maybe))))
                                        (reverse sub-areas))
                              (keep identity
                                    (map (lambda (mouse-cycle)
                                           (if (mouse-cycle :press-func x* y*)
                                               mouse-cycle
                                               #f))
                                         raw-mouse-cycles))))))
       
     (define do-nothing-mouse-cycle (make-mouse-cycle (lambda (button x* y*)
                                                        (assert #f))
                                                      (lambda (button x* y*)
                                                        #f)
                                                      (lambda (button x* y*)
                                                        #f)))

     (define (get-mouse-cycle button x* y*)
       ;;(c-display "GET MOUSE CYCLE")
       (and (paint?)
            (inside? x* y*)
	    (or (call-with-exit (lambda (return)
                                  (for-each (lambda (sub-area)
                                              (and-let* ((res (sub-area :get-mouse-cycle button x* y*)))
                                                        (return res)))
                                            (reverse sub-areas))
                                  #f))
		(call-with-exit (lambda (return)
                                  (for-each (lambda (mouse-cycle)
                                              (let ((use-it (mouse-cycle :press-func button x* y*)))
                                                (cond ((eq? 'eat-mouse-cycle use-it)
                                                       (return do-nothing-mouse-cycle))
                                                      ((eq? #t use-it)
                                                       (return mouse-cycle))
                                                      (else
                                                       (assert (eq? #f use-it))))))
                                            mouse-cycles)
                                  #f)))))

     (define (mouse-press-internal button x* y*)
       ;;(c-display "_____________________________________mouse-press" curr-mouse-cycle)
       (if (not (<ra> :release-mode))
           (assert (not curr-mouse-cycle))) ;; Unfortunately, we can't trust Qt to send release events. (fixed now)
       (set! curr-mouse-cycle (get-mouse-cycle button x* y*))
       ;;(c-display "====-------Setting curr-mouse-cycle to:" curr-mouse-cycle)
       ;;(<ra> :show-warning "gakk")

       curr-mouse-cycle)
     
     (define (mouse-move-internal button x* y*)
       ;;(c-display "..mouse-move-internal for" class-name ". y:" y* ". has-curr:" (to-boolean curr-mouse-cycle)  ". has_nonpress:" (to-boolean curr-nonpress-mouse-cycle))
       (and curr-mouse-cycle
            (curr-mouse-cycle :drag-func button x* y*)))
     
     (define (mouse-release-internal button x* y*)
       ;;(if curr-mouse-cycle
       ;;    (c-display "..mouse-release-internal for" class-name ". y:" y*))
       ;;(c-display "mouse-release enter" curr-mouse-cycle)
       (let ((mouse-cycle curr-mouse-cycle))
         (set! curr-mouse-cycle (<optional-hash-table>))
         ;;(c-display "===------ Unsetting curr-mouse-cycle");
         (if mouse-cycle
             (mouse-cycle :release-func button x* y*)))
       ;;(c-display "mouse-release leave" curr-mouse-cycle)
       )

     (define (mouse-callback-internal button state x y)

       ;;(c-display "   mouse-callback-internal" "has:" (if curr-mouse-cycle #t #f) ". button/state:" button state
       ;;           (if (= state *is-releasing*) "releasing" (if (= state *is-leaving*) "leaving" (if (= state *is-pressing*) "pressing" "unknown"))))
       
       (handle-raw-mouse-cycles #t button state x y)
       (handle-raw-mouse-cycles #f button state x y)
       
       
       ;; make sure release is always called when releasing, no matter other states.
       (when (or (= state *is-releasing*)
                 (= state *is-leaving*))
         ;;(if curr-mouse-cycle
         ;;(c-display "     MOUSE-CALLBACK-INTERNAL called for" class-name ". y:" y ". type:" (if (= state *is-releasing*) "RELEASE" "LEAVE"))
         (mouse-release-internal button x y))
       
       (cond (*current-mouse-cycle*
              #f) ;; i.e. mouse.scm is handling mouse now.
             ((= state *is-leaving*)
              #f)
             ((= state *is-moving*)
              (mouse-move-internal button x y))
             ((not (inside? x y))
              #f)
             ((= state *is-pressing*)
              (mouse-press-internal button x y))
             ((= state *is-releasing*)
              #f)
             (else
              (assert (= state *is-entering*))
              #f)))

     (define (has-mouse)
       ;;(c-display "has-mouse:" class-name curr-mouse-cycle curr-nonpress-mouse-cycle)
       (if parent-area
           (parent-area :has-mouse)
           (get-bool curr-mouse-cycle)))
;           (any? (lambda (raw-mouse-cycle)
;                   (raw-mouse-cycle :is-active))
;                 raw-mouse-cycles)
     
       ;; Status bar
     ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
     
     (define statusbar-text-id -1)
     
     (define (set-statusbar-text! text)
       (set! statusbar-text-id (<ra> :set-statusbar-text text)))

     (define (remove-statusbar-text)
       (<gui> :tool-tip "")
       (<ra> :remove-statusbar-text statusbar-text-id))

     (define (a-sub-area-contains-active-raw-mouse-handler? area data)
       (call-with-exit
        (lambda (return)
          (for-each (lambda (raw-mouse-cycle)
                      (if (and (raw-mouse-cycle :is-active)
                               (equal? data (raw-mouse-cycle :data)))
                          (return #t)))
                    (area :get-raw-mouse-cycles))
          (any? (lambda (sub-area)
                  (a-sub-area-contains-active-raw-mouse-handler? sub-area data))
                (area :get-sub-areas)))))
       
     (define (a-sub-area-contains-active-raw-statusbar-text-mouse-cycle-handler? area)
       (a-sub-area-contains-active-raw-mouse-handler? area 'statusbar-text-handler))
  
     (define (add-statusbar-text-handler string-or-func)
       (add-raw-mouse-cycle!
        :enter-func (lambda (button x* y)
                      (if (any? a-sub-area-contains-active-raw-statusbar-text-mouse-cycle-handler? sub-areas)
                          #f
                          (let ()
                            (define string-or-pair (if (procedure? string-or-func)
                                                       (string-or-func)
                                                       string-or-func))
                            (define text (if (pair? string-or-pair)
                                             (cadr string-or-pair)
                                             string-or-pair))
                            (define also-show-tooltip (if (pair? string-or-pair)
                                                          (car string-or-pair)
                                                          #f))
                            
                            (if also-show-tooltip
                                (<gui> :tool-tip text))
                            (set-statusbar-text! text)
                            #t)))
        :leave-func (lambda (button x y)
                      (remove-statusbar-text))
        :data 'statusbar-text-handler))
       
     (define (a-sub-area-contains-active-raw-statusbar-text-mouse-cycle-handler? area)
       (a-sub-area-contains-active-raw-mouse-handler? area 'mouse-pointerhandler))

     (define (add-mouse-pointerhandler set-mouse-pointer-func!)
       (add-raw-mouse-cycle!
        :enter-func (lambda (button x* y)
                      (if (any? a-sub-area-contains-active-raw-statusbar-text-mouse-cycle-handler? sub-areas)
                          #f
                          (let ()
                            (set-mouse-pointer set-mouse-pointer-func! gui)
                            #t)))
        :leave-func (lambda (button x y)
                      #t
                      ;;(set-mouse-pointer ra:set-normal-mouse-pointer gui)                      
                      )
        :data 'mouse-pointerhandler))
       
     ;; Painting
     ;;;;;;;;;;;;;;;
       
     (define (paint)  ;; Called before painting the current area's sub-areas
       #f)
     (define (post-paint) ;; Called after painting the current area's sub-areas
       #f)
     
     (define (paint-internal px1 py1 px2 py2) ;; px1, py1, etc. is the clip area of the parent area.

       ;;(c-display "\n\npaint-internal called" ',(car def) "(" x1 y1 x2 y2 "). p: (" px1 py1 px2 py2 ")")

       (when (and (paint?)
                  (<gui> :area-needs-painting gui x1 y1 x2 y2));;overlaps? x1* y1* x2* y2*))
         
         ;;(c-display "paint-internal hepp" ',(car def) paint "sub-areas" sub-areas)
         (let ((cx1 (max x1 px1))
               (cy1 (max y1 py1))
               (cx2 (min x2 px2))
               (cy2 (min y2 py2)))

           (when (and (> cx2 cx1)
                      (> cy2 cy1))
             
             (<gui> :do-clipped gui cx1 cy1 cx2 cy2
                    (lambda ()
                      (define (paintit)
                        (paint)                
                        (for-each (lambda (sub-area)
                                    (sub-area :paint-internal cx1 cy1 cx2 cy2))
                                  sub-areas))
                      
                      (if font
                          (<gui> :do-font gui font paintit)
                          (paintit))
             
                      (post-paint)))))))
     
     (define class-name ',(car def))

     (let () ;; Put body into new scope to avoid accidentally overriding an internal method. (use define-override instead of define to purposefully override)
       #t ;; Added to silence "let has no body" error messages.
       ,@body)

     ,@body-methods

     :get-width () width
     :get-height () height
     :get-gui () gui
     :get-position x (apply get-position x)
     :get-i-position x (apply get-i-position x)
     :inside? x (apply inside? x)
     :update-me! x (apply update-me! x)
     :update-me-and-all-parents-and-siblings! () (update-me-and-all-parents-and-siblings!)
     :set-font! dasfont (set! font dasfont)
     :set-position! x (apply set-position! x)
     :set-position-and-size! x (apply set-position-and-size! x)
     :resize! x (apply resize! x)
     :move! x (apply move! x)
     :move-internal! x (apply move-internal! x)
     :set-parent-area! (new-parent-area) (begin
                                           (assert new-parent-area)
                                           (set! parent-area new-parent-area))
     :get-parent-area x parent-area
     :add-sub-area-plain! (sub-area) (add-sub-area-plain! sub-area)
     :add-sub-area! x (apply add-sub-area! x)
     :add-sub-area-above! x (apply add-sub-area-above! x)
     :add-sub-area-below! x (apply add-sub-area-below! x)     
     :remove-sub-area! x (apply remove-sub-area! x)
     :shallow-remove-sub-areas! x (apply shallow-remove-sub-areas! x) ;; Only sets sub-areas to empty list. Does not remove sub areas from sub areas and so forth.
     :remove-sub-areas! x (apply remove-sub-areas! x)
     :lift-sub-area! x (apply lift-sub-area! x)
     :lift-me! x (apply lift-me! x)
     :get-sub-areas () sub-areas
     :get-state  x (apply get-state x)
     :apply-state! x (apply apply-state! x)

     :key-pressed-internal! x (apply key-pressed-internal x)
     :key-released-internal! x (apply key-released-internal x)
     :mouse-wheel-moved-internal! x (apply mouse-wheel-moved-internal! x)
     :add-mouse-cycle-prepend! x (apply add-mouse-cycle-prepend! x)
     :add-mouse-cycle! x (apply add-mouse-cycle! x)
     :get-mouse-cycle x (apply get-mouse-cycle x)
     :add-raw-mouse-cycle! x (apply add-raw-mouse-cycle! x)
     :get-raw-mouse-cycles x raw-mouse-cycles
     :handle-raw-mouse-cycles x (apply handle-raw-mouse-cycles x)
     :detect-hovering! x (apply detect-hovering! x)
     :is-hovering () is-hovering
     :add-hover-callback! x (apply add-hover-callback! x)
     :add-mouse-pointerhandler x (apply add-mouse-pointerhandler x)
     :overlaps? x (apply overlaps? x)
     ;;:paint x (apply paint x)
     :paint-internal x (apply paint-internal x)
     :mouse-callback-internal x (apply mouse-callback-internal x)
     :has-mouse () (has-mouse)
     :is-alive () is-alive
     :reset! x (apply reset! x)
     :about-to-be-removed-internal! x (apply about-to-be-removed-internal! x)
     :add-statusbar-text-handler x (apply add-statusbar-text-handler x)
     :override-method! (funcname func) (let ((funcname (keyword->symbol funcname)))
                                         (let* ((org (<_> "super:" funcname)))
                                           (eval `(let ((,org ,funcname))
                                                    ;;(c-display "FUNCNAME:" ',funcname ". old:" ,funcname)
                                                    (set! ,funcname ,func)
                                                    ;;(c-display "GOTIT")
                                                    ))))
     :class-name () class-name
     ))
 


(def-area-subclass (<area> :gui :x1 :y1 :x2 :y2)  
  )


;; Warning: Does not check if the states are compatible.
(def-area-subclass (<keep-states-area> :gui :x1 :y1 :x2 :y2)    
  
  (define-override (get-state)
    (hash-table :sub-states (map (lambda (area)
                                    (area :get-state))
                                  sub-areas)))
  
  (define-override (apply-state! state)
    (define sub-states (state :sub-states))
    (if (= (length sub-states)
           (length sub-areas))
        (for-each (lambda (state sub-area)
                    (sub-area :apply-state! state))
                  sub-states
                  sub-areas)))
  )

(def-area-subclass (<use-first-subarea-state-as-state-area> :gui :x1 :y1 :x2 :y2)
  (define-override (get-state)
    (if (null? sub-areas)
        (begin
          (c-display "Warning: No sub areas in use-first-subarea-state-as-state-area area")
          (hash-table))
        ((car sub-areas) :get-state)))
  (define-override (apply-state! state)
    ((car sub-areas) :apply-state! state)))


(delafina (make-qtarea :width 100 :height 100 :sub-area-creation-callback #f :enable-mouse-callbacks #t)
  (define gui (<gui> :widget width height))  
  (define x1 0)
  (define y1 0)
  (define x2 width)
  (define y2 height)
  (def-area-subclass (<qtarea>)
    (<gui> :add-paint-callback gui
           (lambda (width height)
             (paint-internal 0 0 width height)))

    (<gui> :add-deleted-callback gui
           (lambda (radium-runs-custom-exec)
             (remove-sub-areas!))) ;; clean-up.
    
    (when enable-mouse-callbacks
      (<gui> :add-mouse-callback gui
             (lambda (button state x y)
               (mouse-callback-internal button state x y)
               ;;(c-display "has-mouse:" (and (defined? 'has-mouse) (has-mouse)))
               ;;50))
               (has-mouse)))
      (<gui> :add-mouse-wheel-callback gui mouse-wheel-moved-internal!))

    (define-optional-func the-sub-area (key . rest))
    
    (define (recreate width* height*)
      (resize! width* height*)
      (define state (and the-sub-area
                         (the-sub-area :get-state)))
      (remove-sub-areas!)
      (set! the-sub-area (sub-area-creation-callback gui width height state))
      (if state
          (the-sub-area :apply-state! state))
      (add-sub-area-plain! the-sub-area))

    (when sub-area-creation-callback
      (<gui> :add-resize-callback gui recreate)
      (recreate width height))

    (add-method! :recreate (lambda ()
                             (recreate width height)))
    )
  
  (define area (<new> :qtarea))
  
  area)



(define *use-testgui* #f)
(<declare-variable> *testgui*)


#!!
(def-area-subclass (<testarea> :gui :x1 :y1 :x2 :y2)  
  (define X 0)
  (define Y 0)

  (define-override (paint)
    ;;(c-display "x1:" gui x1 y1 x2 y2 (<ra> :generate-new-color))
    (<gui> :filled-box gui (<ra> :generate-new-color 1) x1 y1 x2 y2)
    (<gui> :draw-text gui "green" "hello" X Y x2 y2)
    (<gui> :draw-line gui "white" X Y x2 y2 2.3))
  
  (add-mouse-cycle! (lambda (button x* y*)
                      (set! X x*)
                      (set! Y y*)
                      (update X Y x2 y2)
                      (c-display "press button/x/y" x* y*))
                    (lambda (button x* y*)
                      (set! X x*)
                      (set! Y y*)
                      (update X Y x2 y2)
                      (c-display "move button/x/y" x* y*))
                    (lambda (button x* y*)
                      (set! X x*)
                      (set! Y y*)
                      (update X Y x2 y2)
                      (c-display "release button/x/y" x* y*)))
  )


(pretty-print (macroexpand (def-area-subclass (<area-with-custom-method> :gui :x1 :y1 :x2 :y2)
                             (this :add-method 'custom-method (lambda ()
                                                                (c-display "this text was printed from a custom method!"))))
                           )
              )



(define testarea2 (<new> :area-with-custom-method *testarea* 0 0 100 100))))

(pretty-print (macroexpand (<new> :area-with-custom-method *testarea* 0 0 100 100)))
(testarea2 :add-method! :ai (lambda () (c-display "hello")))

(testarea2 :custom-method)
(testarea2 :ai)

(if (and (defined? '*testgui*)
         *testgui*
         (<gui> :is-open *testgui*))
    (<gui> :close *testgui*))

(define *testgui* (and *use-testgui*
                       (<gui> :widget 500 500)))


;; Save some cycles by not painting background color if only vertical audio meters are updated (meters are repainted continously)
(when *use-testgui*
  (<gui> :dont-autofill-background *testgui*)
  (<gui> :set-background-color *testgui* (<gui> :get-background-color *testgui*)))


!!#

#||
(define testarea (<new> :testarea *testgui* 100 200 1100 1200))

(testarea :get-position c-display)

(<gui> :show *testgui*)

(<gui> :add-paint-callback *testgui*
       (lambda (width height)
         (testarea :paint-internal 0 0 width height)))

(<gui> :add-mouse-callback *testgui*
       (lambda (button state x y)
         (c-display "asd" x y)
         (testarea :mouse-callback-internal button state x y)
         (if (testarea :has-mouse)
             #t
             #f)))
||#

                     
(def-area-subclass (<text-area> :gui :x1 :y1 :x2 :y2
                                :text ;; can also be function
                                :background-color #f ;; If #f, background will not be painted. can also be function
                                :text-color *text-color* ;; can also be function
                                :wrap-lines #f
                                :align-top #f
                                :align-right #f
                                :align-left #f
                                :paint-border #t
                                :border-rounding 2
                                :border-width 1.2
                                :border-color "#222222"
                                :scale-font-size #t
                                :cut-text-to-fit #f
                                :only-show-left-part-if-text-dont-fit #t ;; only make sense to set #f if both scale-font-size and cut-text-to-fit is #f.
                                :text-is-base64 #f
                                :light-up-when-hovered #f
                                )

  (define (get-text)
    (maybe-thunk-value text))

  (define (get-text-color)
    (maybe-thunk-value text-color))

  (define (get-border-color)
    (maybe-thunk-value border-color))

  (define (get-border-width)
    (maybe-thunk-value border-width))

  (define (get-background-color)
    (and background-color
         (maybe-thunk-value background-color)))
  
  (if light-up-when-hovered
      (detect-hovering!))
  
  (define (paint-text-area gui x1 y1 x2 y2)
    (let ((background-color (get-background-color)))
      (when (or background-color
                (and light-up-when-hovered
                     is-hovering))
        (when (and light-up-when-hovered
                   is-hovering)
          (set! background-color (<gui> :make-color-lighter (if background-color background-color "#88888888") 1.2)))
        ;;(<gui> :filled-box gui background-color x1 y1 x2 y2 border-rounding border-rounding *gradient-vertical-dark-sides* 0.1)))
        (<gui> :filled-box gui background-color x1 y1 x2 y2 border-rounding border-rounding (if align-right *gradient-diagonal-light-upper-right* *gradient-diagonal-light-upper-left*) 0.1)))
    
    (define text (maybe-thunk-value text))

    (define text-width (<gui> :text-width text gui))

    (let ()
      (define x1 (+ (cond (align-right
                           (- x2 text-width)
                           )
                          (align-left
                           (+ 2 x1))
                          (else
                           x1))
                    1))
      (define x2 (- x2 1))
      
      (when (and (not scale-font-size)
                 (not cut-text-to-fit)
                 (not only-show-left-part-if-text-dont-fit))
        (when (> text-width (- x2 x1))
          (set! x1 (+ x1 (- (- x2 x1) text-width)))))

      (<gui> :draw-text gui (maybe-thunk-value text-color) text
             x1
             y1
             x2
             y2
             wrap-lines
             align-top
             (or align-left
                 align-right)
             0 ;; rotate
             cut-text-to-fit
             scale-font-size
             text-is-base64
             ))

    (when paint-border
      (define background-color (<gui> :get-background-color gui))
      (<gui> :do-clipped gui x1 y1 x2 y2
             (lambda ()
               ;;(<gui> :draw-box gui background-color (+ 0 x1) (+ 0 y1) (- x2 0) (- y2 0) 2 0 0)
               ;;(<gui> :draw-box gui *mixer-strip-border-color* x1 y1 x2 y2 1.5 border-rounding border-rounding)
               (<gui> :draw-box gui (get-border-color) x1 y1 x2 y2 (get-border-width) border-rounding border-rounding)
               ))
      )
    )

  (add-method! :paint-text-area paint-text-area)

  (define-override (paint)
    (paint-text-area gui x1 y1 x2 y2))

  )


(def-area-subclass (<line-input> :gui :x1 :y1 :x2 :y2
                                 :prompt ""
                                 :text ""
                                 :background-color "low_background"
                                 :get-wide-string #f
                                 :callback)
  
  (add-sub-area-plain! (<new> :text-area gui x1 y1 x2 y2
                              :text text
                              :background-color background-color
                              ;;:text-color "black"
                              :align-left #t
                              :scale-font-size #f
                              ;;:only-show-left-part-if-text-dont-fit #f
                              :text-is-base64 get-wide-string
                              :light-up-when-hovered #t
                              ))
  
  (add-mouse-cycle! :press-func (lambda (button x* y*)
                                  (and (= button *left-button*)
                                       (<ra> :schedule 0
                                             (lambda ()
                                               (let ((new-name (if get-wide-string
                                                                   (<ra> :request-w-string prompt #t text)
                                                                   (<ra> :request-string prompt #t text))))
                                                 (c-display "GAKKKGAKK_________ NEWNAME" (<-> "-" new-name "-"))
                                                 (when (not (string=? new-name text))
                                                   (set! new-name (callback new-name))
                                                   (if new-name
                                                       (set! text new-name))
                                                   (update-me!))
                                                 #f)))
                                       #t))))

(define (get-default-button-color gui)
  (define gui-background-color (<gui> :get-background-color gui))
  (<gui> :mix-colors "#010101" gui-background-color 0.5))

(def-area-subclass (<checkbox> :gui :x1 :y1 :x2 :y2
                               :is-selected-func
                               :value-changed-callback
                               :paint-func #f
                               :text "" ;; Only used if paint-func is #f
                               :text-color "buttons_text"
                               :selected-color #f ;; only used if paint-func is #f. If #f, use get-default-button-color
                               :prepend-checked-marker #t
                               :gradient-background #f
                               :right-mouse-clicked-callback #f
                               :delete-clicked-callback #f
                               :border-width 0.25
                               :box-rounding #f
                               )

  (if (not selected-color)
      (set! selected-color "check_box_selected_v2")) ;;(get-default-button-color gui)))

  (detect-hovering!)

  (define-override (paint)
    (if paint-func
        (paint-func gui x1 y1 x2 y2 (is-selected-func) is-hovering)
        (begin
          (define is-selected (is-selected-func))
          (draw-button gui
                         (if (procedure? text) (text) text)
                         is-selected
                         x1 y1 x2 y2
                         selected-color
                         ;;:unselected-color (<gui> :get-background-color gui)
                         :background-color "check_box_unselected_v2" ;;"button_color_v2" ;;(<gui> :get-background-color gui)
                         :is-hovering is-hovering
                         :prepend-checked-marker prepend-checked-marker
                         :text-color text-color
                         :gradient-background (or is-selected is-hovering gradient-background)
                         :paint-implicit-border #f
                         :implicit-border-width border-width
                         :box-rounding box-rounding
                         :paint-black-border #t
                         )
          ;;(<gui> :draw-box gui "black" x1 y1 x2 y2 1.1 3 3)
          )))

  (add-mouse-cycle! (lambda (button x* y*)
                      (cond ((and delete-clicked-callback
                                  (delete-button? button))
                             (delete-clicked-callback)
                             #t)
                            ((and right-mouse-clicked-callback
                                  (= button *right-button*)
                                  (not (<ra> :shift-pressed))
                                  )
                             (right-mouse-clicked-callback)
                             #t)
                            ((= button *left-button*)                        
                             (value-changed-callback (not (is-selected-func)))
                             (update-me!)
                             #t)
                            (else
                             #t)))))
                          
                            
(def-area-subclass (<radiobuttons> :gui :x1 :y1 :x2 :y2
                                   :num-buttons
                                   :curr-button-num
                                   :value-changed-callback
                                   :layout-horizontally #t
                                   :paint-func #f
                                   :text-func (lambda (num) "")
                                   :text-color "buttons_text"
                                   :selected-color #f ;; only used if paint-func is #f. If #f, use get-default-button-color
                                   :right-mouse-clicked-callback #f
                                   :delete-clicked-callback #f
                                   :border-width 0.25
                                   :box-rounding #f
                                   )

  (define layout-func (if layout-horizontally
                          horizontally-layout-areas
                          vertically-layout-areas))

  (define radiobuttons (make-vector num-buttons #f))
  
  (add-method! :get-radiobutton (lambda (num)
                                  (radiobuttons num)))
                                  
  (layout-func x1 y1 x2 y2
               (iota num-buttons)
               :spacing 2
               :callback
               (lambda (num x1 y1 x2 y2)
                 (define checkbox
                   (<new> :checkbox gui x1 y1 x2 y2
                          (lambda ()
                            (= num curr-button-num))
                          (lambda (is-on)
                            (if is-on
                                (set! curr-button-num num))
                            (for-each (lambda (num)
                                        (value-changed-callback num (= curr-button-num num)))
                                      (iota num-buttons))
                            (update-me!)
                            )
                          :paint-func (and paint-func
                                           (lambda (gui x1 y1 x2 y2 is-on)
                                             (paint-func gui x1 y1 x2 y2 num is-on)))
                          :text (if text-func
                                    (text-func num)
                                    "o")
                          :text-color text-color
                          :selected-color #f
                          :prepend-checked-marker #f
                          :gradient-background #f
                          :right-mouse-clicked-callback (and right-mouse-clicked-callback
                                                             (lambda ()
                                                               (right-mouse-clicked-callback num)))
                          :delete-clicked-callback (and delete-clicked-callback
                                                        (lambda ()
                                                          (delete-clicked-callback num)))
                          :border-width border-width
                          :box-rounding box-rounding))
                 
                 (set! (radiobuttons num) checkbox)
  
                 (add-sub-area-plain! checkbox)))

  )

(define *button-is-pressing* (make-hash-table 10 eq?))
(define *button-is-pressing-num-stoppers* (make-hash-table 10 eq?))

(def-area-subclass (<button> :gui :x1 :y1 :x2 :y2
                             :paint-func #f
                             :text ""
                             :background-color #f
                             :statusbar-text #f
                             :callback #f
                             :callback-release #f
                             :right-mouse-clicked-callback #f
                             :delete-clicked-callback #f
                             :id #f)

  (define is-pressing #f)
  (define (is-pressing?)
    (if id
        (*button-is-pressing* id)
        is-pressing))

  (define (set-is-pressing! maybe)
    (if id
        (set! (*button-is-pressing* id) maybe)
        (set! is-pressing maybe))
    (update-me!))

  (define fontheight (get-fontheight))
  (define b (max 1 (myfloor (/ fontheight 2.5)))) ;; border
  
  (define r 3) ;;rounding
  (define r/2 2)

  (if (not background-color)
      (set! background-color "button_v2")) ;;(get-default-button-color gui)))

  (detect-hovering!)

  (define (mypaint)
    ;;(<gui> :filled-box gui background-color x1 y1 x2 y2)
    (draw-button gui (if (procedure? text) (text) text) (is-pressing?)
                 x1 y1 x2 y2
                 :selected-color "button_pressed_v2"
                 :background-color (if (procedure? background-color) (background-color) background-color)
                 :is-hovering is-hovering))

  (define (start-show-pressed!)
    (set-is-pressing! #t))

  (define (stop-show-pressed!)
    (if id
        (let ((num-stoppers (or (*button-is-pressing-num-stoppers* id)
                                0)))
          ;;(c-display "---------Num stoppers for" id ":" num-stoppers)
          (set! (*button-is-pressing-num-stoppers* id) (+ num-stoppers 1))))
    (<ra> :schedule 0
          (lambda ()
            (if id
                (let ((num-stoppers (or (*button-is-pressing-num-stoppers* id)
                                        1)))
                  (set! (*button-is-pressing-num-stoppers* id) (- num-stoppers 1))
                  (if (= 1 num-stoppers)
                      (set-is-pressing! #f)))
                (set-is-pressing! #f))                
            #f)))
    
  '(define (mypaint)
    (if (not (is-pressing?))
        (<gui> :filled-box gui background-color (+ x1 0) (+ y1 0) (- x2 0) (- y2 0) r r))
    
    (if (not (string=? "" text))
        (<gui> :draw-text
               gui
               *text-color*
               text
               (+ x1 3) (+ y1 2) (- x2 3) (- y2 2)
               #t ; wrap lines
               #f ; align left
               #f ; align top
               0  ; rotate
               #f ; cut text to fit
               #t ; scale font size
               ))
    (if is-pressing
        (<gui> :draw-box gui background-color (+ x1 r/2) (+ y1 r/2) (- x2 r/2) (- y2 r/2) b r r))

    (<gui> :draw-box gui "black" x1 y1 x2 y2 1.1 r r)
    )
    
  (define-override (paint)
    (if paint-func
        (paint-func gui x1 y1 x2 y2)
        (mypaint)))

  (if statusbar-text
      (add-statusbar-text-handler statusbar-text))

  (add-mouse-cycle! (lambda (button x* y*)
                      ;;(c-display "BUTTON:" button)
                      (cond ((and delete-clicked-callback
                                  (delete-button? button))
                             (delete-clicked-callback)
                             'eat-mouse-cycle)
                            ((and right-mouse-clicked-callback
                                  (= button *right-button*)
                                  (not (<ra> :shift-pressed))
                                  )
                             (right-mouse-clicked-callback)
                             'eat-mouse-cycle)
                            ((= button *left-button*)
                             ;;(set! is-pressing #t)
                             (<ra> :schedule 0
                                   (lambda ()
                                     (if callback
                                         (callback))
                                     #f))
                             (start-show-pressed!)
                             #t)
                            (else
                             #f)))
                    (lambda (button x* y*)
                      #t)
                    (lambda (button x* y*)
                      (stop-show-pressed!)
                      (cond ((and callback-release
                                  (= button *left-button*))
                             (callback-release)))
                      (update-me!))))


(def-area-subclass (<scrollbar> :gui :x1 :y1 :x2 :y2
                                :callback
                                :slider-pos
                                :slider-length ;; between 0 and 1. E.g. for 0.5; slider length = scrollbar length * 0.5. Can also be a function returning the slider length.
                                :vertical
                                :background-color "scroll_bar_background_v2" ;;"#224653" ;;#f
                                :paint-border #t
                                :border-color "black"
                                :border-rounding 0
                                :slider-color "scroll_bar_v2" ;;"#701040"
                                :slider-pressed-color #f ;;"#222222" ;;#f
                                :border-width #f
                                :mouse-press-callback #f
                                :mouse-release-callback #f
                                :is-moving #f
                                )

  (assert slider-length)
  
  (if (not slider-pressed-color)
      (set! slider-pressed-color (<gui> :mix-colors "#000000" slider-color 0.4)))

  (define b (if border-width
                border-width
                (/ (get-fontheight) 5.0)))

  (define (get-slider-length)
    (if (procedure? slider-length)
        (slider-length)
        slider-length))

  (define (set-legal-slider-pos! new-pos call-callback?)
    (set! slider-pos (between 0
                              new-pos
                              (- 1.0 (get-slider-length))))
    (if call-callback?
        (report!))
    (update-me!))

  (add-method! :get-slider-pos (lambda () slider-pos))

  (add-method! :set-slider-pos! set-legal-slider-pos!)
                 
  (define is-moving-internal #f)

  (define (is-moving?)
    (or (and is-moving
             (is-moving))
        is-moving-internal))
  
  (add-method! :is-moving is-moving)
                            
  (define-override (paint)
    (paint-scrollbar gui
                     slider-pos
                     (+ slider-pos (get-slider-length))
                     vertical
                     x1 y1 x2 y2
                     background-color
                     (if (is-moving?)
                         slider-pressed-color
                         slider-color)
                     slider-color
                     b
                     border-rounding))

  (define (report!)
    (callback slider-pos
	      (+ slider-pos (get-slider-length))))

  (define start-mouse-pos 0)
  
  (add-delta-mouse-cycle!
   (lambda (button x* y*)
     (and (= button *left-button*)
          (begin
            (if mouse-press-callback
                (mouse-press-callback))
            (set-mouse-pointer ra:set-closed-hand-mouse-pointer gui)
            ;;(c-display "start:" slider-pos)
            (set! start-mouse-pos slider-pos)
            (set! is-moving-internal #t)
            (update-me!)
            #t)))
   (lambda (button x* y* dx dy)
     (set-legal-slider-pos! (+ start-mouse-pos
                               (scale (if vertical dy dx)
                                      0 (if vertical
                                            (- height (* b 2))
                                            (- width (* b 2)))
                                      0 1))
                            #t))
   
   (lambda (button x* y* dx dy)
     (set-mouse-pointer ra:set-open-hand-mouse-pointer gui)
     (set! is-moving-internal #f)
     (update-me!)
     (if mouse-release-callback
         (mouse-release-callback))
     ;;(c-display "release button/x/y" x* y*)
     #f
     ))

  (add-raw-mouse-cycle!
   :enter-func (lambda (button x* y)
                 (if (any? a-sub-area-contains-active-raw-statusbar-text-mouse-cycle-handler? sub-areas)
                     #f
                     (let ()
                       (set-mouse-pointer ra:set-open-hand-mouse-pointer gui)
                       #t)))
   :leave-func (lambda (button x y)
                 '(if (not (is-moving?))
                      (set-mouse-pointer ra:set-normal-mouse-pointer gui))
                 #t
                 )
   :data 'mouse-pointerhandler)

;;(add-mouse-pointerhandler ra:set-open-hand-mouse-pointer)
  
  '(add-raw-mouse-cycle!
   :enter-func (lambda (button x* y)
                 (c-display "ENTER SCROLLBAR" class-name)
                 (set-mouse-pointer ra:set-open-hand-mouse-pointer gui)
                 #t)
   :leave-func (lambda (button x y)
                 (c-display "LEAVE SCROLLBAR")
                 (set-mouse-pointer ra:set-normal-mouse-pointer gui)))

  )

#!!
(begin
  (define testarea (make-qtarea))
  (define scrollbar (<new> :scrollbar (testarea :get-gui)
                           10 10 100 100
                           (lambda x (c-display "callback:" x))
                           0
                           0.2
                           #f
                           :background-color "white"
                           ))
  (testarea :add-sub-area-plain! scrollbar)
  (<gui> :show (testarea :get-gui)))
!!#

#!!
(def-area-subclass (<scroll-area> :gui :x1 :y1 :x2 :y2
                                  :child-area
                                  :dx 0
                                  :dy 0)

  (define vertical-scrollbar ...)
  (define horizontal-scrollbar ...)

  (define (update-areas!)
    (remove-sub-areas!)
    (add-sub-area! child-area (+ x1 dx) (+ y1 dy))
    (child-area :get-position
                (lambda (x1* y1* x2* y2* width* height*)
                  (if (> width* width)
                      (add-vertical-scrollbar))
                  (if (> height* height)
                      (add-horizontal-scrollbar))
                  ...))

    (update-me!)
    )

  (update-areas!)

  )
!!#


;; Deprecated. Use vertical-list-area2 instead.
(def-area-subclass (<vertical-list-area> :gui :x1 :y1 :x2 :y2
                                         :create-areas
                                         :scrollbar-color "#400010"
                                         :background-color #f
                                         :expand-area-widths #t
                                         )

  (define areas #f)
  
  (add-method! :get-areas (lambda ()
                            areas))
  
  (define total-area-height #f)
  (define slider-length 10)
  (define all-fits #t)  
  (define scrollbar-width 0)
  (define scrollbar-x1 x2)
  (define-optional-func scrollbar (key . rest))
  
  (define (scrollbar-callback pos1 pos2)
    (define pos1 (scale pos1
                        0 1
                        0 total-area-height))
    ;;(c-display "scrollbar-callback" pos1 pos2)
    (position-areas! (+ y1 (- pos1))))

  (define* (reload-areas! (num-tries 0))
    (define all-fitted all-fits)
    (remove-sub-areas!)
    (set! areas (create-areas x1 (if all-fits
                                     x2
                                     scrollbar-x1)))
    (set! total-area-height (apply + (map (lambda (area)
                                              (area :get-position (lambda (x1 y1 x2 y2 width height)
                                                                    height)))
                                            areas)))
    
    (set! slider-length (if (= 0 total-area-height)
                              1
                              (min 1 (/ height total-area-height))))
    
    (set! all-fits (>= slider-length 1))
    
    (set! scrollbar-width (if all-fits
                              0
                              (between 1
                                       (/ width 10)
                                       (min (average (<gui> :text-width "Xx")
                                                     (<gui> :text-width "x"))
                                            (/ width 2)))))
    
    (set! scrollbar-x1 (- x2 scrollbar-width))

    (if (or (not scrollbar)
            (not (eq? all-fits all-fitted)))
        (set! scrollbar (<new> :scrollbar
                               gui
                               scrollbar-x1 y1
                               x2 y2
                               scrollbar-callback
                               :slider-pos 0
                               :slider-length slider-length
                               :vertical #t
                               ;;:background-color background-color
                               )))

  ;;(scrollbar :resize! scrollbar-width height)
    
    (if (>= num-tries 10)
        (c-display "Warning: vertical-list-area::reload-areas! called recursively" num-tries "times"))
    
    (if (and (< num-tries 50)
             (not (eq? all-fits all-fitted)))
        (reload-areas! (+ num-tries 1))))


  (define-override (get-state)
    (hash-table ;;:areas areas
                :y1 y1
                :start-y1 (if (null? areas)
                              0
                              ((car areas) :get-position
                               (lambda (a-x1 a-y1 a-x2 a-y2 a-width a-height)
                                 a-y1)))
                :slider-pos (scrollbar :get-slider-pos)))
  
  (define-override (apply-state! state)
    (when (not all-fits)
      (if (not (state :y1))
          (c-display "           ERROR:" state)
          (begin
            (define dy (+ (state :start-y1) (- y1 (state :y1))))
            ;;(c-display "     apply-state!. Position dy:" dy)
            (scrollbar :set-slider-pos! (state :slider-pos) #t)))))

  ;;(reload-areas!)
  
  (define (position-areas! start-y1)
    (set! start-y1 (round start-y1))
    ;;(remove-sub-areas!)
;    (shallow-remove-sub-areas!) ;; TODO: Ensure effect monitors are removed.
    (reload-areas!)
    ;;(shallow-remove-sub-areas!)
    (add-sub-area-plain! scrollbar)
    (define i 1)
    (let loop ((areas areas)
               (area-y1 start-y1))
      (when (not (null? areas))
        (define area (car areas))
        (define area-y2 (+ area-y1 (area :get-height)))
        ;;(c-display "Area " i ": " area-y1 area-y2)
        (set! i (+ i 1))
        (if expand-area-widths
            (area :set-position-and-size! x1 area-y1 (- scrollbar-x1 0) area-y2)
            (area :set-position! x1 area-y1))
        (when (and (>= area-y2 y1)
                   (< area-y1 y2))          
          (add-sub-area-plain! area)
          ;;(display "Added :")
          ;;(area :get-position c-display)
          )
        (loop (cdr areas)
              area-y2))))

  (position-areas! y1)

  (define (get-total-areas-height)
    (apply + (map (lambda (area)
                    (area :get-position
                          (lambda (a-x1 a-y1 a-x2 a-y2 a-width a-height)
                            a-height)))
                  areas)))
  
  (define (scroll-area-to-top area)
    (scrollbar :set-slider-pos!
               (scale (area :get-position
                            (lambda (a-x1 a-y1 a-x2 a-y2 a-width a-height)
                              a-y1))
                      ((car areas) :get-position
                       (lambda (a-x1 a-y1 a-x2 a-y2 a-width a-height)
                         a-y1))
                      ((last areas) :get-position
                       (lambda (a-x1 a-y1 a-x2 a-y2 a-width a-height)
                         a-y2))
                      ;;(get-total-areas-height)
                      0 1)
               #t))

  (add-method! :ensure-area-is-visible
               (lambda (area)
                 (define (a-y1)
                   (area :get-position
                         (lambda (a-x1 a-y1 a-x2 a-y2 a-width a-height)
                           a-y1)))
                 (define (a-y2)
                   (area :get-position
                         (lambda (a-x1 a-y1 a-x2 a-y2 a-width a-height)
                           a-y2)))
                 (define (test-y1)
                   (< (a-y1) y1))
                 (define (test-y2)
                   (> (a-y2) y2))
                 
                 (define (run-loop test direction)
                   (let loop ((last (scrollbar :get-slider-pos))
                              (n 0))
                     (when (test)
                       (scroll! direction)
                       (let ((now (scrollbar :get-slider-pos)))
                         (if (and (not (= last now))
                                  (< n 10000))
                             (loop now (+ n 1)))))))                 
                 (cond ((test-y1)
                        (run-loop test-y1 #t))
                       ((test-y2)
                        (run-loop test-y2 #f)))))

  (define (scroll! is-up)
    (define is-down (not is-up))
    (define first-y1 (and (not (null? areas))
                          ((car areas) :get-position
                           (lambda (a-x1 a-y1 a-x2 a-y2 a-width a-height)
                             a-y1))))
    
    (define last-y2 (and (not (null? areas))
                         ((last areas) :get-position
                          (lambda (a-x1 a-y1 a-x2 a-y2 a-width a-height)
                            a-y2))))

    ;;(c-display "is-up:" is-up x* y* first-y1 last-y2)
    
    (call-with-exit
     (lambda (exit2)
       (let loop ((areas areas)
                  (n 0))
         (when (not (null? areas))
           (define area (car areas))
           (area :get-position
                 (lambda (a-x1 a-y1 a-x2 a-y2 a-width a-height)
                   (define (doit dy)
                     ;;(set! dy (* dy 4))
                     (define new-first-y1 (+ first-y1 dy))
                     (define new-last-y2 (+ last-y2 dy))
                     (position-areas! new-first-y1)
                     ;;(c-display "scrolling" n new-first-y1 new-last-y2)
                     (scrollbar :set-slider-pos!
                                (scale y1
                                       new-first-y1
                                       new-last-y2
                                       0 1)
                                #f)
                     (exit2))
                   (if is-up
                       (when (>= a-y2 (- y1 0.0001)) ;; subtracting 0.0001 to eliminate rounding error
                         ;;(c-display "  " n " how-much1:" (- y1 a-y1))
                         (doit (- y1 a-y1)))
                       (when (< y1 (- a-y2 0.0001)) ;; subtracting 0.0001 to eliminate rounding error
                         ;;(c-display "  " n " how-much2:" (- a-y2 y1))
                         (define dy (- last-y2 y2))                                                
                         (when (> (+ dy 0.0001) 0)
                           (set! dy (min dy (- a-y2 y1)))
                           (doit (- dy)))))))
           (loop (cdr areas)
                 (1+ n)
                 ))))))
    
  (define-override (mouse-wheel-moved-last is-up x* y*)
    (scroll! is-up)
    (scroll! is-up)
    (scroll! is-up)
    #t)
  )

(def-area-subclass (<vertical-list-area2> :gui :x1 :y1 :x2 :y2
                                          :num-sub-areas
                                          :get-sub-area-height ;; Either a number (if all sub-areas have the same height) or a function taking (area-num x1 x2) as arguments
                                          :create-sub-area ;; Function taking (area-num x1 x2) as arguments
                                          :sub-areas-can-be-cached #f
                                          :background-color #f
                                          :num-areas-to-mousewheel-scroll 3
                                          )

  (assert (not sub-areas-can-be-cached)) ;; There'a a bug here when using this. An error message pops up when scrolling.
  
  (if (number? get-sub-area-height)
      (set! get-sub-area-height (round get-sub-area-height)))

  (define (get-area-x2)
    (if all-fits
        x2
        (- scrollbar-x1 1)))
  
  (define areas (make-vector num-sub-areas #f))
  (define areas-used (make-vector num-sub-areas #f))

  (define area-heights (make-vector num-sub-areas #f))

  (define (get-area-height num)
    (if (number? get-sub-area-height)
        get-sub-area-height
        (let ()
          (define height (area-heights num))
          (if height
              height
              (let ((height (get-sub-area-height num x1 (get-area-x2))))
                (set! (area-heights num) height)
                height)))))

  (define area-y1s (make-vector num-sub-areas))
  (define area-y2s (make-vector num-sub-areas))

  (define (recreate-area-y12s! area-y1)
    (let loop ((num 0)
               (area-y1 area-y1))
      (when (< num num-sub-areas)
        (define height (get-area-height num))
        (define area-y2 (+ area-y1 height))
        (set! (area-y1s num) area-y1)
        (set! (area-y2s num) area-y2)
        (loop (+ 1 num)
              area-y2))))
                 
  
  (define total-area-height (let loop ((num 0)
                                       (total 0))
                              (if (= num num-sub-areas)
                                  total
                                  (loop (+ num 1)
                                        (+ total (get-area-height num))))))
  
  (define slider-length (if (= 0 total-area-height)
                            1
                            (min 1 (/ height total-area-height))))
  
  (define all-fits (>= slider-length 1))
  
  (define scrollbar-width (if all-fits
                              0
                              (between 1
                                       (/ width 10)
                                       (min (average (<gui> :text-width "Xx")
                                                     (<gui> :text-width "x"))
                                            (/ width 2)))))
  
  (define scrollbar-x1 (- x2 scrollbar-width))

  (define (scrollbar-callback pos1 pos2)
    (define pos1 (scale pos1
                        0 1
                        0 total-area-height))
    ;;(c-display "scrollbar-callback" pos1 pos2)
    (position-areas! (+ y1 (- pos1))))

  (define scrollbar (and (not all-fits)
                         (<new> :scrollbar
                                gui
                                scrollbar-x1 y1
                                x2 y2
                                scrollbar-callback
                                :slider-pos 0
                                :slider-length slider-length
                                :vertical #t
                                ;;:background-color background-color
                                )))
  
  (if scrollbar
      (add-sub-area-plain! scrollbar))

  (define-override (get-state)
    (hash-table :slider-pos (and scrollbar
                                 (scrollbar :get-slider-pos))))
  
  (define-override (apply-state! state)
    (when scrollbar
      (if (or (not state)
              (not (state :slider-pos)))
          (c-display "           ERROR:" state)
          (begin
            ;;(define dy (+ (state :start-y1) (- y1 (state :y1))))
            ;;(c-display "     apply-state!. Position dy:" dy)
            (scrollbar :set-slider-pos! (state :slider-pos) #t)))))

  (define (position-areas! start-y1)

    (set! start-y1 (round start-y1))
    
    (recreate-area-y12s! start-y1)

    (define (add! num area-y1)
      ;;(c-display "ADDING" num area-y1 ". used:" (area-used num))
      (define area (areas num))
      (if area
          (if (areas-used num)
              (area :set-position! x1 area-y1)
              (begin
                (assert sub-areas-can-be-cached)
                (set! (areas-used num) #t)
                (add-sub-area! area x1 area-y1)))
          (let ((area (create-sub-area num x1 (get-area-x2))))
            (if sub-areas-can-be-cached
                (assert (null? (area :get-sub-areas))))
            (add-sub-area! area x1 area-y1)
            (set! (areas num) area)
            (set! (areas-used num) #t))))
      
    (define (remove! num)
      (define area (areas num))
      (when area
        ;;(c-display "REMOVING" num)
        (remove-sub-area! area)
        (set! (areas-used num) #f)
        (if (not sub-areas-can-be-cached)
            (set! (areas num) #f))))
      
    (let loop ((num 0)
               (area-y1 start-y1))
      ;;(c-display "    loop. num/area-y1/y2: " num area-y1 y2)
      (if (and (< num num-sub-areas)
               (< area-y1 y2))
          (begin
            (define area-y2 (+ area-y1 (get-area-height num)))
            (cond ((> area-y2 y1)
                   (add! num area-y1))
                  ((areas num)
                   (remove! num)))
            (loop (+ num 1)
                  area-y2))
          (let loop ((num num))
            (when (< num num-sub-areas)
              (remove! num)
              (loop (+ 1 num)))))))
          
  
  (position-areas! y1)

  (define (get-largest-area-y1)
    (- y2 total-area-height))
    
  (define (set-area-at-top! num)
    ;;(c-display "       SETTING AT TOP:" num)
    (define first-y1 (area-y1s 0))
    (define a-y1 (area-y1s num))
    (define dy (- a-y1 first-y1))
    (position-areas! (max (get-largest-area-y1)
                          (- y1 dy))))
     
  (define (scroll-up!)
    (when (not all-fits)
      (let loop ((num 0))
        (when (< num num-sub-areas)
          (define a-y1 (area-y1s num))
          ;;(define a-y2 (area-y2s num))
          ;;(c-display "a-y1 / y1:" a-y1 y1)
          (if (>= (- a-y1 0.001) y1)
              (begin
                (set-area-at-top! (max 0 (- num num-areas-to-mousewheel-scroll)))
                (scrollbar :set-slider-pos!
                           (scale y1
                                  (area-y1s 0)
                                  (area-y2s (- num-sub-areas 1))
                                  0 1)
                           #f)
                )
              (loop (+ num 1)))))))
        
  (define (scroll-down!)
    (when (not all-fits)
      (let loop ((num 0))
        (when (< num num-sub-areas)
          (define a-y1 (area-y1s num))
          ;;(define a-y2 (area-y2s num))
          ;;(c-display "a-y1 / y1:" a-y1 y1)
          (if (>= (- a-y1 0.001) y1)
              (begin
                (set-area-at-top! (min (- num-sub-areas 1)
                                       (+ num num-areas-to-mousewheel-scroll)))
                (scrollbar :set-slider-pos!
                           (scale y1
                                  (area-y1s 0)
                                  (area-y2s (- num-sub-areas 1))
                                  0 1)
                           #f)
                )
              (loop (+ num 1)))))))

  (define (scroll! is-up)
    (if is-up
        (scroll-up!)
        (scroll-down!)))
    
  (define-override (mouse-wheel-moved-last is-up x* y*)
    (scroll! is-up)
    #t)
  )

#!!
(when (defined? 'horizontally-layout-areas)
  (define (recreate gui width height state)
    (define area
      (<new> :vertical-list-area gui 0 0 width height
           (map (lambda (i)
                  (define blocknum i)
                  (define color ;;(<ra> :get-block-color blocknum))
                    (<gui> :mix-colors
                           (<ra> :get-block-color blocknum)
                           "white" ;;(<gui> :get-background-color -1)
                           0.95))
                  (define line
                    (<new> :text-area gui
                           10 0 100 (* 1.2 (get-fontheight))
                           (lambda ()
                             (if (< i (<ra> :get-num-blocks))
                                 (<-> i ": " (<ra> :get-block-name i))
                                 ""))
                           :text-color "sequencer_text_color"
                           :background-color (lambda ()
                                               (if (= (<ra> :current-block) i)
                                                   (<gui> :mix-colors color "green" 0.1)
                                                   color))
                           :align-left #t))
                  (line :add-mouse-cycle!
                        (lambda (button x* y*)
                          ;;(c-display "hepp" i)
                          (line :get-position
                                (lambda (x1 y1 x2 y2 width height)
                                  (<gui> :create-block-drag-icon gui (floor width) (floor height) (floor (- x* x1)) (floor (- y* y1)) i
                                         (lambda (gui width height)
                                           ;;(c-display "-------w2: " width height)
                                           (line :paint-text-area gui 0 0 width height)
                                           ;;(<gui> :draw-line gui "black" 5 3 10 5 20)
                                           ))))
                          #t)
                        (lambda (button x* y*)
                          #t)
                        (lambda (button x* y*)
                          #t))
                  line)
                (iota (<ra> :get-num-blocks)))))
    (if state
        (area :apply-state! state))
    area)

  (define testarea (make-qtarea :width 452 :height 750
                                :sub-area-creation-callback recreate))
  (<gui> :show (testarea :get-gui))
  )
!!#
#!!
(when (defined? 'horizontally-layout-areas)
  (define (recreate gui width height state)
    (define audiofiles (to-list (<ra> :get-audio-files)))
    (<new> :vertical-list-area gui 0 0 width height
           (map (lambda (i audiofile)
                  (define color (<gui> :mix-colors
                                       (<ra> :get-audiofile-color audiofile)
                                       "white"
                                       0.65))
                  (define line
                    (<new> :text-area gui
                           10 0 100 (* 1.2 (get-fontheight))
                           (lambda ()
                             (<-> i ": " (<ra> :get-path-string audiofile)))
                           :text-color "sequencer_text_color"
                           :background-color color
                           :align-left #t))
                  (line :add-mouse-cycle!
                        (lambda (button x* y*)
                          ;;(c-display "hepp" i)
                          (line :get-position
                                (lambda (x1 y1 x2 y2 width height)
                                  (<gui> :create-file-drag-icon gui (floor width) (floor height) (floor (- x* x1)) (floor (- y* y1)) audiofile
                                         (lambda (gui width height)
                                           ;;(c-display "-------w2: " width height)
                                           (line :paint-text-area gui 0 0 width height)
                                           ;;(<gui> :draw-line gui "black" 5 3 10 5 20)
                                           ))))
                          #t)
                        (lambda (button x* y*)
                          #t)
                        (lambda (button x* y*)
                          #t))
                  line)
                (iota (length audiofiles))
                audiofiles)))

  (define testarea (make-qtarea :width 450 :height 750
                                :sub-area-creation-callback recreate))
  (<gui> :show (testarea :get-gui))
  )
!!#


#!!
(begin
  ;(def-area-subclass (<text-area> :gui :x1 :y1 :x2 :y2 :text)
  ;  (define-override (paint)
  ;    (<gui> :draw-text gui *text-color* text (+ x1 (get-fontheight)) y1 x2 y2
  ;           #f ;wrap-lines 
  ;           #f ;align-top 
  ;           #t ;align-left
  ;           )
  ;    (<gui> :draw-box gui "black" x1 y1 x2 y2 1.5 2 2)))
      
  (define testarea (make-qtarea :width 150 :height 450))
  (define list-area (<new> :vertical-list-area (testarea :get-gui) 10 20 150 400
                           (map (lambda (i)
                                  (<new> :text-area (testarea :get-gui)
                                         10 0 100 (* 1.2 (get-fontheight))
                                         (<-> i ": hello")
                                         :align-left #t))
                                (iota 20))
                           ))
  (testarea :add-sub-area-plain! list-area)
  (<gui> :show (testarea :get-gui))
  )
(show-async-message :text "hello")

(<ra> :get-path "/tmpwef")

(<ra> :iterate-directory (<ra> :get-path "/home/kjetil") #t
      (lambda (is-final file-info)
        (if (and (not is-final)
                 (file-info :is-audiofile))
            (c-display "file-info:" file-info))
        #t))
(<ra> :iterate-directory "L3RtcA==" #f c-display)
!!#


(define (get-block-table-entry-text blocknum)
  (<-> (if (< blocknum 10) " " "") blocknum ": " (<ra> :get-block-name blocknum)))


(def-area-subclass (<seqblock-table-entry-area> :gui :x1 :y1 :x2 :y2
                                                :is-current
                                                :entry-num
                                                :file-info #f
                                                :blocknum #f
                                                :allow-dragging #f
                                                :background-color #f
                                                :callback #f)
  
  (assert (or file-info blocknum))

  (detect-hovering!)

  (define (is-current?)
    (if (procedure? is-current)
        (is-current)
        is-current))
  
  (define (get-text-color)
    (cond ((is-current?)
           "sequencer_text_current_block_color")
          ;;*text-color*)
          (blocknum
           "sequencer_text_color")
          ((file-info :is-dir)
           *text-color*)
          (background-color
           "black")
          (else
           "soundfile"
           )))
  
  (define ch-color "black")
  (define size-color (if background-color
                         "black"
                         *text-color*)) ;;"#081040")

  (define is-dir (and file-info (file-info :is-dir)))
  (define is-soundfile (and file-info (file-info :is-audiofile)))

  (define name-text (if blocknum
                        (<ra> :to-base64 (get-block-table-entry-text blocknum))
                        (let ((filename (<ra> :get-base64-from-filepath (file-info :filename))))
                          (if (and is-dir
                                   ;;(not (string=? "." filename))
                                   ;;(not (string=? ".." filename))
                                   )
                              (<ra> :append-base64-strings filename (<ra> :to-base64 "/"))
                              filename))))
    
  (define ch-text (cond (blocknum
                         (<-> (<ra> :get-num-tracks blocknum) "tr"))
                        (is-soundfile 
                         (<-> (file-info :num-ch) "ch"))
                        (else                         
                         "")))

  (define size-text (cond ((or blocknum is-soundfile)
                           (let ((s (if blocknum
                                        (/ (/ (<ra> :get-block-length blocknum)
                                              (<ra> :get-sample-rate))
                                           (<ra> :get-reltempo blocknum))
                                        (/ (file-info :num-frames)
                                           (file-info :samplerate)))))
                             (get-displayable-seconds s)))
                          (is-dir
                           "")
                          (else
                           (<-> (one-decimal-string (/ (file-info :size)
                                                       (* 1024 1024)))
                                "MB"))))

  (add-method! :set-current! (lambda (doit)
                               (set! is-current doit)
                               (update-me!)))

  (add-mouse-cycle! (lambda (button x* y*)
                      (define gotit #f)
                      (if callback
                          (set! gotit (callback button x* y* entry-num)))
                      (if gotit
                          #t
                          (and (= button *left-button*)
                               (begin
                                 ;;(set! dragging-entry (make-dragging-entry))
                                 ;;(<gui> :show dragging-entry)
                                 ;;(move-dragging-entry!)
                                 ;;(c-display "w: " width height)
                                 ;;(c-display "file-info:" file-info)
                                 (cond (blocknum
                                        (<gui> :create-block-drag-icon gui (floor width) (floor height) (floor (- x* x1)) (floor (- y* y1)) blocknum
                                               (lambda (gui width height)
                                                 ;;(c-display "-------w2: " width height)
                                                 ;;(<gui> :filled-box gui "#00000000" 0 0 width height 0 0 *no-gradient*) ;; fill with transparent background
                                                 (paint2 gui -1 0 width height)
                                                 ;;(line :paint-text-area gui 0 0 width height)
                                                 ;;(<gui> :draw-line gui "black" 5 3 10 5 20)
                                                 )))
                                       ((and (not (file-info :is-dir))
                                             allow-dragging)
                                        (<gui> :create-file-drag-icon gui (floor width) (floor height) (floor (- x* x1)) (floor (- y* y1)) (file-info :path)
                                               (lambda (gui width height)
                                                 (c-display "-------w2: " width height)
                                                 (paint2 gui -1 0 width height)
                                                 ))))
                                 #t))))
                    (lambda (button x* y*)
                      ;;(move-dragging-entry!)
                      #t)
                    (lambda (button x* y*)
                      ;;(<gui> :close dragging-entry)
                      ;;(<gui> :hide dragging-entry)
                      ;;(set! dragging-entry #f)
                      ;;(drop-callback (<ra> :get-mouse-pointer-x) (<ra> :get-mouse-pointer-y))
                      #t))

  (define (paint2 gui x1 y1 x2 y2)
    (define default-size-x1 (- x2 (<gui> :text-width "2.99m" gui)))
    (define ch-x1 (- default-size-x1 (<gui> :text-width "2ch" gui)))
    (define name-x2 (- ch-x1 (<gui> :text-width " " gui)))
    (define ch-x2 (- default-size-x1 (<gui> :text-width " " gui)))

    (define size-x1 (max default-size-x1 (- x2 (<gui> :text-width size-text gui))))

    (define entry-background-color (if background-color
                                       background-color
                                       "low_background"))

    (if is-hovering
        (set! entry-background-color (<gui> :make-color-lighter entry-background-color 1.2)))
    
    ;;(set! entry-background-color (<gui> :set-alpha-for-color entry-background-color 0.05)))

    ;;(if is-current
    ;;    (set! entry-background-color (<gui> :mix-colors entry-background-color "green" 0.1)))

    ;;(<gui> :filled-box gui (<gui> :get-background-color gui) (+ 1 x1) y1 x2 y2 4 4)
    (<gui> :filled-box gui
           entry-background-color
           (+ 1 x1) y1 (- x2 2) y2 4 4
           (if background-color *gradient-vertical-light-top* *no-gradient*))

    ;; name
    (<gui> :draw-text gui (get-text-color) name-text
           (+ 4 x1) y1
           (if is-dir x2 name-x2) y2
           #f ;; wrap lines
           #f ;; align-top
           #t ;; align-left
           0 ;; rotate
           #t ;; cut-text-to-fit
           #f ;; scale-font-size
           #t ;; text is base64
           )

    (cond ((or blocknum
               is-soundfile)
           ;; ch
           (<gui> :draw-text gui ch-color ch-text
                  ch-x1 y1
                  ch-x2 y2
                  #f ;; wrap lines
                  #f ;; align-top
                  #t ;; align-left
                  0 ;; rotate
                  #f ;; cut-text-to-fit
                  #t ;; scale-font-size
                  )
           
           ;; duration
           (<gui> :draw-text gui size-color size-text
                  size-x1 y1
                  x2 y2
                  #f ;; wrap lines
                  #f ;; align-top
                  #t ;; align-left
                  0 ;; rotate
                  #f ;; cut-text-to-fit
                  #t ;; scale-font-size
                  ))

          ((not is-dir)
           ;; size
           (<gui> :draw-text gui size-color size-text
                  ch-x1 y1
                  x2 y2
                  #f ;; wrap lines
                  #f ;; align-top
                  #f ;; align-left
                  0 ;; rotate
                  #t ;; cut-text-to-fit
                  #f ;; scale-font-size
                  )))

    (when (is-current?)

      ;; Why was this line here?
      ;;(<gui> :set-clip-rect gui (+ x1 1) y1 x2 y2)
      
      (<gui> :draw-box gui "sequencer_text_current_block_color" (+ 0.5 x1) (+ y1 0.5) (- x2 1) (- y2 1) 1.9 4 4) ;;2 2)
      ;;(<gui> :set-clip-rect gui cx1 cy1 cx2 cy2)
      )

    (<gui> :draw-box gui "black" (+ 1 x1) y1 x2 y2 0.5 4 4)
    )
  
  (define-override (paint)
    (paint2 gui x1 y1 x2 y2))
  )

;; TODO: Right-click options/double click: "Insert/append new audio seqtrack for this audio file".  
(def-area-subclass (<file-browser> :gui :x1 :y1 :x2 :y2
                                   :path
                                   :id-text
                                   :only-audio-files #f
                                   :state #f)

  (define num-settings-buttons 9)

  (define curr-settings-num (string->number (<ra> :get-settings (<-> "filebrowser_" id-text "_curr-settings-num") "0")))
  (define curr-entry-num 0)

  (set! path (<ra> :get-settings-f (<-> "filebrowser_" id-text "_" curr-settings-num) path))
  
  (define entries '())
  (define file-browser-entries '())

  (define-optional-func vertical-list-area (key . rest))

  (define states (make-vector num-settings-buttons #f))

  (set! font (<ra> :get-sample-browser-font #f))

  (define (store-curr-entry-state!)
    (set! (states curr-settings-num)
          (hash-table :path path
                       :entries entries
                       :entries-is-complete entries-is-complete
                       :vertical-list-area-state (and vertical-list-area
                                                      (vertical-list-area :get-state))
                       )))
    
  (define-override (get-state)
    (store-curr-entry-state!)
    (hash-table :curr-settings-num curr-settings-num
                :states states))

  (define (apply-state2! state)
    (set! path (state :path))
    ;;(c-display "          Apply state. Complete state:" (state :entries-is-complete))
    (if (state :entries-is-complete)
        (begin
          (set! entries (state :entries))
          (set! entries-is-complete #t)
          (inc! update-num 1)
          (update-areas!)
          (let ((vla-state (state :vertical-list-area-state)))
            (if (and vla-state vertical-list-area)
                (vertical-list-area :apply-state! vla-state))))
        (update-directory!)))
    
  (define-override (apply-state! state)
    ;;(c-display "apply-state:" state)
    (set! curr-settings-num (state :curr-settings-num))
    (set! states (state :states))
    (apply-state2! (states curr-settings-num)))

  (delafina (set-new-path! :new-path
                           :store-setting #t)
    (define old-path path)
    (let loop ((new-path new-path)
               (n 0))
      (set! path new-path)
      (set! curr-entry-num 0)
      (set! entries '())
      (set! file-browser-entries '())
      (c-display "         Calling 2")
      (if (not (update-directory!))
          (if (< n 5)
              (if (= n 0)
                  (loop old-path 1)
                  (loop (<ra> :get-home-path) 1)))
          (<ra> :put-settings-f (<-> "filebrowser_" id-text "_" curr-settings-num) path))))
    
  (define (set-new-curr-entry! new-curr-entry-num)
    (when (not (null? entries))
      (c-display "selected:" new-curr-entry-num ".old:" curr-entry-num)
      (c-display "entry:" (file-browser-entries curr-entry-num))
      (define file-info (entries new-curr-entry-num))
      
      (if (file-info :is-dir)
          (set-new-path! (file-info :path))
          (begin
            (file-browser-entries curr-entry-num :set-current! #f)
            (set! curr-entry-num new-curr-entry-num)
            (file-browser-entries curr-entry-num :set-current! #t)))
      ))
  
  (define (update-areas!)
    ;;(c-display "\n\n\n---------------------- num entries:" (length entries) "-----------------------\n\n\n")
    (remove-sub-areas!)

    (define border 1)

    (define pathline-y1 (+ y1 (get-fontheight) border))

    (define (get-settings num)
      (<ra> :get-settings-f (<-> "filebrowser_" id-text "_" num) path))
    
    (define radiobuttons
      (<new> :radiobuttons gui x1 y1 x2 (- pathline-y1 border)
             num-settings-buttons
             curr-settings-num
             (lambda (num is-on)
               (c-display "numison:" num is-on)
               (when is-on
                 (store-curr-entry-state!)
                 (set! curr-settings-num num)
                 (<ra> :put-settings (<-> "filebrowser_" id-text "_curr-settings-num") (<-> num))
                 (let ((state (states curr-settings-num)))
                   (if state
                       (apply-state2! state)
                       (set-new-path! (get-settings num)
                                      :store-setting #f))))
               #t)
             #t
             :text-func (lambda (num)
                          (<-> num))))
    (add-sub-area-plain! radiobuttons)

    (for-each (lambda (num)
                ((radiobuttons :get-radiobutton num) :add-statusbar-text-handler
                 (lambda ()
                   (define path (get-settings num))
                   (list #t
                         (<-> num ": " (<ra> :get-path-string path))))))
              (iota num-settings-buttons))
    
    (define button-width (* 2 (<gui> :text-width "R")))
    (define reload-x1 (+ x1 button-width border))
    (define line-input-x1 (+ reload-x1 button-width border))

    (define browser-y1 (+ pathline-y1 (get-fontheight) border))

    (add-sub-area-plain! (<new> :button gui x1 pathline-y1 (- reload-x1 border) (- browser-y1 border)
                                :text "⇧"
                                :callback-release
                                (lambda ()
                                  (set-new-path! (<ra> :get-parent-path path)))))

    (add-sub-area-plain! (<new> :button gui reload-x1 pathline-y1 (- line-input-x1 border) (- browser-y1 border)
                                :text "↻"
                                :callback-release
                                (lambda ()
                                  (set-new-path! path))))

    (define line-input (<new> :line-input gui line-input-x1 pathline-y1 x2 (- browser-y1 border)
                              :prompt ""
                              :text (<ra> :get-base64-from-filepath path)
                              :get-wide-string #t
                              :callback
                              (lambda (new-name)
                                (if (string=? new-name "")
                                    (<ra> :get-base64-from-filepath path)
                                    (begin
                                      (c-display "new-name: -" new-name "-" (<ra> :from-base64 new-name) "-")
                                      (set-new-path! (<ra> :get-filepath-from-base64 new-name))
                                      new-name)))))
                                
    (add-sub-area-plain! line-input)

    (set! file-browser-entries
          (map (lambda (entry entry-num)
                 (<new> :seqblock-table-entry-area gui 
                        0 0 10 (* 1.2 (get-fontheight))
                        (= entry-num curr-entry-num)
                        entry-num
                        :file-info entry
                        :allow-dragging #t
                        :background-color #f
                        :callback 
                        (lambda (button x y entry-num)
                          (if (= button *right-button*)
                              #t
                              (begin
                                (set-new-curr-entry! entry-num)
                                #f)))
                        ))
               entries
               (iota (length entries))
               ))

    (set! vertical-list-area (<new> :vertical-list-area gui x1 browser-y1 x2 y2 (lambda (x1 x2) file-browser-entries)))
    (add-sub-area-plain! vertical-list-area)
    )
  
  (update-areas!) ;; necessary in case there are no entries. (fix: update-directory! probably doesn't update if there is no entries in dir)

  (define entries-is-complete #f)
  (define update-num 0) ;; Used to be able to cancel previous ra:iterate-directory iterations.
  
  (define (update-directory!)
    (inc! update-num 1)
    ;;(c-display "Updating path: -" (<ra> :get-path-string path) "-. id:" id ". update-num:" update-num)
    (let ((last-time (time))
          (temp '())
          (curr-update-num update-num))
      (<ra> :iterate-directory path #t
            (lambda (is-finished file-info)
              ;;(c-display "file-info:" file-info)
              (cond ((not is-alive)
                     ;;(c-display "   Abort: not alive. curr:" curr-update-num ". update-num:" update-num ". id:" id)
                     #f)
                    ((not (= curr-update-num update-num))
                     ;;(c-display "   Abort: Not update. curr:" curr-update-num ". update-num:" update-num ". id:" id)
                     #f)  ;; There has been a later call to ra:iterate-directory.
                    (else
                     (set! entries-is-complete #f)
                     (if (and (not is-finished)
                              (or (not only-audio-files)
                                  (file-info :is-dir)
                                  (file-info :is-audiofile)))
                         (set! temp (cons file-info temp)))
                     ;;(c-display "timeetc." time last-time (> (time) (+ last-time 50)))
                     (when (or is-finished
                               (and (not (null? temp))
                                    (> (time) (+ last-time 50))))
                       (set! entries (sort (append entries temp)
                                           (lambda (a b)
                                             (define is-dir-a (a :is-dir))
                                             (define is-dir-b (b :is-dir))
                                             (if (eq? is-dir-a is-dir-b)
                                                 (string<? (<ra> :get-path-string (a :filename))
                                                           (<ra> :get-path-string (b :filename)))
                                                 is-dir-a))))
                       (if is-finished
                           (set! entries-is-complete #t))
                       (set! temp '())
                       (update-areas!)
                       (set! last-time (time))
                       )
                     #t))))))

  (if state
      (apply-state! state)
      (update-directory!)
      )
  
  )

#!!
(when (defined? 'horizontally-layout-areas)
  (define (recreate gui width height state)
    (define list-area (<new> :file-browser gui 10 20 (- width 10) (- height 20)
                             :path (<ra> :get-path "/home/kjetil/") ;;radium/bin/sounds")
                             :id-text "test"
                             :only-audio-files #t
                             :state state
                             ))
    list-area)
  ;;(testarea :add-sub-area-plain! list-area)

  (define testarea (make-qtarea :width 450 :height 750
                                :sub-area-creation-callback recreate))
  (<gui> :show (testarea :get-gui))
  )
!!#

(def-area-subclass (<tabs> :gui :x1 :y1 :x2 :y2
                           :is-horizontal
                           :curr-tab-num
                           :tab-names
                           :state
                           :get-tab-area-func)

  (define num-tabs (length tab-names))
  (define tab-bar-height (* (<ra> :get-tab-bar-height) (get-fontheight)))

  (define tab-bar-x2 (if is-horizontal
                       x2
                       (+ x1 tab-bar-height)))
  (define tab-bar-y2 (if is-horizontal
                         (+ y1 tab-bar-height)
                         y2))

  (define sub-x1 (if is-horizontal
                     x1
                     (+ x1 tab-bar-height)))
  (define sub-y1 (if is-horizontal
                     (+ y1 tab-bar-height)
                     y1))

  (define hovered-tab-num -1)
  
  (define-optional-func tab-area (key . rest))

  (define tab-states (make-vector num-tabs #f))

  (define-override (get-state)
    (set! (tab-states curr-tab-num) (tab-area :get-state))
    (hash-table :curr-tab-num curr-tab-num
                :tab-states tab-states))

  (define-override (apply-state! state)
    (set! curr-tab-num (state :curr-tab-num))
    (set! tab-states (state :tab-states))
    (recreate-areas!))

  (define-override (paint)
    (paint-tab-bar gui x1 y1 tab-bar-x2 tab-bar-y2
                   is-horizontal
                   tab-names
                   curr-tab-num
                   #f ;;:background-color (<gui> :mix-colors (<gui> :get-background-color gui) "red" 0.95)
                   hovered-tab-num
                   ))

  (define (recreate-areas!)
    (remove-sub-areas!)
    (set! tab-area (get-tab-area-func curr-tab-num
                                      sub-x1 sub-y1
                                      x2 y2
                                      (tab-states curr-tab-num)
                                      ))
    (add-sub-area-plain! tab-area)
    (update-me!))

  (define (get-tab-num x* y*)
    (call-with-exit
     (lambda (return)
       (for-each (lambda (tab-num)
                   (get-tab-coords is-horizontal tab-num num-tabs x1 y1 tab-bar-x2 tab-bar-y2
                                   (lambda (x1 y1 x2 y2)
                                     ;;(c-display "x*/y*:" x* y* ". x1/y1/x2/y2:" x1 y1 x2 y2)
                                     (if (and (>= x* x1)
                                              (< x* x2)
                                              (>= y* y1)
                                              (< y* y2))
                                         (return tab-num)))))
                 (iota num-tabs))
       -1)))
  
  (add-mouse-pointerhandler ra:set-normal-mouse-pointer)
  
  (add-raw-mouse-cycle!
   :move-func (lambda (button x* y*)
                (define tab-num (get-tab-num x* y*))
                (when (not (= tab-num hovered-tab-num))
                  (set! hovered-tab-num tab-num)
                  (update-me!))
                #f))
  
  (add-mouse-cycle! :press-func (lambda (button x* y*)
                                  (and (= button *left-button*)
                                       (let ((tab-num (get-tab-num x* y*)))
                                         (if (>= tab-num 0)
                                             (begin
                                               (when (not (= tab-num curr-tab-num))
                                                 (set! (tab-states curr-tab-num) (tab-area :get-state))
                                                 (set! curr-tab-num tab-num)
                                                 (recreate-areas!))
                                               #t)
                                             #f)))))
  
  
  ;;(c-display "STATE:" state)
  (if state
      (apply-state! state)
      (recreate-areas!))
  )

#!!
(when (defined? 'horizontally-layout-areas)
  (define (recreate gui width height state)
    (define list-area (<new> :tabs gui 10 20 (- width 10) (- height 20)
                             :is-horizontal #f
                             :curr-tab-num 0
                             :tab-names '("Hide" "Blocks" "Audio files" "File Browser")
                             :get-tab-area-func
                             (lambda (tab-num x1 y1 x2 y2 state)
                               (if (< tab-num 2)
                                   (<new> :button gui x1 y1 x2 y2
                                          :text (<-> "ai:" tab-num))
                                   (<new> :file-browser gui x1 y1 x2 y2
                                          :path (<ra> :get-path "/home/kjetil/") ;;radium/bin/sounds")
                                          :id-text "test"
                                          :only-audio-files #t
                                          :state state
                                          )))
                             ))
    list-area)
  ;;(testarea :add-sub-area-plain! list-area)

  (define testarea (make-qtarea :width 450 :height 750
                                :sub-area-creation-callback recreate))
  (<gui> :show (testarea :get-gui))
  )
!!#

#!!
(when (defined? 'horizontally-layout-areas)
  (define (recreate gui width height state)
    (define list-area (<new> :tabs gui 10 20 (- width 10) (- height 20)
                             :is-horizontal #f
                             :curr-tab-num 0
                             :tab-names '("tab1" "tab2" "browser")
                             :get-tab-area-func
                             (lambda (tab-num x1 y1 x2 y2)
                               (if (< tab-num 2)
                                   (<new> :button gui x1 y1 x2 y2
                                          :text (<-> "ai:" tab-num))
                                   (<new> :file-browser gui x1 y1 x2 y2
                                          :path (<ra> :get-path "/home/kjetil/") ;;radium/bin/sounds")
                                          :id-text "test"
                                          :only-audio-files #t
                                          )))
                             ))
    list-area)
  ;;(testarea :add-sub-area-plain! list-area)

  (define testarea (make-qtarea :width 450 :height 750
                                :sub-area-creation-callback recreate))
  (<gui> :show (testarea :get-gui))
  )
  
!!#



(define-struct table-area-column
  :name
  :width ;; Can also be a string, for instance "Hello hello". Used to approximate the width.
  :max-width ;; Can also be #f.
  :keyword ;; The keyword used to get the column value out of a row hash table.
  :value-format ;; A symbol. Used to know how to sort. Must be either string, number, boolean, or undefined. (If "undefined", the column won't/can't be sorted)
  :create-area #f ;; A function taking a row entry and a column value as arguments. The function returns an area for this column. If #f, a simple text area will be created instead.
)

(delafina (get-table-column-widths :columns
                                   :space-left 
                                   :column-widths #f
                                   :counter 0)

  (if (not column-widths)
      (set! column-widths (make-list (length columns) 0)))
  
  (define (can-be-expanded? column-width column)
    (if (not (column :max-width))
         #t
         (< column-width (column :max-width))))
    
    (define columns-that-can-be-expanded (map cadr
                                              (keep2 can-be-expanded?
                                                     column-widths
                                                     columns)))
                                                 
    (define num-columns-to-be-expanded (length columns-that-can-be-expanded))
    
    (define total-weight (apply + (map (lambda (column)
                                         (column :width))
                                       columns-that-can-be-expanded)))

    (define new-space-left 0)
    
    (define new-widths (map (lambda (column-width column)
                              (if (can-be-expanded? column-width column)
                                  (let ((new-width (+ column-width
                                                      (* space-left
                                                         (/ (column :width)
                                                            total-weight)))))
                                    (if (and (column :max-width)
                                             (> new-width (column :max-width)))
                                        (begin
                                          (inc! new-space-left (- new-width (column :max-width)))
                                          (column :max-width))
                                        new-width))
                                  column-width))
                            column-widths
                            columns))
    
    ;;(c-display ":old " column-widths ". :new" new-widths ". :old-space-left" space-left ". :new-space-left" new-space-left ". :total-weight" total-weight ". num-to-be-expanded:" num-columns-to-be-expanded)
    
    (if (and (> new-space-left 0.5)
             (< counter 1000)) ;; safety
        (get-table-column-widths columns new-space-left new-widths (+ counter 1))
        new-widths))

(define (sort-table-rows! column rows do-down)
  (define keyword (symbol->keyword (column :keyword)))
  (define less-than? (cond ((eq? (column :value-format) 'number)
                            (if do-down
                                (lambda (a b)
                                  (< (a keyword)
                                     (b keyword)))
                                (lambda (a b)
                                  (< (b keyword)
                                     (a keyword)))))
                           ((eq? (column :value-format) 'string)
                            (if do-down
                                (lambda (a b)
                                  (string<? (a keyword)
                                            (b keyword)))
                                (lambda (a b)
                                  (string<? (b keyword)
                                            (a keyword)))))
                           ((eq? (column :value-format) 'boolean)
                            (if do-down
                                (lambda (a b)
                                  (and (not (a keyword))
                                       (b keyword)))
                                (lambda (a b)
                                  (and (not (b keyword))
                                       (a keyword)))))
                           (else
                            #f)))
  (if less-than?
      (sort! rows less-than?)
      rows))


(def-area-subclass (<table> :gui :x1 :y1 :x2 :y2
                            :columns ;; A list of table-area-column structs
                            :rows ;; Either a vector of rows, or a function returning a vector of rows.
                            )

  (define fontheight (get-fontheight))
  (define entry-height (round (* 1.2 fontheight)))
  
  (define border 1)
  
  (define header-y2 (round (+ y1 (* 1.2 fontheight))))
  
  (define entries-y1 (+ header-y2 border))
  
  (set! rows (let ((rows (if (procedure? rows)
                             (rows)
                             rows)))
               (for-each (lambda (row num)
                           (set! (row :num) num))
                         rows
                         (iota (vector-length rows)))
               rows))

  (define num-rows (length rows))

  (let ((num-width (<-> (+ 1 num-rows))))
    (set! columns (cons (make-table-area-column "#"
                                                num-width
                                                num-width
                                                #f
                                                'undefined)
                        ;(lambda (gui x1 y1 x2 y2 entry num)
                        ;                            (<new> :text-area gui x1 y1 x2 y2
                        ;                                   :text (<-> num))))
                        columns)))

  ;; Convert :width and :max-width into numbers
  (let ((text-border (* 2 (<gui> :text-width "-" gui))))
    (for-each (lambda (column)
                (if (string? (column :width))
                    (set! (column :width) (+ text-border
                                             (<gui> :text-width (column :width) gui))))
                (if (string? (column :max-width))
                    (set! (column :max-width) (+ text-border
                                                 (<gui> :text-width (column :max-width) gui)))))
              columns))

  (define column-widths (map round (get-table-column-widths columns (- width (* border 2)))))

  (define table-x1s '())
  (define table-x2s '())
  
  (let loop ((x1 border)
             (widths column-widths))
    (if (null? widths)
        '()
        (let* ((width (max 2 (car widths)))
               (next-x1 (min x2 (+ x1 width))))
          (push-back! table-x1s x1)
          (push-back! table-x2s (if (null? (cdr widths))
                                    (- x2 border)
                                    (- next-x1 border)))
          (loop next-x1
                (cdr widths)))))

  (define sorted-column-num 1)
  (define sorted-down #t)
  
  ;; table headers
  ;;;;;;;;;;;;;;;;;
  (for-each (lambda (column-num column x1 x2)
              (if (= 0 column-num)
                  (add-sub-area-plain! (<new> :text-area gui x1 y1 x2 header-y2 :text "#"))
                  (let ((button #f))
                    (set! button (<new> :button gui x1 y1 x2 header-y2
                                        :text (lambda ()
                                                (if (= sorted-column-num column-num)
                                                    (if sorted-down
                                                        (<-> (column :name) "⇓")
                                                        (<-> (column :name) "⇑"))
                                                    (column :name)))
                                        :background-color (lambda ()
                                                            (if (= sorted-column-num column-num)
                                                                "green"
                                                                "blue"))
                                        :callback-release
                                        (lambda ()
                                          (if (= sorted-column-num column-num)
                                              (set! sorted-down (not sorted-down))
                                              (set! sorted-column-num column-num))
                                          (set! rows (sort-table-rows! column rows sorted-down))
                                          ;;(c-display (rows 0) (rows 1))
                                          (update-me!))))
                    (add-sub-area-plain! button))))
            (iota (length columns))
            columns
            table-x1s
            table-x2s)

  ;; table itself
  ;;;;;;;;;;;;;;;;;
  (define (create-entry-area gui x1 y1 x2 y2 column columnnum rownum)
    (define area (<new> :text-area gui x1 y1 x2 y2
                        :text (if (= 0 columnnum)
                                  (<-> rownum)
                                  (lambda ()
                                    (<-> ((rows rownum) (symbol->keyword (column :keyword))))))
                        :align-left (not (= 0 columnnum))
                        ))
    area)
    
  (define (create-row-area gui x1 x2 num)
    (define row (vector-ref rows num))
    (define y1 0)
    (define y2 (- entry-height border))
    (define row-area (<new> :area gui x1 y1 x2 y2))
    (for-each (lambda (columnnum column x1 x2)
                (row-area :add-sub-area-plain! (create-entry-area gui x1 y1 x2 y2 column columnnum num)))
              (iota (length columns))
              columns
              table-x1s
              table-x2s)
    row-area)

  (define table (<new> :vertical-list-area2 gui x1 entries-y1 x2 y2
                       :num-sub-areas (vector-length rows)
                       :get-sub-area-height entry-height
                       :create-sub-area
                       (lambda (num x1 x2)
                         (create-row-area gui x1 x2 num)))
    )
  
  (add-sub-area-plain! table)

  (define-override (get-state)
    (hash-table :sorted-column-num sorted-column-num
                :sorted-down sorted-down
                :rows (copy rows)
                :table-state (table :get-state)))
  
  (define-override (apply-state! state)
    (set! sorted-column-num (state :sorted-column-num))
    (set! sorted-down (state :sorted-down))    
    ;;(set! rows (state :rows))
    (set! rows (sort-table-rows! (columns sorted-column-num) rows sorted-down))
    (table :apply-state! (state :table-state))
    (update-me!))
  
  '(define-override (paint)
    (<gui> :filled-box gui "black" x1 y1 x2 y2)) ;; fill in space between rows (didn't fix it, looks like a qt bug)
  
  ;(c-display "ROWS:" x1 y1 x2 y2 rows)
  ;(c-display "COLUMNS:" (length columns) table-x1s table-x2s "--- x1/x2:" x1 x2 ":column-widths:" column-widths ":sum" (apply + column-widths) ":width" width)
  )

'(def-area-subclass (<table> :gui :x1 :y1 :x2 :y2
                            :columns ;; A list of table-area-column structs
                            :rows ;; Either a vector of rows, or a function returning a vector of rows. Note that each row will get an additional ":num" entry.
                            )
  (define-override (paint)
    ;;(c-display "x1:" gui x1 y1 x2 y2 (<ra> :generate-new-color))
   (<gui> :filled-box gui (<ra> :generate-new-color 1) x1 y1 x2 y2)
   (<gui> :draw-text gui "green" "hello" x1 y1 x2 y2)
   (<gui> :draw-line gui "white" x1 y1 x2 y2 2.3)))

#!!
(let ((columns (list (make-table-area-column "col1"
                                             "aiai"
                                             "wefiwe"
                                             'col1-keyword
                                             'string)
                     (make-table-area-column "col2"
                                             "ai2"
                                             #f
                                             'col2-keyword
                                             'string)
                     (make-table-area-column "col3"
                                             "aiai3"
                                             #f
                                             'col3-keyword
                                             'string))))

  (define rows (list (hash-table :col1-keyword "row11"
                                 :col2-keyword "row12"
                                 :col3-keyword "row13")
                     (hash-table :col1-keyword "row21"
                                 :col2-keyword "row22"
                                 :col3-keyword "row23")
                     (hash-table :col1-keyword "row31"
                                 :col2-keyword "row32"
                                 :col3-keyword "row33")
                     (hash-table :col1-keyword "row41"
                                 :col2-keyword "row42"
                                 :col3-keyword "row43")
                     (hash-table :col1-keyword "row51"
                                 :col2-keyword "row52"
                                 :col3-keyword "row53")))
  
  (set! rows (append rows
                     (map copy (make-list 500 (car rows)))))

  (set! columns (list (make-table-area-column "Keys"
                                              "CTRL + SHIFT + HOME"
                                              #f
                                              'keys
                                              'string)
                      (make-table-area-column "Function"
                                              "ra.doLotsOfEvil"
                                              #f
                                              'function
                                              'string)
                      (make-table-area-column "Argument"
                                              "True"
                                              #f
                                              'argument
                                              'string)))

  (define search-string "")
  
  '(set! rows
        (keep identity
              (map (lambda (keybinding)
                     (define keys (to-string (car keybinding)))
                     ;;(c-display "KEYBINDING:" keys (string? keys))
                     ;;(c-display "KEYBINDING2:" (cdr keybinding) (string? (cdr keybinding)))
                     (define func-and-arg (string-split (cdr keybinding) #\space))
                     (define func (car func-and-arg))
                     (define arg (string-join (cdr func-and-arg) " "))
                     
                     (and (or (string=? search-string "")
                              (string-case-insensitive-contains? keys search-string)
                              (string-case-insensitive-contains? func search-string)
                              (string-case-insensitive-contains? arg search-string))
                          (hash-table :keys keys
                                      :function func
                                      :argument arg)))
                   (map identity (<ra> :get-keybindings-from-keys)))))

  (set! search-string "switch-show-time-sequencer-lane")
  
  (set! rows
        (keep identity
              (apply append
                     (map (lambda (keybindings)
                            (define func-and-arg-string (symbol->string (car keybindings)))
                            (define func-and-arg (string-split func-and-arg-string #\space))
                            ;;(c-display "FUNC_AND_ART:" func-and-arg)
                            (define func (car func-and-arg))
                            (define arg (string-join (cdr func-and-arg) " "))                     
                            (map (lambda (keys)
                                   (set! keys (string-join keys " "))
                                   ;;(define keys (to-string (car keybinding)))
                                   ;;(c-display "KEYBINDING:" keys (string? keys))
                                   ;;(c-display "KEYBINDING2:" (cdr keybinding) (string? (cdr keybinding)))
                                   (and (or (string=? search-string "")
                                            (string-case-insensitive-contains? keys search-string)
                                            (string-case-insensitive-contains? func search-string)
                                            (string-case-insensitive-contains? arg search-string))
                                        (hash-table :keys keys
                                                    :function func
                                                    :argument arg)))
                                 (remove-duplicates-in-sorted-list equal?  ;; call remove-duplicates again since merge-keybindings may have merged into several equal keybindings
                                                                   (merge-keybindings (to-list (<ra> :get-keybindings-from-command func-and-arg-string))))))
                            
                                 ;;(get-displayable-keybindings1 func-and-arg-string)))
                          (map identity (<ra> :get-keybindings-from-commands))))))

  
  '(set! rows '())
        
  '(for-each (lambda (keybinding)
              (define keys (to-string (car keybinding)))
              (for-each (lambda (prepared)
                          (for-each (lambda (keys)
                                      (define func-and-arg (string-split (prepared :command) #\space))
                                      (define func (car func-and-arg))
                                      (define arg (string-join (cdr func-and-arg) " "))
                                      
                                      (and (or (string=? search-string "")
                                               (string-case-insensitive-contains? keys search-string)
                                               (string-case-insensitive-contains? func search-string)
                                               (string-case-insensitive-contains? arg search-string))
                                           (begin
                                             (c-display "PrePARED:" keys " - " prepared)
                                             (push! rows
                                                    (hash-table :keys keys
                                                                :function func
                                                                :argument arg)))))
                                    (prepared :keybindings)))
                        (get-prepared-existing-keybindings-from-keys keys)))
            (<ra> :get-keybindings-from-keys))
  
  (set! rows (list->vector rows))

  ;;(for-each c-display rows)
  
  (define width 400)
    
  (define qtarea (make-qtarea :width width :height (floor (* width 0.6))
                              :sub-area-creation-callback
                              (lambda (gui width height state)
                                (define table (<new> :table gui 0 0 width height
                                                     columns
                                                     rows))
                                ;;(if state
                                ;;    (table :apply-state! state))
                                table)))
  
  (define gui (qtarea :get-gui))

  ;;(<gui> :set-background-color gui "low_background")

  (<gui> :set-parent gui -1)
  
  (<gui> :show gui))
                                                      

(<ra> :get-keybindings-from-command "ra.switchShowTimeSequencerLane(2)")

(merge-keybindings (map (lambda (keys)
                          (string-split keys #\space))
                        (to-list (<ra> :get-keybindings-from-command "ra.quantitizeRange"))))


(car (map identity (<ra> :get-keybindings-from-commands)))

(get-displayable-keybindings1 (<-> (car (car (map identity (<ra> :get-keybindings-from-commands))))))

(for-each c-display (<ra> :get-keybindings-from-keys))

!!#

(delafina (horizontally-layout-areas :x1 :y1 :x2 :y2
                                     :args
                                     :x1-border 0
                                     :y1-border 0
                                     :x2-border 0
                                     :y2-border 0
                                     :spacing 0
                                     :callback)
  (define half-spacing (/ spacing 2))
  (define num-areas (length args))
  (let loop ((args args)
             (n 0))
    (when (not (null? args))
      (let ((arg (car args))
            (x1* (+ (scale n 0 num-areas (+ x1 x1-border) (- x2 x2-border))
                    (if (> n 0)
                        half-spacing
                        0)))
            (x2* (- (scale (1+ n) 0 num-areas (+ x1 x1-border) (- x2 x2-border))
                    (if (< n (- num-areas 1))
                        half-spacing
                        0))))
        (apply callback (append (if (list? arg) arg (list arg))
                                (list x1* (+ y1 y1-border)
                                      x2* (- y2 y2-border)))))
      (loop (cdr args)
            (1+ n)))))

(delafina (vertically-layout-areas :x1 :y1 :x2 :y2
                                   :args
                                   :x1-border 0
                                   :y1-border 0
                                   :x2-border 0
                                   :y2-border 0
                                   :spacing 0
                                   :callback)
  (define half-spacing (/ spacing 2))
  (define num-areas (length args))
  (let loop ((args args)
             (n 0))
    (when (not (null? args))
      (let ((arg (car args))
            (y1* (+ (scale n 0 num-areas (+ y1 y1-border) (- y2 y2-border))
                    (if (> n 0)
                        half-spacing
                        0)))                 
            (y2* (- (scale (1+ n) 0 num-areas (+ y1 y1-border) (- y2 y2-border))
                    (if (< n (- num-areas 1))
                        half-spacing
                        0))))
        (apply callback (append (if (list? arg) arg (list arg))
                                (list (+ x1 x1-border) y1*
                                      (- x2 x2-border) y2*))))
      (loop (cdr args)
            (1+ n)))))


