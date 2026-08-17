# CapRover Patch Targets

Runtime files modified for the assigned-conversations permission patch:

> Validated against Chatwoot v4.16.2 (upstream merge 2026-08-17). All 12
> targets below still carry the custom changes after the upgrade; no new
> runtime overlay files were required.

```json
{
  "TaskTemplate": {
    "ContainerSpec": {
      "Mounts": [
        {
          "Type": "bind",
          "Source": "/root/custom_chatwoot/app/finders/conversation_finder.rb",
          "Target": "/app/app/finders/conversation_finder.rb"
        },
        {
          "Type": "bind",
          "Source": "/root/custom_chatwoot/app/listeners/action_cable_listener.rb",
          "Target": "/app/app/listeners/action_cable_listener.rb"
        },
        {
          "Type": "bind",
          "Source": "/root/custom_chatwoot/app/listeners/notification_listener.rb",
          "Target": "/app/app/listeners/notification_listener.rb"
        },
        {
          "Type": "bind",
          "Source": "/root/custom_chatwoot/app/policies/conversation_policy.rb",
          "Target": "/app/app/policies/conversation_policy.rb"
        },
        {
          "Type": "bind",
          "Source": "/root/custom_chatwoot/app/services/conversations/permission_filter_service.rb",
          "Target": "/app/app/services/conversations/permission_filter_service.rb"
        },
        {
          "Type": "bind",
          "Source": "/root/custom_chatwoot/app/services/conversations/unread_counts/broadcast_scope.rb",
          "Target": "/app/app/services/conversations/unread_counts/broadcast_scope.rb"
        },
        {
          "Type": "bind",
          "Source": "/root/custom_chatwoot/app/services/conversations/unread_counts/counter.rb",
          "Target": "/app/app/services/conversations/unread_counts/counter.rb"
        },
        {
          "Type": "bind",
          "Source": "/root/custom_chatwoot/app/services/conversations/unread_counts/notifier.rb",
          "Target": "/app/app/services/conversations/unread_counts/notifier.rb"
        },
        {
          "Type": "bind",
          "Source": "/root/custom_chatwoot/app/services/messages/mention_service.rb",
          "Target": "/app/app/services/messages/mention_service.rb"
        },
        {
          "Type": "bind",
          "Source": "/root/custom_chatwoot/app/services/messages/new_message_notification_service.rb",
          "Target": "/app/app/services/messages/new_message_notification_service.rb"
        },
        {
          "Type": "bind",
          "Source": "/root/custom_chatwoot/app/services/search_service.rb",
          "Target": "/app/app/services/search_service.rb"
        },
        {
          "Type": "bind",
          "Source": "/root/custom_chatwoot/app/services/whatsapp/incoming_message_base_service.rb",
          "Target": "/app/app/services/whatsapp/incoming_message_base_service.rb"
        }
      ]
    }
  }
}
```
