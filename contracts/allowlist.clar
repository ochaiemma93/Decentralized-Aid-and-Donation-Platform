;; Allowlist Contract - Owner-managed membership list
;; Independent contract with no cross-contract calls or traits

;; Constants
(define-constant ERR-NOT-AUTHORIZED u1000)
(define-constant ERR-ALREADY-ADDED u1001)
(define-constant ERR-NOT-FOUND u1002)
(define-constant ERR-OWNER-ALREADY-SET u1003)

;; Data Variables
(define-data-var owner (optional principal) none)

;; Data Maps
(define-map allowlist principal bool)

;; Public Functions
(define-public (init-owner (new-owner principal))
  (if (is-some (var-get owner))
    (err ERR-OWNER-ALREADY-SET)
    (ok (var-set owner (some new-owner)))))

(define-public (add (who principal))
  (let ((current-owner (var-get owner)))
    (asserts! (is-some current-owner) (err ERR-NOT-AUTHORIZED))
    (asserts! (is-eq tx-sender (unwrap-panic current-owner)) (err ERR-NOT-AUTHORIZED))
    (asserts! (is-none (map-get? allowlist who)) (err ERR-ALREADY-ADDED))
    (ok (map-set allowlist who true))))

(define-public (remove (who principal))
  (let ((current-owner (var-get owner)))
    (asserts! (is-some current-owner) (err ERR-NOT-AUTHORIZED))
    (asserts! (is-eq tx-sender (unwrap-panic current-owner)) (err ERR-NOT-AUTHORIZED))
    (asserts! (is-some (map-get? allowlist who)) (err ERR-NOT-FOUND))
    (ok (map-delete allowlist who))))

;; Read-only Functions
(define-read-only (is-allowed (who principal))
  (default-to false (map-get? allowlist who)))

(define-read-only (get-owner)
  (var-get owner))