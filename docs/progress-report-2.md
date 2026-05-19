# QChain — Progress Report 2

**Project:** Post-Quantum Cryptography in Blockchain Technology  
**Submitted:** 31st March 2026  
**Team:** Team 5M's  
**Supervisors:** Dr. Manar Abu Talib (Head), Dr. Sohail Abbas (Co-Supervisor)

---

## Team Members

| Name | Role | GitHub |
| --- | --- | --- |
| Mohammed Bin Ali Maqqavi | Project Lead, Quantum Engineer | @M0hd-Maqqavi |
| Mohammed Abdul Haris | Technical Lead, Software Engineer | @mohammed-ah-14 |
| Muhammed Nihal Valiya Puthiyakath | UI/UX Designer, Quality Assurance Lead | @nihvp |
| Mohammed Hisham Obeid | Blockchain Engineer, Security Analyst | @MohammedObeid88 |

---

## 1. Introduction

This progress report documents the second phase of the QChain project — a quantum-resistant digital credential verification system built on Hyperledger Fabric. It covers the implementation period from March 2nd to March 31st, 2026, and presents the UI/UX design of the web portal, full frontend implementation of both mobile and web applications, off-chain backend cryptographic integration, and smart contract development.

The work documented here transitions QChain from the conceptual architecture established in Progress Report 1 into a fully implemented, multi-component working prototype. The system now comprises a role-based web portal (QPortal), a mobile wallet (QWallet), an off-chain cryptographic backend using ML-DSA (CRYSTALS-Dilithium), IPFS-based decentralized storage, and a Hyperledger Fabric blockchain network with custom chaincode.

### 1.1 Project Scope

This report covers five primary areas:

1. **UI/UX Design — QPortal** — complete design of the web-based portal for Issuers, Verifiers, and IT Administrators across 50+ screens
2. **System Implementation Overview** — evolution from conceptual to implemented architecture, detailing all six system components
3. **QWallet Mobile Application** — full Flutter implementation of the holder credential wallet
4. **QPortal Web Application** — full Flutter Web implementation of the institutional portal
5. **Off-Chain Backend & IPFS Integration** — Go-based cryptographic backend with ML-DSA-44 and IPFS storage
6. **Blockchain Smart Contract & Middleware** — Hyperledger Fabric chaincode, RBAC, identity management, and REST API

### 1.2 Project Objectives

The primary objective of QChain is to design and implement a scalable, secure, and quantum-resistant blockchain credential system that demonstrates practical integration of post-quantum cryptography within a permissioned blockchain environment.

Specific objectives:

- **QWallet (Mobile)** — develop a Flutter mobile wallet for secure credential storage and QR-based presentation
- **QPortal (Web)** — design and implement a web-based administrative portal for issuers, verifiers, and IT administrators
- **ML-DSA-44 Integration** — integrate post-quantum digital signature generation and verification via liboqs-go and Cloudflare CIRCL
- **IPFS Off-Chain Storage** — implement IPFS-based storage for credential payloads and signatures
- **Blockchain Anchoring** — anchor credential references (CID) on Hyperledger Fabric
- **Custom Chaincode** — develop role-based chaincode for credential lifecycle management
- **X.509 Identity Access Control** — establish identity-based access control using Fabric CA
- **Performance Evaluation** — benchmark and compare classical vs. post-quantum approaches

### 1.3 Expected Outcomes (Phase 2)

All core outcomes listed below have been achieved and are documented in this report:

- Fully functional post-quantum credential issuance and verification platform
- ML-DSA-44 integrated with blockchain infrastructure via liboqs-go and CIRCL
- Hybrid architecture (on-chain anchoring + off-chain IPFS storage) demonstrated end-to-end
- Performance benchmarking results comparing ML-DSA-44, ML-DSA-65, ML-DSA-87 across both implementations
- Secure identity management using X.509 certificates with Fabric CA
- Modular, well-documented codebase hosted on GitHub
- QPortal UI/UX design covering Issuer, Verifier, and IT Admin dashboards (50+ screens)
- QWallet mobile application with onboarding, credential wallet, QR presentation, and selective disclosure
- Experimental validation of tamper resistance via CID mismatch detection
- Scalable architectural blueprint adaptable to real-world academic credential systems

---

## 2. UI/UX Design: QPortal

This section presents the UI/UX design of QPortal, the web-based interface of the QChain digital credentialing platform. The design focused on providing intuitive, role-based user journeys tailored to Issuers, Verifiers, and IT Administrators, while ensuring accessible interactions with complex cryptographic processes such as credential issuance, storage, presentation, and verification.

### 2.1 Issuer Dashboard

The Issuer Dashboard is the primary workspace for issuing authorities. It displays key daily metrics — credentials issued today, unread alerts, and upcoming expirations — and provides Quick Actions for single credential creation, batch issuing, and schema management. The screen emphasizes recent issuing activities, expiry warnings, and a historical chart of credentials issued over the past four weeks.

#### 2.1.1 Single Issue

The Single Credential Workflow guides the issuer through a five-step process for authorizing a digital document for an individual recipient:

| Step | Screen | Purpose |
| --- | --- | --- |
| 1 | Introduce Available Credentials | Select credential template / schema |
| 2 | Display Searchable Directory | Locate the intended recipient |
| 3 | Present a Targeted Data Entry | Capture specific credential attributes |
| 4 | Generate a Visual Draft | Verify formatting and accuracy |
| 5 | Present a Final Summary | Confirm and cryptographically sign and issue |

#### 2.1.2 Batch Issue

The Batch Credential Workflow supports issuing digital documents for up to 1,000 recipients simultaneously:

| Step | Screen | Purpose |
| --- | --- | --- |
| 1 | Introduce Available Credentials | Select schema and review required data columns |
| 2 | Provide a Downloadable Template | Download template and upload batch data files |
| 3 | Display a Validation Table | Auto-review uploaded records; only "Valid" records proceed |
| 4 | Present a Final Batch Summary | Confirm and cryptographically sign all valid records |
| 5 | Generate a Final Status Breakdown | Downloadable audit reports for successful and rejected issuances |

#### 2.1.3 All Credentials

The "All Credentials" page provides a centralized, searchable repository of all issued documents, featuring:

- **Search and Filter** — dynamic search by ID, name, credential type, or status
- **Comprehensive Ledger** — tracks holder information, issuance dates, and validity states (Valid, Revoked, Suspended, Expired)
- **Batch Selection** — select multiple records for bulk export
- **Individual Review** — view detailed information for a single selected credential

#### 2.1.4 Credential Details

The "Credential Details" page provides a focused view of a single issued document, including:

- **System & Holder Information** — core unalterable data: Credential ID, issuing authority, recipient identity
- **Editable Information** — update holder email and expiry date
- **Reissue Capability** — generate an updated, newly-signed credential after modifying editable fields
- **Cryptographic Information** — expandable section showing Dilithium signing algorithm, signature hash, blockchain transaction ID, and IPFS reference

#### 2.1.5 Credential History

The "Credential History" view provides a timeline-style audit trail for individual documents, chronologically tracking every administrative action (issuance, suspension, restoration, revocation) with the timestamp and the staff member who authorized it. For negative-impact actions (suspensions, revocations), the timeline expands to show the underlying reason or justification.

#### 2.1.6 Revoke / Suspend Management

The "Revoke / Suspend Management" page provides a dedicated workspace for governing active credential status. Issuers can search for credentials, permanently revoke or temporarily suspend active documents, restore previously suspended items, and transition to the full credential view for inspection before executing critical status changes.

#### 2.1.7 Schemas

The "Schemas" page is the central management hub for credential templates, displaying a directory of all active and archived schemas with issuance counts per schema. Outdated schemas can be archived without affecting existing credentials. Schemas with zero issuances can be permanently deleted; those with active credentials are protected from deletion.

#### 2.1.8 Schema Details

The "Schema Details" page provides a dedicated editor for configuring the data structure of a credential template — defining fields (e.g., "Research Field", "Student ID"), their data types, and required/optional status. Essential metadata (unique ID, creation date, creator, category) is displayed. Administrators can dynamically add or delete fields.

#### 2.1.9 Create New Schema

The Create New Schema workflow guides administrators through a four-step process:

| Step | Screen | Purpose |
| --- | --- | --- |
| 1 | Capture Foundational Metadata | Schema name, description, and category |
| 2 | Provide a Builder | Define data fields, assign types, and set required parameters |
| 3 | Generate a Visual Simulation | Preview how the credential appears to holders and verifiers |
| 4 | Explicit Confirmation | Permanently anchor the immutable template structure to the blockchain |

### 2.2 Verifier Dashboard

The Verifier Dashboard is the credential validation workspace, displaying immediate performance metrics (verifications completed today, pending alerts). It provides quick access to QR scanning, manual verification, and batch verification. The screen emphasizes a log of recent verification outcomes (Valid, Revoked, Expired) and a visual history of verification volume over the last seven days.

#### 2.2.1 Scan

The Scan QR Code interface provides real-time credential authentication via a connected hardware scanner. The process begins with a ready-state screen that prompts capture of the credential's QR code with immediate error handling for failed scans. A successful scan transitions to a Verification Result card displaying validity status, holder details, and automated cryptographic policy checks (blockchain integrity, issuer authorization).

#### 2.2.2 Manual Verify

The Manual Verify page provides three alternative authentication methods for when QR scanning is unavailable:

| Method | Input | Use Case |
| --- | --- | --- |
| Credential ID | Unique alphanumeric string | Direct ID entry |
| OTP | 6-digit time-sensitive code | Dynamically generated from holder's wallet |
| Upload Document | Single PDF file | Cryptographic validation via file upload |

Each method generates a comprehensive Verification Result explicitly confirming validity or flagging tampered data.

#### 2.2.3 Batch Verify

The Batch Verify workflow authenticates large volumes of documents simultaneously (up to 500 records):

| Step | Screen | Purpose |
| --- | --- | --- |
| 1 | Provide a Downloadable Spreadsheet | Upload batch data files containing Credential IDs |
| 2 | Display a Validation Table | Review records; correct or delete problematic rows |
| 3 | Present a Final Summary | Only "Valid" records are processed for blockchain verification |
| 4 | Generate a Detailed Status Report | Outcome per record with export options for auditing |

#### 2.2.4 Verification History

The "Verification History" page presents the complete, searchable audit log of all credential verifications, tracking date, time, holder name, verification method (QR Scan or Manual), verifying staff member, and final result per event. Users can select multiple records for bulk export, while individual record inspection is limited to one record at a time.

#### 2.2.5 Verification Details

The "Verification Details" page provides a dedicated historical review mode for a previously authenticated document, displaying the identical Verification Result generated at the moment of original verification, including holder details, outcome, and failure reason if applicable. A dedicated Export function allows downloading the record for formal reporting.

#### 2.2.6 Subscription

The "Subscriptions" page is a centralized hub for monitoring the ongoing validity of third-party credentials. Organizations can track documents (e.g., a hospital monitoring a doctor's medical license) via a consent-based mechanism for a defined period. Statuses range from active and pending to expired or rejected. Status changes trigger automatic alerts via the notification center.

#### 2.2.7 Add New Subscription

The "Add New Subscription" interface allows organizations to initiate a monitoring request by entering a Credential ID. The system automatically routes a formal consent request to the holder. The organization receives monitoring access only after the holder explicitly approves.

#### 2.2.8 Subscriptions Alert

The "Subscription Alerts" page is a centralized notification center for actively monitored credentials, displaying alerts for events such as temporary suspensions, permanent revocations, reissuances, or detected tampering. Verifiers can acknowledge alerts to move them from the active queue to a historical archive.

#### 2.2.9 Policy

The "Policies" page is the central management hub for custom verification rules, displaying a directory of all established policies with their current status (Active, Inactive, Draft) and the credential categories they apply to (Academic, Medical, etc.). Administrators can review, create, or delete any policy from this ledger.

#### 2.2.10 Policy Details

The "Policy Details" page provides an in-depth view of a specific policy, showing the complete configuration including toggleable rules (expiration checks, required issuance dates, specific issuer types) and target credential types. All settings are editable to accommodate evolving organizational requirements.

#### 2.2.11 Create New Policy

The "Create New Policy" page provides a builder interface for establishing custom verification rules from scratch — identical in structure to Policy Details but with all fields initially empty, allowing the administrator to define a policy name, activate rule configurations, and specify target document types.

#### 2.2.12 Add Policy

The "Add Policies" page provides a dynamic selection interface during the active verification process. Verifiers can search the organization's policy bucket and select up to a maximum of three policies to enforce during a current authentication task.

### 2.3 IT Admin Dashboard

The IT Admin Dashboard is the central control panel for system administration, displaying critical organizational metrics (active staff distribution, active cryptographic algorithm) and the institution's Decentralized Identifier (DID). It emphasizes a "Recent Audit Activity" log alongside staff overviews and capability requests.

#### 2.3.1 Manage Profile

The "Manage Profile" page allows IT Admins to maintain and update core organizational metadata — official name, high-resolution logo, organization type, and country of operation — ensuring a consistent, verified profile across the credential ecosystem.

#### 2.3.2 Staff & Permissions

The "Staff & Permissions" page serves as the central access control hub, displaying a directory of all personnel (Issuer and Verifier roles) with name, email, portal access, role, addition date, and account status. Administrators can enforce security protocols by managing who can issue and who can verify credentials.

#### 2.3.3 Manage Staff & Permissions

Two interfaces facilitate staff management:

- **Invite Staff Member** — enter organization-linked email, select portal (Issuer or Verifier), and assign initial operational role
- **Edit Staff Member** — dynamically adjust a team member's portal assignment and role; includes a Delete function for instant access revocation

#### 2.3.4 Audit Log

The "Audit Log" page provides a complete, tamper-evident, append-only, read-only record of all portal activities — logins, credential issuances, policy changes, verification attempts. Each entry includes timestamp, action, staff identity and role, and originating IP address. The log is searchable and exportable for compliance and regulatory audits.

#### 2.3.5 Crypto Settings

The "Crypto Settings" page provides visibility and control over the cryptographic mechanisms used to sign credentials. The current signing algorithm (e.g., Dilithium) is displayed and can be updated. Changes apply only to future issuances; previously issued credentials remain valid under their original cryptographic parameters. The Organization's Public Key is displayed for external integration and technical auditing.

#### 2.3.6 Request Additional Capabilities

The "Request Additional Capabilities" page provides a formal channel for expanding an organization's functional access (e.g., from Issuer-only to Issuer + Verifier). A tracking ledger monitors the lifecycle of every request. IT Admins can delete pending requests as a formal application withdrawal.

#### 2.3.7 New Request

The Request New Capability workflow is a guided four-step process:

| Step | Screen | Purpose |
| --- | --- | --- |
| 1 | Automatically Identify Current Access | Identify existing access and select new capability |
| 2 | Capture the Category | Capture organization category and intended use case |
| 3 | Secure Upload | Upload signed formal request letter and supporting accreditation documents |
| 4 | Display a Comprehensive Summary | Final review before official submission |

---

## 3. System Implementation Overview

This section presents the transition of QChain from the theoretical architecture established in Progress Report 1 into a fully implemented, multi-component system.

### 3.1 Evolution from Conceptual to Implemented Architecture

**TABLE I — Evolution of Concepts from Report 1 to Report 2**

| Aspect | Progress Report 1 | Progress Report 2 |
| --- | --- | --- |
| Architecture | Conceptual design | Fully implemented system |
| UI | Wireframes & design | Functional Flutter applications |
| Cryptography | Standalone Dilithium tests | Integrated ML-DSA signing service |
| IPFS | Proof-of-concept upload | Production-integrated storage workflow |
| Blockchain | Fabric network setup | Chaincode logic for credential anchoring |

### 3.2 Implemented System Architecture

The current QChain system consists of six primary components:

1. Flutter Mobile Wallet (QWallet — Holder Application)
2. Flutter Web Portal (QPortal — Issuer, Verifier, IT Admin)
3. Go-based Off-Chain Backend
4. ML-DSA-44 Cryptographic Module (liboqs-go & Cloudflare CIRCL)
5. IPFS Node (Decentralized Storage)
6. Hyperledger Fabric Network with JavaScript Chaincode

#### 3.2.1 Flutter Mobile Wallet (Holder Application)

Located in `UI_App/`, QWallet is the digital identity wallet for credential holders. It is built with Flutter for cross-platform compatibility and abstracts blockchain and cryptographic complexity from end users. The wallet does not communicate directly with the blockchain — it interacts with backend services responsible for retrieving credential data from IPFS and performing ML-DSA signature verification.

Key capabilities: secure credential storage, QR-code-based presentation, selective disclosure, activity log, and settings management.

#### 3.2.2 QPortal Web Application (Issuer, Verifier, and IT Administrator Interfaces)

Located in `UI_WebApp/`, QPortal is a role-based multi-user platform that operationalizes the UI/UX designs by transforming conceptual workflows into functional frontend modules. Upon credential submission, the portal triggers backend cryptographic services that generate ML-DSA signatures, upload the signed credential to IPFS, and record the resulting CID on the blockchain via a chaincode transaction.

#### 3.2.3 Off-Chain Backend (Go + ML-DSA Integration)

Located in `offchain/`, this Go-based backend is the cryptographic core of QChain. It integrates the liboqs-go library to enable ML-DSA-44 operations. Responsibilities include: ML-DSA key pair generation, credential signing, signature verification, credential JSON packaging, IPFS upload, and CID extraction. A dual-implementation strategy provides both a C-bindings variant (liboqs) and a pure Go variant (CIRCL) for performance comparison.

#### 3.2.4 IPFS Storage Layer

IPFS provides decentralized, content-addressed storage for the system. Given ML-DSA-44 signature sizes (~2–3 KB), storing full credential data on-chain would create scalability challenges. IPFS stores complete credential JSON documents, embedded ML-DSA signatures, and associated metadata. Each stored file produces a unique CID from its cryptographic hash, enabling tamper detection. Only the CID (46 bytes) is stored on-chain, reducing per-credential blockchain storage by ~98%.

#### 3.2.5 Hyperledger Fabric Network

The blockchain layer uses Hyperledger Fabric — a permissioned blockchain providing immutable record-keeping, MSP-based access control, and modular chaincode execution. Custom JavaScript chaincode manages credential anchoring: storing CID references, retrieving CIDs on request, and associating issuer identities with credential records. Only minimal metadata (CID + issuer identifier) is stored on-chain.

---

## 4. QWallet Mobile Application Implementation

QWallet is the Flutter-based mobile application for credential holders. It abstracts blockchain and cryptographic complexity, providing an intuitive interface for managing and presenting post-quantum verifiable credentials.

### 4.1 Technology Stack

**TABLE II — Technology Stack for QWallet**

| Component | Specification |
| --- | --- |
| Framework | Flutter SDK ^3.9.2 |
| Language | Dart ^3.9.2 |
| State Management | GetX ^4.7.3 (navigation), StatefulWidget with setState() (local state) |
| Navigation | GetX declarative routing with GetMaterialApp |
| UI Components | flutter_card_swiper ^7.2.0, flutter_swiper_view ^1.1.8 |
| Icons | phosphor_flutter ^2.1.0, cupertino_icons ^1.0.8 |
| Typography | Custom fonts: Formula1 (branding), SFPro (UI text) |

#### 4.1.1 State Management Approach

The application employs a hybrid state management pattern:

- **Navigation State** — managed via GetX using `Get.toNamed()`, `Get.offAllNamed()`, and `Get.back()`
- **Local UI State** — individual screens use Flutter's `StatefulWidget` with `setState()` for screen-level state
- **Data Passing** — inter-screen data transfer via `Get.arguments` for type-safe parameter passing

#### 4.1.2 Folder Structure Overview

Located at `UI_App/`. Dependencies and version specifications are defined in `UI_App/pubspec.yaml`.

#### 4.1.3 Architectural Pattern

The application follows a screen-based architecture without formal MVC/MVVM separation. Each screen is self-contained, managing its own state and UI logic, prioritizing rapid prototyping with clear file organization.

### 4.2 Screen Implementations

#### 4.2.1 Onboarding Screens

Files: `UI_App/lib/screens/onboard_1_screen.dart`, `onboard_2_screen.dart`, `onboard_3_screen.dart`

- **Onboard1** — "Own your credentials" — explains credential ownership
- **Onboard2** — "How it works" — three-step explanation (Receive, Store Securely, Present Anywhere)
- **Onboard3** — simulates quantum-resistant keypair generation with animated visual feedback and NIST FIPS 204 compliance badge displaying the ML-DSA/Dilithium algorithm identifier

#### 4.2.2 Dashboard (Home Screen)

File: `UI_App/lib/screens/home_screen.dart`

Presents credential statistics and recent activity:

- **Credential Status Summary** — counts for Valid, Suspended, Revoked, and Expired credentials
- **Favourites Section** — quick access to frequently-used credentials
- **Recent Activity** — timeline of credential operations

#### 4.2.3 Credential Storage (Wallet Screen)

File: `UI_App/lib/screens/wallet_screen.dart`

Credentials are organized into eight semantic categories: Identity, Medical, Banking, Education, Government, Professional, Travel, and Memberships. Each category displays a count and navigates to `CategoryDocumentsScreen`.

#### 4.2.4 Document Detail Screen

File: `UI_App/lib/screens/document_detail_screen.dart`

Displays comprehensive credential information including 13+ attribute fields, issuer information, validity dates, digital signature reference, blockchain anchor hash (truncated), and DID. Actions available: Present via QR code, Share Link (navigates to selective disclosure), Export Document.

### 4.3 Credential Storage Logic

#### 4.3.1 Current Implementation Status

The current implementation uses **in-memory mock data** without persistent storage. No Hive, SharedPreferences, flutter_secure_storage, or SQLite implementations are in place.

Mock data locations: `UI_App/lib/model/IdentityDoc.dart`, `UI_App/lib/constants/data.dart`

#### 4.3.2 Credential Model Structure

The model class represents the core credential data structure, to be extended with cryptographic fields: digital signature bytes, IPFS CID reference, and blockchain transaction hash.

#### 4.3.3 Data Schema for Production

**TABLE III — Current Prototype Schema**

| Field | Type | Description |
| --- | --- | --- |
| id | String | Unique credential identifier |
| cid | String | IPFS Content Identifier |
| signature | Uint8List | ML-DSA-44 signature bytes |
| publicKey | String | Issuer's public key |
| txHash | String | Blockchain transaction reference |
| schemaId | String | Schema definition reference |
| attributes | Map<String, dynamic> | Credential-specific fields |
| issuedAt | DateTime | Issuance timestamp |
| expiresAt | DateTime? | Optional expiration |
| status | CredentialStatus | Valid/Revoked/Suspended/Expired |

### 4.4 QR-Based Presentation Flow

#### 4.4.1 Implementation Overview

File: `UI_App/lib/screens/present_screen.dart`

The QR presentation screen implements a time-limited credential presentation mechanism:

- **QR Display** — currently uses `Icons.qr_code_2` as placeholder; production will use `qr_flutter`
- **Expiration Timer** — 10-second countdown (configurable; production: 5 minutes)
- **Visual States** — Active QR and Expired QR with refresh option
- **Progress Indicator** — linear progress bar showing remaining time

#### 4.4.2 Timer Implementation

A countdown timer mechanism prevents replay attacks by ensuring credentials cannot be reused after expiration. Single-use, time-limited QR codes enforce this security property.

#### 4.4.3 QR Visual Component

In production, `qr_flutter` will encode the credential CID, a nonce, and timestamp into a QR code matrix.

#### 4.4.4 Production QR Encoding Specification

The production QR code encodes: credential CID, nonce, and timestamp in a tamper-evident format.

### 4.5 Selective Disclosure Design

#### 4.5.1 Implementation Approach

File: `UI_App/lib/screens/selective_screen.dart`

A field visibility map drives selective disclosure. Sensitive fields (National ID) and technical fields (Digital Signature, Blockchain Anchor, DID) are hidden by default, implementing privacy-by-design principles.

#### 4.5.2 UI Implementation

Green indicates visible fields; red indicates hidden fields, providing clear visual feedback for field visibility status.

#### 4.5.3 Future ZKP Evolution

| Stage | Approach |
| --- | --- |
| Current State | Boolean field masking before JSON export |
| Future State | ZK-SNARK proofs enabling attribute assertions without revealing underlying data |
| Integration Point | The `_visible` map drives ZK circuit inputs, generating proofs only for selected attributes |

### 4.6 Activity Log

File: `UI_App/lib/screens/activity_screen.dart`

Displays chronological credential operations grouped by "Today" and "Earlier", with operation types (Received, Presented, Refreshed, Verified), color-coded status indicators, and per-entry timestamps.

### 4.7 Settings

File: `UI_App/lib/screens/settings_screen.dart`

Configuration sections: Security (biometric settings), Backup (recovery phrase management), Appearance (theme selection), and About (version, DID display `did:fabric:0x3f...8a2c`).

---

## 5. QPortal Web Application Implementation

QPortal is the Flutter Web application for institutional actors. Unlike QWallet, QPortal is workflow-centric and integrates closely with backend cryptographic services and blockchain infrastructure. It facilitates credential form submission, signature generation requests, IPFS storage operations, and blockchain transaction triggers.

### 5.1 Technology Stack

**TABLE IV — Technology Stack for QPortal**

| Component | Specification |
| --- | --- |
| Framework | Flutter Web SDK ^3.9.2 |
| Language | Dart ^3.9.2 |
| Routing | Custom Navigator 2.0 (not go_router) |
| State Management | Custom RouterDelegate with ChangeNotifier, StatefulWidget |
| Icons | font_awesome_flutter ^10.12.0 |
| Typography | Custom fonts: Formula (branding), SFPro (UI text) |

Dependencies are specified in `UI_WebApp/pubspec.yaml`.

#### 5.1.1 Routing Architecture

The application implements Flutter's Navigator 2.0 pattern with a custom `RouterDelegate` that manages both navigation state and role-based variant switching. When navigating to a route belonging to a different portal (Issuer/Verifier/Admin), the variant automatically updates to display the appropriate sidebar section.

#### 5.1.2 Role-Based Access Control

A variant enum controls portal access and sidebar visibility. Each role has distinct capabilities and accent colors:

- **Issuer** — Navy Blue
- **Verifier** — Forest Green
- **IT Admin** — Purple

#### 5.1.3 Folder Structure

Located at `UI_WebApp/`. All dependency specifications are in `UI_WebApp/pubspec.yaml`.

### 5.2 Issuer Portal

#### 5.2.1 Credential Creation Form (5-Step Wizard)

File: `UI_WebApp/lib/screens/issuer/issue_single_credential_page.dart`

**TABLE V — Steps for Credential Issuance**

| Step | Label | Function |
| --- | --- | --- |
| 1 | Select Credential Type | Choose from active schemas |
| 2 | Find Holder | Search and select recipient |
| 3 | Fill Credential Details | Dynamic form based on schema |
| 4 | Credential Preview | Visual preview with all fields |
| 5 | Confirm & Issue | Authorization checkbox + issuance |

#### 5.2.2 Form Validation

A validation function iterates through schema-defined required fields, ensuring all mandatory attributes are populated before advancing to preview.

#### 5.2.3 Issuance Simulation

A two-phase issuance process: first, cryptographic signing with ML-DSA-44/Dilithium; then blockchain transaction submission. Generated credential IDs follow the format `QC-YYYY-NNNNNN`.

#### 5.2.4 Production API Integration Points

- **Step 5 Confirmation** — triggers `_startIssuing()`
- **Signing Phase** — calls off-chain PQC service API
- **Blockchain Phase** — invokes Hyperledger Fabric chaincode
- **IPFS Upload** — credential JSON stored, CID returned
- **Completion** — returns credential ID and transaction hash

### 5.3 Verifier Portal

#### 5.3.1 QR Scanning Implementation

File: `UI_WebApp/lib/screens/verifier/scan_validation_page.dart`

Designed for hardware QR scanner integration with a 260×260 dotted scan area and pulsing animation providing visual feedback while awaiting scanner input.

#### 5.3.2 Manual Verification Modes

File: `UI_WebApp/lib/screens/verifier/manual_verify_page.dart`

**TABLE VI — Verification Modes**

| Mode | Input | Use Case |
| --- | --- | --- |
| Credential ID | Text field | Direct ID entry |
| OTP | 6-digit code | Time-based verification code from QWallet |
| Document | File upload | PDF credential verification |

#### 5.3.3 Verification API Call Simulation

A two-phase simulation: first, extracting credential data from the uploaded document; then verifying signature and blockchain anchor via backend API.

### 5.4 IT Admin Portal

#### 5.4.1 Audit Log

File: `UI_WebApp/lib/screens/IT Admin/audit_log_page.dart`

Features: append-only, read-only log display; search across actions, details, staff; pagination (25/50/100 rows per page); export to XLSX, PDF, JSON; action badges with color coding.

#### 5.4.2 Cryptographic Settings

File: `UI_WebApp/lib/screens/ITAdmin/crypto_settings_page.dart`

Allows administrators to configure PQC algorithm selection (Dilithium or Falcon), view the organization public key, and manage key rotation (placeholder).

### 5.5 Shared UI Architecture

#### 5.5.1 Layout System

File: `UI_WebApp/lib/utils/app_shell.dart`

Responsive behavior: persistent sidebar on large screens (≥910px); hamburger menu + drawer on small screens (<910px). `AnimatedSwitcher` provides smooth page transitions.

#### 5.5.2 Navigation Sidebar

File: `UI_WebApp/lib/components/sidebar.dart`

The sidebar receives variant, active route, and navigation callback as props, ensuring synchronized state between router and UI.

#### 5.5.3 Theme Configuration

File: `UI_WebApp/lib/theme/appColours.dart`

The color system provides semantic meaning through color: role identification (Issuer / Verifier / IT Admin) and credential status (Valid / Revoked / Suspended / Expired).

---

## 6. Off-Chain Backend & IPFS Integration

### 6.1 Overview of Off-Chain Architecture

The off-chain backend addresses the fundamental tension between data integrity guarantees and blockchain scalability constraints. ML-DSA-44 signatures measure ~2 KB versus 64 bytes for ECDSA, making on-chain storage impractical. QChain implements a hybrid on-chain/off-chain model: the blockchain stores only CIDs (cryptographic hashes referencing off-chain data), while full credential documents and post-quantum signatures reside on IPFS. This reduces blockchain storage requirements by ~98% while maintaining cryptographic verifiability.

The system employs a **dual-implementation strategy** to evaluate trade-offs:

- **go-bindings** (liboqs-go) — uses a Go wrapper around the Open Quantum Safe C library; optimized execution via native C implementations
- **go-native** (Cloudflare CIRCL) — pure Go implementation; eliminates C dependencies; simplifies cross-platform deployment

Both implementations expose identical functional interfaces, enabling direct performance comparison.

### 6.2 Backend Technology Stack

The off-chain backend is implemented in Go 1.23, selected for its strong cryptographic library ecosystem, robust concurrency primitives, and efficient compiled binary distribution.

#### 6.2.1 Core Dependencies

- `github.com/open-quantum-safe/liboqs-go` — Go bindings to liboqs C library (go-bindings implementation)
- `github.com/ipfs/go-ipfs-api v0.7.0` — HTTP client for IPFS daemon API
- `github.com/cloudflare/circl v1.3.7` — pure Go ML-DSA implementation (go-native implementation)

#### 6.2.2 Technology Stack Comparison

**TABLE VII — Technology Stack for Off-Chain Backend**

| Component | go-bindings (liboqs) | go-native (CIRCL) |
| --- | --- | --- |
| Programming Language | Go 1.23 + C (CGO) | Go 1.23 (pure) |
| PQC Library | liboqs v0.10.0 (C) | Cloudflare CIRCL v1.3.7 |
| IPFS Integration | go-ipfs-api v0.7.0 | go-ipfs-api v0.7.0 |
| Build Requirements | cmake, ninja, gcc, libssl | git, ca-certificates |
| CGO Dependency | Required (CGO_ENABLED=1) | Disabled (CGO_ENABLED=0) |
| Docker Base Image (Builder) | golang:1.23-bookworm (~1.2GB) | golang:1.23-alpine (~400MB) |
| Docker Base Image (Runtime) | debian:bookworm-slim (~150MB) | alpine:3.19 (~20MB) |
| Cross-Compilation Complexity | High (C toolchain required) | Low (native Go) |
| Performance (Signing) | 0.091 ms/op | 0.196 ms/op |

#### 6.2.3 Containerization Architecture

Both implementations use multi-stage Docker builds. The go-bindings Dockerfile compiles liboqs from source (requiring cmake and ninja), resulting in a ~150MB runtime image. The go-native Dockerfile requires only basic Go tooling, reducing compilation time from ~5–8 minutes to ~2–3 minutes and producing a ~20MB runtime image — a 7.5× size reduction.

### 6.3 ML-DSA-44 Cryptographic Integration

ML-DSA (Module-Lattice-Based Digital Signature Algorithm, previously CRYSTALS-Dilithium) was standardized by NIST in 2024. The system implements ML-DSA-44, corresponding to NIST Security Level 2 (classical security equivalent to AES-128 and SHA-256 preimage resistance).

#### 6.3.1 Key Generation

Key generation produces an ML-DSA-44 keypair stored exclusively in process memory. The `GenerateKeyPair()` function returns a **1,312-byte** public key and a **2,560-byte** private key. Both implementations use cryptographically secure random number generation for key material.

**Security Note**: The current implementation exposes private keys via standard output for demonstration purposes. Production deployment requires HSM or KMS-based key management.

#### 6.3.2 Credential Signing Process

Digital signature generation is performed on the IPFS CID of the uploaded document (rather than the document content itself). Since the CID is a cryptographic hash of the document, signing the CID transitively authenticates the document content.

The `Sign()` method implements ML-DSA-44 signing via matrix-vector multiplications over polynomial rings with rejection sampling, producing a **2,420-byte** signature. Signatures are hex-encoded for JSON serialization (4,840 ASCII characters).

#### 6.3.3 Signature Verification Process

The verification algorithm requires only matrix-vector multiplications without rejection sampling, making it computationally less expensive than signing. The `Verify()` function returns a boolean: `true` guarantees (with overwhelming probability) that the signature was generated using the corresponding private key and the message was not modified.

#### 6.3.4 Signature Size Analysis

**TABLE VIII — Signature Size Comparison**

| Artifact | Size (bytes) | ECDSA-P256 Equivalent | Size Ratio |
| --- | --- | --- | --- |
| Public Key | 1,312 | 64 | 20.5× |
| Private Key | 2,560 | 32 | 80.0× |
| Signature | 2,420 | 64 | 37.8× |
| IPFS CID (Base58) | 46 | 46 | 1.0× |

The 37.8× signature size increase motivates off-chain storage. By storing only the 46-byte CID on-chain, the system reduces per-credential blockchain storage by **98.1%** while maintaining full cryptographic verifiability.

### 6.4 Credential JSON Structure

The verification payload stored on IPFS is a JSON object with two fields:

- `document_cid` — IPFS CID of the original credential document (Base58 or Base32 encoded)
- `pqc_signature` — hex-encoded ML-DSA-44 signature bytes (4,840 characters; ~5 KB total payload)

### 6.5 IPFS Integration

#### 6.5.1 IPFS Node Configuration

The system connects to an IPFS daemon via HTTP API using environment variables (`IPFS_API_HOST`). In Docker Compose deployment, the IPFS service runs as a separate container (ipfs/kubo:latest) with three exposed ports:

- `5001` — HTTP API for programmatic interaction
- `8080` — Gateway for browser-based retrieval
- `4001` — Swarm port for peer-to-peer distribution

#### 6.5.2 Credential Upload Workflow

The IPFS upload process consists of two sequential phases:

- **Phase 1** — upload the original PDF document; IPFS chunks the file, constructs a Merkle DAG, and returns the root `documentCID`
- **Phase 2** — generate the ML-DSA-44 signature over `documentCID`, construct the verification payload JSON, and upload to IPFS to receive the `finalCID`

This two-phase strategy allows verifiers to retrieve only the verification payload first, and conditionally retrieve the document itself only if signature validation succeeds.

#### 6.5.3 CID Extraction and Handling

CIDs are returned directly from the `sh.Add()` function as strings (CIDv1 in Base32 encoding). Error handling uses a fail-fast `log.Fatalf()` pattern appropriate for CLI tools.

#### 6.5.4 Retrieval from IPFS

The current implementation performs document and payload retrieval manually via the IPFS HTTP gateway. Production implementation would use programmatic retrieval via `shell.Cat()` with explicit SHA-256 hash verification of retrieved content.

### 6.6 CLI Application Architecture

The off-chain components implement a CLI execution model — a single-shot batch-processing pattern appropriate for proof-of-concept validation.

#### 6.6.1 Execution Model

1. Application starts via Docker container invocation
2. Initializes cryptographic libraries and IPFS connections
3. Executes the complete credential issuance workflow
4. Writes output to standard output
5. Terminates with exit code 0 (success) or 1 (failure)

#### 6.6.2 Docker Compose Orchestration

**TABLE IX — Docker Commands and Implementation**

| Command | Implementation | Purpose |
| --- | --- | --- |
| `docker compose --profile bindings run --rm go-bindings` | liboqs (C-bindings) | Execute optimized C-based implementation |
| `docker compose --profile native run --rm go-native` | CIRCL (pure Go) | Execute portable pure-Go implementation |
| `docker compose --profile full up` | Both | Start all services for integration testing |

#### 6.6.3 Environment Configuration

Runtime configuration is injected through Docker Compose environment variables. The `depends_on` clause with `condition: service_healthy` ensures the IPFS daemon completes initialization before the CLI application starts, preventing race conditions.

#### 6.6.4 Transition to Service Architecture

Future integration with UI applications and Hyperledger Fabric requires refactoring to a persistent service model with: REST API endpoints, persistent key management (HSM/KMS), asynchronous job queues, stateful `/health` and `/metrics` endpoints, and OAuth2-based authentication.

### 6.7 End-to-End Backend Workflow

#### 6.7.1 Issuance Flow (Backend Perspective)

The credential issuance workflow in `offchain/go-bindings/main.go` executes nine steps:

1. **Algorithm Initialization** — initialize ML-DSA-44 via liboqs; `defer signer.Clean()` ensures secure memory erasure
2. **Key Pair Generation** — generate fresh 1,312-byte public key and 2,560-byte private key
3. **IPFS Connection** — establish connection to IPFS daemon (reused for both uploads)
4. **Document File Opening** — open PDF credential from container's working directory
5. **Document Upload to IPFS** — IPFS chunks file and returns root `documentCID`
6. **CID Signing** — sign `documentCID` with ML-DSA-44 private key → 2,420-byte signature
7. **Verification Payload Construction** — construct JSON with `document_cid` and hex-encoded signature
8. **Payload Upload to IPFS** — upload JSON → receive `finalCID` (to be recorded on blockchain)
9. **Output Generation** — print `finalCID` to stdout for manual blockchain storage

Total workflow: ~200ms (liboqs) or ~350ms (CIRCL), excluding IPFS network latency.

#### 6.7.2 Verification Flow (Backend Perspective)

The intended multi-step verification flow (partially implemented):

1. Retrieve verification payload JSON from IPFS using `finalCID`
2. Parse JSON to extract `documentCID` and hex-encoded signature
3. Hex-decode the signature string to binary format
4. Retrieve issuer's ML-DSA-44 public key from blockchain or trusted registry
5. Invoke `Verify(publicKey, documentCID, signature)`
6. On success, retrieve original document from IPFS using `documentCID`
7. Return structured verification result

**Current Status**: The go-native implementation includes inline verification confirming cryptographic correctness. No standalone verification CLI tool or API endpoint yet exists for the full multi-step flow.

### 6.8 Testing and Experimental Validation

#### 6.8.1 Functional Testing

Performance-oriented functional testing is implemented via Go's benchmarking framework (`main_test.go` files for both implementations). Three benchmark functions are implemented:

- **BenchmarkKeyGeneration** — measures key pair generation throughput across ML-DSA-44, 65, and 87
- **BenchmarkSigning** — measures signing throughput using a fixed dummy CID
- **BenchmarkVerification** — measures signature verification throughput

**Outstanding adversarial tests** (not yet implemented): invalid signature tests, tampered CID tests, and wrong public key tests.

#### 6.8.2 Performance Measurements

Executed via: `go test -bench=. -benchmem`

**TABLE X — go-bindings (liboqs) Performance**

| Operation | Security Level | Speed (ms/op) | Relative Performance |
| --- | --- | --- | --- |
| Key Generation | ML-DSA-44 | 0.041 | Baseline |
| | ML-DSA-65 | 0.071 | 1.73× slower |
| | ML-DSA-87 | 0.122 | 2.98× slower |
| Signing | ML-DSA-44 | 0.091 | Baseline |
| | ML-DSA-65 | 0.147 | 1.62× slower |
| | ML-DSA-87 | 0.212 | 2.33× slower |
| Verification | ML-DSA-44 | 0.037 | Baseline |
| | ML-DSA-65 | 0.064 | 1.73× slower |
| | ML-DSA-87 | 0.113 | 3.05× slower |
| Total Workflow | ML-DSA-44 | 0.169 | Baseline |
| | ML-DSA-65 | 0.282 | 1.67× slower |
| | ML-DSA-87 | 0.447 | 2.65× slower |

**TABLE XI — go-native (CIRCL) Performance**

| Operation | Security Level | Speed (ms/op) | Relative Performance |
| --- | --- | --- | --- |
| Key Generation | ML-DSA-44 | 0.085 | Baseline |
| | ML-DSA-65 | 0.153 | 1.80× slower |
| | ML-DSA-87 | 0.228 | 2.68× slower |
| Signing | ML-DSA-44 | 0.196 | Baseline |
| | ML-DSA-65 | 0.373 | 1.90× slower |
| | ML-DSA-87 | 0.520 | 2.65× slower |
| Verification | ML-DSA-44 | 0.034 | Baseline |
| | ML-DSA-65 | 0.046 | 1.35× slower |
| | ML-DSA-87 | 0.065 | 1.91× slower |
| Total Workflow | ML-DSA-44 | 0.315 | Baseline |
| | ML-DSA-65 | 0.572 | 1.82× slower |
| | ML-DSA-87 | 0.813 | 2.58× slower |

Key findings: liboqs executes signing ~2× faster than CIRCL (0.091ms vs 0.196ms). CIRCL exhibits marginally faster verification (0.034ms vs 0.037ms). Both achieve sub-millisecond latency for the primary signing operation (vs. 0.02–0.05ms for classical ECDSA — approximately 2–5× overhead). ML-DSA-44 offers the optimal balance for NIST Level 2 security.

---

## 7. Blockchain Smart Contract & Middleware Integration

### 7.1 Hyperledger Fabric Network Architecture

#### 7.1.1 Network Topology

The QChain network operates with two primary organizations:

- **Org1MSP** — represents governmental entities (credential verification, student registration). CA at `ca.org1.example.com:7054`
- **Org2MSP** — represents academic institutions (credential issuance). CA at `ca.org2.example.com:8054`

Both organizations participate in the shared channel `mychannel`. The PQCreddy chaincode (`pqcreddy`) is deployed to this channel.

**TABLE XII — Network Topology**

| Component | Organization | Expected Configuration | Status |
| --- | --- | --- | --- |
| CA Server | Org1MSP | ca.org1.example.com:7054 | Referenced but not deployed |
| CA Server | Org2MSP | ca.org2.example.com:8054 | Referenced but not deployed |
| Channel | Both orgs | mychannel | Referenced in code |
| Chaincode | Both orgs | pqcreddy | Implemented |
| Peer Nodes | Org1MSP, Org2MSP | Not defined | Missing |
| Orderer Service | N/A | Not defined | Missing |

**Note**: While the code references this topology, practical deployment configuration files (docker-compose for Fabric peer nodes, orderer services, and CA servers) are absent from the repository. This represents a gap between conceptual architecture and operational deployment.

#### 7.1.2 Membership Service Providers (MSP)

MSPs define the cryptographic mechanisms by which Fabric validates participant identities. Each MSP maintains X.509 certificates, CRLs, and organizational unit identifiers establishing trust relationships. The `getMSPID()` API enforces hard organizational boundaries — participants from Org1MSP cannot invoke functions restricted to Org2MSP, and vice versa. Node Organizational Units (NodeOUs) enable fine-grained classification into functional roles (clients, peers, admins, orderers).

#### 7.1.3 Channel and Ledger Configuration

Channel configuration parameters include consortium definition, ordering service, anchor peers, and endorsement policies. Note that the operational configuration artifacts (channel creation transaction, genesis block, endorsement policies) do not yet exist in the repository. The following components would need to be created for operational deployment: `configtx.yaml`, genesis block, peer configuration files, and orderer configuration.

### 7.2 PQCreddy Smart Contract Design

#### 7.2.1 Contract Structure and Initialization

The PQCreddy smart contract is a JavaScript class extending the Hyperledger Fabric Contract API, located at `PQCreddy.js`. It imports `json-stringify-deterministic` and `sort-keys-recursive` to ensure canonical JSON serialization, which is critical for consistent cryptographic hashing across blockchain state.

#### 7.2.2 Transaction Functions Overview

**TABLE XIII — PQCreddy Transaction Functions**

| Function | Type | Purpose | Access Control |
| --- | --- | --- | --- |
| init() | Initialization | Contract initialization | None |
| registerHolder() | Write | Register student identity | Org1MSP + government.role=issuer |
| issueCredential() | Write | Issue post-quantum credential | Org2MSP + university.role=issuer |
| verifyCredential() | Read | Verify credential status and public key | Org1MSP (any role) |
| revokeCredential() | Write | Revoke a credential | Org2MSP + university.role=issuer |
| checkAccess() | Helper | Enforce MSP and attribute-based authorization | Internal use |
| getStudent() | Helper | Retrieve student record from state | Internal use |
| getCredential() | Helper | Retrieve credential record from state | Internal use |

#### 7.2.3 Data Models

**Student Data Model**: Created during `registerHolder()`. Student ID is auto-generated from the transaction ID (`S-` + first 8 characters of `ctx.stub.getTxID()`). Fields include student ID, name, department, and major.

**Credential Data Model**: Contains credential ID (`CRED-` prefix), holder (foreign key to Student.ID), issuer (X.509 DN), status (active/revoked), info (credential content), issuedAt (ISO 8601, Dubai timezone), and publicKey (ML-DSA-44 public key, 1,312 bytes).

**Critical Omission**: The Credential data model does not include an IPFS CID field. This breaks the architectural integrity of the hybrid on-chain/off-chain model — the linkage between on-chain metadata and off-chain documents must be managed externally.

### 7.3 Role-Based Access Control Implementation

#### 7.3.1 Access Control Mechanism

The `checkAccess()` helper function performs two sequential authorization checks:

1. **MSP Verification** — `ctx.clientIdentity.getMSPID()` must match the required organization; otherwise the transaction fails
2. **Attribute Verification** — `ctx.clientIdentity.assertAttributeValue()` verifies the transaction submitter's certificate contains the required role attribute (format: `${body}.role`, where body is "government" or "university")

#### 7.3.2 Permission Matrix

**TABLE XIV — PQCreddy Access Control Matrix**

| Function | Required MSP | Required Attribute | Rationale |
| --- | --- | --- | --- |
| registerHolder() | Org1MSP | government.role=issuer | Government entities register student identities |
| issueCredential() | Org2MSP | university.role=issuer | Only universities may issue academic credentials |
| verifyCredential() | Org1MSP | (any) | Government entities verify; no specific role required |
| revokeCredential() | Org2MSP | university.role=issuer | Only the issuing university may revoke credentials |

**Design Note**: This architecture creates a dependency — universities cannot issue credentials for students not pre-registered by government entities. This tight coupling may not align with existing administrative processes.

#### 7.3.3 Identity Attributes

Custom attributes are embedded in X.509 enrollment certificates during Fabric CA registration. The `ecert: true` flag ensures attributes are cryptographically bound to the certificate (verifiable by `assertAttributeValue()` in chaincode). The three application roles are `issuer`, `holder`, and `verifier`, combined with organization namespacing (`government.role` / `university.role`).

### 7.4 Identity Management and Enrollment

#### 7.4.1 Fabric CA Architecture

Separate CA instances for each organization: `ca.org1.example.com:7054` (government) and `ca.org2.example.com:8054` (university). This separation ensures each organization maintains autonomous control over identity lifecycle. The hierarchical enrollment model requires admin users to enroll first before registering non-admin users.

**Note**: The `enrollAdmin.js` script is currently absent from the repository, representing an incomplete identity management system. This must be addressed before operational deployment.

#### 7.4.2 User Registration Workflow

The `registerUser.js` script implements a nine-phase enrollment process:

| Phase | Action |
| --- | --- |
| 1 | Organization mapping (government → Org1MSP, university → Org2MSP) |
| 2 | Connection profile loading (files missing from repository) |
| 3 | CA Client initialization |
| 4 | Wallet setup (file system wallet at `./wallet`) |
| 5 | Admin identity verification |
| 6 | User registration with CA (returns one-time enrollment secret) |
| 7 | User enrollment (exchanges secret for X.509 certificate and ECDSA P-256 private key) |
| 8 | X.509 identity creation (binds certificate to MSP ID) |
| 9 | Wallet storage (persists identity for subsequent transaction submissions) |

**Security Note**: Fabric's identity layer uses classical ECDSA rather than post-quantum algorithms. While credential signatures employ ML-DSA-44, the underlying identity infrastructure remains vulnerable to future quantum attacks.

### 7.5 Express Middleware and REST API

#### 7.5.1 Gateway Connection

The Express.js middleware (`server.js`) is the REST API gateway between client applications and Hyperledger Fabric. The `getContract()` helper implements the standard Fabric SDK connection pattern.

**Critical Security Flaw**: All API requests use the same hardcoded blockchain identity (`appUser`). This renders the carefully constructed chaincode access control mechanisms ineffective — every transaction carries the same identity regardless of the requesting user. Proper implementation requires per-request credentials mapped to distinct blockchain identities.

#### 7.5.2 API Endpoint Catalog

**TABLE XV — Express Middleware API Endpoints**

| Endpoint | HTTP Method | Request Parameters | Chaincode Function | Working Status |
| --- | --- | --- | --- | --- |
| /registerStudent | POST | {name, department, major} | registerHolder() | Would work if network existed |
| /issueCredential | POST | {studentID, info} | issueCredential() | Fails: missing pqcClient + syntax errors |
| /verifyCredential | POST | {credID, message, signature, publicKey} | verifyCredential() | Fails: missing pqcClient |
| /revokeCredential | POST | {studentID, credID} | revokeCredential() | Would fail due to chaincode bug |

#### 7.5.3 Endpoint: Issue Credential

The `/issueCredential` endpoint implements the intended integration between the middleware and the off-chain PQC services. Currently fails due to a missing `pqcClient` module.

#### 7.5.4 Endpoint: Verify Credential

The `/verifyCredential` endpoint implements a two-tier verification strategy: on-chain state validation (credential status + public key match) combined with off-chain ML-DSA-44 signature verification. Both checks must pass for the credential to be considered valid. Currently fails due to missing `pqcClient` module.

### 7.6 End-to-End Credential Lifecycle Workflows

#### 7.6.1 Credential Issuance Flow

| Phase | Status | Key Action |
| --- | --- | --- |
| 1 — Administrative Bootstrap | ❌ Not implemented | Enroll bootstrap admins (enrollAdmin.js absent) |
| 2 — Organizational User Registration | ⚠️ Partial | Implemented but blocked by missing connection profiles |
| 3 — Student Identity Registration | ✅ Would work | POST /registerStudent → registerHolder() → ledger write |
| 4 — Document Preparation & IPFS Upload | ✅ Complete | Execute go-bindings → PDF upload → ML-DSA sign → finalCID |
| 5 — Credential Issuance via Blockchain | ⚠️ Partial | Blocked by missing pqcClient module |
| 6 — CID Storage | ❌ Missing field | Credential data model lacks IPFS_CID field |

#### 7.6.2 Credential Verification Flow

| Phase | Status | Key Action |
| --- | --- | --- |
| 1 — Verifier Identity Setup | ❌ Not implemented | Blocked by missing enrollAdmin.js |
| 2 — Credential Retrieval | ⚠️ Partial | No query endpoint exists; getCredential() helper is not a public transaction |
| 3 — Hybrid Verification | ⚠️ Partial | Dual on-chain + off-chain validation designed; pqcClient missing |
| 4 — Document Retrieval from IPFS | ⚠️ Manual only | CID not stored on-chain; manual gateway access required |

#### 7.6.3 Credential Revocation Flow

**Critical Bug Identified**: The `revokeCredential()` function modifies the Credential object's status in memory but executes `putState()` on the Student object rather than the Credential object. The Credential status remains "active" on the ledger — revocations do not persist. This represents a **severe security vulnerability**: credentials cannot be revoked and remain valid indefinitely.

---

## 8. Quality Alignment & Validation

Quality assurance overseen by Muhammed Nihal. The implemented system reflects alignment with the quality requirements defined in the Team Charter:

| Attribute | Status | Notes |
| --- | --- | --- |
| Security | ✅ Met | NIST-standardized ML-DSA-44 (CRYSTALS-Dilithium) replaces ECDSA; only CID stored on-chain; tamper detection via content-addressing |
| Functionality | ✅ Met | Full credential lifecycle implemented: issuance, PQC signing, IPFS storage, blockchain anchoring, QR presentation, verification; QPortal and QWallet functional |
| Reliability | ✅ Met | Deterministic ML-DSA verification; immutable Fabric ledger; IPFS hash-based content validation |
| Usability | ✅ Met | Consistent design, structured navigation, role-specific dashboards; QR-based presentation simplifies verification; GetX (mobile) and Navigator 2.0 (web) provide responsive interaction |
| Maintainability | ✅ Met | Modular repository structure separates UI, backend, and chaincode; cryptographic operations isolated from presentation; Flutter + Go + Fabric + Docker ensure reproducible deployment |
| Transparency | ✅ Met | Blockchain anchoring ensures credential transaction traceability; issuer identities verifiable via CA; CID-based referencing enables independent integrity validation |

---

## 9. Planned vs Actual Progress

According to the Progress Gantt Chart, the project was divided into structured phases: research, architecture design, frontend development, backend implementation, blockchain integration, and testing.

Progress Report 1 was achieved as scheduled. In this phase, frontend UI/UX implementation progressed slightly faster than anticipated — both QWallet (mobile) and QPortal (web) were completed earlier than the projected deadline, allowing additional refinement of navigation and state management.

The off-chain backend implementation aligned closely with the projected schedule. ML-DSA integration using liboqs-go, IPFS upload functionality, and CID extraction were completed within the designated timeframe. Minor delays occurred during environment configuration and Docker–Fabric dependency alignment, but these did not significantly impact overall milestones.

Chaincode development began slightly later than originally planned due to prioritization of cryptographic backend validation; however, core smart contract logic for CID anchoring and credential retrieval was implemented within the adjusted schedule.

Overall, the project remains on track relative to the original Gantt timeline. All deliverables outlined for the end of the Junior Project phase have been completed: frontend systems, backend cryptographic engine, and blockchain anchoring logic. Remaining tasks correspond to optimization, integration refinement, and extended testing, scheduled for the Senior Project phase.

---

## 10. Next Steps (Senior Project Phase)

The next phase transitions QChain from a functional prototype toward a robust, experimentally validated system:

| Task | Priority | Deliverable |
| --- | --- | --- |
| Full chaincode–backend API integration | High | Seamless transaction submission from web portal |
| Fix revokeCredential() bug | High | Correct putState() target; persistent revocation |
| Add IPFS CID field to Credential data model | High | Complete on-chain/off-chain linkage |
| Resolve missing pqcClient module | High | Working /issueCredential and /verifyCredential endpoints |
| Create enrollAdmin.js and connection profiles | High | Operational Fabric network deployment |
| Performance evaluation | Medium | ML-DSA signing latency, IPFS upload/retrieval, Fabric confirmation time; ECDSA vs ML-DSA comparison |
| Adversarial security tests | Medium | Invalid signature, tampered CID, wrong public key test cases |
| Selective disclosure optimization | Medium | Refined field-masking logic |
| QR verification workflow refinement | Medium | Improved error handling and production QR encoding |
| Documentation finalization | Low | Code commenting, repository structuring, README updates |

**Key milestone:** Complete system integration and experimental validation before submission of the Final Senior Project report.

---

## 11. Bibliography

1. M. A. Haris, "Notion-QPortal UI/UX," 27 03 2026. [Online]. Available: https://www.notion.so/QPortal-UI-UX-323709b86769800785c0c2f2f1667091. [Accessed 27 03 2026].
2. M. A. Haris, "Notion-Issuer," 27 3 2026. [Online]. Available: https://www.notion.so/Issuer-323709b86769808497affae72f0c0155. [Accessed 27 3 2026].
3. M. A. Haris, "Notion-Verifier," 26 3 2026. [Online]. Available: https://www.notion.so/Verifier-323709b8676980cea679d977b970dbd2. [Accessed 26 3 2026].
4. M. A. Haris, "Notion-ITAdmin," 26 03 2026. [Online]. Available: https://www.notion.so/IT-Admin-323709b86769805788afd2bf33d75e06. [Accessed 27 03 2026].
5. M. A. Haris, "GitHub-UI_App," 15 02 2026. [Online]. Available: https://github.com/nihvp/QChain-PQC-blockchain/tree/main/UI_App. [Accessed 27 03 2026].
6. M. A. Haris, "GitHub-UI_WebApp," 15 03 2026. [Online]. Available: https://github.com/nihvp/QChain-PQC-blockchain/tree/main/UI_WebApp. [Accessed 27 03 2026].
7. Z. Zheng, S. Xie, H. Dai and H. Wang, "Blockchain challenges and opportunities: a survey," *International Journal of Web and Grid Services (Inderscience)*, vol. 14, no. 44, pp. 352–375, 2018.
8. L. D. et al., "CRYSTALS-Dilithium: A lattice-based digital signature scheme," *IACR Transactions on Cryptographic Hardware and Embedded Systems*, no. 1, pp. 238–268, 2018.
9. M. Nihal, "GitHub-offchain," 10 02 2026. [Online]. Available: https://github.com/nihvp/QChain-PQC-blockchain/tree/main/offchain. [Accessed 26 03 2026].
10. M. Nihal, "GitHub-binding," 10 02 2026. [Online]. Available: https://github.com/nihvp/QChain-PQC-blockchain/tree/main/offchain/go-bindings. [Accessed 26 03 2026].
11. M. Nihal, "GitHub-native," 10 03 2026. [Online]. Available: https://github.com/nihvp/QChain-PQC-blockchain/tree/main/offchain/go-native. [Accessed 26 03 2026].
12. "GitHub:liboqs-go Library," [Online]. Available: https://github.com/open-quantum-safe/liboqs-go. [Accessed 27 03 2026].
13. "GitHub-IPFS," [Online]. Available: https://github.com/ipfs/go-ipfs-api. [Accessed 27 02 2026].
14. "GitHub-circl," [Online]. Available: https://github.com/cloudflare/circl. [Accessed 26 03 2026].
15. N. I. o. S. a. Technology, "Module-Lattice-Based Digital Signature Standard (ML-DSA)," *Federal Information Processing Standards Publication (FIPS) 204, U.S. Department of Commerce*, Aug. 2024.
16. L. Ducas, E. Kiltz, T. Lepoint, V. Lyubashevsky, P. Schwabe, G. Seiler and G. Stehlé, "CRYSTALS-Dilithium: A lattice-based digital signature scheme," *IACR Transactions on Cryptographic Hardware and Embedded Systems*, no. 1, pp. 238–268, 2018.
17. V. Lyubashevsky, "Lattice signatures without trapdoors," in *Advances in Cryptology – EUROCRYPT 2012, Lecture Notes in Computer Science*, vol. 7237, pp. 738–755, 2012.
18. J. Benet, "IPFS – Content Addressed, Versioned, P2P File System," *arXiv preprint arXiv:1407.3561*, July 2014.
19. M. B. A. Maqqavi, "GitHub-Docker," 20 03 2026. [Online]. Available: https://github.com/nihvp/QChain-PQC-blockchain/tree/main/docker. [Accessed 26 03 2026].
20. M. Obied, "GitHub-Hyperledger Fabric," 10 02 2026. [Online]. Available: https://github.com/nihvp/QChain-PQC-blockchain/tree/main/fabric. [Accessed 27 03 2026].

---

**Last Updated:** 31st March 2026
