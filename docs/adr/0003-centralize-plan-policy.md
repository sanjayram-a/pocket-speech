# Centralize plan policy and entitlements

Neon stores versioned server-owned Plan Policies for active voices, monthly clone creation, generated duration, request size, text length, and concurrency. FastAPI resolves and enforces the effective policy, while Flutter only displays returned limits; this keeps quotas changeable and provides the entitlement boundary required for future server-verified Google Play subscriptions without trusting client state.
