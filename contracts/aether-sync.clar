;; AetherSync Main Contract

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-unauthorized (err u101))
(define-constant err-invalid-version (err u102))

;; Data structures
(define-map sync-states
  { client: principal }
  {
    version: uint,
    data-hash: (buff 32),
    timestamp: uint,
    previous-version: uint
  }
)

(define-map authorized-clients
  { client: principal }
  { authorized: bool }
)

;; Authorization
(define-public (authorize-client (client principal))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (ok (map-set authorized-clients {client: client} {authorized: true}))
  )
)

(define-public (revoke-client (client principal))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (ok (map-set authorized-clients {client: client} {authorized: false}))
  )
)

;; Sync operations
(define-public (record-sync 
  (version uint)
  (data-hash (buff 32))
  (previous-version uint)
)
  (let
    (
      (client tx-sender)
      (is-authorized (default-to false (get authorized (map-get? authorized-clients {client: client}))))
    )
    (asserts! is-authorized err-unauthorized)
    (ok (map-set sync-states
      {client: client}
      {
        version: version,
        data-hash: data-hash,
        timestamp: block-height,
        previous-version: previous-version
      }
    ))
  )
)

;; Read operations
(define-read-only (get-sync-state (client principal))
  (map-get? sync-states {client: client})
)

(define-read-only (is-client-authorized (client principal))
  (default-to false (get authorized (map-get? authorized-clients {client: client})))
)
