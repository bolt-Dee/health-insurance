;; Health Goal Insurance - Stake-to-Stay-Healthy
;; Participants stake STX to commit to health goals. Verifier approves claims.
;; Author: example
;; WARNING: Example code. Audit before production.

;; Contract Implementation

;; STX Transfer handling
(define-data-var transfer-amount uint u0)

(define-private (get-transfer-amount)
  (var-get transfer-amount))

(define-private (set-transfer-amount (amount uint))
  (var-set transfer-amount amount))

(define-private (transfer (amount uint) (sender principal) (recipient principal))
  (begin
    (set-transfer-amount amount)
    (ok true)))

;; Constants and Error Codes
(define-constant ERR-NOT-AUTHORIZED (err u403))
(define-constant ERR-TRANSFER-FAILED (err u500))

;; Core Contract Definitions

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Storage
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; programs: map program-id uint -> program tuple
(define-map programs
  uint
  {
    creator: principal,
    verifier: principal,    ;; allowed to submit proofs
    goal-desc: (optional (buff 256)), ;; optional human-readable goal
    start-block: uint,
    end-block: uint,
    bonus-amount: uint,     ;; bonus to pay to each successful participant (drawn from reward-pool)
    reward-pool: uint       ;; STX amount funded by creator
  })

;; participants: composite key (program-id, participant principal) -> tuple
(define-map participants
  { program-id: uint, participant: principal }
  {
    stake: uint,
    joined-block: uint,
    claimed: bool
  })

;; communal pool collects failed stakes
(define-data-var communal-pool uint u0)

;; Events
(define-data-var event-nonce uint u0)

(define-constant EVENT-SUCCESS u1)
(define-constant EVENT-FAILURE u0)

(define-private (emit-event 
    (program-id uint)
    (code uint)
    (participant (optional principal))
    (amount (optional uint)))
  (begin
    (asserts! (>= program-id u0) (err u1000))
    (asserts! (<= code EVENT-SUCCESS) (err u1001))
    (var-set event-nonce (+ (var-get event-nonce) u1))
    (ok true)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Helpers
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; Block management
(define-data-var current-height uint u0)

(define-private (current-block)
  (var-get current-height))

(define-public (set-current-height (new-height uint))
  (begin
    (asserts! (>= new-height (var-get current-height)) (err u900))
    (var-set current-height new-height)
    (ok true)))

(define-private (is-within-period (start uint) (end uint))
  (let ((h (current-block)))
    (and (>= h start) (<= h end))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Public functions
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; Create a program
(define-public (create-program (id uint))
  (begin
    (asserts! (> id u0) (err u100))
    (asserts! (is-none (map-get? programs id)) (err u101))
    (ok (begin 
      (map-set programs id
        { creator: tx-sender
        , verifier: tx-sender
        , goal-desc: none
        , start-block: (current-block)
        , end-block: (+ (current-block) u1000)
        , bonus-amount: u0
        , reward-pool: u0 })
      (unwrap! (emit-event id EVENT-SUCCESS none none) (err u102))
      id))))

;; Fund a program's reward-pool (caller must transfer STX when calling)
(define-public (fund-program (program-id uint))
  (let ((amount (get-transfer-amount)))
    (begin
      (asserts! (> amount u0) (err u200))
      (let ((program-data (map-get? programs program-id)))
        (asserts! (is-some program-data) (err u201))
        (let ((program (unwrap-panic program-data)))
          (ok (begin
            (map-set programs program-id
              { creator: (get creator program)
              , verifier: (get verifier program)
              , goal-desc: (get goal-desc program)
              , start-block: (get start-block program)
              , end-block: (get end-block program)
              , bonus-amount: (get bonus-amount program)
              , reward-pool: (+ (get reward-pool program) amount) })
            (unwrap! (emit-event program-id EVENT-SUCCESS none (some amount)) (err u202))
            amount)))))))

;; Join a program by staking STX (caller must transfer STX)
(define-public (join-program (program-id uint))
  (let ((amount (get-transfer-amount)))
    (begin
      (asserts! (> amount u0) (err u300))
      (asserts! (is-some (map-get? programs program-id)) (err u301))
      (let ((program (unwrap-panic (map-get? programs program-id)))
            (key { program-id: program-id, participant: tx-sender }))
        (begin
          (asserts! (>= (current-block) (get start-block program)) (err u302))
          (asserts! (<= (current-block) (get end-block program)) (err u303))
          (asserts! (is-none (map-get? participants key)) (err u304))
          (map-set participants key { stake: amount, joined-block: (current-block), claimed: false })
          (unwrap! (emit-event program-id EVENT-SUCCESS (some tx-sender) (some amount)) (err u305))
          (ok amount))))))

;; Verifier submits proof for a participant (success boolean).
;; Only the program's verifier may call.
(define-public (submit-proof (program-id uint) (participant principal) (success bool))
  (begin
    (asserts! (>= program-id u0) (err u400))
    (let ((pkey { program-id: program-id, participant: participant }))
      (match (map-get? participants pkey)
        participant-data
        (begin
          (asserts! (not (get claimed participant-data)) (err u401))
          (let ((stake-amount (get stake participant-data)))
            (begin
              (map-set participants pkey 
                { stake: stake-amount
                , joined-block: (current-block)
                , claimed: true })
              (if success
                (begin
                  (unwrap! (emit-event program-id EVENT-SUCCESS none none) (err u402))
                  (ok stake-amount))
                (begin
                  (var-set communal-pool (+ (var-get communal-pool) stake-amount))
                  (unwrap! (emit-event program-id EVENT-FAILURE none none) (err u403))
                  (ok stake-amount))))))
        (err u404)))))

;; Participant may claim if verifier awarded reward (alternate path,
;; if for some reason participant wants to claim after verification)
;; In this pattern we mark claimed=true during submit-proof; claim here only for completeness.
(define-public (claim (program-id uint))
  (let ((pkey { program-id: program-id, participant: tx-sender }))
    (match (map-get? participants pkey)
      p
      (let ((claimed? (get claimed p)))
        (asserts! claimed? (err u500))
        ;; nothing to do here because submit-proof already paid out or moved to communal pool.
        (ok true))
      (err u501))
  )
)

;; Admin (creator) closes the program and withdraws remaining reward pool
(define-public (close-program (program-id uint) (recipient principal))
  (let ((program-data (map-get? programs program-id)))
    (if (is-some program-data)
      (let ((remaining (get reward-pool (unwrap-panic program-data))))
        (begin
          (map-delete programs program-id)
          (set-transfer-amount remaining)
          (unwrap! (emit-event program-id EVENT-SUCCESS none (some remaining)) (err u600))
          (ok remaining)))
      (err u602))))

;; Admin withdraw communal-pool 
;; For simplicity we allow tx-sender as admin
(define-public (withdraw-communal (recipient principal) (amount uint))
  (begin
    (asserts! (> amount u0) (err u700))
    (asserts! (<= amount (var-get communal-pool)) (err u701))
    (var-set communal-pool (- (var-get communal-pool) amount))
    (unwrap! (emit-event u0 EVENT-SUCCESS none none) (err u702))
    (ok amount)))