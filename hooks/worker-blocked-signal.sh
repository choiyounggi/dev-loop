#!/usr/bin/env bash
# contract: t1-blocked-hook owns the implementation
#
# worker-blocked-signal.sh — Claude Code plugin hook (StopFailure, Notification,
# UserPromptSubmit). Inside the MANAGED tmux worker only, it records that the
# worker is blocked on something no human will answer, so the coordinator can
# wake immediately instead of waiting for the pane-hash stall heuristic.
#
# BlockedRecord (the contract t3-blocked-consume reads):
#   path   <worktree>/.orchestration/blocked/<task>.json   (worktree-relative;
#          never written into the coordinator checkout, issue #167)
#   fields exactly seven strings:
#     ts        date -u +%Y-%m-%dT%H:%M:%SZ  (same format as status updatedAt)
#     taskId    status record basename without .json
#     session   status record session ("" when absent)
#     event     StopFailure | Notification
#     reason    the StopFailure error value (unknown when absent), or the
#               notification_type
#     detail    error_details or message, first 300 characters ("" when absent)
#     worktree  physical cwd of the worker session
#   write  StopFailure (any error); Notification types permission_prompt,
#          idle_prompt, elicitation_dialog, elicitation_url_dialog,
#          agent_needs_input, worker_permission_prompt,
#          quota_auto_resume_stale, quota_auto_resume_disabled
#   clear  UserPromptSubmit; Notification quota_auto_resume_fired
#   last event wins.
#
# Meaning: the last blocking event since the last prompt submission or
# automatic usage-limit resume. A dialog answered by keys inside a running
# turn produces no clear event, so the file can outlive its block: a consumer
# treats the record as current only while its ts is later than the task's
# status updatedAt, combined with its own progress evidence.
#
# Always exits 0.
exit 0
