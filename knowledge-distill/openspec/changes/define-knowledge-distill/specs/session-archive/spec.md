## ADDED Requirements

### Requirement: Explicit optional archival
The system SHALL archive an agent session only after an explicit user or agent request and SHALL operate fully when no sessions are archived.

#### Scenario: Ordinary session completes
- **WHEN** work finishes without an archive request
- **THEN** knowledge validation, reconciliation, and distillation continue to function without creating a session archive

#### Scenario: Valuable session is selected
- **WHEN** a user or agent explicitly requests archival
- **THEN** the system prepares that session for review and persistence

### Requirement: Complete immutable evidence
An archive SHALL preserve the complete available session transcript, including prompts, responses, decisions, tool calls, and tool results, except material explicitly removed by the archive safety process.

#### Scenario: Future agent needs exact debugging evidence
- **WHEN** an archived session is opened
- **THEN** the agent can inspect the original ordered transcript rather than relying only on a generated summary

#### Scenario: Archived transcript would be modified
- **WHEN** later knowledge changes refer to an existing archive
- **THEN** the archive remains immutable and new interpretation is stored in mutable knowledge nodes or a new archive

### Requirement: Searchable session summary
Each archive SHALL include a concise text summary that identifies its goal, outcome, decisions, rejected approaches, relevant files, verification, and links to related knowledge nodes.

#### Scenario: Agent searches for an earlier investigation
- **WHEN** search terms match an archive summary or transcript
- **THEN** the system returns the archive identity, summary context, and location of the exact transcript

### Requirement: Many-to-many provenance links
The archive format SHALL permit a session to reference multiple knowledge nodes and a knowledge node to reference multiple archived sessions or exact session ranges.

#### Scenario: Debugging crosses subsystems
- **WHEN** one archived session contributes evidence to several knowledge areas
- **THEN** each relevant node can link to the same archive without placing the archive inside one knowledge subtree

### Requirement: Archive safety gate
The system SHALL require review for secrets, unsafe machine-specific data, and excessive content size before an archive is accepted into the repository, and SHALL record any intentional omissions.

#### Scenario: Potential secret is detected
- **WHEN** the archive preparation process detects sensitive content
- **THEN** archival stops until the content is removed, explicitly redacted, or the archive is abandoned

#### Scenario: Content is redacted
- **WHEN** material is intentionally removed during archival
- **THEN** the transcript contains a visible redaction marker rather than silently appearing complete
