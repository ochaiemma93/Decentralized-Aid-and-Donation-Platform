(define-constant ERR-NOT-AUTHORIZED (err u401))
(define-constant ERR-INVALID-AMOUNT (err u402))
(define-constant ERR-CAMPAIGN-NOT-FOUND (err u404))
(define-constant ERR-CAMPAIGN-INACTIVE (err u403))
(define-constant ERR-INSUFFICIENT-FUNDS (err u405))
(define-constant ERR-ALREADY-EXISTS (err u409))
(define-constant ERR-MILESTONE-NOT-FOUND (err u406))
(define-constant ERR-MILESTONE-COMPLETED (err u407))
(define-constant ERR-NO-ESCROW (err u408))
(define-constant ERR-REFUND-NOT-ELIGIBLE (err u410))
(define-constant ERR-EXCEEDS-ESCROW (err u412))
(define-constant REFUND-WINDOW-BLOCKS u28800)

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

(define-map organizer-reputation
  { organizer: principal }
  {
    total-campaigns: uint,
    successful-campaigns: uint,
    total-raised: uint,
    completed-milestones: uint,
    reputation-score: uint,
    trust-level: uint
  }
)

(define-map campaign-outcomes
  { campaign-id: uint }
  {
    is-successful: bool,
    completion-percentage: uint,
    milestones-completed: uint,
    outcome-verified: bool
  }
)

(define-map escrow-donations
  { campaign-id: uint, donor: principal }
  {
    amount: uint,
    timestamp: uint
  }
)

(define-map escrow-total
  { campaign-id: uint }
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

(define-read-only (get-organizer-reputation (organizer principal))
  (map-get? organizer-reputation { organizer: organizer })
)

(define-read-only (get-campaign-outcome (campaign-id uint))
  (map-get? campaign-outcomes { campaign-id: campaign-id })
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
    (unwrap-panic (update-organizer-campaign-count tx-sender))
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
    (unwrap-panic (update-milestone-reputation (get organizer campaign)))
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

(define-public (update-organizer-campaign-count (organizer principal))
  (let ((current-rep (get-organizer-reputation organizer)))
    (map-set organizer-reputation
      { organizer: organizer }
      {
        total-campaigns: (+ u1 (default-to u0 (get total-campaigns current-rep))),
        successful-campaigns: (default-to u0 (get successful-campaigns current-rep)),
        total-raised: (default-to u0 (get total-raised current-rep)),
        completed-milestones: (default-to u0 (get completed-milestones current-rep)),
        reputation-score: (default-to u0 (get reputation-score current-rep)),
        trust-level: (default-to u0 (get trust-level current-rep))
      }
    )
    (ok true)
  )
)

(define-public (update-milestone-reputation (organizer principal))
  (let ((current-rep (get-organizer-reputation organizer)))
    (map-set organizer-reputation
      { organizer: organizer }
      {
        total-campaigns: (default-to u0 (get total-campaigns current-rep)),
        successful-campaigns: (default-to u0 (get successful-campaigns current-rep)),
        total-raised: (default-to u0 (get total-raised current-rep)),
        completed-milestones: (+ u1 (default-to u0 (get completed-milestones current-rep))),
        reputation-score: (calculate-reputation-score organizer),
        trust-level: (calculate-trust-level organizer)
      }
    )
    (ok true)
  )
)

(define-public (finalize-campaign-outcome (campaign-id uint))
  (let ((campaign (unwrap! (get-campaign campaign-id) ERR-CAMPAIGN-NOT-FOUND))
        (organizer (get organizer campaign))
        (target (get target-amount campaign))
        (raised (get raised-amount campaign))
        (completion-percentage (if (> target u0) (/ (* raised u100) target) u0))
        (is-successful (>= raised (* target u80 (/ u1 u100))))
        (current-rep (get-organizer-reputation organizer)))
    (asserts! (is-eq tx-sender organizer) ERR-NOT-AUTHORIZED)
    (map-set campaign-outcomes
      { campaign-id: campaign-id }
      {
        is-successful: is-successful,
        completion-percentage: completion-percentage,
        milestones-completed: (get-campaign-milestone-count campaign-id),
        outcome-verified: true
      }
    )
    (map-set organizer-reputation
      { organizer: organizer }
      {
        total-campaigns: (default-to u0 (get total-campaigns current-rep)),
        successful-campaigns: (+ (if is-successful u1 u0) (default-to u0 (get successful-campaigns current-rep))),
        total-raised: (+ raised (default-to u0 (get total-raised current-rep))),
        completed-milestones: (default-to u0 (get completed-milestones current-rep)),
        reputation-score: (calculate-reputation-score organizer),
        trust-level: (calculate-trust-level organizer)
      }
    )
    (ok is-successful)
  )
)

(define-read-only (calculate-reputation-score (organizer principal))
  (let ((rep (get-organizer-reputation organizer)))
    (match rep
      current-rep
      (let ((total-campaigns (get total-campaigns current-rep))
            (successful-campaigns (get successful-campaigns current-rep))
            (completed-milestones (get completed-milestones current-rep)))
        (if (> total-campaigns u0)
          (+ (/ (* successful-campaigns u60) total-campaigns)
             (if (< (* completed-milestones u5) u40) (* completed-milestones u5) u40))
          u0
        )
      )
      u0
    )
  )
)

(define-read-only (calculate-trust-level (organizer principal))
  (let ((score (calculate-reputation-score organizer)))
    (if (>= score u90) u5
      (if (>= score u75) u4
        (if (>= score u60) u3
          (if (>= score u40) u2
            (if (>= score u20) u1 u0)
          )
        )
      )
    )
  )
)

(define-read-only (get-organizer-trust-metrics (organizer principal))
  (let ((rep (get-organizer-reputation organizer)))
    (match rep
      current-rep
      (ok {
        organizer: organizer,
        total-campaigns: (get total-campaigns current-rep),
        successful-campaigns: (get successful-campaigns current-rep),
        success-rate: (if (> (get total-campaigns current-rep) u0)
                        (/ (* (get successful-campaigns current-rep) u100) (get total-campaigns current-rep))
                        u0),
        total-raised: (get total-raised current-rep),
        completed-milestones: (get completed-milestones current-rep),
        reputation-score: (get reputation-score current-rep),
        trust-level: (get trust-level current-rep)
      })
      (ok {
        organizer: organizer,
        total-campaigns: u0,
        successful-campaigns: u0,
        success-rate: u0,
        total-raised: u0,
        completed-milestones: u0,
        reputation-score: u0,
        trust-level: u0
      })
    )
  )
)

(define-read-only (is-trusted-organizer (organizer principal))
  (>= (calculate-trust-level organizer) u3)
)

(define-read-only (contract-principal)
  (as-contract tx-sender)
)

(define-read-only (get-escrowed-amount (donor principal) (campaign-id uint))
  (default-to u0 (get amount (map-get? escrow-donations { campaign-id: campaign-id, donor: donor })))
)

(define-read-only (get-escrow-total (campaign-id uint))
  (default-to u0 (get total (map-get? escrow-total { campaign-id: campaign-id })))
)

(define-read-only (is-refund-eligible (campaign-id uint))
  (match (get-campaign campaign-id)
    campaign
    (let ((deadline (+ (get created-at campaign) REFUND-WINDOW-BLOCKS))
          (outcome (map-get? campaign-outcomes { campaign-id: campaign-id }))
          (outcome-failed (match outcome
                            data
                            (and (get outcome-verified data) (not (get is-successful data)))
                            false)))
      (or (not (get is-active campaign))
          outcome-failed
          (and (>= stacks-block-height deadline)
               (< (get raised-amount campaign) (get target-amount campaign))))
    )
    false
  )
)

(define-public (donate-escrow (campaign-id uint) (amount uint))
  (let ((campaign (unwrap! (get-campaign campaign-id) ERR-CAMPAIGN-NOT-FOUND))
        (prev (map-get? escrow-donations { campaign-id: campaign-id, donor: tx-sender }))
        (prev-amt (default-to u0 (get amount prev)))
        (recipient (contract-principal))
        (total-row (map-get? escrow-total { campaign-id: campaign-id }))
        (total-prev (default-to u0 (get total total-row))))
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    (asserts! (get is-active campaign) ERR-CAMPAIGN-INACTIVE)
    (try! (stx-transfer? amount tx-sender recipient))
    (map-set escrow-donations { campaign-id: campaign-id, donor: tx-sender }
      { amount: (+ prev-amt amount), timestamp: stacks-block-height })
    (map-set escrow-total { campaign-id: campaign-id } { total: (+ total-prev amount) })
    (ok (+ prev-amt amount))
  )
)

(define-public (claim-escrow-refund (campaign-id uint))
  (let ((record (map-get? escrow-donations { campaign-id: campaign-id, donor: tx-sender }))
        (amount (default-to u0 (get amount record)))
        (eligible (is-refund-eligible campaign-id))
        (total-row (map-get? escrow-total { campaign-id: campaign-id }))
        (total-prev (default-to u0 (get total total-row)))
        (sender (contract-principal)))
    (asserts! (> amount u0) ERR-NO-ESCROW)
    (asserts! eligible ERR-REFUND-NOT-ELIGIBLE)
    (try! (as-contract (stx-transfer? amount sender tx-sender)))
    (map-set escrow-donations { campaign-id: campaign-id, donor: tx-sender }
      { amount: u0, timestamp: stacks-block-height })
    (map-set escrow-total { campaign-id: campaign-id }
      { total: (if (> total-prev amount) (- total-prev amount) u0) })
    (ok amount)
  )
)

(define-public (convert-escrow-to-donation (campaign-id uint) (amount uint))
  (let ((campaign (unwrap! (get-campaign campaign-id) ERR-CAMPAIGN-NOT-FOUND))
        (record (map-get? escrow-donations { campaign-id: campaign-id, donor: tx-sender }))
        (escrowed (default-to u0 (get amount record)))
        (sender (contract-principal))
        (organizer (get organizer campaign))
        (total-row (map-get? escrow-total { campaign-id: campaign-id }))
        (total-prev (default-to u0 (get total total-row)))
        (prior-donation (map-get? donations { donor: tx-sender, campaign-id: campaign-id }))
        (prior-amt (default-to u0 (get amount prior-donation))))
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    (asserts! (>= escrowed amount) ERR-INSUFFICIENT-FUNDS)
    (try! (as-contract (stx-transfer? amount sender organizer)))
    (map-set escrow-donations { campaign-id: campaign-id, donor: tx-sender }
      { amount: (- escrowed amount), timestamp: stacks-block-height })
    (map-set escrow-total { campaign-id: campaign-id }
      { total: (if (> total-prev amount) (- total-prev amount) u0) })
    (map-set campaigns { campaign-id: campaign-id }
      (merge campaign { raised-amount: (+ (get raised-amount campaign) amount) }))
    (map-set donations { donor: tx-sender, campaign-id: campaign-id }
      { amount: (+ amount prior-amt), timestamp: stacks-block-height })
    (map-set donor-total-donations { donor: tx-sender }
      { total: (+ amount (get-donor-total tx-sender)) })
    (ok amount)
  )
)
