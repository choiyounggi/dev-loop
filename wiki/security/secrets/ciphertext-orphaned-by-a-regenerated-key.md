---
id: security-secrets-ciphertext-orphaned-by-a-regenerated-key
domain: security
category: secrets
applies_to: [general, aes-gcm, node]
confidence: verified
sources:
  - https://cheatsheetseries.owasp.org/cheatsheets/Cryptographic_Storage_Cheat_Sheet.html
  - https://nodejs.org/api/crypto.html
  - https://guides.rubyonrails.org/active_record_encryption.html
  - https://developers.google.com/tink/design/keysets
last_verified: 2026-09-06
related: [security-secrets-secrets-in-code, debugging-methodology-hypothesis-testing, debugging-methodology-probe-path-vs-operation-path, infrastructure-data-backup-and-restore]
---

# Stored Ciphertext That No Longer Decrypts After an Environment Script Regenerated the Key

## When this applies

Rows encrypted server-side with a symmetric AEAD (AES-GCM or similar) fail to
decrypt although they were readable before; the service logs that the key
loaded; and an environment bootstrap script (`init:env`, a setup task, a
container entrypoint) is able to create or overwrite the key. Also when you are
about to delete the unreadable rows.

## Do this

1. **Separate the two claims the logs conflate.** "Key loaded" is a statement
   about the process; "this row was encrypted under the loaded key" is a
   statement about the data. A wrong key and a tampered ciphertext produce the
   same failure — in Node, `decipher.final()` "will throw, indicating that the
   cipher text should be discarded due to failed authentication" — so no error
   text distinguishes them.
2. **Run one fresh round-trip.** Encrypt a sentinel with the loaded key and
   decrypt it in the same process. Success proves the code path and the key;
   the fault is then in the relationship between key and stored data.
3. **Scan read-only before any deletion.** Attempt decryption of every affected
   row with the loaded key (and with every previous key you still hold) and
   record `recoverable / total`; act on the count:

| Finding | Do |
|---------|----|
| The key fails to load (missing variable, provider error) | Fix the load path; the data has not been touched and needs nothing |
| Key loads, round-trip passes, `0 / N` rows recoverable | Every row predates the current key — a regeneration happened. Recover the previous key (below) or, for disposable development data, delete the rows and record the count in the change note |
| Key loads, a subset fails | A partial rotation: group failures by the stored key id/version; decrypt each group with its own key; treat rows whose key is gone as the `0 / N` case |
| Rows carry no key id or version at all | Add one now (a version column, or a key-id prefix on the ciphertext) before re-encrypting, so the next mismatch reads as "unknown key id" at the row instead of an authentication failure |

4. **Recover before you re-encrypt.** Old keys are retained precisely for this:
   OWASP notes "old keys should … be stored for a certain period after they have
   been retired, in case old backups of copies of the data need to be
   decrypted". Read the previous value from the secret manager's version history
   or a backup ([infrastructure-data-backup-and-restore]), decrypt, re-encrypt
   under the current key, then retire the old key.
5. **Make the bootstrap idempotent.** Generate the key only when none exists, and
   make any path that would overwrite an existing key stop with a loud message
   naming the rows that depend on it; an unintended regeneration is an unplanned
   rotation with no re-encryption step.

## Edge cases

| Case | Then |
|------|------|
| The data is production data | Deletion is not an option at any count; recover the key from the secret store's version history or backups, re-encrypt, and log the incident |
| A rotation is in progress by design | Store a key identifier with each ciphertext and decrypt by it — Rails ActiveRecord Encryption keeps `previous:` key providers for exactly this, and Tink prefixes "ciphertexts with a 5-byte string derived from the ID" so the right key is selected without trying them all |
| The round-trip of step 2 fails too | The fault is the key material or the code, not the data — go to [debugging-methodology-hypothesis-testing] with "wrong key bytes" and "wrong IV/tag handling" as the competing suspects |
| The "key loaded" log line is your only evidence the key is right | That is a probe of a different path than the failing operation ([debugging-methodology-probe-path-vs-operation-path]); the round-trip plus the row scan are the operation-path probes |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Debug the decrypt code because the key loads fine | Run the sentinel round-trip, then the read-only row scan | A passing round-trip beside a failing stored row locates the fault in key-to-data lineage, not in code |
| Delete rows on the first decryption error | Scan every row read-only and record `recoverable / total` first | A partial count means recoverable data exists; the count is also the evidence for the deletion decision |
| Let the init script regenerate the key on every run | Generate only when absent, warn loudly on overwrite | OWASP: "the code and processes required to rotate a key are in place before they are required" — rotation is a deliberate procedure that includes re-encryption |
| Keep a single key with no identifier on the ciphertext | Store a key version/id with each row | The next mismatch then fails as a lookup at the row, not as an authentication error indistinguishable from tampering |

## Sources

- https://cheatsheetseries.owasp.org/cheatsheets/Cryptographic_Storage_Cheat_Sheet.html — key rotation by "Decrypting it and re-encrypting it with the new key" or by "Marking each item with the ID of the key that was used to encrypt it, and storing multiple keys to allow the old data to be decrypted"; "old keys should … be stored for a certain period after they have been retired, in case old backups of copies of the data need to be decrypted"; "the code and processes required to rotate a key are in place before they are required"
- https://nodejs.org/api/crypto.html — for authenticated modes, when the tag does not verify "decipher.final() will throw, indicating that the cipher text should be discarded due to failed authentication" — a wrong key surfaces as this same error
- https://guides.rubyonrails.org/active_record_encryption.html — `config.active_record.encryption.previous = [ { key_provider: MyOldKeyProvider.new } ]` and the per-attribute `previous:` option: previous keys are kept so existing ciphertext stays readable through a rotation
- https://developers.google.com/tink/design/keysets — Tink can "prefix ciphertexts with a 5-byte string derived from the ID" of the key so decryption selects the key instead of trying every key in the keyset
- Field reproduction 2026-08-30 (linkly-calendar, `ChatEncryptionService`, AES-GCM, Node): the log showed "environment loaded (true)" and "decryption failed (keyVersion=1)" at the same second after `init:env` had been re-run and had regenerated the key; a read-only scan found 124/124 rows unrecoverable with the loaded key; the development rows were deleted and the service returned to normal
