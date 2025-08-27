# SubTracker-Data

Public data for the SubTracker project: curated subscription providers, standardized labels, and daily-updated foreign exchange rates.

## Overview
This repository hosts the public, versioned dataset used by SubTracker. It is designed to be:
- Transparent — data changes are tracked via commits.
- Easy to consume — fetch directly via Git, pinned commits, or raw file URLs.
- Continuously updated — exchange rates and other dynamic resources are refreshed daily.

If you are building tooling or integrations around subscriptions, this dataset lets you stay aligned with SubTracker’s provider catalog, labeling taxonomy, and currency conversions.

## What’s Included
- Subscription providers — a comprehensive, regularly maintained list of providers and related metadata.
- Labels taxonomy — standardized labels/categories to classify subscriptions consistently.
- Exchange rates — daily snapshots enabling currency normalization and reporting.

Note: The exact file and folder structure may evolve; please consult the repository tree for the latest layout.

## Update Cadence
- Exchange rates: updated daily.
- Providers and labels: updated as needed (curation and corrections).
- All updates are tracked through commits; you can pin to a specific point in time when reproducibility matters.

## How to Consume This Data
You can use any of the following approaches, depending on your needs:

- Clone the repository
  - Best for local analysis, development, or bulk processing.
  - Use a specific commit hash to ensure reproducibility.

- Pin to a commit
  - In CI/CD or production systems, reference a specific commit hash to avoid unexpected changes.
  - Update the pin on your schedule after validating changes.

- Fetch raw files
  - For lightweight use, you can fetch individual files via the repository’s raw URLs.
  - Cache responses and set appropriate timeouts/retries in your client.

General recommendations:
- Validate and sanitize input before using it in downstream systems.
- Cache the data if you do not need real-time updates (e.g., daily or hourly refresh).
- Implement graceful fallbacks if a file is temporarily unavailable.

## Versioning, Reproducibility, and Pinning
- This dataset is maintained via Git; commit hashes serve as immutable references.
- When building pipelines or scheduled jobs, pin to a commit hash (or tag, when available).
- Record the commit hash alongside any derived analytics or reports for auditability.

## Data Quality and Changes
- Schema and field names may evolve to improve consistency or coverage.
- Breaking changes will be minimized and documented in commit messages and/or release notes when applicable.
- If you depend on specific fields, add validation at ingest time to detect changes early.

## Contributing
Contributions that improve accuracy, coverage, or documentation are welcome.

- Open an issue to propose enhancements or report problems (e.g., missing providers, taxonomy gaps, or rate anomalies).
- For data changes, include clear rationale, sources (when applicable), and sample use cases.
- Keep changes atomic and easy to review.

## Attribution and Sources
Where applicable, data files include attribution or references to original sources. Please retain attribution when redistributing derived works.

## License
Unless stated otherwise in a file header, the contents of this repository are provided for public use under an open license. Review the LICENSE file (if present) for terms. If no license is present, please open an issue to clarify usage rights for your scenario.

## Security and Responsible Use
- Do not include or rely on personally identifiable information (PII) in this dataset.
- If you discover a data accuracy or integrity issue, please open a responsible disclosure issue with enough detail to reproduce.
- For financial calculations, consider using pinned daily exchange rates and document your chosen methodology (e.g., end-of-day vs. intraday).

## Support and Contact
- Questions or feedback: open an issue in this repository with a clear title and description.
- For general information about the SubTracker project, see the main project page.

Thank you for using SubTracker-Data. Your feedback helps keep the ecosystem accurate and reliable.

