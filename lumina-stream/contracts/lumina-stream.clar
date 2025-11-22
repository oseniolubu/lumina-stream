;; Lumina Stream - Dynamic Reputation DAO Governance Platform
;; A multi-dimensional reputation system with expertise-weighted voting

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-MEMBER-NOT-FOUND (err u101))
(define-constant ERR-ALREADY-EXISTS (err u102))
(define-constant ERR-PROPOSAL-NOT-FOUND (err u103))
(define-constant ERR-INVALID-EXPERTISE (err u104))
(define-constant ERR-ALREADY-VOTED (err u105))
(define-constant ERR-VOTING-CLOSED (err u106))
(define-constant ERR-INSUFFICIENT-REPUTATION (err u107))
(define-constant ERR-PROPOSAL-NOT-PASSED (err u108))
(define-constant ERR-ALREADY-EXECUTED (err u109))
(define-constant ERR-INVALID-COMMITTEE (err u110))
(define-constant ERR-CONTRIBUTION-NOT-FOUND (err u111))

;; Minimum reputation thresholds
(define-constant MIN-PROPOSAL-REPUTATION u100)
(define-constant MIN-VOTE-REPUTATION u10)
(define-constant REPUTATION-DECAY-RATE u5) ;; 5% per decay period
(define-constant VOTING-PERIOD u1440) ;; approximately 10 days in blocks

;; Data Variables
(define-data-var proposal-counter uint u0)
(define-data-var contribution-counter uint u0)
(define-data-var committee-counter uint u0)
(define-data-var total-members uint u0)

;; Member Structure with Multi-Dimensional Reputation
(define-map members
    { member: principal }
    {
        total-reputation: uint,
        joined-at: uint,
        last-activity: uint,
        proposals-created: uint,
        votes-cast: uint,
        contributions-made: uint,
        active: bool
    }
)

;; Domain-Specific Expertise Tokens
(define-map expertise-scores
    { member: principal, domain: (string-ascii 50) }
    {
        score: uint,
        contributions: uint,
        validations: uint,
        last-updated: uint
    }
)

;; Expertise Committee Registry
(define-map committees
    { committee-id: uint }
    {
        domain: (string-ascii 50),
        chair: principal,
        member-count: uint,
        created-at: uint,
        active: bool
    }
)

;; Committee Membership
(define-map committee-members
    { committee-id: uint, member: principal }
    {
        joined-at: uint,
        expertise-level: uint
    }
)

;; Proposal Structure with Routing
(define-map proposals
    { proposal-id: uint }
    {
        proposer: principal,
        title: (string-ascii 100),
        description: (string-ascii 500),
        committee-id: uint,
        created-at: uint,
        voting-ends-at: uint,
        votes-for: uint,
        votes-against: uint,
        total-voting-power: uint,
        executed: bool,
        passed: bool,
        proposal-type: (string-ascii 50)
    }
)

;; Vote Records
(define-map votes
    { proposal-id: uint, voter: principal }
    {
        vote-for: bool,
        voting-power: uint,
        voted-at: uint
    }
)

;; Contribution Tracking with Proof
(define-map contributions
    { contribution-id: uint }
    {
        contributor: principal,
        domain: (string-ascii 50),
        proof-hash: (buff 32),
        reputation-gained: uint,
        validated: bool,
        validator: (optional principal),
        created-at: uint
    }
)

;; Peer Validation Records
(define-map validations
    { contribution-id: uint, validator: principal }
    {
        approved: bool,
        validated-at: uint,
        expertise-weight: uint
    }
)

;; Member Decision Accuracy Tracking
(define-map decision-accuracy
    { member: principal }
    {
        correct-predictions: uint,
        total-predictions: uint,
        accuracy-score: uint
    }
)

;; Read-only functions

;; Get member information
(define-read-only (get-member (member principal))
    (map-get? members { member: member })
)

;; Get expertise score for specific domain
(define-read-only (get-expertise-score (member principal) (domain (string-ascii 50)))
    (map-get? expertise-scores { member: member, domain: domain })
)

;; Get proposal details
(define-read-only (get-proposal (proposal-id uint))
    (map-get? proposals { proposal-id: proposal-id })
)

;; Get vote record
(define-read-only (get-vote (proposal-id uint) (voter principal))
    (map-get? votes { proposal-id: proposal-id, voter: voter })
)

;; Get contribution details
(define-read-only (get-contribution (contribution-id uint))
    (map-get? contributions { contribution-id: contribution-id })
)

;; Get committee information
(define-read-only (get-committee (committee-id uint))
    (map-get? committees { committee-id: committee-id })
)

;; Check if member is in committee
(define-read-only (is-committee-member (committee-id uint) (member principal))
    (is-some (map-get? committee-members { committee-id: committee-id, member: member }))
)

;; Get decision accuracy
(define-read-only (get-decision-accuracy (member principal))
    (map-get? decision-accuracy { member: member })
)

;; Calculate streaming reputation with decay
(define-read-only (calculate-streaming-reputation (member principal))
    (match (get-member member)
        member-data
        (let
            (
                (base-reputation (get total-reputation member-data))
                (blocks-since-activity (- block-height (get last-activity member-data)))
                (decay-periods (/ blocks-since-activity u144)) ;; decay every ~1 day
                (decay-amount (* (/ (* base-reputation REPUTATION-DECAY-RATE) u100) decay-periods))
            )
            (if (> base-reputation decay-amount)
                (ok (- base-reputation decay-amount))
                (ok u0)
            )
        )
        (ok u0)
    )
)

;; Calculate voting power based on expertise and reputation
(define-read-only (calculate-voting-power (member principal) (committee-id uint))
    (match (get-committee committee-id)
        committee
        (let
            (
                (domain (get domain committee))
                (expertise (default-to { score: u0, contributions: u0, validations: u0, last-updated: u0 }
                    (get-expertise-score member domain)))
                (base-reputation (unwrap! (calculate-streaming-reputation member) (ok u0)))
                (expertise-multiplier (+ u100 (get score expertise))) ;; 100% + expertise score
                (voting-power (/ (* base-reputation expertise-multiplier) u100))
            )
            (ok voting-power)
        )
        (ok u0)
    )
)

;; Get platform statistics
(define-read-only (get-platform-stats)
    {
        total-proposals: (var-get proposal-counter),
        total-contributions: (var-get contribution-counter),
        total-committees: (var-get committee-counter),
        total-members: (var-get total-members)
    }
)

;; Public functions

;; Join as a new member
(define-public (join-dao)
    (let
        (
            (member tx-sender)
            (existing-member (get-member member))
        )
        (if (is-some existing-member)
            ERR-ALREADY-EXISTS
            (begin
                (map-set members
                    { member: member }
                    {
                        total-reputation: u0,
                        joined-at: block-height,
                        last-activity: block-height,
                        proposals-created: u0,
                        votes-cast: u0,
                        contributions-made: u0,
                        active: true
                    }
                )
                (map-set decision-accuracy
                    { member: member }
                    {
                        correct-predictions: u0,
                        total-predictions: u0,
                        accuracy-score: u0
                    }
                )
                (var-set total-members (+ (var-get total-members) u1))
                (ok true)
            )
        )
    )
)

;; Submit a contribution with proof
(define-public (submit-contribution
    (domain (string-ascii 50))
    (proof-hash (buff 32))
)
    (let
        (
            (contribution-id (+ (var-get contribution-counter) u1))
            (member-data (unwrap! (get-member tx-sender) ERR-MEMBER-NOT-FOUND))
        )
        ;; Create contribution record
        (map-set contributions
            { contribution-id: contribution-id }
            {
                contributor: tx-sender,
                domain: domain,
                proof-hash: proof-hash,
                reputation-gained: u0,
                validated: false,
                validator: none,
                created-at: block-height
            }
        )

        ;; Update member data
        (map-set members
            { member: tx-sender }
            (merge member-data {
                contributions-made: (+ (get contributions-made member-data) u1),
                last-activity: block-height
            })
        )

        (var-set contribution-counter contribution-id)

        (ok contribution-id)
    )
)

;; Validate a contribution
(define-public (validate-contribution
    (contribution-id uint)
    (approved bool)
)
    (let
        (
            (contribution (unwrap! (get-contribution contribution-id) ERR-CONTRIBUTION-NOT-FOUND))
            (validator-data (unwrap! (get-member tx-sender) ERR-MEMBER-NOT-FOUND))
            (domain (get domain contribution))
            (validator-expertise (default-to { score: u0, contributions: u0, validations: u0, last-updated: u0 }
                (get-expertise-score tx-sender domain)))
            (contributor (get contributor contribution))
            (contributor-data (unwrap! (get-member contributor) ERR-MEMBER-NOT-FOUND))
            (reputation-gain (if approved u20 u0))
        )
        ;; Check validator has sufficient expertise
        (asserts! (>= (get score validator-expertise) u10) ERR-INSUFFICIENT-REPUTATION)

        ;; Record validation
        (map-set validations
            { contribution-id: contribution-id, validator: tx-sender }
            {
                approved: approved,
                validated-at: block-height,
                expertise-weight: (get score validator-expertise)
            }
        )

        ;; Update contribution status if approved
        (if approved
            (begin
                (map-set contributions
                    { contribution-id: contribution-id }
                    (merge contribution {
                        validated: true,
                        validator: (some tx-sender),
                        reputation-gained: reputation-gain
                    })
                )

                ;; Update contributor reputation
                (map-set members
                    { member: contributor }
                    (merge contributor-data {
                        total-reputation: (+ (get total-reputation contributor-data) reputation-gain)
                    })
                )

                ;; Update contributor expertise in domain
                (let
                    (
                        (current-expertise (default-to { score: u0, contributions: u0, validations: u0, last-updated: u0 }
                            (get-expertise-score contributor domain)))
                    )
                    (map-set expertise-scores
                        { member: contributor, domain: domain }
                        {
                            score: (+ (get score current-expertise) u10),
                            contributions: (+ (get contributions current-expertise) u1),
                            validations: (get validations current-expertise),
                            last-updated: block-height
                        }
                    )
                )
            )
            true
        )

        (ok true)
    )
)

;; Create an expertise committee
(define-public (create-committee (domain (string-ascii 50)))
    (let
        (
            (committee-id (+ (var-get committee-counter) u1))
            (member-data (unwrap! (get-member tx-sender) ERR-MEMBER-NOT-FOUND))
        )
        ;; Check reputation threshold
        (asserts! (>= (get total-reputation member-data) MIN-PROPOSAL-REPUTATION) ERR-INSUFFICIENT-REPUTATION)

        ;; Create committee
        (map-set committees
            { committee-id: committee-id }
            {
                domain: domain,
                chair: tx-sender,
                member-count: u1,
                created-at: block-height,
                active: true
            }
        )

        ;; Add creator as first member
        (map-set committee-members
            { committee-id: committee-id, member: tx-sender }
            {
                joined-at: block-height,
                expertise-level: u100
            }
        )

        (var-set committee-counter committee-id)

        (ok committee-id)
    )
)

;; Join a committee
(define-public (join-committee (committee-id uint))
    (let
        (
            (committee (unwrap! (get-committee committee-id) ERR-INVALID-COMMITTEE))
            (member-data (unwrap! (get-member tx-sender) ERR-MEMBER-NOT-FOUND))
            (domain (get domain committee))
            (expertise (default-to { score: u0, contributions: u0, validations: u0, last-updated: u0 }
                (get-expertise-score tx-sender domain)))
        )
        ;; Check not already member
        (asserts! (not (is-committee-member committee-id tx-sender)) ERR-ALREADY-EXISTS)

        ;; Check has some expertise in domain
        (asserts! (>= (get score expertise) u5) ERR-INSUFFICIENT-REPUTATION)

        ;; Add to committee
        (map-set committee-members
            { committee-id: committee-id, member: tx-sender }
            {
                joined-at: block-height,
                expertise-level: (get score expertise)
            }
        )

        ;; Update committee member count
        (map-set committees
            { committee-id: committee-id }
            (merge committee {
                member-count: (+ (get member-count committee) u1)
            })
        )

        (ok true)
    )
)

;; Create a proposal routed to committee
(define-public (create-proposal
    (title (string-ascii 100))
    (description (string-ascii 500))
    (committee-id uint)
    (proposal-type (string-ascii 50))
)
    (let
        (
            (proposal-id (+ (var-get proposal-counter) u1))
            (member-data (unwrap! (get-member tx-sender) ERR-MEMBER-NOT-FOUND))
            (committee (unwrap! (get-committee committee-id) ERR-INVALID-COMMITTEE))
        )
        ;; Check reputation threshold
        (asserts! (>= (get total-reputation member-data) MIN-PROPOSAL-REPUTATION) ERR-INSUFFICIENT-REPUTATION)

        ;; Create proposal
        (map-set proposals
            { proposal-id: proposal-id }
            {
                proposer: tx-sender,
                title: title,
                description: description,
                committee-id: committee-id,
                created-at: block-height,
                voting-ends-at: (+ block-height VOTING-PERIOD),
                votes-for: u0,
                votes-against: u0,
                total-voting-power: u0,
                executed: false,
                passed: false,
                proposal-type: proposal-type
            }
        )

        ;; Update member data
        (map-set members
            { member: tx-sender }
            (merge member-data {
                proposals-created: (+ (get proposals-created member-data) u1),
                last-activity: block-height
            })
        )

        (var-set proposal-counter proposal-id)

        (ok proposal-id)
    )
)

;; Cast vote on proposal with expertise weighting
(define-public (vote-on-proposal (proposal-id uint) (vote-for bool))
    (let
        (
            (proposal (unwrap! (get-proposal proposal-id) ERR-PROPOSAL-NOT-FOUND))
            (member-data (unwrap! (get-member tx-sender) ERR-MEMBER-NOT-FOUND))
            (existing-vote (get-vote proposal-id tx-sender))
            (voting-power (unwrap! (calculate-voting-power tx-sender (get committee-id proposal)) ERR-MEMBER-NOT-FOUND))
        )
        ;; Check voting is still open
        (asserts! (< block-height (get voting-ends-at proposal)) ERR-VOTING-CLOSED)

        ;; Check hasn't voted already
        (asserts! (is-none existing-vote) ERR-ALREADY-VOTED)

        ;; Check minimum reputation
        (asserts! (>= (get total-reputation member-data) MIN-VOTE-REPUTATION) ERR-INSUFFICIENT-REPUTATION)

        ;; Record vote
        (map-set votes
            { proposal-id: proposal-id, voter: tx-sender }
            {
                vote-for: vote-for,
                voting-power: voting-power,
                voted-at: block-height
            }
        )

        ;; Update proposal vote counts
        (map-set proposals
            { proposal-id: proposal-id }
            (merge proposal {
                votes-for: (if vote-for (+ (get votes-for proposal) voting-power) (get votes-for proposal)),
                votes-against: (if vote-for (get votes-against proposal) (+ (get votes-against proposal) voting-power)),
                total-voting-power: (+ (get total-voting-power proposal) voting-power)
            })
        )

        ;; Update member stats
        (map-set members
            { member: tx-sender }
            (merge member-data {
                votes-cast: (+ (get votes-cast member-data) u1),
                last-activity: block-height
            })
        )

        (ok true)
    )
)

;; Execute proposal if passed
(define-public (execute-proposal (proposal-id uint))
    (let
        (
            (proposal (unwrap! (get-proposal proposal-id) ERR-PROPOSAL-NOT-FOUND))
        )
        ;; Check voting has ended
        (asserts! (>= block-height (get voting-ends-at proposal)) ERR-VOTING-CLOSED)

        ;; Check not already executed
        (asserts! (not (get executed proposal)) ERR-ALREADY-EXECUTED)

        ;; Check if passed (more votes for than against)
        (asserts! (> (get votes-for proposal) (get votes-against proposal)) ERR-PROPOSAL-NOT-PASSED)

        ;; Mark as executed and passed
        (map-set proposals
            { proposal-id: proposal-id }
            (merge proposal {
                executed: true,
                passed: true
            })
        )

        (ok true)
    )
)

;; Update decision accuracy after proposal execution
(define-public (update-decision-accuracy (proposal-id uint))
    (let
        (
            (proposal (unwrap! (get-proposal proposal-id) ERR-PROPOSAL-NOT-FOUND))
            (voter-vote (unwrap! (get-vote proposal-id tx-sender) ERR-MEMBER-NOT-FOUND))
            (accuracy-data (unwrap! (get-decision-accuracy tx-sender) ERR-MEMBER-NOT-FOUND))
            (voted-correctly (is-eq (get vote-for voter-vote) (get passed proposal)))
        )
        ;; Check proposal has been executed
        (asserts! (get executed proposal) ERR-PROPOSAL-NOT-PASSED)

        ;; Update accuracy stats
        (map-set decision-accuracy
            { member: tx-sender }
            {
                correct-predictions: (if voted-correctly
                    (+ (get correct-predictions accuracy-data) u1)
                    (get correct-predictions accuracy-data)),
                total-predictions: (+ (get total-predictions accuracy-data) u1),
                accuracy-score: (if voted-correctly
                    (+ (get accuracy-score accuracy-data) u10)
                    (get accuracy-score accuracy-data))
            }
        )

        (ok true)
    )
)
