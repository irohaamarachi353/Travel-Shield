;; Decentralized Travel Protection Smart Contract
;; Automated travel insurance platform enabling policy purchases, claim submissions, 
;; and instant payouts for travel-related incidents including trip cancellations,
;; flight delays, baggage loss, medical emergencies, and trip interruptions.

;; Error constants
(define-constant err-unauthorized-access (err u100))
(define-constant err-invalid-policy-data (err u101))
(define-constant err-policy-has-expired (err u102))
(define-constant err-insufficient-contract-funds (err u103))
(define-constant err-claim-already-submitted (err u104))
(define-constant err-invalid-claim-data (err u105))
(define-constant err-claim-submission-expired (err u106))
(define-constant err-already-processed-request (err u107))
(define-constant err-invalid-amount-specified (err u108))
(define-constant err-policy-not-active-status (err u109))
(define-constant err-invalid-date-range (err u110))
(define-constant err-user-policy-list-full (err u111))
(define-constant err-policy-claim-list-full (err u112))
(define-constant err-invalid-input-parameter (err u113))
(define-constant err-invalid-string-format (err u114))

;; Financial and time constraints
(define-constant minimum-premium-amount u100000) ;; 0.1 STX minimum
(define-constant maximum-coverage-limit u100000000000) ;; 100,000 STX maximum
(define-constant minimum-trip-duration-days u1) ;; 1 day minimum
(define-constant maximum-trip-duration-days u365) ;; 1 year maximum
(define-constant claim-submission-window-blocks u4320) ;; ~30 days in blocks (assuming 10 min blocks)
(define-constant maximum-policy-identifier u1000000) ;; Policy ID limit
(define-constant maximum-claim-identifier u1000000) ;; Claim ID limit
(define-constant blocks-per-day u144) ;; Assuming 10 minute blocks

;; Policy status enumeration
(define-constant policy-status-active u1)
(define-constant policy-status-expired u2)
(define-constant policy-status-cancelled u3)
(define-constant policy-status-claimed u4)

;; Claim processing status enumeration
(define-constant claim-status-pending-review u1)
(define-constant claim-status-approved-payment u2)
(define-constant claim-status-rejected-invalid u3)
(define-constant claim-status-payment-completed u4)

;; Insurance claim type categories
(define-constant claim-type-trip-cancellation u1)
(define-constant claim-type-flight-delay u2)
(define-constant claim-type-baggage-loss u3)
(define-constant claim-type-medical-emergency u4)
(define-constant claim-type-trip-interruption u5)

;; Policy tier definitions
(define-constant policy-tier-basic u1)
(define-constant policy-tier-comprehensive u2)
(define-constant policy-tier-premium u3)

;; Contract state variables
(define-data-var next-available-policy-id uint u0)
(define-data-var next-available-claim-id uint u0)
(define-data-var total-collected-premiums uint u0)
(define-data-var total-paid-claim-amounts uint u0)
(define-data-var current-contract-balance uint u0)
(define-data-var contract-owner-address principal tx-sender)

;; Main policy storage with comprehensive details
(define-map active-insurance-policies
  { policy-identifier: uint }
  {
    policy-holder-address: principal,
    paid-premium-amount: uint,
    total-coverage-amount: uint,
    trip-departure-block: uint,
    trip-return-block: uint,
    travel-destination-name: (string-ascii 100),
    current-policy-status: uint,
    policy-creation-block: uint,
    selected-policy-tier: uint
  }
)

;; Insurance claim records with full tracking
(define-map submitted-insurance-claims
  { claim-identifier: uint }
  {
    associated-policy-id: uint,
    claim-submitter-address: principal,
    incident-claim-type: uint,
    requested-claim-amount: uint,
    incident-description-text: (string-ascii 500),
    supporting-evidence-hash: (string-ascii 64),
    current-claim-status: uint,
    claim-submission-block: uint,
    claim-processing-block: (optional uint),
    assigned-processor-address: (optional principal)
  }
)

;; User policy tracking for quick access
(define-map user-owned-policies
  { policy-holder: principal }
  { owned-policy-identifiers: (list 50 uint) }
)

;; Policy-specific claim tracking
(define-map policy-associated-claims
  { policy-identifier: uint }
  { related-claim-identifiers: (list 10 uint) }
)

;; Coverage percentage by policy tier and claim type
(define-map tier-coverage-percentages
  { policy-tier-level: uint }
  { 
    trip-cancellation-coverage: uint,
    flight-delay-coverage: uint,
    baggage-loss-coverage: uint,
    medical-emergency-coverage: uint,
    trip-interruption-coverage: uint
  }
)

;; Authorized claim processor registry
(define-map authorized-claim-processors
  { processor-address: principal }
  { is-currently-authorized: bool }
)

;; Initialize coverage percentages for different policy tiers (basis points: 10000 = 100%)
(map-set tier-coverage-percentages { policy-tier-level: policy-tier-basic }
  {
    trip-cancellation-coverage: u5000,   ;; 50% coverage
    flight-delay-coverage: u1000,        ;; 10% coverage
    baggage-loss-coverage: u2000,        ;; 20% coverage
    medical-emergency-coverage: u8000,   ;; 80% coverage
    trip-interruption-coverage: u4000    ;; 40% coverage
  }
)

(map-set tier-coverage-percentages { policy-tier-level: policy-tier-comprehensive }
  {
    trip-cancellation-coverage: u7500,   ;; 75% coverage
    flight-delay-coverage: u2000,        ;; 20% coverage
    baggage-loss-coverage: u3000,        ;; 30% coverage
    medical-emergency-coverage: u10000,  ;; 100% coverage
    trip-interruption-coverage: u6000    ;; 60% coverage
  }
)

(map-set tier-coverage-percentages { policy-tier-level: policy-tier-premium }
  {
    trip-cancellation-coverage: u10000,  ;; 100% coverage
    flight-delay-coverage: u3000,        ;; 30% coverage
    baggage-loss-coverage: u5000,        ;; 50% coverage
    medical-emergency-coverage: u10000,  ;; 100% coverage
    trip-interruption-coverage: u8000    ;; 80% coverage
  }
)

;; Input validation helper functions
(define-private (is-valid-coverage-amount (coverage-amount uint))
  (and (>= coverage-amount minimum-premium-amount) 
       (<= coverage-amount maximum-coverage-limit))
)

(define-private (is-valid-policy-tier (policy-tier uint))
  (and (>= policy-tier policy-tier-basic) 
       (<= policy-tier policy-tier-premium))
)

(define-private (is-valid-claim-type (claim-type uint))
  (and (>= claim-type claim-type-trip-cancellation) 
       (<= claim-type claim-type-trip-interruption))
)

(define-private (is-valid-policy-identifier (policy-id uint))
  (and (> policy-id u0) (<= policy-id maximum-policy-identifier))
)

(define-private (is-valid-claim-identifier (claim-id uint))
  (and (> claim-id u0) (<= claim-id maximum-claim-identifier))
)

(define-private (is-positive-amount (amount uint))
  (> amount u0)
)

(define-private (is-valid-destination-string (destination (string-ascii 100)))
  (> (len destination) u0)
)

(define-private (is-valid-description-text (description (string-ascii 500)))
  (> (len description) u0)
)

(define-private (is-valid-evidence-hash (evidence-hash (string-ascii 64)))
  (and (> (len evidence-hash) u0) (<= (len evidence-hash) u64))
)

(define-private (is-valid-processor-address (processor-address principal))
  (not (is-eq processor-address (as-contract tx-sender)))
)

;; Premium calculation based on coverage, duration, and tier
(define-private (compute-policy-premium (coverage-amount uint) (trip-duration-days uint) (policy-tier uint))
  (let
    (
      (base-premium-rate (if (is-eq policy-tier policy-tier-basic) u50
                         (if (is-eq policy-tier policy-tier-comprehensive) u75
                             u100)))
      (duration-multiplier (if (<= trip-duration-days u7) u100
                          (if (<= trip-duration-days u30) u150
                              u200)))
    )
    (/ (* (* coverage-amount base-premium-rate) duration-multiplier) u1000000)
  )
)

;; Comprehensive trip date validation using block heights
(define-private (are-valid-trip-dates (departure-block uint) (return-block uint))
  (let
    (
      (current-block stacks-block-height)
      (total-trip-duration (- return-block departure-block))
    )
    (and
      (> departure-block current-block)
      (> return-block departure-block)
      (>= total-trip-duration (* minimum-trip-duration-days blocks-per-day))
      (<= total-trip-duration (* maximum-trip-duration-days blocks-per-day))
    )
  )
)

;; Calculate maximum claimable amount for specific incident type
(define-private (get-maximum-claimable-amount (policy-id uint) (incident-type uint))
  (match (map-get? active-insurance-policies { policy-identifier: policy-id })
    policy-details
      (match (map-get? tier-coverage-percentages { policy-tier-level: (get selected-policy-tier policy-details) })
        coverage-rules
          (let
            (
              (total-coverage (get total-coverage-amount policy-details))
              (applicable-percentage (if (is-eq incident-type claim-type-trip-cancellation)
                                       (get trip-cancellation-coverage coverage-rules)
                                     (if (is-eq incident-type claim-type-flight-delay)
                                       (get flight-delay-coverage coverage-rules)
                                     (if (is-eq incident-type claim-type-baggage-loss)
                                       (get baggage-loss-coverage coverage-rules)
                                     (if (is-eq incident-type claim-type-medical-emergency)
                                       (get medical-emergency-coverage coverage-rules)
                                       (get trip-interruption-coverage coverage-rules))))))
            )
            (some (/ (* total-coverage applicable-percentage) u10000))
          )
        none
      )
    none
  )
)

;; Add new policy to user's collection
(define-private (register-policy-to-user (user-address principal) (policy-id uint))
  (let
    (
      (existing-policies (default-to (list) 
                           (get owned-policy-identifiers 
                             (map-get? user-owned-policies { policy-holder: user-address }))))
    )
    (match (as-max-len? (append existing-policies policy-id) u50)
      updated-policy-list (begin
        (map-set user-owned-policies
          { policy-holder: user-address }
          { owned-policy-identifiers: updated-policy-list }
        )
        (ok true)
      )
      err-user-policy-list-full
    )
  )
)

;; Associate new claim with its policy
(define-private (register-claim-to-policy (policy-id uint) (claim-id uint))
  (let
    (
      (existing-claims (default-to (list) 
                         (get related-claim-identifiers 
                           (map-get? policy-associated-claims { policy-identifier: policy-id }))))
    )
    (match (as-max-len? (append existing-claims claim-id) u10)
      updated-claim-list (begin
        (map-set policy-associated-claims
          { policy-identifier: policy-id }
          { related-claim-identifiers: updated-claim-list }
        )
        (ok true)
      )
      err-policy-claim-list-full
    )
  )
)

;; Main policy purchase function with comprehensive validation
(define-public (purchase-travel-insurance-policy 
  (desired-coverage-amount uint)
  (trip-departure-block uint) 
  (trip-return-block uint)
  (destination-location (string-ascii 100))
  (selected-tier uint))
  (let
    (
      (new-policy-id (+ (var-get next-available-policy-id) u1))
      (current-block stacks-block-height)
      (trip-length-days (/ (- trip-return-block trip-departure-block) blocks-per-day))
    )
    ;; Comprehensive input validation
    (asserts! (is-valid-coverage-amount desired-coverage-amount) err-invalid-amount-specified)
    (asserts! (is-valid-policy-tier selected-tier) err-invalid-policy-data)
    (asserts! (is-valid-destination-string destination-location) err-invalid-string-format)
    (asserts! (are-valid-trip-dates trip-departure-block trip-return-block) err-invalid-date-range)
    
    (let
      (
        (calculated-premium (compute-policy-premium desired-coverage-amount trip-length-days selected-tier))
      )
      (asserts! (>= calculated-premium minimum-premium-amount) err-invalid-amount-specified)
      
      ;; Process premium payment from customer to contract
      (try! (stx-transfer? calculated-premium tx-sender (as-contract tx-sender)))
      
      ;; Create comprehensive policy record
      (map-set active-insurance-policies
        { policy-identifier: new-policy-id }
        {
          policy-holder-address: tx-sender,
          paid-premium-amount: calculated-premium,
          total-coverage-amount: desired-coverage-amount,
          trip-departure-block: trip-departure-block,
          trip-return-block: trip-return-block,
          travel-destination-name: destination-location,
          current-policy-status: policy-status-active,
          policy-creation-block: current-block,
          selected-policy-tier: selected-tier
        }
      )
      
      ;; Update contract state and financial tracking
      (var-set next-available-policy-id new-policy-id)
      (var-set total-collected-premiums (+ (var-get total-collected-premiums) calculated-premium))
      (var-set current-contract-balance (+ (var-get current-contract-balance) calculated-premium))
      
      ;; Register policy with user account
      (try! (register-policy-to-user tx-sender new-policy-id))
      
      (ok new-policy-id)
    )
  )
)

;; Comprehensive claim submission with full validation
(define-public (submit-insurance-claim
  (policy-id uint)
  (incident-type uint)
  (claim-amount uint)
  (incident-description (string-ascii 500))
  (evidence-documentation (string-ascii 64)))
  (let
    (
      (new-claim-id (+ (var-get next-available-claim-id) u1))
      (submission-block stacks-block-height)
    )
    ;; Validate all claim submission parameters
    (asserts! (is-valid-policy-identifier policy-id) err-invalid-policy-data)
    (asserts! (is-valid-claim-type incident-type) err-invalid-claim-data)
    (asserts! (is-positive-amount claim-amount) err-invalid-amount-specified)
    (asserts! (is-valid-description-text incident-description) err-invalid-string-format)
    (asserts! (is-valid-evidence-hash evidence-documentation) err-invalid-string-format)
    
    (let
      (
        (policy-details (unwrap! (map-get? active-insurance-policies { policy-identifier: policy-id }) err-invalid-policy-data))
        (maximum-claimable (unwrap! (get-maximum-claimable-amount policy-id incident-type) err-invalid-claim-data))
      )
      ;; Verify claim eligibility and policy ownership
      (asserts! (is-eq tx-sender (get policy-holder-address policy-details)) err-unauthorized-access)
      (asserts! (is-eq (get current-policy-status policy-details) policy-status-active) err-policy-not-active-status)
      (asserts! (<= claim-amount maximum-claimable) err-invalid-amount-specified)
      (asserts! (<= submission-block (+ (get trip-return-block policy-details) claim-submission-window-blocks)) err-claim-submission-expired)
      
      ;; Create detailed claim record
      (map-set submitted-insurance-claims
        { claim-identifier: new-claim-id }
        {
          associated-policy-id: policy-id,
          claim-submitter-address: tx-sender,
          incident-claim-type: incident-type,
          requested-claim-amount: claim-amount,
          incident-description-text: incident-description,
          supporting-evidence-hash: evidence-documentation,
          current-claim-status: claim-status-pending-review,
          claim-submission-block: submission-block,
          claim-processing-block: none,
          assigned-processor-address: none
        }
      )
      
      ;; Update system counters and associations
      (var-set next-available-claim-id new-claim-id)
      (try! (register-claim-to-policy policy-id new-claim-id))
      
      (ok new-claim-id)
    )
  )
)

;; Administrative claim processing function
(define-public (process-submitted-claim (claim-id uint) (approve-claim bool))
  (let
    (
      (processing-block stacks-block-height)
      (updated-status (if approve-claim claim-status-approved-payment claim-status-rejected-invalid))
    )
    (asserts! (is-valid-claim-identifier claim-id) err-invalid-claim-data)
    
    ;; Verify processor authorization
    (asserts! (or 
      (is-eq tx-sender (var-get contract-owner-address))
      (default-to false (get is-currently-authorized 
                          (map-get? authorized-claim-processors { processor-address: tx-sender }))))
      err-unauthorized-access)
    
    (let
      (
        (claim-details (unwrap! (map-get? submitted-insurance-claims { claim-identifier: claim-id }) err-invalid-claim-data))
      )
      (asserts! (is-eq (get current-claim-status claim-details) claim-status-pending-review) err-already-processed-request)
      
      ;; Update claim with processing decision
      (map-set submitted-insurance-claims
        { claim-identifier: claim-id }
        (merge claim-details {
          current-claim-status: updated-status,
          claim-processing-block: (some processing-block),
          assigned-processor-address: (some tx-sender)
        })
      )
      
      (ok approve-claim)
    )
  )
)

;; Execute payment for approved claims
(define-public (execute-claim-payment (claim-id uint))
  (begin
    (asserts! (is-valid-claim-identifier claim-id) err-invalid-claim-data)
    
    (let
      (
        (claim-details (unwrap! (map-get? submitted-insurance-claims { claim-identifier: claim-id }) err-invalid-claim-data))
        (payment-amount (get requested-claim-amount claim-details))
      )
      (asserts! (is-eq (get current-claim-status claim-details) claim-status-approved-payment) err-invalid-claim-data)
      (asserts! (>= (var-get current-contract-balance) payment-amount) err-insufficient-contract-funds)
      
      ;; Transfer approved amount to claimant
      (try! (as-contract (stx-transfer? payment-amount tx-sender (get claim-submitter-address claim-details))))
      
      ;; Update claim status and financial records
      (map-set submitted-insurance-claims
        { claim-identifier: claim-id }
        (merge claim-details { current-claim-status: claim-status-payment-completed })
      )
      
      (var-set current-contract-balance (- (var-get current-contract-balance) payment-amount))
      (var-set total-paid-claim-amounts (+ (var-get total-paid-claim-amounts) payment-amount))
      
      (ok payment-amount)
    )
  )
)

;; Automated payout system for flight delay claims
(define-public (execute-automatic-flight-delay-payout (claim-id uint))
  (begin
    (asserts! (is-valid-claim-identifier claim-id) err-invalid-claim-data)
    
    (let
      (
        (claim-details (unwrap! (map-get? submitted-insurance-claims { claim-identifier: claim-id }) err-invalid-claim-data))
        (payout-amount (get requested-claim-amount claim-details))
      )
      (asserts! (is-eq (get incident-claim-type claim-details) claim-type-flight-delay) err-unauthorized-access)
      (asserts! (is-eq (get current-claim-status claim-details) claim-status-pending-review) err-already-processed-request)
      (asserts! (>= (var-get current-contract-balance) payout-amount) err-insufficient-contract-funds)
      
      ;; Auto-approve and complete payment
      (map-set submitted-insurance-claims
        { claim-identifier: claim-id }
        (merge claim-details {
          current-claim-status: claim-status-payment-completed,
          claim-processing-block: (some stacks-block-height),
          assigned-processor-address: (some (as-contract tx-sender))
        })
      )
      
      (try! (as-contract (stx-transfer? payout-amount tx-sender (get claim-submitter-address claim-details))))
      
      ;; Update financial state
      (var-set current-contract-balance (- (var-get current-contract-balance) payout-amount))
      (var-set total-paid-claim-amounts (+ (var-get total-paid-claim-amounts) payout-amount))
      
      (ok payout-amount)
    )
  )
)

;; Policy cancellation with partial refund mechanism
(define-public (cancel-active-policy (policy-id uint))
  (begin
    (asserts! (is-valid-policy-identifier policy-id) err-invalid-policy-data)
    
    (let
      (
        (policy-details (unwrap! (map-get? active-insurance-policies { policy-identifier: policy-id }) err-invalid-policy-data))
        (current-block stacks-block-height)
        (refund-amount (/ (get paid-premium-amount policy-details) u2)) ;; 50% refund policy
      )
      (asserts! (is-eq tx-sender (get policy-holder-address policy-details)) err-unauthorized-access)
      (asserts! (is-eq (get current-policy-status policy-details) policy-status-active) err-policy-not-active-status)
      (asserts! (> (get trip-departure-block policy-details) current-block) err-policy-has-expired)
      
      ;; Update policy status to cancelled
      (map-set active-insurance-policies
        { policy-identifier: policy-id }
        (merge policy-details { current-policy-status: policy-status-cancelled })
      )
      
      ;; Process cancellation refund
      (try! (as-contract (stx-transfer? refund-amount tx-sender (get policy-holder-address policy-details))))
      (var-set current-contract-balance (- (var-get current-contract-balance) refund-amount))
      
      (ok refund-amount)
    )
  )
)

;; Contract funding mechanism for liquidity management
(define-public (deposit-contract-funds (deposit-amount uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner-address)) err-unauthorized-access)
    (asserts! (is-positive-amount deposit-amount) err-invalid-amount-specified)
    (try! (stx-transfer? deposit-amount tx-sender (as-contract tx-sender)))
    (var-set current-contract-balance (+ (var-get current-contract-balance) deposit-amount))
    (ok deposit-amount)
  )
)

;; Processor authorization management
(define-public (grant-processor-authorization (processor-address principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner-address)) err-unauthorized-access)
    (asserts! (is-valid-processor-address processor-address) err-invalid-input-parameter)
    (map-set authorized-claim-processors { processor-address: processor-address } { is-currently-authorized: true })
    (ok true)
  )
)

(define-public (revoke-processor-authorization (processor-address principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner-address)) err-unauthorized-access)
    (asserts! (is-valid-processor-address processor-address) err-invalid-input-parameter)
    (map-set authorized-claim-processors { processor-address: processor-address } { is-currently-authorized: false })
    (ok true)
  )
)

;; Comprehensive read-only query functions

(define-read-only (get-policy-details (policy-id uint))
  (if (is-valid-policy-identifier policy-id)
    (map-get? active-insurance-policies { policy-identifier: policy-id })
    none
  )
)

(define-read-only (get-claim-information (claim-id uint))
  (if (is-valid-claim-identifier claim-id)
    (map-get? submitted-insurance-claims { claim-identifier: claim-id })
    none
  )
)

(define-read-only (get-user-policy-collection (user-address principal))
  (map-get? user-owned-policies { policy-holder: user-address })
)

(define-read-only (get-policy-claim-history (policy-id uint))
  (if (is-valid-policy-identifier policy-id)
    (map-get? policy-associated-claims { policy-identifier: policy-id })
    none
  )
)

(define-read-only (get-comprehensive-contract-statistics)
  {
    total-active-policies: (var-get next-available-policy-id),
    total-submitted-claims: (var-get next-available-claim-id),
    total-premium-revenue: (var-get total-collected-premiums),
    total-claims-expenditure: (var-get total-paid-claim-amounts),
    available-contract-balance: (var-get current-contract-balance)
  }
)

(define-read-only (get-tier-coverage-details (policy-tier uint))
  (if (is-valid-policy-tier policy-tier)
    (map-get? tier-coverage-percentages { policy-tier-level: policy-tier })
    none
  )
)

(define-read-only (calculate-premium-quote (coverage-amount uint) (departure-block uint) (return-block uint) (policy-tier uint))
  (if (and 
        (is-valid-coverage-amount coverage-amount)
        (is-valid-policy-tier policy-tier)
        (are-valid-trip-dates departure-block return-block))
    (let
      (
        (trip-duration (/ (- return-block departure-block) blocks-per-day))
      )
      (ok (compute-policy-premium coverage-amount trip-duration policy-tier))
    )
    err-invalid-policy-data
  )
)

(define-read-only (check-processor-authorization-status (processor-address principal))
  (default-to false (get is-currently-authorized 
                      (map-get? authorized-claim-processors { processor-address: processor-address })))
)