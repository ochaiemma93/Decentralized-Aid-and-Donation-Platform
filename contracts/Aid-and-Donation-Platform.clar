(define-constant ERR-NOT-AUTHORIZED (err u401))
(define-constant ERR-INVALID-AMOUNT (err u402))
(define-constant ERR-CAMPAIGN-NOT-FOUND (err u404))
(define-constant ERR-CAMPAIGN-INACTIVE (err u403))
(define-constant ERR-INSUFFICIENT-FUNDS (err u405))
(define-constant ERR-ALREADY-EXISTS (err u409))
(define-constant ERR-MILESTONE-NOT-FOUND (err u406))
(define-constant ERR-MILESTONE-COMPLETED (err u407))

(define-data-var campaign-id-nonce uint u0)
(define-data-var transaction-id-nonce uint u0)

(define-map campaigns
  { campaign-id: uint }
  {
    organizer: principal,
    title: (string-ascii 100),
    description: (string-ascii 500),
    target-amount: uint,
    raised-amount: uint,
    is-active: bool,
    created-at: uint,
    category: (string-ascii 50)
  }
)

(define-map donations
  { donor: principal, campaign-id: uint }
  {
    amount: uint,
    timestamp: uint
  }
)

(define-map milestones
  { campaign-id: uint, milestone-id: uint }
  {
    description: (string-ascii 200),
    required-amount: uint,
    is-completed: bool,
    completion-proof: (optional (string-ascii 200))
  }
)

(define-map fund-usage
  { transaction-id: uint }
  {
    campaign-id: uint,
    amount: uint,
    purpose: (string-ascii 200),
    recipient: principal,
    timestamp: uint,
    proof-document: (optional (string-ascii 200))
  }
)

(define-map campaign-milestones-count
  { campaign-id: uint }
  { count: uint }
)

(define-map donor-total-donations
  { donor: principal }
  { total: uint }
)

(define-read-only (get-campaign (campaign-id uint))
  (map-get? campaigns { campaign-id: campaign-id })
)

(define-read-only (get-donation (donor principal) (campaign-id uint))
  (map-get? donations { donor: donor, campaign-id: campaign-id })
)

(define-read-only (get-milestone (campaign-id uint) (milestone-id uint))
  (map-get? milestones { campaign-id: campaign-id, milestone-id: milestone-id })
)

(define-read-only (get-fund-usage (transaction-id uint))
  (map-get? fund-usage { transaction-id: transaction-id })
)

(define-read-only (get-donor-total (donor principal))
  (default-to u0 (get total (map-get? donor-total-donations { donor: donor })))
)

(define-read-only (get-campaign-milestone-count (campaign-id uint))
  (default-to u0 (get count (map-get? campaign-milestones-count { campaign-id: campaign-id })))
)

(define-read-only (get-next-campaign-id)
  (+ (var-get campaign-id-nonce) u1)
)

(define-public (create-campaign 
  (title (string-ascii 100))
  (description (string-ascii 500))
  (target-amount uint)
  (category (string-ascii 50)))
  (let ((new-campaign-id (+ (var-get campaign-id-nonce) u1)))
    (asserts! (> target-amount u0) ERR-INVALID-AMOUNT)
    (asserts! (is-none (map-get? campaigns { campaign-id: new-campaign-id })) ERR-ALREADY-EXISTS)
    (map-set campaigns
      { campaign-id: new-campaign-id }
      {
        organizer: tx-sender,
        title: title,
        description: description,
        target-amount: target-amount,
        raised-amount: u0,
        is-active: true,
        created-at: stacks-block-height,
        category: category
      }
    )
    (var-set campaign-id-nonce new-campaign-id)
    (ok new-campaign-id)
  )
)

(define-public (donate (campaign-id uint) (amount uint))
  (let ((campaign (unwrap! (get-campaign campaign-id) ERR-CAMPAIGN-NOT-FOUND))
        (current-donation (get-donation tx-sender campaign-id)))
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    (asserts! (get is-active campaign) ERR-CAMPAIGN-INACTIVE)
    (try! (stx-transfer? amount tx-sender (get organizer campaign)))
    (map-set campaigns
      { campaign-id: campaign-id }
      (merge campaign { raised-amount: (+ (get raised-amount campaign) amount) })
    )
    (map-set donations
      { donor: tx-sender, campaign-id: campaign-id }
      {
        amount: (+ amount (default-to u0 (get amount current-donation))),
        timestamp: stacks-block-height
      }
    )
    (map-set donor-total-donations
      { donor: tx-sender }
      { total: (+ amount (get-donor-total tx-sender)) }
    )
    (ok amount)
  )
)

(define-public (add-milestone 
  (campaign-id uint)
  (description (string-ascii 200))
  (required-amount uint))
  (let ((campaign (unwrap! (get-campaign campaign-id) ERR-CAMPAIGN-NOT-FOUND))
        (milestone-count (get-campaign-milestone-count campaign-id))
        (new-milestone-id (+ milestone-count u1)))
    (asserts! (is-eq tx-sender (get organizer campaign)) ERR-NOT-AUTHORIZED)
    (asserts! (> required-amount u0) ERR-INVALID-AMOUNT)
    (map-set milestones
      { campaign-id: campaign-id, milestone-id: new-milestone-id }
      {
        description: description,
        required-amount: required-amount,
        is-completed: false,
        completion-proof: none
      }
    )
    (map-set campaign-milestones-count
      { campaign-id: campaign-id }
      { count: new-milestone-id }
    )
    (ok new-milestone-id)
  )
)

(define-public (complete-milestone 
  (campaign-id uint)
  (milestone-id uint)
  (proof-document (string-ascii 200)))
  (let ((campaign (unwrap! (get-campaign campaign-id) ERR-CAMPAIGN-NOT-FOUND))
        (milestone (unwrap! (get-milestone campaign-id milestone-id) ERR-MILESTONE-NOT-FOUND)))
    (asserts! (is-eq tx-sender (get organizer campaign)) ERR-NOT-AUTHORIZED)
    (asserts! (not (get is-completed milestone)) ERR-MILESTONE-COMPLETED)
    (asserts! (>= (get raised-amount campaign) (get required-amount milestone)) ERR-INSUFFICIENT-FUNDS)
    (map-set milestones
      { campaign-id: campaign-id, milestone-id: milestone-id }
      (merge milestone 
        { 
          is-completed: true,
          completion-proof: (some proof-document)
        }
      )
    )
    (ok true)
  )
)

(define-public (record-fund-usage 
  (campaign-id uint)
  (amount uint)
  (purpose (string-ascii 200))
  (recipient principal)
  (proof-document (optional (string-ascii 200))))
  (let ((campaign (unwrap! (get-campaign campaign-id) ERR-CAMPAIGN-NOT-FOUND))
        (new-transaction-id (+ (var-get transaction-id-nonce) u1)))
    (asserts! (is-eq tx-sender (get organizer campaign)) ERR-NOT-AUTHORIZED)
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    (asserts! (>= (get raised-amount campaign) amount) ERR-INSUFFICIENT-FUNDS)
    (map-set fund-usage
      { transaction-id: new-transaction-id }
      {
        campaign-id: campaign-id,
        amount: amount,
        purpose: purpose,
        recipient: recipient,
        timestamp: stacks-block-height,
        proof-document: proof-document
      }
    )
    (var-set transaction-id-nonce new-transaction-id)
    (ok new-transaction-id)
  )
)

(define-public (deactivate-campaign (campaign-id uint))
  (let ((campaign (unwrap! (get-campaign campaign-id) ERR-CAMPAIGN-NOT-FOUND)))
    (asserts! (is-eq tx-sender (get organizer campaign)) ERR-NOT-AUTHORIZED)
    (map-set campaigns
      { campaign-id: campaign-id }
      (merge campaign { is-active: false })
    )
    (ok true)
  )
)

(define-public (activate-campaign (campaign-id uint))
  (let ((campaign (unwrap! (get-campaign campaign-id) ERR-CAMPAIGN-NOT-FOUND)))
    (asserts! (is-eq tx-sender (get organizer campaign)) ERR-NOT-AUTHORIZED)
    (map-set campaigns
      { campaign-id: campaign-id }
      (merge campaign { is-active: true })
    )
    (ok true)
  )
)

(define-read-only (calculate-campaign-efficiency (campaign-id uint))
  (let ((campaign (unwrap! (get-campaign campaign-id) ERR-CAMPAIGN-NOT-FOUND)))
    (if (> (get target-amount campaign) u0)
      (ok (/ (* (get raised-amount campaign) u100) (get target-amount campaign)))
      ERR-INVALID-AMOUNT
    )
  )
)

(define-read-only (get-campaign-progress (campaign-id uint))
  (let ((campaign (unwrap! (get-campaign campaign-id) ERR-CAMPAIGN-NOT-FOUND))
        (target (get target-amount campaign))
        (raised (get raised-amount campaign)))
    (ok {
      campaign-id: campaign-id,
      target-amount: target,
      raised-amount: raised,
      progress-percentage: (if (> target u0) (/ (* raised u100) target) u0),
      is-fully-funded: (>= raised target),
      remaining-amount: (if (>= raised target) u0 (- target raised))
    })
  )
)

(define-read-only (get-transaction-history (campaign-id uint) (limit uint))
  (ok {
    campaign-id: campaign-id,
    total-raised: (default-to u0 (get raised-amount (get-campaign campaign-id))),
    query-limit: limit
  })
)
