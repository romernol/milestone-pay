;; Milestone Payment Contract
;; A time-locked contract for project milestone payments

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_MILESTONE_NOT_FOUND (err u101))
(define-constant ERR_MILESTONE_ALREADY_PAID (err u102))
(define-constant ERR_MILESTONE_NOT_DUE (err u103))
(define-constant ERR_INSUFFICIENT_FUNDS (err u104))
(define-constant ERR_INVALID_AMOUNT (err u105))

;; Data structures
(define-map milestones
    { project-id: uint, milestone-id: uint }
    {
        recipient: principal,
        amount: uint,
        due-block: uint,
        paid: bool,
        description: (string-ascii 256)
    }
)

(define-map projects
    { project-id: uint }
    {
        owner: principal,
        contractor: principal,
        total-milestones: uint,
        total-amount: uint,
        created-block: uint
    }
)

;; Data variables
(define-data-var next-project-id uint u1)

;; Helper functions
(define-private (get-project-id)
    (var-get next-project-id)
)

(define-private (increment-project-id)
    (var-set next-project-id (+ (var-get next-project-id) u1))
)

;; Public functions

;; Create a new project with milestones
(define-public (create-project (contractor principal) (milestone-data (list 10 { amount: uint, delay-blocks: uint, description: (string-ascii 256) })))
    (let
        (
            (project-id (get-project-id))
            (current-block block-height)
        )
        (try! (fold create-milestone-helper milestone-data (ok { project-id: project-id, milestone-count: u0, current-block: current-block, contractor: contractor })))
        (map-set projects
            { project-id: project-id }
            {
                owner: tx-sender,
                contractor: contractor,
                total-milestones: (len milestone-data),
                total-amount: (fold + (map get-amount milestone-data) u0),
                created-block: current-block
            }
        )
        (increment-project-id)
        (ok project-id)
    )
)

;; Helper function for creating milestones
(define-private (create-milestone-helper 
    (milestone-info { amount: uint, delay-blocks: uint, description: (string-ascii 256) })
    (acc-result (response { project-id: uint, milestone-count: uint, current-block: uint, contractor: principal } uint))
)
    (match acc-result
        acc-data 
        (let
            (
                (project-id (get project-id acc-data))
                (milestone-id (get milestone-count acc-data))
                (due-block (+ (get current-block acc-data) (get delay-blocks milestone-info)))
                (contractor (get contractor acc-data))
            )
            (map-set milestones
                { project-id: project-id, milestone-id: milestone-id }
                {
                    recipient: contractor,
                    amount: (get amount milestone-info),
                    due-block: due-block,
                    paid: false,
                    description: (get description milestone-info)
                }
            )
            (ok {
                project-id: project-id,
                milestone-count: (+ milestone-id u1),
                current-block: (get current-block acc-data),
                contractor: contractor
            })
        )
        err-val (err err-val)
    )
)

;; Helper function to get amount from milestone info
(define-private (get-amount (milestone-info { amount: uint, delay-blocks: uint, description: (string-ascii 256) }))
    (get amount milestone-info)
)

;; Fund the contract for a specific project
(define-public (fund-project (project-id uint) (amount uint))
    (let
        (
            (project (unwrap! (map-get? projects { project-id: project-id }) ERR_MILESTONE_NOT_FOUND))
        )
        (asserts! (is-eq tx-sender (get owner project)) ERR_UNAUTHORIZED)
        (asserts! (> amount u0) ERR_INVALID_AMOUNT)
        (stx-transfer? amount tx-sender (as-contract tx-sender))
    )
)

;; Release milestone payment
(define-public (release-milestone (project-id uint) (milestone-id uint))
    (let
        (
            (milestone (unwrap! (map-get? milestones { project-id: project-id, milestone-id: milestone-id }) ERR_MILESTONE_NOT_FOUND))
            (project (unwrap! (map-get? projects { project-id: project-id }) ERR_MILESTONE_NOT_FOUND))
        )
        ;; Check authorization (either project owner or contractor can trigger)
        (asserts! (or (is-eq tx-sender (get owner project)) (is-eq tx-sender (get contractor project))) ERR_UNAUTHORIZED)
        
        ;; Check if milestone is not already paid
        (asserts! (not (get paid milestone)) ERR_MILESTONE_ALREADY_PAID)
        
        ;; Check if milestone is due
        (asserts! (>= block-height (get due-block milestone)) ERR_MILESTONE_NOT_DUE)
        
        ;; Transfer funds
        (try! (as-contract (stx-transfer? (get amount milestone) tx-sender (get recipient milestone))))
        
        ;; Mark milestone as paid
        (map-set milestones
            { project-id: project-id, milestone-id: milestone-id }
            (merge milestone { paid: true })
        )
        
        (ok true)
    )
)

;; Read-only functions

;; Get milestone details
(define-read-only (get-milestone (project-id uint) (milestone-id uint))
    (map-get? milestones { project-id: project-id, milestone-id: milestone-id })
)

;; Get project details
(define-read-only (get-project (project-id uint))
    (map-get? projects { project-id: project-id })
)

;; Check if milestone is ready for payment
(define-read-only (is-milestone-ready (project-id uint) (milestone-id uint))
    (match (map-get? milestones { project-id: project-id, milestone-id: milestone-id })
        milestone
        (and 
            (not (get paid milestone))
            (>= block-height (get due-block milestone))
        )
        false
    )
)

;; Get contract balance
(define-read-only (get-contract-balance)
    (stx-get-balance (as-contract tx-sender))
)

;; Get current block height
(define-read-only (get-current-block)
    block-height
)