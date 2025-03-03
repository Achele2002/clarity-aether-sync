;; AetherSync Main Contract

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-unauthorized (err u101))
(define-constant err-invalid-version (err u102))
(define-constant err-version-gap (err u103))
(define-constant err-concurrent-update (err u104))
(define-constant err-invalid-page-size (err u105))
(define-constant err-invalid-data-hash (err u106))

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

;; Helper functions
(define-private (is-valid-hash (hash (buff 32)))
  (is-eq (len hash) u32)
)

(define-private (check-version-gap (current-version uint) (new-version uint))
  (< (- new-version current-version) u10)
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
        (check-version-gap (get version current-state) version)
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
    (asserts! (is-valid-hash data-hash) err-invalid-data-hash)
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

;; Enhanced event pagination
(define-read-only (get-latest-events (start-id uint) (page-size uint))
  (begin
    (asserts! (and (>= page-size u1) (<= page-size u50)) err-invalid-page-size)
    (let
      (
        (max-id (var-get last-event-id))
        (actual-start (if (> start-id max-id) max-id start-id))
      )
      (filter map-get? sync-events
        (map - (list actual-start (- actual-start u1) (- actual-start u2)))
      )
    )
  )
)

;; Read operations
(define-read-only (get-sync-state (client principal))
  (map-get? sync-states {client: client})
)

(define-read-only (is-client-authorized (client principal))
  (default-to false (get authorized (map-get? authorized-clients {client: client})))
)
