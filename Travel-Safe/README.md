# Decentralized Travel Protection Smart Contract

## Overview

This Clarity smart contract provides a decentralized travel insurance platform that enables users to purchase travel insurance policies, submit claims for travel-related incidents, and receive automated payouts. The contract supports multiple types of travel coverage including trip cancellations, flight delays, baggage loss, medical emergencies, and trip interruptions.

## Key Features

- **Automated Policy Management**: Purchase and manage travel insurance policies with flexible coverage options
- **Multi-Tier Coverage**: Three policy tiers (Basic, Comprehensive, Premium) with different coverage percentages
- **Claim Processing**: Streamlined claim submission and processing system
- **Automated Payouts**: Instant payouts for eligible flight delay claims
- **Policy Cancellation**: Cancel policies before trip departure with partial refunds
- **Administrative Controls**: Authorized claim processors and contract owner management

## Contract Architecture

### Policy Tiers and Coverage

The contract supports three policy tiers with varying coverage percentages:

#### Basic Tier
- Trip Cancellation: 50%
- Flight Delay: 10%
- Baggage Loss: 20%
- Medical Emergency: 80%
- Trip Interruption: 40%

#### Comprehensive Tier
- Trip Cancellation: 75%
- Flight Delay: 20%
- Baggage Loss: 30%
- Medical Emergency: 100%
- Trip Interruption: 60%

#### Premium Tier
- Trip Cancellation: 100%
- Flight Delay: 30%
- Baggage Loss: 50%
- Medical Emergency: 100%
- Trip Interruption: 80%

### Constants and Limits

- **Minimum Premium**: 0.1 STX
- **Maximum Coverage**: 100,000 STX
- **Trip Duration**: 1 day to 365 days
- **Claim Window**: 30 days after trip return
- **Maximum Policies per User**: 50
- **Maximum Claims per Policy**: 10

## Core Functions

### Policy Management

#### `purchase-travel-insurance-policy`
Purchase a new travel insurance policy.

**Parameters:**
- `desired-coverage-amount` (uint): Total coverage amount in microSTX
- `trip-departure-block` (uint): Block height when trip begins
- `trip-return-block` (uint): Block height when trip ends
- `destination-location` (string-ascii 100): Travel destination
- `selected-tier` (uint): Policy tier (1=Basic, 2=Comprehensive, 3=Premium)

**Returns:** Policy ID

#### `cancel-active-policy`
Cancel an active policy before trip departure with 50% refund.

**Parameters:**
- `policy-id` (uint): ID of the policy to cancel

**Returns:** Refund amount

### Claim Processing

#### `submit-insurance-claim`
Submit a claim for a travel-related incident.

**Parameters:**
- `policy-id` (uint): Associated policy ID
- `incident-type` (uint): Type of incident (1-5)
- `claim-amount` (uint): Requested claim amount
- `incident-description` (string-ascii 500): Description of the incident
- `evidence-documentation` (string-ascii 64): Hash of supporting evidence

**Returns:** Claim ID

#### `process-submitted-claim`
Process a submitted claim (admin function).

**Parameters:**
- `claim-id` (uint): ID of the claim to process
- `approve-claim` (bool): Whether to approve or reject the claim

#### `execute-claim-payment`
Execute payment for an approved claim.

**Parameters:**
- `claim-id` (uint): ID of the approved claim

#### `execute-automatic-flight-delay-payout`
Automatically process and pay flight delay claims.

**Parameters:**
- `claim-id` (uint): ID of the flight delay claim

### Administrative Functions

#### `deposit-contract-funds`
Deposit funds to ensure contract liquidity (owner only).

**Parameters:**
- `deposit-amount` (uint): Amount to deposit

#### `grant-processor-authorization`
Authorize a new claim processor (owner only).

**Parameters:**
- `processor-address` (principal): Address to authorize

#### `revoke-processor-authorization`
Revoke claim processor authorization (owner only).

**Parameters:**
- `processor-address` (principal): Address to deauthorize

## Read-Only Functions

### `get-policy-details`
Retrieve detailed information about a specific policy.

### `get-claim-information`
Get comprehensive claim data by claim ID.

### `get-user-policy-collection`
List all policies owned by a specific user.

### `get-policy-claim-history`
Get all claims associated with a policy.

### `get-comprehensive-contract-statistics`
Retrieve overall contract statistics including total policies, claims, and financial metrics.

### `get-tier-coverage-details`
Get coverage percentages for a specific policy tier.

### `calculate-premium-quote`
Calculate premium cost for given coverage parameters.

### `check-processor-authorization-status`
Check if an address is authorized to process claims.

## Claim Types

1. **Trip Cancellation** (type 1): Coverage for cancelled trips
2. **Flight Delay** (type 2): Compensation for delayed flights
3. **Baggage Loss** (type 3): Reimbursement for lost luggage
4. **Medical Emergency** (type 4): Coverage for medical incidents
5. **Trip Interruption** (type 5): Compensation for interrupted trips

## Policy Status

- **Active** (1): Policy is currently valid
- **Expired** (2): Policy has passed its expiration date
- **Cancelled** (3): Policy was cancelled by the holder
- **Claimed** (4): Policy has had a claim processed

## Claim Status

- **Pending Review** (1): Claim submitted, awaiting processing
- **Approved Payment** (2): Claim approved, pending payment
- **Rejected Invalid** (3): Claim rejected
- **Payment Completed** (4): Claim payment executed

## Premium Calculation

Premiums are calculated based on:
- Coverage amount
- Trip duration
- Policy tier selected

**Formula:**
```
Premium = (Coverage × Base Rate × Duration Multiplier) / 1,000,000
```

Base rates:
- Basic: 0.005% (50 basis points)
- Comprehensive: 0.0075% (75 basis points)
- Premium: 0.01% (100 basis points)

Duration multipliers:
- 1-7 days: 1.0x
- 8-30 days: 1.5x
- 31+ days: 2.0x

## Error Codes

- `u100`: Unauthorized access
- `u101`: Invalid policy data
- `u102`: Policy has expired
- `u103`: Insufficient contract funds
- `u104`: Claim already submitted
- `u105`: Invalid claim data
- `u106`: Claim submission expired
- `u107`: Already processed request
- `u108`: Invalid amount specified
- `u109`: Policy not active
- `u110`: Invalid date range
- `u111`: User policy list full
- `u112`: Policy claim list full
- `u113`: Invalid input parameter
- `u114`: Invalid string format

## Usage Example

```clarity
;; Purchase a comprehensive policy for 1000 STX coverage
(contract-call? .travel-insurance purchase-travel-insurance-policy
  u1000000000  ;; 1000 STX in microSTX
  u2000000     ;; Departure block
  u2001000     ;; Return block (approximately 7 days later)
  "Paris, France"
  u2)          ;; Comprehensive tier

;; Submit a flight delay claim
(contract-call? .travel-insurance submit-insurance-claim
  u1           ;; Policy ID
  u2           ;; Flight delay type
  u50000000    ;; 50 STX claim amount
  "Flight delayed 4 hours due to weather"
  "evidence-hash-123")
```

## Security Considerations

- All policy purchases require upfront premium payment
- Claims must be submitted within 30 days of trip completion
- Only policy holders can submit claims for their policies
- Contract maintains sufficient reserves for claim payouts
- Authorized processors are required for claim approval
- Policy cancellations only available before trip departure

## Deployment Requirements

- Stacks blockchain compatibility
- Sufficient STX balance for contract deployment
- Initial funding for claim reserves
- Authorized claim processor setup