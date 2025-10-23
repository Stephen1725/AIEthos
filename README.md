**AIEthos**
===========

* * * * *

**Decentralized AI-Based Reputation Scoring System**
----------------------------------------------------

This repository contains the Clarity smart contract implementation for **AIEthos**, a sophisticated, decentralized reputation scoring system. AIEthos is designed to provide a fair, transparent, and dynamically calculated reputation score for users, leveraging authenticated submissions from authorized AI Verifiers. The system incorporates weighted algorithms that factor in AI confidence, verifier credibility, and a time-based decay mechanism to ensure scores remain relevant and reflective of current behavior.

* * * * *

**Features**
------------

-   **Decentralized Score Submission:** Only whitelisted, staked **AI Verifiers** can submit reputation scores.

-   **Weighted Scoring:** Reputation is calculated using a weighted average that incorporates:

    -   The score provided by the AI Verifier (from **0** to **100**).

    -   The **credibility weight** of the submitting Verifier.

    -   The **AI confidence** level associated with the score submission.

-   **Reputation Decay:** Scores for inactive users are subject to a time-based decay mechanism, preventing stagnation and promoting dynamic relevance.

-   **Dispute Mechanism:** Users can raise formal disputes against their current reputation, which are logged for future resolution by the contract owner or a designated governance mechanism.

-   **Role-Based Access Control:** Strict control ensures only the `CONTRACT-OWNER` can register or deactivate AI Verifiers.

-   **Initialization:** New users can be initialized with a neutral **default score** (u50).

* * * * *

**Contract Details**
--------------------

### **Constants & Error Codes**

| Constant | Value | Description |
| --- | --- | --- |
| `CONTRACT-OWNER` | `tx-sender` | The deployer and administrator of the contract. |
| `ERR-NOT-AUTHORIZED` | `u100` | Caller lacks the necessary permission (e.g., non-owner trying to register a verifier). |
| `ERR-INVALID-SCORE` | `u101` | Submitted score or confidence is outside the allowed range. |
| `ERR-USER-NOT-FOUND` | `u102` | Operation targets a user not initialized in the system. |
| `ERR-ALREADY-VERIFIER` | `u103` | Attempting to register an address already listed as a verifier. |
| `ERR-NOT-VERIFIER` | `u104` | Transaction sender is not an active verifier. |
| `ERR-DISPUTE-EXISTS` | `u105` | Attempting to raise a dispute that already exists (though not strictly enforced by the current logic). |
| `ERR-NO-DISPUTE` | `u106` | Operation requires an existing dispute that was not found. |
| `ERR-INVALID-WEIGHT` | `u107` | Verifier credibility weight is outside the valid range. |
| `MIN-SCORE` | `u0` | The lowest possible reputation score. |
| `MAX-SCORE` | `u100` | The highest possible reputation score. |
| `DEFAULT-SCORE` | `u50` | The score assigned to a newly initialized user. |
| `DECAY-RATE` | `u5` | The percentage (5%) by which the score decays per inactive period. |
| `MIN-VERIFIER-STAKE` | `u1000` | Minimum required stake (in tokens) for a verifier. |

### **Data Structures**

#### **`user-scores` (Map)**

Stores the calculated reputation for each user.

| Field | Type | Description |
| --- | --- | --- |
| `score` | `uint` | The current, calculated reputation score. |
| `total-interactions` | `uint` | Total number of score submissions processed for the user. |
| `last-updated` | `uint` | The block height of the last score update/recalculation. |
| `status` | `(string-ascii 20)` | Textual status based on the score (e.g., "excellent," "poor"). |

#### **`verifiers` (Map)**

Tracks authorized AI Verifiers and their relevant data.

| Field | Type | Description |
| --- | --- | --- |
| `is-active` | `bool` | Whether the verifier is currently authorized to submit scores. |
| `credibility-weight` | `uint` | A weight (1-100) determining the influence of the verifier's submission. |
| `total-verifications` | `uint` | Count of scores submitted by this verifier. |
| `stake-amount` | `uint` | The token stake held by the verifier to ensure good behavior. |

#### **`score-submissions` (Map)**

Logs every individual score submission before it's factored into the final score.

| Key | Type | Description |
| --- | --- | --- |
| `user` | `principal` | The user who received the score. |
| `verifier` | `principal` | The verifier who submitted the score. |
| `submission-id` | `uint` | A unique, auto-incrementing ID for the submission. |
| **Value: `score`** | `uint` | The raw score (0-100) from the AI. |
| **Value: `timestamp`** | `uint` | Block height of the submission. |
| **Value: `ai-confidence`** | `uint` | The AI's confidence level (0-100) in its own rating. |
| **Value: `category`** | `(string-ascii 30)` | The category of the interaction (e.g., "financial", "social"). |

#### **`disputes` (Map)**

Records formal user disputes against their score.

| Key | Type | Description |
| --- | --- | --- |
| `user` | `principal` | The user raising the dispute. |
| `dispute-id` | `uint` | A unique, auto-incrementing ID for the dispute. |
| **Value: `reason`** | `(string-ascii 200)` | The user's explanation for the dispute. |
| **Value: `status`** | `(string-ascii 20)` | The current status (e.g., "pending", "resolved"). |
| **Value: `created-at`** | `uint` | Block height when the dispute was raised. |
| **Value: `resolved-at`** | `uint` | Block height when the dispute was resolved (`u0` if pending). |

### **Private Functions**

#### `calculate-weighted-score`

Code snippet

```
(define-private (calculate-weighted-score (base-score uint) (verifier-weight uint) (ai-confidence uint))

```

Calculates the contribution of a single score submission. The calculation uses a complex formula to weigh the `base-score` by both the `verifier-weight` and the `ai-confidence`:

Contribution=200(100base-score×verifier-weight​)×(100+ai-confidence)​

#### `apply-score-decay`

Code snippet

```
(define-private (apply-score-decay (current-score uint) (blocks-inactive uint))

```

Calculates the score reduction for inactive accounts. Decay is applied based on the number of inactive periods (where a period is u1000 blocks).

Decay Amount=100current-score×(1000blocks-inactive​)×DECAY-RATE​

The final score is capped at `MIN-SCORE` (u0).

#### `is-valid-score` / `is-valid-weight`

Simple range validation checks for scores (0-100) and verifier weights (1-100).

### **Public Functions**

#### `initialize-user`

Code snippet

```
(define-public (initialize-user)

```

Initializes the calling principal with the `DEFAULT-SCORE` (u50) if they are not already in the system.

#### `register-verifier`

Code snippet

```
(define-public (register-verifier (verifier principal) (weight uint) (stake uint))

```

Allows the `CONTRACT-OWNER` to add a new AI Verifier. Requires the verifier to provide a minimum stake and a valid credibility weight.

#### `deactivate-verifier`

Code snippet

```
(define-public (deactivate-verifier (verifier principal))

```

Allows the `CONTRACT-OWNER` to set a verifier's `is-active` status to `false`, revoking their scoring privileges.

#### `submit-score`

Code snippet

```
(define-public (submit-score (user principal) (score uint) (ai-confidence uint) (category (string-ascii 30)))

```

Allows an **active verifier** to submit a score for a user. This function *records* the submission but does not immediately update the user's overall reputation.

#### `calculate-and-update-reputation` (Core Logic)

Code snippet

```
(define-public (calculate-and-update-reputation (user principal) (submission-ids (list 10 uint)))

```

This is the central function for reputation management, executed by any user to update the specified user's score based on the latest submissions.

1.  **Time Decay:** Applies `apply-score-decay` to the current score based on the time elapsed since `last-updated`.

2.  **Submission Processing:** Iterates through a list of new `submission-ids` using the **`process-submission-fold`** helper.

    -   For each submission, it calculates the **weighted contribution** using `calculate-weighted-score` and sums up the total weighted score and total weight.

3.  **New Average:** Calculates a **new calculated score** by dividing the `final-score-sum` by the `final-weight-sum`.

4.  **Blending:** Blends the `new-calculated-score` with the `decayed-score` using a **70% new / 30% historical** ratio for score stability.

5.  **Update:** Updates the `user-scores` map with the final, blended score, new block height, updated interaction count, and a corresponding status (excellent, good, fair, poor).

#### `raise-dispute`

Code snippet

```
(define-public (raise-dispute (reason (string-ascii 200)))

```

Allows the calling user to log a dispute against their current reputation.

### **Read-Only Functions**

-   **`get-reputation`**: Retrieves the current `user-scores` data for a principal.

-   **`get-verifier-info`**: Retrieves the `verifiers` data for a principal.

* * * * *

**Deployment**
--------------

The AIEthos smart contract is written in **Clarity** and is intended to be deployed on a Stacks blockchain.

### **Prerequisites**

1.  A functional Stacks development environment (e.g., Clarinet).

2.  Access to a Stacks wallet for deployment.

### **Steps**

1.  **Deployment:** Deploy the `ai-based-reputation-scoring.clar` contract file to your chosen Stacks network. The transaction sender of the deployment will automatically be set as the `CONTRACT-OWNER`.

2.  **Verifier Registration:** The `CONTRACT-OWNER` must call `(register-verifier ...)` to onboard official AI entities that will provide scores.

3.  **User Initialization:** Any user can call `(initialize-user)` to establish their presence in the system with the default score.

4.  **Score Submission:** Registered Verifiers call `(submit-score ...)` to log new reputation data.

5.  **Score Recalculation:** Users (or a dedicated orchestrator service) call `(calculate-and-update-reputation ...)` with the latest submission IDs to process and update the final score.

* * * * *

**Development & Contribution**
------------------------------

### **Contributing**

We welcome contributions to the AIEthos project! If you've found a bug, have an idea for an improvement, or want to submit new code, please follow these steps:

1.  **Fork** the repository.

2.  Create a new feature branch (`git checkout -b feature/AmazingFeature`).

3.  Commit your changes (`git commit -m 'Add AmazingFeature'`). Ensure your commits follow conventional commit guidelines.

4.  Push to the branch (`git push origin feature/AmazingFeature`).

5.  Open a **Pull Request** detailing your changes, their rationale, and any relevant testing information.

### **Testing**

Testing should be performed using the Clarinet testing framework. Key areas to test include:

-   Role-Based Access Control (ensuring only the owner can register/deactivate verifiers).

-   Score range validation (`MIN-SCORE` and `MAX-SCORE`).

-   The complex calculation logic in `calculate-weighted-score` for various inputs of weight and confidence.

-   The decay logic in `apply-score-decay` over different block periods.

-   The blending and final status assignment in `calculate-and-update-reputation`.

* * * * *

**License**
-----------

**MIT License**

Copyright (c) 2025 AI-Ethos Development Team

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

* * * * *

**Roadmap & Future Enhancements**
---------------------------------

-   **Dispute Resolution Mechanism:** Implement an official, public function for the `CONTRACT-OWNER` or a decentralized council to resolve disputes, potentially resulting in score adjustments or verifier penalties.

-   **Staking & Slashing:** Introduce actual token transfers for verifier staking and implement a slashing mechanism for verifiers found to be submitting malicious or inaccurate data.

-   **Dynamic Verifier Weight:** Introduce a mechanism to dynamically adjust a verifier's `credibility-weight` based on the historical accuracy and fairness of their submissions.

-   **Submission Time Limit:** Add a check to `calculate-and-update-reputation` to ignore submissions that are too old, preventing manipulation.

-   **List Scaling:** Refactor the `process-submission-fold` logic to allow for more than 10 submissions to be processed at once, or implement a more scalable map structure for submissions.
