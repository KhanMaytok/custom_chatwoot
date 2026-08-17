# LLM Instructions — Upgrading this custom Chatwoot fork

Use this document whenever the task is "incorporate changes from the upstream
Chatwoot repo into this fork" or "upgrade custom_chatwoot to a newer version".

## Context

- This repo: `D:\ruby_proyects\custom_chatwoot` — custom fork of Chatwoot.
  Branch `master`, origin = `https://github.com/KhanMaytok/custom_chatwoot.git`.
  Its git history is **squashed** (a handful of commits, no upstream ancestry,
  no tags at fork time). All custom changes live in the tree of `master`.
- Upstream clone: `D:\ruby_proyects\chatwoot` — full history with release tags
  (`v4.15.1`, `v4.16.2`, ...). Its `develop` branch tree equals the latest
  merged release tag tree.
- Because this fork has no shared ancestry with upstream, a plain `git merge`
  or `git cherry-pick` cannot work. The procedure below builds a **synthetic
  merge base** so git can perform a real 3-way merge.

## Custom changes that MUST be preserved

### 1. Assigned-conversations permission patch (12 runtime files)

These are also listed in `caprover_targets.md` (the CapRover bind-mount
manifest). Behavior model (source of truth for conflict resolution):

- Administrator → sees all conversations, base unread counts.
- Agent (no custom role) → sees **only conversations assigned to them**
  (`:mine` mode).
- Agent with a custom role → governed by the enterprise overlay (upstream
  behavior); do not touch enterprise code.

| File | Custom behavior |
| --- | --- |
| `app/finders/conversation_finder.rb` | `participating` filter keeps the base scope via a subquery (`@conversations.where(id: ...select(:id))`) |
| `app/policies/conversation_policy.rb` | `agent_can_view_conversation?` → `assigned_to_user?` (was `inbox_access? \|\| team_access?`) |
| `app/services/conversations/permission_filter_service.rb` | non-admin → `accessible_conversations.assigned_to(user)` |
| `app/listeners/action_cable_listener.rb` | broadcast tokens = **assignee + admins** (`conversation_user_tokens`), with `previous_assignee_ids` support |
| `app/listeners/notification_listener.rb` | creation recipients = **assignee + admins** (`conversation_creation_recipients`) |
| `app/services/conversations/unread_counts/broadcast_scope.rb` | broadcast users = current + previous assignee (reads `changed_attributes` from the event) |
| `app/services/conversations/unread_counts/counter.rb` | `permission_mode`: admin → `:base`, agent → `:mine`, else `:none` (`conversation_permissions?` helper) |
| `app/services/conversations/unread_counts/notifier.rb` | dispatch **must include `changed_attributes:`** so the previous assignee gets refreshed |
| `app/services/messages/mention_service.rb` | valid mentionable users = admins + assignee |
| `app/services/messages/new_message_notification_service.rb` | participating-user notifications removed |
| `app/services/search_service.rb` | conversation/message search scoped via `Conversations::PermissionFilterService` (`permitted_conversations`) |
| `app/services/whatsapp/incoming_message_base_service.rb` | WhatsApp referral text appended to content (`referral_message_content`) + referral media attached (`attach_referral_media`) |

### 2. Repo hygiene changes

- `.github/` and `.vscode/` deleted; `.codegraph/.gitignore` and
  `caprover_targets.md` added; `CLAUDE.md` and `.windsurf/rules/chatwoot.md`
  materialized from symlinks.
- Many files are mode-only changes (`100755 → 100644`): a Windows checkout
  artifact. Harmless — preserve them, they never cause content conflicts.

### 3. Specs

`spec/...` files mirroring the 12 runtime files were adapted to the custom
permission model (e.g. "agent with inbox access but not assigned" → 401).
Preserve them.

### 4. Enterprise

The user runs **OSS**. Keep `enterprise/` 100% upstream unless the user
explicitly asks to change it. Do not adapt enterprise specs to the custom
permission model.

## Procedure (Windows PowerShell + git)

### 1. Preflight

- Both working trees must be clean.
- Identify the previous and new version tags in the upstream clone:
  `git -C D:\ruby_proyects\chatwoot tag -l "v4.*"`.
- Confirm the upstream checkout's tree equals the release tag:
  `git -C D:\ruby_proyects\chatwoot diff --stat v4.16.2 develop`
  (empty output = identical; use the tag as the merge target).

### 2. Fetch upstream into this repo (one-time setup)

```powershell
git remote add upstream D:/ruby_proyects/chatwoot   # only if not present
git fetch upstream tag v4.15.1 tag v4.16.2          # previous + new version
```

### 3. Understand the deltas

```powershell
git diff --name-status v4.15.1 master      # custom delta (expect ~111 files)
git diff --name-status v4.15.1 v4.16.2     # upstream delta
```

Compute the intersection and check for these hazards:

- Files modified by custom **and** changed upstream → real conflict candidates.
- Files deleted by custom that upstream modified → modify/delete conflicts.
- Upstream renames (`--diff-filter=R`) that touch custom-modified files →
  duplication risk.
- Remember that many "custom changes" are mode-only (`100755→100644`): they
  merge cleanly and are not real conflicts.

### 4. Review enterprise overrides of patched files

Check compatibility only (do not edit):

- `enterprise/app/policies/enterprise/conversation_policy.rb`
- `enterprise/app/finders/enterprise/conversation_finder.rb`
- `enterprise/app/services/enterprise/search_service.rb`
- `enterprise/app/services/enterprise/conversations/permission_filter_service.rb`

### 5. Backup the current master

```powershell
git branch pre-upgrade master
```

### 6. Build the synthetic merge base (the key trick)

```powershell
$tree = git rev-parse 'master^{tree}'
$parent = git rev-parse 'v4.15.1^{commit}'
$syn = git commit-tree $tree -p $parent -m 'chore: synthetic base (custom tree on upstream v4.15.1)'
git checkout -b upgrade-v4.16.2 $syn
```

### 7. Merge

```powershell
git merge v4.16.2 --no-ff -m "merge: integrate upstream v4.16.2 into custom fork"
```

### 8. Known conflict hotspots and their resolutions

- `app/services/conversations/unread_counts/notifier.rb`: adopt the upstream
  structure (`perform` + `dispatch_unread_count_changed` + feature-flag
  helpers) but **keep `changed_attributes: changed_attributes` in the
  dispatch**.
- `app/services/conversations/unread_counts/counter.rb`: usually auto-merges.
  Result must keep the custom `permission_mode` / `conversation_permissions?`
  **and** upstream `with_filtered_counts` / `filtered_counter`.
- `app/services/whatsapp/incoming_message_base_service.rb`: usually auto-merges
  (custom referral hunks vs upstream `set_conversation` coexistence changes).
- Specs: adapt upstream expectations to the custom model:
  - `spec/services/conversations/unread_counts/notifier_spec.rb` and
    `spec/controllers/api/v1/accounts/conversations_controller_spec.rb`:
    dispatch expectations become
    `.with(..., conversation: conversation, changed_attributes: nil)`.
  - Any spec asserting a non-admin sees unassigned / other-assigned
    conversations must be changed to "assigned only" (the OSS
    `permission_filter_service_spec.rb` is already adapted this way).
  - Leave `spec/enterprise/.../permission_filter_service_spec.rb` untouched.
- After resolving, `git add` every resolved file (otherwise `git commit`
  fails with "unmerged files").

### 9. Verification checklist

- No conflict markers in tracked text files:
  `rg -n "^(<<<<<<<|=======|>>>>>>>)"` (exclude lockfiles/binaries).
- `git diff v4.16.2 HEAD --name-only` ≈ the custom delta (extra files should
  only be deliberate spec adaptations).
- The 9 non-overlapping backend files must be byte-identical to pre-upgrade:

  ```powershell
  foreach ($f in @(
    'app/finders/conversation_finder.rb',
    'app/listeners/action_cable_listener.rb',
    'app/listeners/notification_listener.rb',
    'app/policies/conversation_policy.rb',
    'app/services/conversations/permission_filter_service.rb',
    'app/services/conversations/unread_counts/broadcast_scope.rb',
    'app/services/messages/mention_service.rb',
    'app/services/messages/new_message_notification_service.rb',
    'app/services/search_service.rb')) {
    git rev-parse "pre-upgrade:$f"; git rev-parse "HEAD:$f"
  }
  ```

- All 12 `caprover_targets.md` files still differ from the upstream tag
  (`git diff --quiet v4.16.2 HEAD -- <file>` → exit 1).
- `git diff pre-upgrade HEAD --stat` shows the full upstream delta.
- `VERSION_CW` and `package.json` version equal the new version.
- `git diff --check` clean (note: upstream `config/features.yml` line 6 has a
  pre-existing trailing space — ignore it, it exists in upstream too).

### 10. caprover_targets.md

- Re-check each of the 12 paths still carries the custom change.
- Add new entries **only if** the custom patch gained new runtime files
  (hasn't happened so far).
- Bump the validation note to the new version:
  `> Validated against Chatwoot v<NEW> (upstream merge <date>).`

### 11. Finish

```powershell
git commit -m "docs(caprover): validate patch targets against v4.16.2"   # if manifest changed
git update-ref refs/heads/master upgrade-v4.16.2
git checkout master
git push --force origin master     # history is replaced; use --force-with-lease when possible
```

The old master lineage remains reachable on the `pre-upgrade` branch.

## Deploy notes (tell the user)

- Run `bundle exec rails db:migrate` — upstream releases add migrations.
- `bundle install && pnpm install` before running the app.
- Ruby lives behind rbenv: `eval "$(rbenv init -)"` in bash; plain Windows
  PowerShell may not have `ruby` on PATH.
- Targeted specs to validate the patch:
  `bundle exec rspec spec/services/conversations spec/listeners/action_cable_listener_spec.rb spec/controllers/api/v1/accounts/conversations_controller_spec.rb`

## Known caveats (do not "fix" unless asked)

- `enterprise/app/services/enterprise/search_service.rb#advanced_search` still
  filters messages by inbox access, not assignment (pre-existing; OSS-only
  concern).
- `spec/enterprise/services/enterprise/conversations/permission_filter_service_spec.rb`
  assumes upstream behavior for regular agents and would fail if run against
  the custom permission model — the user runs OSS and enterprise specs are not
  executed; leave it upstream.
- Mode-only `100755 → 100644` changes are Windows artifacts — harmless.
