;; AI-Based Reputation Scoring System
;; This smart contract implements a decentralized reputation scoring system
;; where authorized AI verifiers can submit scores, users can dispute ratings,
;; and reputation is calculated using weighted algorithms with decay mechanisms.

;; constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-INVALID-SCORE (err u101))
(define-constant ERR-USER-NOT-FOUND (err u102))
(define-constant ERR-ALREADY-VERIFIER (err u103))
(define-constant ERR-NOT-VERIFIER (err u104))
(define-constant ERR-DISPUTE-EXISTS (err u105))
(define-constant ERR-NO-DISPUTE (err u106))
(define-constant ERR-INVALID-WEIGHT (err u107))

;; Scoring constants
(define-constant MIN-SCORE u0)
(define-constant MAX-SCORE u100)
(define-constant DEFAULT-SCORE u50)
(define-constant DECAY-RATE u5) ;; 5% decay per period if inactive
(define-constant MIN-VERIFIER-STAKE u1000)

;; data maps and vars

;; Track user reputation scores with metadata
(define-map user-scores
    principal
    {
        score: uint,
        total-interactions: uint,
        last-updated: uint,
        status: (string-ascii 20)
    }
)

;; Track authorized AI verifiers with their credibility weights
(define-map verifiers
    principal
    {
        is-active: bool,
        credibility-weight: uint,
        total-verifications: uint,
        stake-amount: uint
    }
)

;; Track individual score submissions from verifiers
(define-map score-submissions
    {user: principal, verifier: principal, submission-id: uint}
    {
        score: uint,
        timestamp: uint,
        ai-confidence: uint,
        category: (string-ascii 30)
    }
)

;; Track disputes raised by users
(define-map disputes
    {user: principal, dispute-id: uint}
    {
        reason: (string-ascii 200),
        status: (string-ascii 20),
        created-at: uint,
        resolved-at: uint
    }
)

;; Global state variables
(define-data-var total-users uint u0)
(define-data-var total-verifiers uint u0)
(define-data-var submission-nonce uint u0)
(define-data-var dispute-nonce uint u0)

;; private functions

;; Calculate weighted average score from multiple submissions
(define-private (calculate-weighted-score (base-score uint) (verifier-weight uint) (ai-confidence uint))
    (let
        (
            (confidence-factor (/ ai-confidence u100))
            (weighted-contribution (/ (* base-score verifier-weight) u100))
        )
        (/ (* weighted-contribution (+ u100 ai-confidence)) u200)
    )
)

;; Apply time-based decay to inactive scores
(define-private (apply-score-decay (current-score uint) (blocks-inactive uint))
    (let
        (
            (decay-periods (/ blocks-inactive u1000))
            (decay-amount (/ (* current-score (* decay-periods DECAY-RATE)) u100))
        )
        (if (> decay-amount current-score)
            MIN-SCORE
            (- current-score decay-amount)
        )
    )
)

;; Validate score is within acceptable range
(define-private (is-valid-score (score uint))
    (and (>= score MIN-SCORE) (<= score MAX-SCORE))
)

;; Validate verifier weight is reasonable
(define-private (is-valid-weight (weight uint))
    (and (> weight u0) (<= weight u100))
)

;; public functions

;; Initialize a new user with default reputation score
(define-public (initialize-user)
    (let
        (
            (existing-user (map-get? user-scores tx-sender))
        )
        (if (is-some existing-user)
            (ok false)
            (begin
                (map-set user-scores tx-sender {
                    score: DEFAULT-SCORE,
                    total-interactions: u0,
                    last-updated: block-height,
                    status: "active"
                })
                (var-set total-users (+ (var-get total-users) u1))
                (ok true)
            )
        )
    )
)

;; Register a new AI verifier (only contract owner)
(define-public (register-verifier (verifier principal) (weight uint) (stake uint))
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
        (asserts! (is-valid-weight weight) ERR-INVALID-WEIGHT)
        (asserts! (>= stake MIN-VERIFIER-STAKE) ERR-NOT-AUTHORIZED)
        (asserts! (is-none (map-get? verifiers verifier)) ERR-ALREADY-VERIFIER)
        
        (map-set verifiers verifier {
            is-active: true,
            credibility-weight: weight,
            total-verifications: u0,
            stake-amount: stake
        })
        (var-set total-verifiers (+ (var-get total-verifiers) u1))
        (ok true)
    )
)

;; Deactivate a verifier (only contract owner)
(define-public (deactivate-verifier (verifier principal))
    (let
        (
            (verifier-data (unwrap! (map-get? verifiers verifier) ERR-NOT-VERIFIER))
        )
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
        (map-set verifiers verifier (merge verifier-data {is-active: false}))
        (ok true)
    )
)

;; Submit a reputation score (only active verifiers)
(define-public (submit-score (user principal) (score uint) (ai-confidence uint) (category (string-ascii 30)))
    (let
        (
            (verifier-data (unwrap! (map-get? verifiers tx-sender) ERR-NOT-VERIFIER))
            (user-data (unwrap! (map-get? user-scores user) ERR-USER-NOT-FOUND))
            (submission-id (var-get submission-nonce))
        )
        (asserts! (get is-active verifier-data) ERR-NOT-AUTHORIZED)
        (asserts! (is-valid-score score) ERR-INVALID-SCORE)
        (asserts! (<= ai-confidence u100) ERR-INVALID-SCORE)
        
        ;; Record the submission
        (map-set score-submissions {user: user, verifier: tx-sender, submission-id: submission-id} {
            score: score,
            timestamp: block-height,
            ai-confidence: ai-confidence,
            category: category
        })
        
        ;; Update verifier stats
        (map-set verifiers tx-sender 
            (merge verifier-data {total-verifications: (+ (get total-verifications verifier-data) u1)})
        )
        
        ;; Update nonce
        (var-set submission-nonce (+ submission-id u1))
        (ok submission-id)
    )
)

;; Get current reputation score for a user
(define-read-only (get-reputation (user principal))
    (map-get? user-scores user)
)

;; Get verifier information
(define-read-only (get-verifier-info (verifier principal))
    (map-get? verifiers verifier)
)

;; Raise a dispute on reputation score
(define-public (raise-dispute (reason (string-ascii 200)))
    (let
        (
            (user-data (unwrap! (map-get? user-scores tx-sender) ERR-USER-NOT-FOUND))
            (dispute-id (var-get dispute-nonce))
        )
        (map-set disputes {user: tx-sender, dispute-id: dispute-id} {
            reason: reason,
            status: "pending",
            created-at: block-height,
            resolved-at: u0
        })
        (var-set dispute-nonce (+ dispute-id u1))
        (ok dispute-id)
    )
)

;; Helper function for fold operation in score calculation
(define-private (process-submission-fold (submission-id uint) (accumulator {score-sum: uint, weight-sum: uint, user: principal}))
    (let
        (
            (user (get user accumulator))
            (current-sum (get score-sum accumulator))
            (current-weight (get weight-sum accumulator))
        )
        ;; Try to get submission data for each verifier (iterating through potential verifiers)
        ;; In production, you'd want a more efficient lookup mechanism
        (match (map-get? score-submissions {user: user, verifier: CONTRACT-OWNER, submission-id: submission-id})
            submission-data
                (match (map-get? verifiers CONTRACT-OWNER)
                    verifier-data
                        (let
                            (
                                (weight (get credibility-weight verifier-data))
                                (confidence (get ai-confidence submission-data))
                                (score (get score submission-data))
                                (weighted-score (calculate-weighted-score score weight confidence))
                            )
                            {
                                score-sum: (+ current-sum (* weighted-score weight)),
                                weight-sum: (+ current-weight weight),
                                user: user
                            }
                        )
                    accumulator
                )
            accumulator
        )
    )
)


