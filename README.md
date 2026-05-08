# webrobot-scaleway-ansible-plugin

Reference **VM-adapter plugin** for the WebRobot platform that adds
[Scaleway](https://www.scaleway.com/) as a cloud-provider option for
elastic Spark VM provisioning. Distributed via the WebRobot marketplace
as a tech-partner bundle.

This is a working example: fork it, swap the implementation under
`ansible/roles/<provider>_adapter/tasks/main.yml`, and you have an
adapter for your own cloud (AWS / GCP / OVH / Vultr / …).

## What's inside

```
.
├── manifest.json                 # bundle manifest (providerKey, regions, prices, …)
├── ansible/
│   └── roles/
│       └── scaleway_adapter/
│           ├── tasks/main.yml    # the adapter itself (HTTP calls to api.scaleway.com)
│           └── meta/main.yml
├── scripts/package-bundle.sh     # builds dist/scaleway-vm-adapter-<v>.zip
└── README.md
```

## How the platform consumes this

When a super_admin approves the bundle, the WebRobot platform:

1. Records `provider_key=scaleway` in the `cloud_provider_adapters`
   registry (Postgres) — pointing to this bundle.
2. At every customer scale Job spawn, an init container
   (`vm-adapter-loader`) downloads the bundle ZIP from MinIO and unpacks
   `ansible/roles/scaleway_adapter/` into the Ansible Job pod.
3. The dispatcher playbook (`scale_customer_vm_agents.yml`) calls
   `include_role: name="scaleway_adapter"` whenever a customer has
   `vm_provider=scaleway` configured.

No platform rebuild, no playbook edit. Hot-pluggable.

See the platform docs for the full design:
- [`docs/CLOUD_ADAPTER_HOT_EXTENSIBILITY.md`](https://github.com/WebRobot-Ltd/webrobot-elt-clouddashboard/) — runtime architecture
- [`docs/CLOUD_PROVIDER_PARTNER_ADAPTER.md`](https://github.com/WebRobot-Ltd/webrobot-elt-clouddashboard/) — Ansible variable contract
- [`docs/INFRASTRUCTURE_PROVIDERS.md`](https://github.com/WebRobot-Ltd/webrobot-elt-clouddashboard/) — billing / metering model

## Adapter contract

Inputs read from the calling playbook:

| Variable | Required | Default | Description |
|---|---|---|---|
| `vm_action` | yes | — | `create` \| `delete` \| `list` \| `health` |
| `vm_api_token` | yes | — | Scaleway secret key (used as `X-Auth-Token`) |
| `vm_server_name` | for create/delete | — | server name |
| `vm_server_type` | no | `DEV1-S` | commercial type |
| `vm_image` | no | `ubuntu_jammy` | image alias or UUID |
| `vm_region` | no | `fr-par-1` | Scaleway zone (note: zone, not region) |
| `vm_ssh_key_refs` | no | `[]` | list of SSH-key UUIDs (TBD) |
| `vm_label_selector` | no | `''` | e.g. `customer-id=tenant-42` (translated to Scaleway tag) |
| `scw_project_id` | for create | env `SCW_DEFAULT_PROJECT_ID` | Scaleway project UUID |

Outputs (set_fact'd by the role):

| Variable | When | Description |
|---|---|---|
| `vm_health_status` | health | `ok` \| `fail` |
| `vm_fleet` | list | array of `{name, id, created, status, public_ip}` |
| `vm_server_id` | create | provider VM UUID |
| `vm_server_ip` | create | reachable IPv4 (or empty) |
| `vm_server_status` | create | `running` \| `starting` \| ... |
| `hcloud_scale_new_metadata` | create | dispatcher hand-off list (legacy name kept for compat) |

## Build & upload

```bash
./scripts/package-bundle.sh
# → dist/scaleway-vm-adapter-0.1.0.zip

webrobot bundle upload dist/scaleway-vm-adapter-0.1.0.zip
# Bundle lands as pending_approval. A super_admin reviews + approves
# from /dashboard/plugins/bundles.
```

After approval the adapter is **live** for any customer that selects
`vm_provider=scaleway` in their cloud-credential settings (UI in
`/dashboard/cloud-credentials`).

## Local dry-run

You can exercise the role without the platform — useful while iterating:

```bash
export SCW_API_TOKEN='your-secret-key'
export SCW_DEFAULT_PROJECT_ID='your-project-uuid'

ansible-playbook -i 'localhost,' --connection=local /dev/stdin <<'YAML'
- hosts: localhost
  roles:
    - role: scaleway_adapter
      vars:
        vm_action: health
        vm_api_token: "{{ lookup('env', 'SCW_API_TOKEN') }}"
YAML
```

Expected output: `vm_health_status=ok` if your token is valid.

## Repository layout for partners

The platform discovers the role at `ansible/roles/<ansibleRole>/` —
where `<ansibleRole>` matches `manifest.components[0].ansibleRole`. If
you ship multiple adapters in one bundle (e.g. `scaleway` + `vultr`),
list both as separate `components[]` and ship one role dir per adapter.

## Pricing & metering

The platform supports four pricing models on the bundle level
(`price_unit` field on `tech_partner_bundles`):

- `per_invocation` — 1 unit per `create`/`delete` call
- `per_minute_runtime` — 1 unit per VM-minute (recommended for cloud providers)
- `flat_monthly` — flat fee per active customer
- `free` — open-source / loss-leader adapters

Set pricing via the WebRobot dashboard:
**Marketplace → Bundles → Set pricing**. Stripe Transfers are made
monthly to the bundle owner's Connect account based on
`stage_usage_daily × pricing × revenue_share_percent`.

## License

Apache-2.0 — fork freely, no attribution required.
