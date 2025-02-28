;; AetherSync Main Contract

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-unauthorized (err u101))
(define-constant err-invalid-version (err u102))
(define-constant err-version-gap (err u103))
(define-constant err-concurrent-update (err u104))

;; Data structures
(define-map sync-states
  { client: principal }
  {
    version: uint,
    data-hash: (buff 32),
    timestamp: uint,
    previous-version: uint,
    last-modified: uint
  }
)

(define-map authorized-clients
  { client: principal }
  { authorized: bool }
)

;; Events
(define-data-var last-event-id uint u0)

(define-map sync-events
  { event-id: uint }
  {
    client: principal,
    event-type: (string-ascii 24),
    version: uint,
    timestamp: uint
  }
)

;; Authorization
(define-public (authorize-client (client principal))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (print {event: "client-authorized", client: client})
    (ok (map-set authorized-clients {client: client} {authorized: true}))
  )
)

(define-public (revoke-client (client principal))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (print {event: "client-revoked", client: client})
    (ok (map-set authorized-clients {client: client} {authorized: false}))
  )
)

;; Event handling
(define-private (record-event (client principal) (event-type (string-ascii 24)) (version uint))
  (let
    ((event-id (+ (var-get last-event-id) u1)))
    (var-set last-event-id event-id)
    (map-set sync-events
      {event-id: event-id}
      {
        client: client,
        event-type: event-type,
        version: version,
        timestamp: block-height
      }
    )
  )
)

;; Version validation
(define-private (validate-version (client principal) (version uint) (previous-version uint))
  (let
    ((current-state (map-get? sync-states {client: client})))
    (asserts! (or
      (is-none current-state)
      (and
        (> version (get version current-state))
        (is-eq previous-version (get version current-state))
      )
    ) err-invalid-version)
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
    (asserts! (validate-version client version previous-version) err-invalid-version)
    
    (record-event client "sync-recorded" version)
    
    (ok (map-set sync-states
      {client: client}
      {
        version: version,
        data-hash: data-hash,
        timestamp: block-height,
        previous-version: previous-version,
        last-modified: block-height
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

(define-read-only (get-latest-events (start-id uint) (count uint))
  (let
    ((max-id (var-get last-event-id)))
    (filter map-get? sync-events
      (map + (list start-id (+ start-id u1) (+ start-id u2)))
    )
  )
)
