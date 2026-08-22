# Require Google sign-in

Pocket Speech requires Google sign-in through Firebase Authentication before users can clone voices or generate speech, superseding the PRD's original anonymous-bootstrap requirement. FastAPI verifies Firebase ID tokens, while Firestore, Firebase Storage, and Firebase Functions remain excluded. Persistent identity is required so plan, quota, and future Google Play subscription state survive reinstalls and repeat sign-ins.
