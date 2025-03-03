;; AetherSync History Contract

;; Constants
(define-constant err-invalid-client (err u200))
(define-constant err-invalid-page (err u201))
(define-constant err-invalid-metadata (err u202))

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

;; Helper functions
(define-private (validate-metadata (metadata (optional (string-utf8 256))))
  (match metadata
    metadata-string (< (len metadata-string) u256)
    true
  )
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
    (asserts! (validate-metadata metadata) err-invalid-metadata)
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

;; Enhanced pagination for history retrieval
(define-read-only (get-history-page (client principal) (start-version uint) (page-size uint))
  (begin
    (asserts! (and (>= page-size u1) (<= page-size u50)) err-invalid-page)
    (filter map-get? sync-history
      (map (lambda (v) {client: client, version: v})
        (generate-version-list start-version page-size))
    )
  )
)

(define-private (generate-version-list (start uint) (count uint))
  (list start (+ start u1) (+ start u2))
)

;; Read operations
(define-read-only (get-history-entry (client principal) (version uint))
  (map-get? sync-history {client: client, version: version})
)
