# Lumina Stream Smart Contract

## Description

Lumina Stream is a dynamic reputation-based DAO governance smart contract built on Stacks blockchain using Clarity. The contract implements a multi-dimensional reputation system where members earn domain-specific expertise through verifiable contributions and peer validation. Voting power is calculated dynamically based on streaming reputation (with time-decay) and expertise relevance to specific proposal committees.

The contract features automated proposal routing to expertise committees, cryptographic proof tracking for contributions, reputation decay mechanisms to ensure active participation, and decision accuracy tracking to incentivize quality governance. This creates a meritocratic governance system where expertise and recent activity determine influence rather than simple token holdings.

## Features

- **Dynamic Reputation Streaming**: Reputation decays over time to reward active participation and recent contributions
- **Domain-Specific Expertise**: Members build expertise in specific domains through validated contributions
- **Expertise Committees**: Proposals are routed to relevant expert committees for specialized decision-making
- **Weighted Voting Power**: Voting power calculated based on reputation and domain expertise relevance
- **Contribution Validation**: Cryptographic proof tracking with peer validation system
- **Decision Accuracy Tracking**: Members earn accuracy scores based on alignment with successful proposals
- **Reputation Decay**: Anti-gaming mechanism that reduces reputation for inactive members
- **Transparent Audit Trails**: Complete history of votes, contributions, and validations
- **Progressive Onboarding**: Members start with low reputation and build expertise over time
- **Automated Proposal Execution**: Passed proposals are marked and ready for execution

## Contract Functions

### Public Functions

#### `join-dao`
Join the DAO as a new member with zero initial reputation.
- **Parameters**: None
- **Returns**: `(ok true)` on success, `ERR-ALREADY-EXISTS` if already member
- **Usage**: First step for any new participant

#### `submit-contribution`
Submit a verifiable contribution with cryptographic proof to earn reputation.
- **Parameters**:
  - `domain (string-ascii 50)`: Domain of expertise for the contribution
  - `proof-hash (buff 32)`: Cryptographic hash of contribution proof
- **Returns**: `(ok contribution-id)` on success
- **Requires**: Must be a DAO member

#### `validate-contribution`
Validate another member's contribution to grant them reputation and expertise.
- **Parameters**:
  - `contribution-id (uint)`: ID of contribution to validate
  - `approved (bool)`: Whether to approve the contribution
- **Returns**: `(ok true)` on success
- **Requires**: Validator must have expertise score >= 10 in the domain

#### `create-committee`
Create a new expertise committee for a specific domain.
- **Parameters**:
  - `domain (string-ascii 50)`: Domain of expertise for the committee
- **Returns**: `(ok committee-id)` on success
- **Requires**: Member must have total reputation >= 100

#### `join-committee`
Join an existing expertise committee.
- **Parameters**:
  - `committee-id (uint)`: ID of committee to join
- **Returns**: `(ok true)` on success
- **Requires**: Must have expertise score >= 5 in committee's domain

#### `create-proposal`
Create a governance proposal routed to a specific committee.
- **Parameters**:
  - `title (string-ascii 100)`: Proposal title
  - `description (string-ascii 500)`: Proposal description
  - `committee-id (uint)`: Committee to route proposal to
  - `proposal-type (string-ascii 50)`: Type/category of proposal
- **Returns**: `(ok proposal-id)` on success
- **Requires**: Member must have total reputation >= 100

#### `vote-on-proposal`
Cast a vote on a proposal with expertise-weighted voting power.
- **Parameters**:
  - `proposal-id (uint)`: ID of proposal to vote on
  - `vote-for (bool)`: True to vote for, false to vote against
- **Returns**: `(ok true)` on success
- **Requires**: Voting period open, haven't voted yet, reputation >= 10

#### `execute-proposal`
Execute a proposal after voting period ends if it passed.
- **Parameters**:
  - `proposal-id (uint)`: ID of proposal to execute
- **Returns**: `(ok true)` on success
- **Requires**: Voting ended, not executed yet, more votes for than against

#### `update-decision-accuracy`
Update your decision accuracy score after a proposal is executed.
- **Parameters**:
  - `proposal-id (uint)`: ID of executed proposal you voted on
- **Returns**: `(ok true)` on success
- **Requires**: Proposal must be executed, must have voted on it

### Read-Only Functions

#### `get-member`
Retrieves member information and statistics.
- **Parameters**: `member (principal)`
- **Returns**: Member data or `none`

#### `get-expertise-score`
Retrieves domain-specific expertise score for a member.
- **Parameters**: `member (principal)`, `domain (string-ascii 50)`
- **Returns**: Expertise data or `none`

#### `get-proposal`
Retrieves proposal details including votes and status.
- **Parameters**: `proposal-id (uint)`
- **Returns**: Proposal data or `none`

#### `get-vote`
Retrieves vote record for a specific voter on a proposal.
- **Parameters**: `proposal-id (uint)`, `voter (principal)`
- **Returns**: Vote data or `none`

#### `get-contribution`
Retrieves contribution details and validation status.
- **Parameters**: `contribution-id (uint)`
- **Returns**: Contribution data or `none`

#### `get-committee`
Retrieves committee information.
- **Parameters**: `committee-id (uint)`
- **Returns**: Committee data or `none`

#### `is-committee-member`
Checks if a principal is a member of a specific committee.
- **Parameters**: `committee-id (uint)`, `member (principal)`
- **Returns**: `true` if member, `false` otherwise

#### `get-decision-accuracy`
Retrieves decision accuracy statistics for a member.
- **Parameters**: `member (principal)`
- **Returns**: Accuracy data or `none`

#### `calculate-streaming-reputation`
Calculates current reputation with time-decay applied (5% per day inactive).
- **Parameters**: `member (principal)`
- **Returns**: `(ok current-reputation)`

#### `calculate-voting-power`
Calculates voting power based on streaming reputation and expertise for a committee.
- **Parameters**: `member (principal)`, `committee-id (uint)`
- **Returns**: `(ok voting-power)`

#### `get-platform-stats`
Retrieves platform-wide statistics.
- **Parameters**: None
- **Returns**: Object with total-proposals, total-contributions, total-committees, total-members

## Usage Examples

### Join the DAO
```clarity
(contract-call? .lumina-stream join-dao)
```

### Submit a contribution in "blockchain-dev" domain
```clarity
(contract-call? .lumina-stream submit-contribution
  "blockchain-dev"
  0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef)
```

### Validate someone's contribution
```clarity
(contract-call? .lumina-stream validate-contribution u1 true)
```

### Create an expertise committee
```clarity
(contract-call? .lumina-stream create-committee "blockchain-dev")
```

### Join a committee
```clarity
(contract-call? .lumina-stream join-committee u1)
```

### Create a proposal
```clarity
(contract-call? .lumina-stream create-proposal
  "Upgrade Smart Contract"
  "Proposal to upgrade the main contract to add new features..."
  u1
  "technical-upgrade")
```

### Vote on a proposal
```clarity
(contract-call? .lumina-stream vote-on-proposal u1 true)
```

### Check your streaming reputation
```clarity
(contract-call? .lumina-stream calculate-streaming-reputation tx-sender)
```

### Check your voting power for a committee
```clarity
(contract-call? .lumina-stream calculate-voting-power tx-sender u1)
```

### Execute a passed proposal
```clarity
(contract-call? .lumina-stream execute-proposal u1)
```

### Update your decision accuracy
```clarity
(contract-call? .lumina-stream update-decision-accuracy u1)
```

### Get platform statistics
```clarity
(contract-call? .lumina-stream get-platform-stats)
```

## Testing

To test the Lumina Stream smart contract:

1. Navigate to the project directory:
```bash
cd lumina-stream/lumina-stream
```

2. Run Clarinet check to validate syntax:
```bash
clarinet check
```

3. Run the test suite:
```bash
npm install
npm test
```

4. Test in Clarinet console:
```bash
clarinet console
```

5. Example test sequence in console:
```clarity
;; Join as first member
(contract-call? .lumina-stream join-dao)

;; Submit a contribution
(contract-call? .lumina-stream submit-contribution "blockchain-dev" 0xabcd1234abcd1234abcd1234abcd1234abcd1234abcd1234abcd1234abcd1234)

;; Get member info
(contract-call? .lumina-stream get-member tx-sender)

;; Check platform stats
(contract-call? .lumina-stream get-platform-stats)

;; Calculate streaming reputation
(contract-call? .lumina-stream calculate-streaming-reputation tx-sender)
```

6. Multi-user governance test workflow:
```clarity
;; User 1: Join and build reputation
(contract-call? .lumina-stream join-dao)
(contract-call? .lumina-stream submit-contribution "governance" 0x1111111111111111111111111111111111111111111111111111111111111111)

;; User 2: Join and validate User 1's contribution
(contract-call? .lumina-stream join-dao)
(contract-call? .lumina-stream validate-contribution u1 true)

;; User 1: Create committee and proposal
(contract-call? .lumina-stream create-committee "governance")
(contract-call? .lumina-stream create-proposal "Test Proposal" "Testing governance" u1 "test")

;; Both users: Vote
(contract-call? .lumina-stream vote-on-proposal u1 true)

;; After voting period: Execute
(contract-call? .lumina-stream execute-proposal u1)
```
