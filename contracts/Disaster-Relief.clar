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
(define-constant err-resource-not-found (err u111))
(define-constant err-insufficient-resources (err u112))
(define-constant err-resource-unavailable (err u113))
(define-constant err-invalid-resource-type (err u114))

(define-data-var dao-treasury uint u0)
(define-data-var total-members uint u0)
(define-data-var proposal-counter uint u0)
(define-data-var crisis-counter uint u0)
(define-data-var voting-period uint u1440)
(define-data-var min-quorum uint u50)
(define-data-var resource-counter uint u0)
(define-data-var allocation-counter uint u0)

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

(define-map disaster-resources
  uint
  {
    resource-type: uint,
    name: (string-ascii 64),
    description: (string-ascii 256),
    quantity: uint,
    available: uint,
    unit: (string-ascii 32),
    provider: principal,
    location: (string-ascii 128),
    active: bool,
    registered-at: uint
  }
)

(define-map resource-allocations
  uint
  {
    resource-id: uint,
    crisis-id: uint,
    recipient: principal,
    quantity: uint,
    allocated-by: principal,
    allocated-at: uint,
    status: uint,
    notes: (string-ascii 256)
  }
)

(define-map resource-types
  uint
  (string-ascii 64)
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

(map-set resource-types u1 "Food")
(map-set resource-types u2 "Water")
(map-set resource-types u3 "Medical Supplies")
(map-set resource-types u4 "Shelter Materials")
(map-set resource-types u5 "Clothing")
(map-set resource-types u6 "Emergency Equipment")

(define-public (register-resource (resource-type uint) (name (string-ascii 64)) (description (string-ascii 256)) (quantity uint) (unit (string-ascii 32)) (location (string-ascii 128)))
  (let ((resource-id (+ (var-get resource-counter) u1)))
    (asserts! (default-to false (map-get? members tx-sender)) err-unauthorized)
    (asserts! (and (>= resource-type u1) (<= resource-type u6)) err-invalid-resource-type)
    (asserts! (> quantity u0) err-invalid-amount)
    (map-set disaster-resources resource-id {
      resource-type: resource-type,
      name: name,
      description: description,
      quantity: quantity,
      available: quantity,
      unit: unit,
      provider: tx-sender,
      location: location,
      active: true,
      registered-at: stacks-block-height
    })
    (var-set resource-counter resource-id)
    (ok resource-id)
  )
)

(define-public (update-resource-quantity (resource-id uint) (new-quantity uint))
  (let ((resource (unwrap! (map-get? disaster-resources resource-id) err-resource-not-found)))
    (asserts! (is-eq tx-sender (get provider resource)) err-unauthorized)
    (asserts! (> new-quantity u0) err-invalid-amount)
    (let (
      (allocated (- (get quantity resource) (get available resource)))
      (new-available (if (>= new-quantity allocated) (- new-quantity allocated) u0))
    )
      (map-set disaster-resources resource-id (merge resource {
        quantity: new-quantity,
        available: new-available
      }))
      (ok true)
    )
  )
)

(define-public (deactivate-resource (resource-id uint))
  (let ((resource (unwrap! (map-get? disaster-resources resource-id) err-resource-not-found)))
    (asserts! (or (is-eq tx-sender (get provider resource)) (is-eq tx-sender contract-owner)) err-unauthorized)
    (map-set disaster-resources resource-id (merge resource {active: false}))
    (ok true)
  )
)

(define-public (allocate-resource (resource-id uint) (crisis-id uint) (recipient principal) (quantity uint) (notes (string-ascii 256)))
  (let (
    (resource (unwrap! (map-get? disaster-resources resource-id) err-resource-not-found))
    (crisis (unwrap! (map-get? crises crisis-id) err-not-found))
    (allocation-id (+ (var-get allocation-counter) u1))
  )
    (asserts! (default-to false (map-get? members tx-sender)) err-unauthorized)
    (asserts! (get active resource) err-resource-unavailable)
    (asserts! (get active crisis) err-crisis-not-active)
    (asserts! (default-to false (map-get? verified-addresses recipient)) err-verification-required)
    (asserts! (> quantity u0) err-invalid-amount)
    (asserts! (>= (get available resource) quantity) err-insufficient-resources)
    
    (map-set resource-allocations allocation-id {
      resource-id: resource-id,
      crisis-id: crisis-id,
      recipient: recipient,
      quantity: quantity,
      allocated-by: tx-sender,
      allocated-at: stacks-block-height,
      status: u1,
      notes: notes
    })
    
    (map-set disaster-resources resource-id (merge resource {
      available: (- (get available resource) quantity)
    }))
    
    (var-set allocation-counter allocation-id)
    (ok allocation-id)
  )
)

(define-public (confirm-resource-delivery (allocation-id uint))
  (let ((allocation (unwrap! (map-get? resource-allocations allocation-id) err-not-found)))
    (asserts! (is-eq tx-sender (get recipient allocation)) err-unauthorized)
    (asserts! (is-eq (get status allocation) u1) err-unauthorized)
    (map-set resource-allocations allocation-id (merge allocation {status: u2}))
    (ok true)
  )
)

(define-public (cancel-resource-allocation (allocation-id uint))
  (let (
    (allocation (unwrap! (map-get? resource-allocations allocation-id) err-not-found))
    (resource (unwrap! (map-get? disaster-resources (get resource-id allocation)) err-resource-not-found))
  )
    (asserts! (or 
      (is-eq tx-sender (get allocated-by allocation))
      (is-eq tx-sender (get provider resource))
      (is-eq tx-sender contract-owner)
    ) err-unauthorized)
    (asserts! (is-eq (get status allocation) u1) err-unauthorized)
    
    (map-set disaster-resources (get resource-id allocation) (merge resource {
      available: (+ (get available resource) (get quantity allocation))
    }))
    
    (map-set resource-allocations allocation-id (merge allocation {status: u3}))
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
    crisis-count: (var-get crisis-counter),
    resource-count: (var-get resource-counter),
    allocation-count: (var-get allocation-counter)
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

(define-read-only (get-disaster-resource (resource-id uint))
  (map-get? disaster-resources resource-id)
)

(define-read-only (get-resource-allocation (allocation-id uint))
  (map-get? resource-allocations allocation-id)
)

(define-read-only (get-resource-type (type-id uint))
  (map-get? resource-types type-id)
)

(define-read-only (get-available-resources-by-type (resource-type uint))
  (ok (var-get resource-counter))
)

(define-read-only (get-resource-allocation-status (allocation-id uint))
  (match (map-get? resource-allocations allocation-id)
    allocation (ok {
      status: (get status allocation),
      status-name: (if (is-eq (get status allocation) u1) "Allocated"
                     (if (is-eq (get status allocation) u2) "Delivered"
                       (if (is-eq (get status allocation) u3) "Cancelled" "Unknown")))
    })
    (err err-not-found)
  )
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
