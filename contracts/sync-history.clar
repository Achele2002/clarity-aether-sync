;; AetherSync History Contract

;; Constants
(define-constant err-invalid-client (err u200))
(define-constant err-invalid-page (err u201))

;; Data structures
(define-map sync-history
  { client: principal, version: uint }
  {
    data-hash: (buff 32),
    timestamp: uint,
    previous-version: uint,
    metadata: (optional (string-utf8 256))
  }
)

;; History operations
(define-public (record-history
  (client principal)
  (version uint)
  (data-hash (buff 32))
  (previous-version uint)
  (metadata (optional (string-utf8 256)))
)
  (begin
    (asserts! (contract-call? .aether-sync is-client-authorized client) err-invalid-client)
    (ok (map-set sync-history
      {client: client, version: version}
      {
        data-hash: data-hash,
        timestamp: block-height,
        previous-version: previous-version,
        metadata: metadata
      }
    ))
  )
)

;; Read operations
(define-read-only (get-history-entry (client principal) (version uint))
  (map-get? sync-history {client: client, version: version})
)

(define-read-only (get-history-page (client principal) (start-version uint) (page-size uint))
  (let
    ((max-version (+ start-version page-size)))
    (filter map-get? sync-history
      (map (lambda (v) {client: client, version: v})
        (list start-version (+ start-version u1) (+ start-version u2)))
    )
  )
)
