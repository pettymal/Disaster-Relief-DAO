(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-insufficient-funds (err u103))
(define-constant err-already-voted (err u104))
(define-constant err-proposal-expired (err u105))
(define-constant err-proposal-not-active (err u106))
(define-constant err-invalid-amount (err u107))
(define-constant err-crisis-not-active (err u108))
(define-constant err-already-verified (err u109))
(define-constant err-verification-required (err u110))

(define-data-var dao-treasury uint u0)
(define-data-var total-members uint u0)
(define-data-var proposal-counter uint u0)
(define-data-var crisis-counter uint u0)
(define-data-var voting-period uint u1440)
(define-data-var min-quorum uint u50)

(define-map members principal bool)
(define-map verified-addresses principal bool)
(define-map member-stakes principal uint)

(define-map crises
  uint
  {
    name: (string-ascii 64),
    description: (string-ascii 256),
    severity: uint,
    active: bool,
    declared-at: uint,
    declared-by: principal
  }
)

(define-map proposals
  uint
  {
    crisis-id: uint,
    recipient: principal,
    amount: uint,
    description: (string-ascii 256),
    proposer: principal,
    votes-for: uint,
    votes-against: uint,
    created-at: uint,
    executed: bool,
    active: bool
  }
)

(define-map votes
  {proposal-id: uint, voter: principal}
  {vote: bool, voted-at: uint}
)

(define-map emergency-contacts
  principal
  {
    contact-info: (string-ascii 128),
    verified: bool,
    added-at: uint
  }
)

(define-public (join-dao (stake-amount uint))
  (let ((sender tx-sender))
    (asserts! (> stake-amount u0) err-invalid-amount)
    (asserts! (>= (stx-get-balance sender) stake-amount) err-insufficient-funds)
    (try! (stx-transfer? stake-amount sender (as-contract tx-sender)))
    (map-set members sender true)
    (map-set member-stakes sender stake-amount)
    (var-set dao-treasury (+ (var-get dao-treasury) stake-amount))
    (var-set total-members (+ (var-get total-members) u1))
    (ok true)
  )
)

(define-public (leave-dao)
  (let (
    (sender tx-sender)
    (stake (default-to u0 (map-get? member-stakes sender)))
  )
    (asserts! (default-to false (map-get? members sender)) err-not-found)
    (asserts! (>= (var-get dao-treasury) stake) err-insufficient-funds)
    (map-delete members sender)
    (map-delete member-stakes sender)
    (var-set dao-treasury (- (var-get dao-treasury) stake))
    (var-set total-members (- (var-get total-members) u1))
    (try! (as-contract (stx-transfer? stake tx-sender sender)))
    (ok true)
  )
)

(define-public (verify-address (address principal))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (not (default-to false (map-get? verified-addresses address))) err-already-verified)
    (map-set verified-addresses address true)
    (ok true)
  )
)

(define-public (declare-crisis (name (string-ascii 64)) (description (string-ascii 256)) (severity uint))
  (let ((crisis-id (+ (var-get crisis-counter) u1)))
    (asserts! (default-to false (map-get? members tx-sender)) err-unauthorized)
    (asserts! (and (>= severity u1) (<= severity u5)) err-invalid-amount)
    (map-set crises crisis-id {
      name: name,
      description: description,
      severity: severity,
      active: true,
      declared-at: stacks-block-height,
      declared-by: tx-sender
    })
    (var-set crisis-counter crisis-id)
    (ok crisis-id)
  )
)

(define-public (deactivate-crisis (crisis-id uint))
  (let ((crisis (unwrap! (map-get? crises crisis-id) err-not-found)))
    (asserts! (or (is-eq tx-sender contract-owner) (is-eq tx-sender (get declared-by crisis))) err-unauthorized)
    (map-set crises crisis-id (merge crisis {active: false}))
    (ok true)
  )
)

(define-public (submit-relief-proposal (crisis-id uint) (recipient principal) (amount uint) (description (string-ascii 256)))
  (let ((proposal-id (+ (var-get proposal-counter) u1)))
    (asserts! (default-to false (map-get? members tx-sender)) err-unauthorized)
    (asserts! (default-to false (map-get? verified-addresses recipient)) err-verification-required)
    (asserts! (> amount u0) err-invalid-amount)
    (asserts! (<= amount (var-get dao-treasury)) err-insufficient-funds)
    (let ((crisis (unwrap! (map-get? crises crisis-id) err-not-found)))
      (asserts! (get active crisis) err-crisis-not-active)
      (map-set proposals proposal-id {
        crisis-id: crisis-id,
        recipient: recipient,
        amount: amount,
        description: description,
        proposer: tx-sender,
        votes-for: u0,
        votes-against: u0,
        created-at: stacks-block-height,
        executed: false,
        active: true
      })
      (var-set proposal-counter proposal-id)
      (ok proposal-id)
    )
  )
)

(define-public (vote-on-proposal (proposal-id uint) (vote-for bool))
  (let (
    (sender tx-sender)
    (proposal (unwrap! (map-get? proposals proposal-id) err-not-found))
    (vote-key {proposal-id: proposal-id, voter: sender})
  )
    (asserts! (default-to false (map-get? members sender)) err-unauthorized)
    (asserts! (get active proposal) err-proposal-not-active)
    (asserts! (is-none (map-get? votes vote-key)) err-already-voted)
    (asserts! (< (- stacks-block-height (get created-at proposal)) (var-get voting-period)) err-proposal-expired)
    
    (map-set votes vote-key {vote: vote-for, voted-at: stacks-block-height})
    
    (if vote-for
      (map-set proposals proposal-id (merge proposal {votes-for: (+ (get votes-for proposal) u1)}))
      (map-set proposals proposal-id (merge proposal {votes-against: (+ (get votes-against proposal) u1)}))
    )
    (ok true)
  )
)

(define-public (execute-proposal (proposal-id uint))
  (let (
    (proposal (unwrap! (map-get? proposals proposal-id) err-not-found))
    (total-votes (+ (get votes-for proposal) (get votes-against proposal)))
    (required-quorum (/ (* (var-get total-members) (var-get min-quorum)) u100))
  )
    (asserts! (get active proposal) err-proposal-not-active)
    (asserts! (not (get executed proposal)) err-unauthorized)
    (asserts! (>= (- stacks-block-height (get created-at proposal)) (var-get voting-period)) err-proposal-not-active)
    (asserts! (>= total-votes required-quorum) err-unauthorized)
    (asserts! (> (get votes-for proposal) (get votes-against proposal)) err-unauthorized)
    (asserts! (>= (var-get dao-treasury) (get amount proposal)) err-insufficient-funds)
    
    (try! (as-contract (stx-transfer? (get amount proposal) tx-sender (get recipient proposal))))
    (var-set dao-treasury (- (var-get dao-treasury) (get amount proposal)))
    (map-set proposals proposal-id (merge proposal {executed: true, active: false}))
    (ok true)
  )
)

(define-public (add-emergency-contact (contact principal) (contact-info (string-ascii 128)))
  (begin
    (asserts! (default-to false (map-get? members tx-sender)) err-unauthorized)
    (map-set emergency-contacts contact {
      contact-info: contact-info,
      verified: false,
      added-at: stacks-block-height
    })
    (ok true)
  )
)

(define-public (verify-emergency-contact (contact principal))
  (let ((contact-data (unwrap! (map-get? emergency-contacts contact) err-not-found)))
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (map-set emergency-contacts contact (merge contact-data {verified: true}))
    (ok true)
  )
)

(define-public (donate-to-treasury (amount uint))
  (begin
    (asserts! (> amount u0) err-invalid-amount)
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    (var-set dao-treasury (+ (var-get dao-treasury) amount))
    (ok true)
  )
)

(define-public (update-voting-period (new-period uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (> new-period u0) err-invalid-amount)
    (var-set voting-period new-period)
    (ok true)
  )
)

(define-public (update-min-quorum (new-quorum uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (and (> new-quorum u0) (<= new-quorum u100)) err-invalid-amount)
    (var-set min-quorum new-quorum)
    (ok true)
  )
)

(define-read-only (get-dao-info)
  {
    treasury: (var-get dao-treasury),
    total-members: (var-get total-members),
    voting-period: (var-get voting-period),
    min-quorum: (var-get min-quorum),
    proposal-count: (var-get proposal-counter),
    crisis-count: (var-get crisis-counter)
  }
)

(define-read-only (get-member-info (member principal))
  {
    is-member: (default-to false (map-get? members member)),
    stake: (default-to u0 (map-get? member-stakes member)),
    is-verified: (default-to false (map-get? verified-addresses member))
  }
)

(define-read-only (get-proposal (proposal-id uint))
  (map-get? proposals proposal-id)
)

(define-read-only (get-crisis (crisis-id uint))
  (map-get? crises crisis-id)
)

(define-read-only (get-vote (proposal-id uint) (voter principal))
  (map-get? votes {proposal-id: proposal-id, voter: voter})
)

(define-read-only (get-emergency-contact (contact principal))
  (map-get? emergency-contacts contact)
)

(define-read-only (is-proposal-executable (proposal-id uint))
  (match (map-get? proposals proposal-id)
    proposal (let (
      (total-votes (+ (get votes-for proposal) (get votes-against proposal)))
      (required-quorum (/ (* (var-get total-members) (var-get min-quorum)) u100))
      (voting-ended (>= (- stacks-block-height (get created-at proposal)) (var-get voting-period)))
    )
      (and 
        (get active proposal)
        (not (get executed proposal))
        voting-ended
        (>= total-votes required-quorum)
        (> (get votes-for proposal) (get votes-against proposal))
        (>= (var-get dao-treasury) (get amount proposal))
      )
    )
    false
  )
)
