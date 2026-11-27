I-002 error-class admission (Increment 3.31) lives in
`packages/studio_error_class_probe` as `ErrorClassAdmission`.

Structural errors and business errors must be reported as
separate classes. A structural failure must not be reported as
a business error, and a business failure must not be reported
as a structural error.

This directory does not host a schema migrator or a 10k
rational-arithmetic suite. The remaining I-002 labels (10k
rational roundtrips, illegal FK/overlap/overflow refusal,
existing synthetic projects) are not claimed. Schema v10 is
not merged. Project user_version stays 9. The closed root is
not extended. I-002 stays partial. Existing I-002
remainingAcceptance wording is not cleared.
