# Milestone Payment Smart Contract

A time-locked smart contract for project milestone payments built on the Stacks blockchain using Clarity.

## Overview

The Milestone Payment Contract enables secure, automated payments for project-based work. It allows project owners to set up milestone-based payment schedules that release funds to contractors automatically when predefined time conditions are met.

## Features

- **Time-locked payments**: Milestones are only payable after their due block height
- **Multi-milestone projects**: Support for up to 10 milestones per project
- **Automated execution**: Payments release automatically when conditions are met
- **Dual authorization**: Both project owner and contractor can trigger payments
- **Fraud prevention**: Built-in checks prevent double payments and unauthorized access
- **Transparent tracking**: All milestone and project data is publicly readable

## Contract Architecture

### Data Structures

**Projects**
```clarity
{
  owner: principal,           // Project creator/funder
  contractor: principal,      // Payment recipient
  total-milestones: uint,     // Number of milestones
  total-amount: uint,         // Total project value in μSTX
  created-block: uint         // Block when project was created
}
```

**Milestones**
```clarity
{
  recipient: principal,       // Who receives the payment
  amount: uint,              // Payment amount in μSTX
  due-block: uint,           // Block height when payment becomes available
  paid: bool,                // Payment status
  description: string        // Milestone description (max 256 chars)
}
```

## Usage Guide

### 1. Creating a Project

```clarity
(contract-call? .milestone-pay create-project
  'ST1CONTRACTOR-ADDRESS
  (list
    { amount: u1000000, delay-blocks: u144, description: "Phase 1: Design" }
    { amount: u2000000, delay-blocks: u1008, description: "Phase 2: Development" }
    { amount: u1500000, delay-blocks: u2016, description: "Phase 3: Testing" }
  )
)
```

**Parameters:**
- `contractor`: Principal address of the payment recipient
- `milestone-data`: List of milestone objects with amount, delay, and description

**Returns:** Project ID (uint)

### 2. Funding a Project

```clarity
(contract-call? .milestone-pay fund-project u1 u4500000)
```

**Parameters:**
- `project-id`: The project ID returned from create-project
- `amount`: Amount in μSTX to fund the contract

**Note:** Only the project owner can fund their projects.

### 3. Releasing Milestone Payments

```clarity
(contract-call? .milestone-pay release-milestone u1 u0)
```

**Parameters:**
- `project-id`: Target project ID
- `milestone-id`: Milestone index (starting from 0)

**Authorization:** Either project owner or contractor can trigger payment release.

## Read-Only Functions

### Get Project Information
```clarity
(contract-call? .milestone-pay get-project u1)
```

### Get Milestone Details
```clarity
(contract-call? .milestone-pay get-milestone u1 u0)
```

### Check if Milestone is Ready
```clarity
(contract-call? .milestone-pay is-milestone-ready u1 u0)
```

### Get Contract Balance
```clarity
(contract-call? .milestone-pay get-contract-balance)
```

## Time Calculations

The contract uses Stacks block heights for timing:
- **Average block time**: ~10 minutes
- **Blocks per hour**: ~6
- **Blocks per day**: ~144
- **Blocks per week**: ~1,008

**Example delays:**
- 1 day: `u144`
- 1 week: `u1008`
- 1 month: `u4320`

## Error Codes

| Code | Error | Description |
|------|-------|-------------|
| u100 | ERR_UNAUTHORIZED | Caller not authorized for this action |
| u101 | ERR_MILESTONE_NOT_FOUND | Project or milestone doesn't exist |
| u102 | ERR_MILESTONE_ALREADY_PAID | Milestone has already been paid |
| u103 | ERR_MILESTONE_NOT_DUE | Milestone due block not yet reached |
| u104 | ERR_INSUFFICIENT_FUNDS | Contract has insufficient STX balance |
| u105 | ERR_INVALID_AMOUNT | Amount must be greater than 0 |

## Security Considerations

### Access Control
- Only project owners can create and fund projects
- Both owners and contractors can trigger milestone payments
- No external parties can access project funds

### Anti-Fraud Measures
- Milestones can only be paid once
- Payments only release after due block height
- All state changes are atomic and validated

### Best Practices
1. **Fund before milestones are due**: Ensure contract has sufficient balance
2. **Verify addresses**: Double-check contractor addresses before project creation
3. **Clear descriptions**: Use descriptive milestone names for transparency
4. **Appropriate timing**: Set realistic block delays for milestone completion

## Deployment

### Prerequisites
- Stacks wallet with STX for deployment
- Clarity CLI or Stacks development environment
- Access to Stacks testnet or mainnet

### Deployment Steps

1. **Deploy the contract:**
```bash
clarinet deploy --network=testnet
```

2. **Verify deployment:**
```clarity
(contract-call? .milestone-pay get-current-block)
```

## Example Workflow

```clarity
;; 1. Create project (returns project-id: u1)
(contract-call? .milestone-pay create-project 
  'ST1CONTRACTOR-PRINCIPAL
  (list
    { amount: u1000000, delay-blocks: u144, description: "Milestone 1" }
    { amount: u1000000, delay-blocks: u288, description: "Milestone 2" }
  )
)

;; 2. Fund the project
(contract-call? .milestone-pay fund-project u1 u2000000)

;; 3. Wait for block height to reach due-block
;; 4. Release first milestone (after 144 blocks)
(contract-call? .milestone-pay release-milestone u1 u0)

;; 5. Release second milestone (after 288 blocks)
(contract-call? .milestone-pay release-milestone u1 u1)
```

## Testing

Use the Clarity REPL or test framework to verify functionality:

```clarity
;; Check milestone readiness
(is-milestone-ready u1 u0)

;; Verify project state
(get-project u1)

;; Monitor contract balance
(get-contract-balance)
```
