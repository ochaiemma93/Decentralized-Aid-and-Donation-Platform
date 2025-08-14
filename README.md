# Decentralized Aid and Donation Platform

A transparent blockchain-based donation platform built on Stacks that ensures complete visibility and accountability for charitable donations.

## Features

- **Transparent Campaigns**: Create fundraising campaigns with detailed descriptions and target amounts
- **Milestone Tracking**: Break down campaigns into measurable milestones with completion proof
- **Donation Transparency**: Track every donation from sender to final usage
- **Fund Usage Recording**: Document exactly how donated funds are spent with proof
- **Real-time Progress**: Monitor campaign progress and funding efficiency
- **Anti-fraud Protection**: Blockchain-based verification prevents fund misappropriation

## Smart Contract Functions

### Campaign Management

- `create-campaign` - Create a new fundraising campaign
- `activate-campaign` / `deactivate-campaign` - Control campaign status
- `get-campaign` - Retrieve campaign details
- `get-campaign-progress` - View funding progress and statistics

### Donations

- `donate` - Contribute STX to a campaign
- `get-donation` - Check individual donation records
- `get-donor-total` - View total donations by a donor

### Milestones

- `add-milestone` - Define campaign milestones with funding requirements
- `complete-milestone` - Mark milestones complete with proof documentation
- `get-milestone` - Retrieve milestone details

### Transparency & Tracking

- `record-fund-usage` - Document how funds are spent with receipts
- `get-fund-usage` - View fund usage records
- `get-transaction-history` - Access complete transaction history
- `calculate-campaign-efficiency` - Measure fundraising effectiveness

## Usage Examples

### Creating a Campaign
```clarity
(contract-call? .Aid-and-Donation-Platform create-campaign 
  "Emergency Food Relief"
  "Providing meals for 1000 families affected by natural disaster"
  u50000000
  "Emergency Relief")
```

### Making a Donation
```clarity
(contract-call? .Aid-and-Donation-Platform donate u1 u1000000)
```

### Recording Fund Usage
```clarity
(contract-call? .Aid-and-Donation-Platform record-fund-usage 
  u1
  u500000
  "Purchase of 200 food packages"
  'SP1EXAMPLE...
  (some "receipt-hash-abc123"))
```

## Data Structures

- **Campaigns**: Store organizer, target amounts, descriptions, and status
- **Donations**: Track donor contributions with timestamps
- **Milestones**: Define goals with completion requirements and proof
- **Fund Usage**: Record spending with purpose, recipient, and documentation
- **Donor Records**: Maintain total donation history per donor

## Error Codes

- `u401` - Not authorized (only campaign organizer can perform action)
- `u402` - Invalid amount (must be greater than 0)
- `u403` - Campaign inactive
- `u404` - Campaign not found
- `u405` - Insufficient funds
- `u406` - Milestone not found
- `u407` - Milestone already completed
- `u409` - Already exists

## Security Features

- Only campaign organizers can manage their campaigns
- All fund transfers are recorded on-chain
- Milestone completion requires proof documentation
- Donation tracking prevents double-spending
- Fund usage must be documented with recipients and purposes

## Getting Started

1. Deploy the contract to Stacks blockchain
2. Create campaigns using `create-campaign`
3. Accept donations via `donate` function
4. Track progress with milestones
5. Document fund usage for complete transparency

This platform ensures donors can verify their contributions reach intended recipients and see exactly how funds create impact.
