;; AetherSync History Contract

;; Constants
(define-constant err-invalid-client (err u200))

;; Data structures
(define-map sync-history
  { client: principal, version: uint }
  {
    data-hash: (buff 32),
    timestamp: uint,
    previous-version: uint
  }
)

;; History operations
(define-public (record-history
  (client principal)
  (version uint)
  (data-hash (buff 32))
  (previous-version uint)
)
  (begin
    (asserts! (contract-call? .aether-sync is-client-authorized client) err-invalid-client)
    (ok (map-set sync-history
      {client: client, version: version}
      {
        data-hash: data-hash,
        timestamp: block-height,
        previous-version: previous-version
      }
    ))
  )
)

;; Read operations
(define-read-only (get-history-entry (client principal) (version uint))
  (map-get? sync-history {client: client, version: version})
)
