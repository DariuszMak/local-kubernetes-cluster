# vault-agent.hcl
# Local dev Vault Agent config.
# The agent authenticates with the dev root token and renders a secrets
# template file that the Python app loads via load_dev_env().
#
# Run with: vault agent -config=vault/vault-agent.hcl

vault {
  address = "http://127.0.0.1:8200"
}

# Use token auth sink — simplest for local dev
auto_auth {
  method "token_file" {
    config = {
      token_file_path = ".vault-token-local"
    }
  }
}

# Write the rendered env file once and exit (no daemon needed for dev)
template {
  contents = <<-EOT
    {{- with secret "secret/data/python-project/dev" -}}
    {{- range $k, $v := .Data.data -}}
    {{ $k }}={{ $v }}
    {{ end -}}
    {{- end -}}
  EOT
  destination   = ".vault-secrets.env"
  perms         = "0600"
  # Render once then the agent can keep watching for rotation
}

# Exit after the first successful render (dev convenience)
# Remove exit_after_auth = true if you want the agent to stay alive
# and auto-rotate the file when secrets change in Vault.
exit_after_auth = true
